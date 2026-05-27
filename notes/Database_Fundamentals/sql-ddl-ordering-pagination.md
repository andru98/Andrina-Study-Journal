# SQL DDL Operations, Ordering, and Pagination
*Personal Study Notes — May 2026*

---

## Table of Contents
1. [ALTER TABLE — Core Operations](#1-alter-table--core-operations)
2. [ALTER TABLE in Production](#2-alter-table-in-production)
3. [Zero-Downtime Data Type Change](#3-zero-downtime-data-type-change)
4. [SQL Clause Execution Order](#4-sql-clause-execution-order)
5. [ORDER BY — Sorting and Tiebreakers](#5-order-by--sorting-and-tiebreakers)
6. [OFFSET Pagination](#6-offset-pagination)
7. [Keyset Pagination](#7-keyset-pagination)
8. [OFFSET vs Keyset — Side by Side](#8-offset-vs-keyset--side-by-side)

---

## 1. ALTER TABLE — Core Operations

ALTER TABLE modifies the **structure** of a table without touching the data inside it. Think of it as renovating the building without moving the furniture.

### Syntax From Memory

```sql
-- Add a column
ALTER TABLE employees ADD COLUMN department VARCHAR(50);
ALTER TABLE employees ADD COLUMN salary INT DEFAULT 0;

-- Drop a column
ALTER TABLE employees DROP COLUMN department;

-- Rename a column
ALTER TABLE employees RENAME COLUMN dept TO department;         -- PostgreSQL
ALTER TABLE employees CHANGE dept department VARCHAR(50);       -- MySQL

-- Change data type
ALTER TABLE employees ALTER COLUMN salary TYPE BIGINT;          -- PostgreSQL
ALTER TABLE employees MODIFY COLUMN salary BIGINT;              -- MySQL

-- Rename a table
ALTER TABLE employees RENAME TO staff;

-- Add a named constraint
ALTER TABLE employees ADD CONSTRAINT chk_salary CHECK (salary > 0);

-- Drop a named constraint
ALTER TABLE employees DROP CONSTRAINT chk_salary;

-- Set NOT NULL on a column (column property — no constraint name)
ALTER TABLE orders ALTER COLUMN notes SET NOT NULL;

-- Remove NOT NULL
ALTER TABLE orders ALTER COLUMN notes DROP NOT NULL;
```

### SET NOT NULL vs Named Constraint

Two ways to enforce NOT NULL — they look similar but behave differently:

```sql
-- Option 1: Column property — simpler, no name, drop by column reference
ALTER TABLE orders ALTER COLUMN notes SET NOT NULL;
ALTER TABLE orders ALTER COLUMN notes DROP NOT NULL;

-- Option 2: Named CHECK constraint — droppable by name, more explicit
ALTER TABLE orders ADD CONSTRAINT chk_notes_not_null CHECK (notes IS NOT NULL);
ALTER TABLE orders DROP CONSTRAINT chk_notes_not_null;
```

Use Option 2 when you want to track and manage constraints explicitly. Use Option 1 for quick column-level enforcement.

---

## 2. ALTER TABLE in Production

This is where understanding matters most — production databases cannot afford downtime.

### The Core Problem

In OLTP databases (PostgreSQL, MySQL), certain ALTER TABLE operations **lock the entire table** while they run. On a 500 million row table, that lock could last hours. During that time nobody can read or write.

### Safe vs Risky Operations

| Operation | PostgreSQL | MySQL |
|-----------|-----------|-------|
| Add nullable column | Instant — metadata only | Table rewrite on older versions |
| Add column with DEFAULT | Instant (PostgreSQL 11+) | Table rewrite |
| Drop column | Instant — marks invisible | Table rewrite |
| Change data type | Locks table | Locks table |
| Add index (standard) | Locks table | Locks table |
| Add index CONCURRENTLY | Non-blocking | Use ALGORITHM=INPLACE |

### OLTP vs OLAP Difference

| | OLTP (PostgreSQL / MySQL) | OLAP (Snowflake / BigQuery) |
|--|--------------------------|----------------------------|
| ALTER TABLE | Can lock table, risky on large tables | Metadata-only, instant |
| Add column | Can be slow | Instant |
| Change data type | Full table rewrite | Instant |
| Why different | Row-based storage needs rewrite | Columnar format stores columns separately |

In Snowflake and BigQuery, ALTER is almost always safe because the columnar storage format means columns are independent — no full rewrite needed.

---

## 3. Zero-Downtime Data Type Change

Changing a data type directly in production is one of the riskiest ALTER operations. The database rewrites every row to convert values to the new type. The safe approach works alongside the live column instead of touching it directly.

### The 7-Step Pattern

**Step 1 — Add a new column with the new type (instant)**
```sql
ALTER TABLE orders ADD COLUMN order_id_new BIGINT;
```
No lock. Just metadata. Existing queries are unaffected.

**Step 2 — Backfill old rows in small batches**
```sql
UPDATE orders SET order_id_new = order_id::BIGINT
WHERE id BETWEEN 1 AND 10000;

UPDATE orders SET order_id_new = order_id::BIGINT
WHERE id BETWEEN 10001 AND 20000;
-- repeat until all rows filled
```
Small batches = short locks on small chunks. No downtime. Never run one massive UPDATE on all rows at once.

**Step 3 — Sync new writes to both columns**

While backfilling runs, the application is still writing new rows to the old column. Use a trigger or application-level dual write to keep both columns in sync.

The concept: every new INSERT or UPDATE automatically populates both `order_id` and `order_id_new` simultaneously until the migration is complete.

**Step 4 — Verify zero mismatches**
```sql
SELECT COUNT(*)
FROM orders
WHERE order_id::BIGINT != order_id_new;
-- Must return 0 before proceeding
```
Do not move forward until this confirms clean data.

**Step 5 — Switch application to new column**

Deploy the application code to read and write `order_id_new` instead of `order_id`. This is a code deploy — no database lock.

**Step 6 — Drop the old column (instant)**
```sql
ALTER TABLE orders DROP COLUMN order_id;
```
PostgreSQL marks it invisible instantly. No table rewrite.

**Step 7 — Rename new column to original name (instant)**
```sql
ALTER TABLE orders RENAME COLUMN order_id_new TO order_id;
```

### When Direct ALTER Is Fine

If the table is small or a maintenance window is available:
```sql
BEGIN;
ALTER TABLE orders ALTER COLUMN order_id TYPE BIGINT;
COMMIT;
```
Acceptable when the table has fewer than 1-2 million rows or the system can tolerate brief downtime.

---

## 4. SQL Clause Execution Order

SQL does not execute in the order it is written. Understanding the actual execution order explains why certain things work or fail.

```
1. FROM       — identify the table(s)
2. WHERE      — filter individual rows
3. GROUP BY   — group the remaining rows
4. HAVING     — filter the groups
5. SELECT     — choose which columns to return
6. ORDER BY   — sort the result
7. LIMIT      — cut to N rows
```

### Why This Matters

```sql
-- FAILS — WHERE runs before SELECT, alias does not exist yet
SELECT salary * 1.1 AS adjusted_salary
FROM employees
WHERE adjusted_salary > 50000;   -- ❌ unknown column at WHERE stage

-- WORKS — use the expression directly in WHERE
SELECT salary * 1.1 AS adjusted_salary
FROM employees
WHERE salary * 1.1 > 50000;     -- ✅

-- WORKS — ORDER BY runs after SELECT, alias is available
SELECT salary * 1.1 AS adjusted_salary
FROM employees
ORDER BY adjusted_salary DESC;   -- ✅ alias exists here
```

### HAVING vs WHERE

```sql
-- WHERE filters rows before grouping
SELECT department, AVG(salary)
FROM employees
WHERE salary > 30000           -- filters individual rows first
GROUP BY department;

-- HAVING filters groups after grouping
SELECT department, AVG(salary)
FROM employees
GROUP BY department
HAVING AVG(salary) > 80000;    -- filters groups after aggregation
```

---

## 5. ORDER BY — Sorting and Tiebreakers

### Basic Sorting

```sql
-- Ascending (default)
SELECT name, salary FROM employees ORDER BY salary ASC;

-- Descending
SELECT name, salary FROM employees ORDER BY salary DESC;

-- Multiple columns
SELECT name, department, salary
FROM employees
ORDER BY department ASC, salary DESC;
```

### Always Add a Tiebreaker

Without a tiebreaker, two rows with the same sort value return in random order. The result is non-deterministic — run the same query twice and rows can appear in different positions.

```sql
-- Non-deterministic — two employees with salary 80000 can appear in any order
ORDER BY salary DESC

-- Deterministic — employee_id breaks the tie, always same result
ORDER BY salary DESC, employee_id ASC
```

This is especially critical for pagination — if rows shift position between pages, users see duplicate rows or miss rows entirely.

### NULL Sort Behavior Across Databases

```sql
ORDER BY salary DESC
```

| Database | NULLs appear |
|----------|-------------|
| PostgreSQL | Last (NULLS LAST default for DESC) |
| MySQL | First for DESC |
| SQL Server | First for DESC |
| BigQuery | Last |

Fix explicitly to be safe across databases:
```sql
ORDER BY salary DESC NULLS LAST    -- PostgreSQL explicit
ORDER BY ISNULL(salary, 0) DESC    -- MySQL workaround
```

---

## 6. OFFSET Pagination

Pagination is showing data in chunks instead of all at once — the same way Google shows 10 results per page or your bank shows 10 transactions per page.

### How OFFSET Works

```sql
-- Page 1: skip 0, return 10
SELECT * FROM orders ORDER BY order_date DESC LIMIT 10 OFFSET 0;

-- Page 2: skip 10, return 10
SELECT * FROM orders ORDER BY order_date DESC LIMIT 10 OFFSET 10;

-- Page 3: skip 20, return 10
SELECT * FROM orders ORDER BY order_date DESC LIMIT 10 OFFSET 20;
```

Formula: `OFFSET = (page_number - 1) × page_size`

### The Hidden Cost

OFFSET does not actually skip rows efficiently. The database reads ALL rows from the beginning, counts through them, discards everything before the offset, then returns your 10 rows.

```
Page 1    → reads 10 rows      → returns 10   → fast
Page 10   → reads 100 rows     → returns 10
Page 100  → reads 1,000 rows   → returns 10
Page 1,000→ reads 10,000 rows  → returns 10
Page 10,000→ reads 100,000 rows → returns 10  → slow
```

### The Numbers Explained

Page 10,000 with page size 10:
```
OFFSET = (10,000 - 1) × 10 = 99,990

Database scans rows 1 to 100,000
Throws away rows 1 to 99,990
Returns rows 99,991 to 100,000
Total rows scanned = 100,000
Rows actually returned = 10
```

From the user's perspective it looks like a jump to page 10,000. Internally the database crawled through 100,000 rows to get there.

---

## 7. Keyset Pagination

Instead of telling the database "skip N rows," keyset pagination tells it "start after the last row I already saw." The database uses an index to jump directly to that position — no scanning, no discarding.

### How It Works

```sql
-- Page 1: no filter, just get first 3
SELECT order_id, order_date, amount
FROM orders
ORDER BY order_date DESC, order_id DESC
LIMIT 3;
```

Result — Page 1:

| order_id | order_date | amount |
|----------|-----------|--------|
| 5001 | 2024-03-01 | 500 |
| 4999 | 2024-02-28 | 300 |
| 4998 | 2024-02-28 | 150 |

Save the last row's values: `order_date = 2024-02-28`, `order_id = 4998`.

```sql
-- Page 2: pass last seen values as WHERE condition
SELECT order_id, order_date, amount
FROM orders
WHERE (order_date, order_id) < ('2024-02-28', 4998)
ORDER BY order_date DESC, order_id DESC
LIMIT 3;
```

The database uses the index on `(order_date, order_id)` to jump directly to that position and reads the next 3 rows. No scanning rows before it.

### Why the Tiebreaker Is Required

If multiple rows share the same date and the boundary falls in the middle of them:

```
5 rows exist on 2024-02-28
Page 1 shows 2 of them (order_ids 4999 and 4998)
3 rows remain on 2024-02-28 (order_ids 4997, 4996, 4995)
```

Without tiebreaker:
```sql
WHERE order_date < '2024-02-28'
-- Skips ALL rows on 2024-02-28 — the 3 remaining rows are lost forever
```

With tiebreaker:
```sql
WHERE (order_date, order_id) < ('2024-02-28', 4998)
-- Same date is fine — order_id must be less than 4998
-- order_ids 4997, 4996, 4995 correctly appear on page 2
```

The tiebreaker makes every position unique so no row is ever accidentally skipped.

---

## 8. OFFSET vs Keyset — Side by Side

| | OFFSET | Keyset |
|--|--------|--------|
| How it works | Skip N rows internally | Start after last seen value |
| User experience | Can jump to any page number | Must go page by page sequentially |
| Database internal work | Scans ALL rows up to offset | Scans ONLY the rows you need |
| Performance at page 1 | Fast | Fast |
| Performance at page 10,000 | Slow — 100,000 rows scanned | Same as page 1 |
| Tiebreaker required | No | Yes — required |
| Use case | Simple apps, admin dashboards, small data | Large scale, infinite scroll, high traffic |

### The Key Insight

OFFSET gives the **illusion** of jumping to any page. From the user's perspective it jumps. From the database's perspective it crawls through every row before that page. Keyset makes both the user and the database work efficiently — but the user loses the ability to jump to an arbitrary page number.

---

*Study notes compiled May 2026 — Anna's DE Prep Journey*
