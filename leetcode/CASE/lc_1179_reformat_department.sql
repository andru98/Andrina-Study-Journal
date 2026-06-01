-- ============================================================
-- LC 1179: Reformat Department Table
-- Difficulty : Easy
-- Topic      : PIVOT using CASE WHEN + MAX + GROUP BY
-- Author     : Anna Shrestha
-- ============================================================
-- Problem:
-- Reformat the Department table so that there is a department
-- id column and a revenue column for each month.
-- Months with no revenue should return NULL.
--
-- Table: Department
-- | id | revenue | month |
-- |----|---------|-------|
-- | 1  | 8000    | Jan   |
-- | 2  | 9000    | Jan   |
-- | 3  | 10000   | Feb   |
-- | 1  | 7000    | Feb   |
-- | 1  | 6000    | Mar   |
--
-- Expected output:
-- | id | Jan_Revenue | Feb_Revenue | Mar_Revenue | ... |
-- |----|-------------|-------------|-------------|-----|
-- | 1  | 8000        | 7000        | 6000        | NULL|
-- | 2  | 9000        | NULL        | NULL        | NULL|
-- | 3  | NULL        | 10000       | NULL        | NULL|
-- ============================================================


-- ------------------------------------------------------------
-- SOLUTION — PIVOT pattern: CASE inside MAX, grouped by id
-- ------------------------------------------------------------
SELECT
    id,
    MAX(CASE WHEN month = 'Jan' THEN revenue END) AS Jan_Revenue,
    MAX(CASE WHEN month = 'Feb' THEN revenue END) AS Feb_Revenue,
    MAX(CASE WHEN month = 'Mar' THEN revenue END) AS Mar_Revenue,
    MAX(CASE WHEN month = 'Apr' THEN revenue END) AS Apr_Revenue,
    MAX(CASE WHEN month = 'May' THEN revenue END) AS May_Revenue,
    MAX(CASE WHEN month = 'Jun' THEN revenue END) AS Jun_Revenue,
    MAX(CASE WHEN month = 'Jul' THEN revenue END) AS Jul_Revenue,
    MAX(CASE WHEN month = 'Aug' THEN revenue END) AS Aug_Revenue,
    MAX(CASE WHEN month = 'Sep' THEN revenue END) AS Sep_Revenue,
    MAX(CASE WHEN month = 'Oct' THEN revenue END) AS Oct_Revenue,
    MAX(CASE WHEN month = 'Nov' THEN revenue END) AS Nov_Revenue,
    MAX(CASE WHEN month = 'Dec' THEN revenue END) AS Dec_Revenue
FROM Department
GROUP BY id
ORDER BY id;


-- ------------------------------------------------------------
-- HOW THE PIVOT PATTERN WORKS — step by step
-- ------------------------------------------------------------

-- Step 1: GROUP BY id buckets all rows for the same department
-- id=1 bucket → [Jan:8000, Feb:7000, Mar:6000]
-- id=2 bucket → [Jan:9000]
-- id=3 bucket → [Feb:10000]

-- Step 2: CASE extracts revenue only when month matches
-- For id=1, Jan column:
--   row Jan  → CASE returns 8000
--   row Feb  → CASE returns NULL
--   row Mar  → CASE returns NULL

-- Step 3: MAX collapses [8000, NULL, NULL] → 8000
-- MAX ignores NULLs and returns the one real value.
-- For months with no data: MAX of [NULL, NULL...] → NULL

-- Why MAX and not SUM?
-- The problem guarantees one revenue per id per month.
-- MAX and SUM give the same result here.
-- MAX is the convention for pivot patterns — it makes intent clear.
-- Use SUM if a department can have multiple entries per month.


-- ------------------------------------------------------------
-- EDGE CASES — mention these in interview
-- ------------------------------------------------------------

-- Edge case 1: What if one department has TWO entries for Jan?
-- | 1 | 8000 | Jan |
-- | 1 | 3000 | Jan |  ← duplicate
--
-- MAX → returns 8000 (picks the highest)
-- SUM → returns 11000 (adds both)
-- Always clarify with interviewer: "Is one revenue per month guaranteed?"

-- Edge case 2: What if a department has no entries at all?
-- It simply won't appear in the GROUP BY result.
-- No row is created for it — not even a NULL row.

-- Edge case 3: What if revenue can be NULL in source data?
-- MAX(CASE WHEN month = 'Jan' THEN revenue END)
-- If revenue IS NULL, CASE returns NULL.
-- MAX of [NULL] = NULL. Result column is NULL. Safe.

-- Edge case 4: What if month values are inconsistent casing?
-- 'jan', 'JAN', 'Jan' would all fail to match 'Jan'.
-- Defensive version:
SELECT
    id,
    MAX(CASE WHEN UPPER(month) = 'JAN' THEN revenue END) AS Jan_Revenue,
    MAX(CASE WHEN UPPER(month) = 'FEB' THEN revenue END) AS Feb_Revenue
FROM Department
GROUP BY id;

-- Edge case 5: ORDER BY id not required by problem
-- but always add in production — deterministic output
-- is easier to test and validate in a pipeline.


-- ------------------------------------------------------------
-- PLATFORM-SPECIFIC PIVOT SYNTAX — for senior interviews
-- ------------------------------------------------------------

-- SQL Server and Snowflake support native PIVOT syntax:
SELECT id, [Jan] AS Jan_Revenue, [Feb] AS Feb_Revenue
FROM Department
PIVOT (
    MAX(revenue)
    FOR month IN ([Jan], [Feb], [Mar])
) AS pivot_table;

-- Interview note:
-- Native PIVOT is cleaner but not universally supported.
-- MySQL and PostgreSQL do NOT support PIVOT natively.
-- CASE + MAX + GROUP BY works on every SQL platform — always
-- default to this pattern unless asked for platform-specific syntax.


-- ------------------------------------------------------------
-- INTERVIEW TALKING POINTS
-- ------------------------------------------------------------
-- Q: Why use MAX() and not just CASE alone?
-- A: After GROUP BY, each id has multiple rows in its bucket.
--    SQL cannot return multiple values for one column —
--    it needs an aggregate to collapse them to one.
--    MAX picks the real value and ignores NULLs automatically.

-- Q: What is the difference between CASE + MAX pivot
--    and native PIVOT syntax?
-- A: Same result. CASE + MAX is portable across all platforms.
--    Native PIVOT is cleaner but only in SQL Server / Snowflake.
--    In production pipelines I use CASE + MAX for portability.

-- Q: What if the number of months is dynamic and unknown?
-- A: Static CASE pivot requires knowing all values upfront.
--    For dynamic pivots use dynamic SQL — build the query
--    as a string, populate month values from the data,
--    then execute with EXEC or EXECUTE IMMEDIATE.
--    This comes up in senior DE interviews.

-- Q: What is the time complexity?
-- A: O(n) — one full scan of the Department table.
--    GROUP BY adds a sort step — O(n log n) in most engines
--    unless a hash aggregation is used.
