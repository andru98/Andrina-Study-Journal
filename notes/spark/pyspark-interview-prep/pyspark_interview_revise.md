# PySpark Optimization Notes — Joins, Shuffling & Partition Skew

## 1. How `groupBy` Works Internally

Whenever a **wide transformation** runs (anything that shuffles — `groupBy`, `join`, `orderBy`, `distinct`), Spark splits the shuffled output into **200 shuffle partitions by default** (`spark.sql.shuffle.partitions`), regardless of how much actual data exists.

**Example:** `SELECT order_status, COUNT(*) FROM orders GROUP BY order_status`

If `order_status` only has **9 distinct values** (e.g. `closed`, `complete`, `pending`, ...), then at most **9 of the 200 shuffle partitions will ever hold data** — one per key (assuming no further key-skew within a key, which is a separate problem). The remaining **191 partitions are empty**.

```
p1 (closed):    2000 records
p1 (complete):  3000 records
p1 (pending):   1000 records
p2 (closed):    1000 records
...
p9 (closed):    1500 records
```

**Why this is a problem:** the task scheduler still has to schedule and launch a task for *every* one of the 200 partitions — including the 191 empty ones. Each task has fixed overhead (launch, serialization, coordination with the driver) regardless of whether it processes any rows. That's pure waste at scale.

**Fix:** enable AQE's `coalescePartitions` (see §3) so Spark detects the empty/tiny partitions after the shuffle and merges them down to a sensible number — instead of blindly scheduling 200 tasks for 9 keys' worth of data.

---

## 2. Join Types in Spark

Given:
```
orders                          customers
order_id | customer_id | status     customer_id | city
101      | 1           | closed     1           | bangalore
102      | 2           | complete   2           | pune
103      | 3           | pending    5           | mumbai
104      | 4           | closed
```

| Join type | Returns | Row count (example) |
|---|---|---|
| **Inner** | Only matching rows from both sides | customer_id 1, 2 → **2 rows** |
| **Left outer** | All left rows + matches from right (nulls where no match) | 1,2 matched + 3,4 padded with null → **4 rows** |
| **Right outer** | All right rows + matches from left (nulls where no match) | 1,2 matched + 5 padded with null → **3 rows** |
| **Full outer** | Everything — matched + unmatched from both sides, nulls padded either direction | 1,2 matched + 3,4 (null right) + 5 (null left) → **5 rows** |
| **Left semi** | Left-table rows that **have** a match in the right table — only left's own columns, right is never pulled in | "Which customers placed at least one order?" |
| **Left anti** | Left-table rows that have **no** match in the right table | "Which customers never placed an order?" |

**`left_semi` / `left_anti` equivalence in SQL:** `left_semi` ≡ `EXISTS (...)`, `left_anti` ≡ `NOT EXISTS (...)`. They're preferred over `inner join + dropDuplicates()` because they never duplicate rows from the join key in the first place — cheaper, and the optimizer can use a more efficient physical plan.

---

## 3. Join Strategies

### a) Broadcast Hash Join (map-side join)
Used when one side of the join is small enough to fit in memory and be copied to every executor.

```
orders:    1.1 GB (9 partitions)
customers: 2 MB

Default broadcast threshold: 10 MB (spark.sql.autoBroadcastJoinThreshold)
→ customers (2MB) < 10MB → gets broadcast
```

**Mechanics:**
1. The driver collects the small table (`customers`) in full.
2. It's converted into a **hash table** for O(1) lookups.
3. A full copy of that hash table is sent (broadcast) to **every executor**.
4. Each executor then joins its local partition of the large table (`orders`) against the in-memory hash table — **no shuffle of `orders` is needed at all.**

```
Executor 1: orders partition 1 + full customers hash table (local)
Executor 2: orders partition 2 + full customers hash table (local)
Executor 3: orders partition 3 + full customers hash table (local)
```

This is the fastest join strategy when applicable — it completely avoids the expensive network shuffle of the large table.

### b) Shuffle Hash Join
Used when **neither** table is small enough to broadcast, but there's still a meaningful size difference (one large, one medium).

- Both tables get shuffled so that matching keys land in the same partition (200 shuffle partitions by default).
- The **smaller** side of each matched partition pair is built into a hash table (per-partition, not broadcast to the whole cluster) so the join itself is a fast hash lookup rather than a full scan.

### c) Sort Merge Join (default/preferred for two large tables)
Used when **both** tables are large — broadcasting isn't viable for either side.

1. **Shuffle:** both tables are shuffled on the join key so matching keys land in the same executor/partition.
2. **Sort:** each partition is sorted by the join key (O(n log n)).
3. **Merge:** two sorted lists can be merged in a single linear pass — this is the actual join step.

This is Spark's go-to strategy for large-large joins because it scales better than shuffle hash join and doesn't require either side to fit fully in memory as a hash table.

---

## 4. Partitioning vs. Bucketing

### Partitioning (directory-based)
```python
orders_df.write.partitionBy("order_status").parquet("output/")
```
If `order_status` has 9 distinct values, you get **9 separate folders**, one per value:
```
output/order_status=closed/
output/order_status=complete/
output/order_status=pending/
...
```
A query like `SELECT * FROM orders WHERE order_status = 'closed'` can skip straight to the relevant folder (**partition pruning**) without scanning the rest.

