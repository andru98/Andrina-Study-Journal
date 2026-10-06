# PySpark Optimization Notes — Memory Management, Aggregation Strategy & File Formats

## 1. Executor Memory Management

When you launch a Spark job with `--executor-memory 8G`, that 8GB doesn't become one single usable pool — Spark carves it up into several distinct regions, each with a specific purpose.

### The memory breakdown — step by step

Starting from the requested **executor (heap) memory** (`spark.executor.memory`):

```
Step 1 — Reserved Memory (fixed, always 300 MB)
  Reserved for Spark's own internal engine operations.
  Not configurable, not counted toward your usable memory.

Step 2 — Usable memory = executor memory − 300 MB reserved

Step 3 — Split the usable memory via spark.memory.fraction (default 0.6)
  60% → Unified Memory  (storage + execution, shared pool)
  40% → User Memory     (RDD-related objects, user-defined data structures)

Step 4 — Split Unified Memory via spark.memory.storageFraction (default 0.5)
  50% → Storage Memory   (caching, persist())
  50% → Execution Memory (shuffle, sort, join, aggregation)
```

**Worked example — 2 GB executor memory:**
```
2048 MB (executor memory)
− 300 MB (reserved)
= 1748 MB usable

Unified memory  = 1748 × 0.6 ≈ 1 GB   →  500 MB storage + 500 MB execution
User memory     = 1748 × 0.4 ≈ 700 MB
```

### Storage vs. Execution — the eviction rule (important, asymmetric)

Storage and execution memory share the unified pool and can **borrow from each other when idle** — but the borrowing rule only runs one direction:

- **Execution memory CAN evict storage memory** (up to a configurable threshold) if it needs more room for an active shuffle/sort/join.
- **Storage memory CANNOT evict execution memory.** If execution is actively using its space, cached/persisted data simply cannot push it out.

**Worked example:** unified pool = 1GB (500MB storage / 500MB execution). You cache 700MB of data.
```
Execution currently needs 700 MB.
Only 300 MB of storage memory is "spare" (unused) — caching uses the rest of what's available in storage's allotment.
Execution is active and using its memory → storage CANNOT reclaim it, even under memory pressure.
Execution, however, CAN evict cached (storage) data if it needs more room.
```
**Why this asymmetry exists:** a running computation (execution) failing due to lack of memory crashes the job outright. A cache eviction (storage) just means re-computing or re-reading that cached data later — recoverable, just slower. Spark prioritizes correctness/completion over caching efficiency.

### Overhead Memory — outside the JVM entirely

```
spark.executor.memoryOverhead = max(384 MB, 0.1 × executor memory)
```
This is **non-heap** memory — outside the JVM, used for things like VM overhead, interned strings, and other native overhead the JVM garbage collector doesn't manage. It's requested from YARN **in addition to** your heap memory, not carved out of it.

**Worked example — the YARN error in these notes:**
```
spark-submit \
  --deploy-mode cluster --master yarn \
  --num-executors 1 --executor-cores 4 \
  --executor-memory 8G \
  --conf spark.dynamicAllocation.enabled=false \
  prog1.py
```
```
Requested heap memory:     8192 MB
Overhead (10% of 8192):     819 MB
PySpark memory:               0 MB
-------------------------------------
Total requested from YARN: 9011 MB

Error: exceeds yarn.scheduler.maximum-allocation-mb (cluster cap, e.g. 8192 MB)
```
**The lesson:** `--executor-memory 8G` does NOT mean YARN only needs to find 8GB for your container — it needs to find 8GB **plus** the overhead on top. If the cluster's configured max container size is exactly 8192MB, an 8GB executor request will *always* fail, because the real ask is ~9GB. Either request less heap memory, or raise `yarn.scheduler.maximum-allocation-mb` / `yarn.nodemanager.resource.memory-mb` at the cluster level.

### Off-Heap Memory — skipping the JVM garbage collector entirely

```
spark.memory.offHeap.enabled = true
spark.memory.offHeap.size    = 2g
```
Normal heap memory objects are managed by the JVM's garbage collector — which takes time (GC pauses) as object counts grow. **Off-heap memory sits outside the JVM entirely**, so there's no garbage collection overhead for data stored there — Spark manages it manually instead.

**Worked example:**
```
Executor (heap) memory: 2 GB → ~912 MB unified area (after reserved + fraction splits)
Off-heap memory:         2 GB (entirely separate region)

Total storage + execution memory available = 912 MB (on-heap) + 2 GB (off-heap) ≈ 2.9 GB
```
This effectively gives execution/storage a much larger working pool without expanding the GC-managed heap — useful for memory-intensive shuffles/joins where GC pauses were becoming a bottleneck.

