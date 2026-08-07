# Query Optimization — Interview Notes
> Covers: EXPLAIN plans, scan types, join algorithms, optimization techniques, common mistakes, platform differences
> Last updated: 2026-07-10

---

## Table of Contents
1. [How Query Engines Work](#1-how-query-engines-work)
2. [EXPLAIN vs EXPLAIN ANALYZE](#2-explain-vs-explain-analyze)
3. [Reading EXPLAIN Output](#3-reading-explain-output)
4. [The Cost Model](#4-the-cost-model)
5. [Key Scan Types](#5-key-scan-types)
6. [Key Join Types](#6-key-join-types)
7. [How Hash Join Works Internally](#7-how-hash-join-works-internally)
8. [Where Joins Happen — Memory vs Disk](#8-where-joins-happen--memory-vs-disk)
9. [Optimization Techniques](#9-optimization-techniques)
10. [Common Performance Killers](#10-common-performance-killers)
11. [Common Mistakes](#11-common-mistakes)
12. [Platform-Specific EXPLAIN](#12-platform-specific-explain)
13. [The 8020 Rule](#13-the-8020-rule)
14. [Top Interview Questions and Answers](#14-top-interview-questions-and-answers)

---

## 1. How Query Engines Work

Every SQL query goes through four stages before returning results:

```
Stage 1: PARSER
→ checks syntax is correct
→ resolves table names and column names
→ "does this SQL make sense?"

Stage 2: OPTIMIZER ← most important
→ generates many possible execution plans
→ estimates cost of each plan using statistics
→ picks cheapest plan
→ decides: index or full scan? which join algorithm?

Stage 3: PLANNER
→ converts chosen strategy into physical steps

Stage 4: EXECUTOR
→ actually runs the plan
→ returns results
```

**The optimizer is not psychic.** It relies on statistics — row counts, value distributions, null fractions. If statistics are stale, the optimizer makes bad choices. Always run `ANALYZE` after large data loads.

---

## 2. EXPLAIN vs EXPLAIN ANALYZE

```sql
-- EXPLAIN: shows plan WITHOUT running query (safe, instant)
EXPLAIN SELECT * FROM orders WHERE order_date >= '2024-01-01';

-- EXPLAIN ANALYZE: shows plan AND runs query (real numbers)
EXPLAIN ANALYZE SELECT * FROM orders WHERE order_date >= '2024-01-01';
```

**Always use EXPLAIN first:**

```
EXPLAIN:
→ safe — doesn't run query
→ instant — no waiting
→ shows estimated plan
→ identify obvious problems first

EXPLAIN ANALYZE:
→ actually runs query — dangerous on writes
→ shows real execution times
→ shows real vs estimated row counts
→ use AFTER identifying suspect area with EXPLAIN
```

**EXPLAIN ANALYZE on writes — wrap in transaction:**

```sql
-- Safe way to analyze DELETE/UPDATE
BEGIN;
EXPLAIN ANALYZE DELETE FROM orders WHERE date < '2024-01-01';
ROLLBACK;  -- ← undoes the delete ✅
```

**PostgreSQL EXPLAIN with extra options:**

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) SELECT ...;

-- ANALYZE  → real execution times
-- BUFFERS  → cache hits vs disk reads
--            hit=980 (from memory ✅) read=20 (from disk ❌)
-- FORMAT JSON → machine-readable output for tools
```

---

## 3. Reading EXPLAIN Output

**Always read bottom up — deepest indented = runs first:**

```
HashAggregate  (cost=1250.00..1260.00 rows=500)
  →  Hash Join  (cost=45.00..1200.00 rows=5000)
        →  Seq Scan on orders  (cost=0.00..1100.00 rows=5000)
              Filter: (order_date >= '2024-01-01')
        →  Seq Scan on customers  (cost=0.00..35.00 rows=1000)

Reading order:
1. Seq Scan on customers → runs first
2. Seq Scan on orders → runs second
3. Hash Join → combines results
4. HashAggregate → groups and counts → final result
```

**EXPLAIN ANALYZE output — two lines per node:**

```
Hash Join
    (cost=45.00..1200.00 rows=5000)      ← ESTIMATED
    (actual time=0.8..12.5 rows=4823     ← ACTUAL
     loops=1)

estimated rows=5000 vs actual rows=4823 → close → good ✅
estimated rows=100  vs actual rows=50000 → 500x off → bad statistics ❌
→ run ANALYZE to fix
```

**Key fields:**

```
cost=startup..total   startup = cost before first row returned
                      total   = cost to return all rows
                      NOT milliseconds — arbitrary comparison units

actual time=first..last  first = time to first row (ms)
                         last  = time to last row (ms)

rows=N    how many rows this node produced
loops=N   how many times this node ran (>1 in nested loops)
```

---

## 4. The Cost Model

PostgreSQL uses unit costs to compare plans:

```
seq_page_cost    = 1.0   ← baseline: sequential disk page read
random_page_cost = 4.0   ← random disk read (4x more expensive)
cpu_tuple_cost   = 0.01  ← process one row in CPU

Cost formula for Seq Scan:
cost = (pages × seq_page_cost) + (rows × cpu_tuple_cost)
     = (100 × 1.0) + (1000 × 0.01)
     = 100 + 10 = 110.0
```

**These are NOT milliseconds — only useful for comparing plans.**

Why random_page_cost is 4x:
```
Sequential reads → disk reads pages in order → fast
Random reads     → disk jumps to specific pages → slow (4x)
Index Scan uses random reads → sometimes Seq Scan is cheaper
for large result sets
```

**Spotting suspicious costs:**

```
One node = 87% of total query cost → that is your bottleneck
Seq Scan on large table with selective filter → missing index
Cost dramatically higher than similar known-fast queries → investigate
```

---

## 5. Key Scan Types

### Sequential Scan (Seq Scan)

```
What: reads every row in table from start to finish
When good: small tables, no useful index, returning most rows
When bad: large table with selective filter (missing index)

EXPLAIN shows:
Seq Scan on orders (cost=0.00..50000.00 rows=1000000)
Filter: (order_date = '2024-01-15')
→ reads 1M rows to find maybe 100 → wasteful ❌
→ solution: CREATE INDEX on order_date
```

### Index Scan

```
What: uses index to find rows, then fetches full row from table
When good: selective queries returning under 5-10% of rows
When bad: returning most of table (index overhead not worth it)

Two steps:
1. search index → find row pointer (random read)
2. follow pointer → fetch full row from table (random read)
```

### Index Only Scan

```
What: answers query entirely from index — never touches main table
When: all needed columns are in the index
Why fastest: one lookup instead of two

SELECT order_date FROM orders WHERE order_date = '2024-01-15'
→ index has order_date ✅ → no table fetch needed ✅
```

### Bitmap Index Scan

```
What: builds bitmap of matching pages, then reads those pages
When: medium selectivity (5-25% of rows)
Why: batches random reads into more sequential pattern
     better than Index Scan for medium result sets
```

### Scan type decision:

```
< 5% rows    → Index Scan (precise, random reads)
5-25% rows   → Bitmap Index Scan (batched reads)
> 25% rows   → Seq Scan (sequential, cheaper per page)
No index     → Seq Scan always
```

---

## 6. Key Join Types

### Nested Loop Join

```
How: for each outer row, scan inner side
Cost: O(N × M) — catastrophic when both sides large

For each customer (N=1000):
    scan all orders (M=1000000)
    → 1,000,000,000 comparisons ❌

Good: small outer table + indexed inner table
Bad:  both tables large → avoid at all costs

⚠️ Warning: Nested Loop where both sides have thousands of rows
→ almost always a problem
→ check for missing index on inner table
→ check if statistics are wrong
```

### Hash Join

```
How: build hash table from smaller table, probe with larger table
Cost: O(N+M) — much better than Nested Loop

Step 1 (Build): read smaller table → build hash table in memory
Step 2 (Probe): for each row in larger table → O(1) hash lookup

Why O(1) not O(log N):
→ hash function maps directly to bucket
→ no searching needed → constant time

Good: medium to large tables, equality joins (=)
Bad:  hash table doesn't fit in memory → spills to disk
```

### Merge Join

```
How: both sides sorted, merge together like a zipper
Cost: O(N log N + M log M) — sort cost + linear merge

Good: pre-sorted data, large tables, range conditions
Bad:  unsorted data (adds sort cost)
```

### Join algorithm comparison:

```
Nested Loop no index:  O(N × M)          ← avoid
Nested Loop + index:   O(N × log M)      ← better
Hash Join:             O(N + M)           ← best for large tables
Merge Join:            O(N logN + M logM) ← best if pre-sorted
```

---

## 7. How Hash Join Works Internally

```
customers (N=1000, smaller):    orders (M=1000000, larger):
id | name                       id | customer_id | amount
1  | Anna                       1  | 1           | 100
2  | Bob                        2  | 1           | 200

Build phase — read customers → hash table in RAM:
hash("1") → bucket 3 → {id=1, name=Anna}
hash("2") → bucket 7 → {id=2, name=Bob}

Probe phase — for each order row:
order 1: customer_id=1 → hash("1") → bucket 3 → Anna ✅ (instant)
order 2: customer_id=1 → hash("1") → bucket 3 → Anna ✅ (instant)

Total: O(N) build + O(M) probe = O(N+M)
Each probe = O(1) hash lookup not O(log N) binary search
```

**Hash Join vs Index:**

```
Hash Join:              Index:
Temporary in memory     Permanent on disk
Built per query         Built once, used forever
O(1) lookup             O(log N) lookup
No setup needed         Must CREATE INDEX
Gone after query        Persists forever
```

---

## 8. Where Joins Happen — Memory vs Disk

**Joins happen in RAM (work_mem in PostgreSQL):**

```
Slow query — join then aggregate:
facts (10M rows on DISK) → loaded into RAM
→ joined to dims → 10M joined rows in RAM ← problem!
→ 10M × 62 bytes = 620MB RAM needed
→ if RAM exceeded → spills to disk → very slow

Fast query — aggregate then join:
facts (10M rows) → GROUP BY in RAM → 1000 rows ← reduced!
→ join 1000 rows to dims → tiny join in RAM ✅
→ no disk spill risk
```

**work_mem setting:**

```sql
SHOW work_mem;          -- default 4MB per operation
SET work_mem = '256MB'; -- increase for heavy queries
-- each sort/hash/join gets this much RAM
-- exceeded → spills to temp disk files → slow
```

---

## 9. Optimization Techniques

### Technique 1 — Add targeted indexes

```sql
-- Run EXPLAIN first → find Seq Scan on large table
-- Add index on that column

-- Missing index on WHERE column:
CREATE INDEX idx_orders_date ON orders(order_date);

-- Missing index on JOIN column (foreign key):
CREATE INDEX idx_orders_customer_id ON orders(customer_id);

-- Composite index for multiple conditions:
CREATE INDEX idx_orders_date_status ON orders(order_date, status);
-- left-most prefix rule: helps WHERE order_date + status
--                        helps WHERE order_date alone
--                        does NOT help WHERE status alone
```

### Technique 2 — Rewrite correlated subqueries as JOINs

```sql
-- SLOW: correlated subquery runs once per outer row
SELECT name FROM customers c
WHERE salary > (
    SELECT AVG(salary) FROM employees e
    WHERE e.department = c.department  -- ← references outer row
);
-- 100K customers = 100K subquery executions ❌

-- FAST: calculate once, join result
WITH dept_avg AS (
    SELECT department, AVG(salary) AS avg_salary
    FROM employees
    GROUP BY department   -- runs ONCE ✅
)
SELECT c.name
FROM customers c
JOIN dept_avg d ON c.department = d.department
WHERE c.salary > d.avg_salary;
```

### Technique 3 — EXISTS instead of IN for large subqueries

```sql
-- SLOW: IN materializes entire subquery result in memory
SELECT * FROM orders
WHERE customer_id IN (
    SELECT id FROM customers WHERE country = 'US'
);
-- stores ALL US customer IDs in memory
-- must check entire list for each order ❌

-- FAST: EXISTS short-circuits on first match
SELECT * FROM orders o
WHERE EXISTS (
    SELECT 1 FROM customers c
    WHERE c.id = o.customer_id
    AND c.country = 'US'
);
-- finds first match → stops immediately ✅
-- no full list materialization
-- 5-10x faster for large subqueries
```

### Technique 4 — Pre-aggregate before joining

```sql
-- SLOW: join 10M rows then aggregate
SELECT d.name, SUM(f.amount)
FROM facts f              -- 10 million rows
JOIN dims d ON f.dim_id = d.id
GROUP BY d.name;
-- produces 10M joined rows in memory → then aggregates ❌

-- FAST: aggregate to 1000 rows then join
SELECT d.name, agg.total
FROM (
    SELECT dim_id, SUM(amount) AS total
    FROM facts
    GROUP BY dim_id        -- 10M → 1000 rows first ✅
) agg
JOIN dims d ON agg.dim_id = d.id;
-- joins only 1000 rows to dims → tiny intermediate result ✅
```

### Technique 5 — Filter early, filter often

```sql
-- SLOW: no WHERE clause — returns everything
SELECT * FROM orders o
JOIN customers c ON o.customer_id = c.id;
-- returns ALL orders for ALL customers ❌

-- SLOW: WHERE clause too late (after join)
SELECT * FROM orders o
JOIN customers c ON o.customer_id = c.id
JOIN products p ON o.product_id = p.id
WHERE c.country = 'US';
-- joins all three tables first → massive intermediate ❌

-- FAST: filter before joining
SELECT * FROM orders o
JOIN (
    SELECT id FROM customers WHERE country = 'US'
) c ON o.customer_id = c.id
JOIN products p ON o.product_id = p.id;
-- reduces customers first → smaller join ✅
```

---

## 10. Common Performance Killers

### Missing index on JOIN or WHERE column

```sql
-- No index on customer_id → Nested Loop scans entire orders per customer
SELECT c.name, o.amount
FROM customers c
JOIN orders o ON c.id = o.customer_id;

-- Fix:
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
-- Hash Join now uses index → O(N+M) not O(N×M) ✅
```

### Implicit type conversion

```sql
-- zip_code is VARCHAR but integer passed → index skipped
SELECT * FROM customers WHERE zip_code = 10001;
-- database must cast every row: CAST("10001" AS INTEGER)
-- 1M casts → can't use index → full table scan ❌

-- Fix: match types
SELECT * FROM customers WHERE zip_code = '10001';
-- VARCHAR = VARCHAR → index works ✅
```

### Function on indexed column

```sql
-- UPPER() on indexed email → index skipped
SELECT * FROM users WHERE UPPER(email) = 'ANNA@GMAIL.COM';
-- index stores original values → UPPER transforms them
-- can't use index ❌

-- Fix: create functional index
CREATE INDEX idx_users_email_upper ON users(UPPER(email));
-- OR store email as lowercase always
```

### SELECT * — returning unnecessary columns

```sql
-- SLOW: fetches all columns → more data, more I/O
SELECT * FROM orders WHERE order_date = '2024-01-15';

-- FAST: only needed columns → less data, enables Index Only Scan
SELECT order_id, amount FROM orders WHERE order_date = '2024-01-15';
```

### Stale statistics

```sql
-- After loading large dataset:
ANALYZE orders;              -- update statistics for one table
ANALYZE;                     -- update all tables

-- If estimates still wrong after ANALYZE:
ALTER TABLE orders
ALTER COLUMN customer_id SET STATISTICS 500;  -- default 100
-- collect more detailed histogram for this column
ANALYZE orders;
```

---

## 11. Common Mistakes

### Mistake 1 — EXPLAIN without ANALYZE

```
Plain EXPLAIN:
→ estimated rows can be wildly wrong
→ shows optimizer's guess not reality
→ useless for actual diagnosis

Always use EXPLAIN ANALYZE when diagnosing ✅
Exception: query takes too long → EXPLAIN first to spot obvious issues
```

### Mistake 2 — Optimizing queries that don't need it

```
Query runs 200ms, executes once per day → don't touch it
Query runs 200ms, executes 1000 times/second → optimize immediately

Focus on: slow AND frequent queries
200ms × 1/day = irrelevant
200ms × 1000/second = 200 seconds compute per second = crisis
```

### Mistake 3 — Adding indexes without checking write impact

```
Every index = slower writes:
INSERT → must update table + all indexes
UPDATE → must update table + all indexes
DELETE → must update table + all indexes

OLTP table (high writes + reads):
→ new index speeds SELECT queries
→ but slows INSERT/UPDATE/DELETE
→ measure both before adding

Read-heavy table  → index helps ✅
Write-heavy table → index might hurt, measure carefully
```

### Mistake 4 — Ignoring estimated vs actual rows gap

```
Estimated: 100 rows, Actual: 1,000,000 rows → 10,000x difference
→ optimizer chose wrong plan (thought table was small)
→ run ANALYZE → re-check estimates
→ if still wrong → increase statistics target for that column
```

---

## 12. Platform-Specific EXPLAIN

### PostgreSQL

```sql
-- Basic plan (safe, instant)
EXPLAIN SELECT ...;

-- With real execution times
EXPLAIN ANALYZE SELECT ...;

-- Full details including cache behavior
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) SELECT ...;

-- Safe analysis of destructive queries
BEGIN;
EXPLAIN ANALYZE DELETE FROM orders WHERE ...;
ROLLBACK;
```

### Snowflake

```
No EXPLAIN command — use Query Profile in web UI:

After running query:
→ Query History → click query → Query Profile tab
→ shows visual DAG of operators

What to look for:
Bytes Spilled to Local Storage  → data exceeded memory → slow
Bytes Spilled to Remote Storage → even worse → very slow
Partition Pruning effectiveness → high % pruned = good ✅
% Scanned from Cache            → high % = good ✅
```

### BigQuery

```
No EXPLAIN — BigQuery optimizes automatically

After running query → Execution Details tab:
Slot time consumed → how much compute used (high = expensive)
Bytes shuffled     → data moved between workers (high = expensive join)
Stage timing       → which stage took longest → find bottleneck
```

### Spark SQL

```sql
EXPLAIN EXTENDED SELECT ...;
-- Shows: parsed plan, analyzed plan, optimized plan, physical plan

EXPLAIN COST SELECT ...;
-- Shows cost estimates per operator
```

```
What to look for in Spark EXPLAIN:
Exchange nodes = data shuffled between workers
→ most expensive operation in Spark
→ network I/O between machines
→ check if JOIN key is partitioned correctly
→ broadcast small table instead of shuffling large table
```

---

## 13. The 80/20 Rule

**80% of query performance problems come from three things:**

```
1. Missing indexes
   → Seq Scan on large table with selective filter
   → fix: CREATE INDEX on filtered/joined column

2. Unnecessary full table scans
   → no WHERE clause, WHERE too broad, function on indexed column
   → fix: add/tighten WHERE, remove function from indexed column

3. Bad join order
   → joining large tables before filtering
   → fix: pre-aggregate, filter early, reorder joins
```

Master EXPLAIN well enough to diagnose these three and you solve the vast majority of performance issues.

---

## 14. Top Interview Questions and Answers

**Q: This query is slow — how would you fix it?**

A: "I look for the obvious problems first in this order: missing WHERE clause returning all rows unnecessarily, SELECT * fetching unneeded columns, correlated subquery running N times that should be rewritten as a JOIN, function on an indexed column preventing index use, and implicit type conversion like passing an integer to a VARCHAR column. I fix the most egregious problem first, measure the improvement, then look for the next issue."

**Q: Walk me through how you would diagnose a slow query.**

A: "I start with EXPLAIN to see the execution plan without running the query — safe and instant. Reading bottom up, I look for three red flags: sequential scans on large tables with selective filters indicating a missing index, nested loops where both sides are large showing O(N×M) complexity, and large gaps between estimated and actual row counts revealing stale statistics. If I need real execution data I run EXPLAIN ANALYZE — wrapped in a transaction with ROLLBACK if it involves writes. Once I identify the bottleneck I either add an index, rewrite the query structure, or run ANALYZE to update statistics."

**Q: What is the difference between Index Scan and Index Only Scan?**

A: "Index Scan uses the index to find row pointers then fetches the full row from the main table — two operations. Index Only Scan answers the query entirely from the index without touching the main table at all — one operation, fastest possible. Index Only Scan only works when all needed columns are stored in the index itself."

**Q: When would you choose Hash Join over Nested Loop?**

A: "Hash Join for medium to large tables joining on equality — it runs in O(N+M) time. Nested Loop for small outer tables with an indexed inner table — it benefits from the index. If I see a Nested Loop where both sides have thousands of rows in EXPLAIN output, that is almost always a problem — either a missing index or wrong statistics causing the optimizer to choose the wrong algorithm."

**Q: What does stale statistics mean and how do you fix it?**

A: "PostgreSQL's optimizer uses statistics — row counts, value distributions — to estimate how many rows each operation will return. If you load a million new rows without updating statistics, the optimizer still thinks the table is small and makes bad choices like choosing Seq Scan over Index Scan. I fix this by running ANALYZE after large data loads. I identify stale statistics in EXPLAIN ANALYZE by comparing estimated rows to actual rows — a 10x or greater difference usually means stale statistics."

**Q: How does Hash Join work internally?**

A: "Hash Join has two phases. Build phase: read the smaller table and build a hash table in memory where the hash function maps join key values to buckets. Probe phase: for each row in the larger table, compute the hash of the join key and look up the matching bucket — O(1) constant time lookup. Total cost is O(N+M) where N is the smaller table and M is the larger table. This is much better than Nested Loop's O(N×M) for large tables."

**Q: Why would you pre-aggregate before joining?**

A: "Joining before aggregating creates a massive intermediate result in memory. If facts has 10 million rows and dims has 1000 rows, the join produces 10 million joined rows in RAM before aggregation — potentially causing memory pressure and disk spill. Pre-aggregating facts to 1000 rows first then joining to dims means only 1000 rows flow through the join — tiny intermediate result, no memory pressure, much faster overall."

---

## Quick Reference Cheat Sheet

```
EXPLAIN:         show plan, safe, no execution
EXPLAIN ANALYZE: show plan + run query, real numbers
Read:            bottom up — deepest = runs first

Scan types:
Seq Scan        → full table, bad for large+selective
Index Scan      → index + table fetch, good <5-10% rows
Index Only Scan → index only, fastest possible
Bitmap Index    → batched reads, good 5-25% rows

Join types:
Nested Loop     → O(N×M), good small+indexed
Hash Join       → O(N+M), good large equality joins
Merge Join      → O(NlogN+MlogM), good pre-sorted

Red flags in EXPLAIN:
Seq Scan + selective filter    → missing index
Nested Loop + both sides large → O(N×M) catastrophe
estimated rows << actual rows  → stale statistics → ANALYZE
High cost single node          → that is your bottleneck

Optimization order:
1. Add targeted index (EXPLAIN first, don't guess)
2. Rewrite correlated subquery as JOIN
3. EXISTS instead of IN for large subqueries
4. Pre-aggregate before joining
5. Filter early — before joins when possible

Performance killers:
Missing index on JOIN/WHERE column
Implicit type conversion (zip_code = 10001 not '10001')
Function on indexed column (UPPER(email))
SELECT * returning unneeded columns
Stale statistics after large data loads
```

---

*Push to: `notes/query_optimization_interview_notes.md`*