⚠️ Only use `partitionBy` on **low-cardinality** columns — a high-cardinality column (e.g. `customer_id` with millions of values) creates millions of tiny folders/files — the "small files problem."

### Bucketing (hash-based, within files)
```python
orders_df.write.bucketBy(8, "order_id").sortBy("order_id").saveAsTable("orders_bucketed")
```
- You specify a **fixed number of buckets** (e.g. 8) and a bucket column (e.g. `order_id`).
- A hash function (`hash(order_id) % 8`) decides which of the 8 buckets each row goes to.
- `orders` (1.1GB, 9 initial partitions) × 8 buckets → up to 9 × 8 = 72 files written.
- Useful for point lookups (`WHERE order_id = ?`) and, more importantly, for **SMB joins** (below).

---

## 5. Sort Merge Bucket (SMB) Join

**When it applies:** both tables are large, **both are bucketed on the same join column**, and **both have the same number of buckets**.

**Why it's fast — shuffle is skipped entirely:**
Since both tables hash the join key with the *same* function and *same* modulus, rows with a given key always land in the **same bucket number** in both tables — this was guaranteed back when the tables were written to disk, not recalculated at query time.

```
orders bucket 1  ↔  customers bucket 1   (same keys, guaranteed)
orders bucket 2  ↔  customers bucket 2
...
```

Spark just pairs up matching bucket numbers directly, and since each bucket's data is already sorted, it's a straightforward **merge** — no `Exchange` (shuffle) step appears in the physical plan at all.

**Real-world payoff (one-time cost vs. recurring cost):**
```
Joining 2 tables of 1TB each, repeatedly, without bucketing:
~30 minutes per join run × many runs = adds up fast

Bucketing: one-time cost to write the bucketed tables
≈ 5 hours total, done once

After that: each join run drops to ~10 minutes
```
The upfront bucketing cost pays for itself quickly if the same large tables get joined repeatedly (e.g. a recurring pipeline).

**Requirement:** this only works when bucket counts match on both sides — if table A has 8 buckets and table B has 16, Spark can't pair them 1:1 and falls back to a shuffle.

---

## 6. Partition Skew & Salting

**The problem:** even with the "right" number of shuffle partitions, if one key is far more common than the others (a **dominating key**), that one partition ends up massively larger than the rest — while other partitions sit mostly empty.

```
Example — joining orders with distinct customers:
customers: 14 files, ~12 MB total, 2 initial partitions
  Partition 1: 7 files, 12,435 records
  Partition 2: 7 files, 12,435 records
```
```
Example — status counts with a dominating key:
complete1: 1,000
complete2: 2,000
complete1 + complete2 combined: 4,500   ← dominant/skewed key
complete3: 1,500
```
One task ends up doing far more work than the others — it becomes the straggler that the whole job waits on, and it's the task most likely to spill to disk or OOM.

**Salting — the fix:** artificially split a dominant key into multiple sub-keys by appending a random "salt" value, spreading what was one giant partition across several smaller ones. (Requires a matching change on the other side of the join — appending the same salt range to the smaller table's matching rows, often via explode, so the salted keys still line up.)

---

## 7. Adaptive Query Execution (AQE)

| | Spark 3.0 | Spark 3.2+ |
|---|---|---|
| Availability | Must enable manually (`spark.sql.adaptive.enabled=true`) | **Enabled by default** |

AQE works by collecting **runtime statistics during the shuffle** — actual record counts, actual data size, min/max per column, and frequency counts per key — rather than relying on pre-execution estimates. With that real information, it can make three key optimizations:

### a) Dynamically coalescing shuffle partitions
Addresses the "200 shuffle partitions but only 9 have data" problem from §1. After seeing actual partition sizes, AQE merges small/empty **adjacent** partitions together, cutting down wasted task-scheduling overhead.
```python
spark.conf.set("spark.sql.adaptive.coalescePartitions.enabled", "true")
```

### b) Dynamically handling partition skew
Addresses the dominating-key problem from §6 — automatically, without manual salting. AQE detects an oversized partition at runtime and **splits** it into smaller sub-partitions.
```python
spark.conf.set("spark.sql.adaptive.skewJoin.enabled", "true")
```

### c) Dynamically switching join strategies
If a highly selective filter (e.g. `WHERE order_status = 'rare_value'`) shrinks one side of a join down below the broadcast threshold **at runtime** — even though it didn't look small enough before the filter ran — AQE can switch the physical join plan from sort-merge to **broadcast** on the fly, after seeing the post-filter size.

---

## Quick Reference — Decision Checklist

- **One table < 10MB?** → Broadcast join happens automatically (map-side join, no shuffle).
- **Both tables large, one-off join?** → Sort merge join (default).
- **Both tables large, joined repeatedly?** → Consider bucketing both on the join key with matching bucket counts → SMB join (no shuffle).
- **Seeing 191/200 empty partitions in Spark UI?** → Enable/verify `coalescePartitions`.
- **One task taking way longer than the rest (straggler)?** → Check for partition skew; enable `skewJoin` or apply salting manually.
- **Filtering heavily before a join?** → AQE may auto-switch join strategy post-filter if a side becomes broadcast-eligible.