### PySpark Memory — a cost unique to Python workloads

```
spark.executor.pyspark.memory
```
When you use Python UDFs or PySpark-specific operations (not pure Scala/Java Spark SQL), Spark has to spin up a **separate Python worker process** alongside the JVM to actually execute your Python code. That worker process needs its own memory allocation — this config sets a cap on it. (Scala/Java-only jobs don't need this at all, since there's no separate Python process involved.)

### Full config reference

| Region | Config | Default |
|---|---|---|
| Heap (JVM) | `spark.executor.memory` | required |
| Overhead (non-heap) | `spark.executor.memoryOverhead` | `max(384MB, 0.1 × executor memory)` |
| Off-heap | `spark.memory.offHeap.size` (+ `.enabled=true`) | 0 (disabled) |
| PySpark worker | `spark.executor.pyspark.memory` | unset |
| Unified vs. User split | `spark.memory.fraction` | 0.6 |
| Storage vs. Execution split (within unified) | `spark.memory.storageFraction` | 0.5 |

**Per-core budget — worked example (4GB executor, 4 cores):**
```
4096 MB − 300 MB reserved = 3796 MB usable
Unified memory ≈ 3796 × 0.6 ≈ 2.3 GB   (≈28% storage + ≈28% execution of total 4GB)
User memory    ≈ 3796 × 0.4 ≈ 1.5 GB

Unified memory per core = 2.3 GB / 4 cores ≈ 600 MB per core
```
This per-core figure is the realistic ceiling for how much a single task can hold in execution memory before it risks spilling to disk — the same calculation used when diagnosing shuffle spill (see the companion joins/shuffling notes).

---

## 2. Hash Aggregate vs. Sort Aggregate

When Spark executes a `GROUP BY` with aggregate functions, the physical plan chooses between two different execution strategies — and the difference in performance can be dramatic.

### Hash Aggregate — Spark's preferred, faster strategy (O(n))

```
hash table (built in execution memory)
key          value
1-january    2   →   1  (incremented as each matching row is seen)
2-february   1
3-january    1
```
**Mechanics:** Spark makes a **single linear pass** over the data. For each row, it hashes the group key, looks up (or creates) the corresponding entry in an in-memory hash table, and updates the accumulator directly — O(1) per row, so **O(n) total**.

### Sort Aggregate — the fallback strategy (O(n log n))

```
Unsorted partition:
1-january, 1-january, 2-february, 1-january, 2-february, 3-january, 1-january

Step 1 — Sort by key (O(n log n)):
1-january, 1-january, 1-january, 1-january, 2-february, 2-february, 3-january

Step 2 — Linear scan, aggregate consecutive matching keys:
1-january → 4
2-february → 2
3-january → 1
```
**Mechanics:** the data must first be **sorted by the grouping key**, so that all rows belonging to the same group are physically adjacent. Only then can Spark do a simple sequential scan, aggregating each contiguous run. The sort step is the expensive part.

### Why sort scales worse — the actual cost math

Sort cost follows `n × log₂(n)` comparisons; hash cost follows `n` lookups:
```
1,000 records:  log₂(1000) ≈ 10   →  1,000 × 10  = 10,000  "operations"
2,000 records:  log₂(2000) ≈ 11   →  2,000 × 11  = 22,000  "operations"
```
Notice that **doubling the data more than doubled the sort cost** (10,000 → 22,000, a 2.2× increase for a 2× data increase) — that extra `log n` factor is what makes sort aggregation scale worse than hash aggregation as data grows. This is exactly why, on the same underlying data, a sort-aggregate query (1.2 min) can run several times slower than a hash-aggregate query (15 sec) once data volume is large enough.

### Why does Spark ever choose the slower Sort Aggregate?

Hash Aggregate isn't always possible. Spark's query planner (Catalyst) falls back to Sort Aggregate when the aggregate expression can't be computed through a simple hash-table accumulator — for example, when:
- An aggregate needs the data in a specific **order** to compute correctly (e.g. certain ordered `first()`/`last()` usages, or aggregations that depend on sequence).
- Multiple **DISTINCT** aggregates are combined with regular aggregates in the same query, which usually requires an extra shuffle/sort pass to de-duplicate before counting.
- The aggregation buffer type isn't one Spark's hash-based path can manage efficiently in a fixed-size, mutable row format.

**The practical takeaway for interviews and real debugging:** run `.explain()` on your query. If you see `SortAggregate` where you expected `HashAggregate`, the fix is usually to look at *why* — often it's an unnecessary `DISTINCT`, an `ORDER BY`-dependent aggregate, or a UDAF that could be rewritten to avoid forcing a sort. Hash Aggregate is always the faster choice when the query logic allows it.

---

## 3. File Formats & Compression Techniques

A foundational question in any data engineering architecture: **how will the data actually be stored on disk?** This breaks into two decisions — **file format** and **compression technique** — and both affect storage cost, processing speed, and I/O cost.

### Row-based vs. Column-based formats

| | Row-based | Column-based |
|---|---|---|
| Writing | Fast, simple — write one row at a time | Slower — must group and write by column |
| Reading a subset of columns | Inefficient — must read entire row even for 1 column | Efficient — reads only the needed column chunks |
| Compression | Less effective (mixed data types per row) | Very effective (similar values grouped together) |

```sql
SELECT order_id, customer_id FROM orders
```
In a **row-based** format, satisfying this query still requires reading every column of every row (including columns you didn't ask for), then discarding what's unneeded. In a **column-based** format, only the `order_id` and `customer_id` column data is read from disk — the rest is skipped entirely.

### Text formats — CSV, JSON, XML

Used widely for simplicity and human-readability, but costly at scale:

- **Everything is stored as text**, even numbers. `90123490` as text takes **16 bytes**; the same value as a native integer takes **4 bytes** — a 4× storage penalty before compression even enters the picture.
- Every read requires **type conversion** (string → int, string → date, etc.), which costs CPU time on every single query.
- **JSON/XML add extra overhead**: the structure (brackets, field names repeated per record) bloats file size further, and these formats are generally **not splittable** — a large JSON/XML file can't be cleanly divided across parallel tasks the way a well-structured binary format can.

```json
{"order_id":1,"order_date":"2013-07-25","customer_id":11599,"order_status":"CLOSED"}
```
Every record repeats the field names (`order_id`, `order_date`, ...) — pure overhead compared to a format that stores the schema once.

**Net effect of text formats:** more storage, slower processing (type conversion overhead), more I/O.

### Specialized formats — Avro, ORC, Parquet

| Format | Orientation | Best fit | Key trait |
|---|---|---|---|
| **Avro** | Row-based | General purpose, landing-zone storage | Fast writes, schema stored with data (self-describing) |
| **ORC** | Column-based | Hive | Highly efficient storage & reads |
| **Parquet** | Column-based | Spark | Highly efficient storage & reads |

All three: support **schema evolution**, are **splittable**, and support **any compression codec** (the codec used is recorded right in the file's metadata — unlike CSV/JSON, which are restricted to fewer compression options).

**Avro** trades read speed for write speed and portability — a good fit for the "landing zone" of a data lake where you're ingesting raw data quickly and figuring out downstream processing later.

**ORC/Parquet** trade write speed for read speed and storage efficiency — the right choice once data is being queried repeatedly (which is most of the time, for most pipelines).

### Lightweight compression techniques used inside ORC/Parquet

- **Dictionary encoding** — for low-cardinality columns (e.g. 1 million records but only 50 distinct US states), build a small lookup dictionary (`karnataka→1, andhra pradesh→2, ...`) and store the short integer code instead of repeating the full string value millions of times.
- **Bit packing** — once dictionary-encoded, values are small integers; bit packing stores them using only as many bits as needed (e.g. 5 bits for a dictionary of 25 entries) instead of a full 32-bit integer.
- **Delta encoding** — for monotonically increasing values like timestamps, store only the *difference* from the previous value instead of the full value each time (`12:49:00, +1s, +1s, +1s...` instead of repeating full timestamps).
- **Run-length encoding (RLE)** — for columns with long runs of repeated values (e.g. a status column with a million `0`s in a row), store the value once plus a repeat count instead of writing the value a million times.

### Parquet file internals

```
File structure:
  Header  → "PAR1" magic bytes
  Body    → Row Groups → Column Chunks → Pages
  Footer  → Metadata
```

**Worked example — a 500MB Parquet file, 80,000 rows:**
```
Row Group 1 (20,000 rows)
  ├── Column chunk: order_id    → ~20 pages (~1 MB) — each page has min/max metadata
  ├── Column chunk: order_date  → ~40 pages
  ├── Column chunk: customer_id → N pages
  └── Column chunk: order_status→ N pages
Row Group 2 (20,000 rows) ... same structure
Row Group 3 (20,000 rows) ...
Row Group 4 (20,000 rows) ...
```
Default row group size target is ~128MB. Each page within a column chunk stores its own **min/max statistics**.

**Predicate pushdown (row-group / page skipping):**
```sql
SELECT * FROM orders WHERE order_id = 45
```
Since each row group's metadata records the min and max `order_id` present in it, Spark can check that metadata *before* reading any actual data — any row group whose min/max range doesn't contain `45` is skipped entirely, with zero I/O spent on it.

**Column/projection pushdown:**
```sql
SELECT order_id, customer_id FROM orders
```
Only the `order_id` and `customer_id` column chunks are read from each row group — `order_date` and `order_status` are never touched. This is the mechanical reason column-based formats are so much faster for wide tables when you only need a few columns.

**Real-world cost relevance (cloud query engines):** services like AWS Athena and Azure Synapse Serverless charge **by the amount of data scanned**, not by query run time. A predicate + column pushdown that reduces a scan from 20TB down to 5GB (because most row groups and columns get skipped) is a direct, measurable cost saving — not just a performance one.

### Schema evolution example

Parquet/ORC/Avro all tolerate a folder of files written at different points in time with **different schemas**, as long as changes are additive/compatible:
```
orders1.csv → orderid, orderdate
orders2.csv → orderid, orderdate, customerid
orders3.csv → orderid, orderdate, customerid, order_status
orders4.csv → orderid, orderdate, order_status, customerid   (column order changed too)
```
A query engine reading the whole folder as one logical table resolves these differences using each file's embedded schema metadata — new columns appear as `null` for older files that predate them, and column order doesn't need to match exactly since columns are matched by name, not position.

### Compression techniques — trade-offs

| Technique | Compression ratio | Speed | Splittable? | Notes |
|---|---|---|---|---|
| **Snappy** | Moderate | Very fast | No (on CSV/text) | Default for Parquet/ORC; fine when used inside a splittable container format |
| **LZO** | Moderate | Fast | Yes | Requires a separate license (not bundled with standard Hadoop distributions) |
| **Gzip** | Good (~2.5× better than Snappy) | Slow | No | Not splittable — container formats needed to still parallelize |
| **Bzip2** | Very good (~9% better than Gzip) | Very slow (~10× slower than Gzip) | Yes | Best for archival / cold storage where compute cost matters less than storage cost |

**Important nuance:** "not splittable" for Snappy/Gzip applies to **raw text files** (CSV compressed directly). When Snappy or Gzip is used **inside a container format** like Parquet, ORC, or Avro, splittability is preserved — because the container format itself is structured into independently-readable chunks (row groups), and compression is applied *within* those chunks rather than across the whole file.

**Benchmark results from this demo (same source dataset, 1.1GB raw CSV):**

| Format + compression | Size | Partitions | Splittable |
|---|---|---|---|
| CSV (raw) | 1.1 GB | 9 | — |
| CSV + Snappy | 313 MB | 1 | No |
| CSV + Gzip | 168 MB | 1 | No |
| CSV + Bzip2 | 139 MB | 2 | Yes |
| Parquet + Snappy | 109 MB | 2 | Yes |
| Parquet + Gzip | 101 MB | 2 | Yes |
| ORC + Snappy | 59 MB | 2 | Yes |
| ORC + LZO | 52 MB | 2 | Yes |

**The pattern this reveals:** switching to a columnar container format (Parquet/ORC) delivers a bigger storage win than compression algorithm choice alone — ORC+Snappy (59MB) beats CSV+Bzip2 (139MB) despite Bzip2 being the strongest compression algorithm in the table. Format choice and compression choice compound together, but format choice matters more.

**Choosing a technique in practice:**
- **Snappy/LZO** — default choice for active, frequently-queried data: moderate compression, fast enough that it rarely becomes the bottleneck.
- **Gzip/Bzip2** — reach for these when storage cost dominates over query speed, such as **archival** data that's rarely read — the slower decompression cost is paid infrequently, so it's worth it for the smaller footprint.

---

## Quick Reference — Decision Checklist

- **Hitting a YARN "exceeds maximum allocation" error?** → Remember overhead memory is *added on top of* `--executor-memory`, not carved from it — reduce requested heap or raise the cluster's max allocation setting.
- **Seeing unexpected cache evictions under memory pressure?** → Expected — execution memory can always evict storage memory, never the reverse.
- **`.explain()` shows `SortAggregate` where you expected `HashAggregate`?** → Look for `DISTINCT` combined with other aggregates, or an ordering-dependent aggregate function — that's usually the trigger.
- **Designing storage for a new pipeline?** → Land raw/streaming data as Avro or plain files; convert to Parquet (Spark) or ORC (Hive) once it's being queried repeatedly.
- **Choosing a compression codec?** → Snappy/LZO for hot, frequently-queried data; Gzip/Bzip2 for cold/archival data where storage cost outweighs read speed.
- **Query engine billed by data scanned (Athena/Synapse Serverless)?** → Columnar format + predicate/column pushdown directly reduces cost, not just latency.
