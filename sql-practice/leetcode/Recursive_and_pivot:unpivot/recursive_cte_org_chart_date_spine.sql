-- ============================================================
-- Topic    : Recursive CTEs for Data Engineers
-- Covers   : Org chart traversal + Date spine gap-filling
-- Source   : DataVidhya / Interview Pattern
-- Level    : Medium
-- Date     : 2026-06-23
-- ============================================================

-- ============================================================
-- PART 1: ORG CHART HIERARCHY TRAVERSAL
-- ============================================================

-- PROBLEM:
-- Table: employees (id, name, manager_id)
-- Find all employees under a given manager at any depth.
-- Include the level (depth) of each employee in the hierarchy.

-- ============================================================
-- APPROACH:
-- Recursive CTE has two mandatory parts:
-- 1. Base case — starting point, runs once
-- 2. Recursive case — references the CTE itself, runs until
--    no more rows are returned
--
-- Each iteration joins the base table (employees) to the
-- PREVIOUS iteration's result (org_chart) to find the next
-- level of reports. Stops automatically when no employees
-- match the previous iteration's ids.
--
-- Level tracks depth in hierarchy:
-- 0 = starting manager
-- 1 = direct reports
-- 2 = reports of reports
-- Used for filtering by depth or displaying indented hierarchy.
-- ============================================================

-- Full org chart starting from CEO (manager_id IS NULL)
WITH RECURSIVE org_chart AS (
    -- Base case: start with CEO
    SELECT
        id,
        name,
        manager_id,
        0 AS level
    FROM employees
    WHERE manager_id IS NULL        -- CEO has no manager

    UNION ALL

    -- Recursive case: find next level of reports
    SELECT
        e.id,
        e.name,
        e.manager_id,
        oc.level + 1                -- increment level each iteration
    FROM employees e
    INNER JOIN org_chart oc
        ON e.manager_id = oc.id     -- employee's manager = previous level
)
SELECT id, name, level
FROM org_chart
ORDER BY level, name;

-- ============================================================
-- FIND EMPLOYEES UNDER SPECIFIC MANAGER (e.g. VP Eng id=2):
-- Only change the base case — recursive case stays identical
-- ============================================================

WITH RECURSIVE org_employee AS (
    -- Base case: start at specific manager
    SELECT id, name, 0 AS level
    FROM employees
    WHERE id = 2                    -- start at VP Eng

    UNION ALL

    -- Recursive case: identical to full org chart
    SELECT e.id, e.name, oe.level + 1
    FROM employees e
    INNER JOIN org_employee oe
        ON e.manager_id = oe.id
)
SELECT id, name, level
FROM org_employee
ORDER BY level, name;

-- ============================================================
-- EXAMPLE WALKTHROUGH (VP Eng query):
-- Table:
-- id | name     | manager_id
-- 1  | CEO      | NULL
-- 2  | VP Eng   | 1
-- 3  | VP Sales | 1
-- 4  | Sr Eng   | 2
-- 5  | Jr Eng   | 2
-- 6  | Sales    | 3
--
-- Iteration 1 (base case):
-- WHERE id = 2 → returns VP Eng (level=0)
-- org_employee = {id=2, VP Eng, level=0}
--
-- Iteration 2 (recursive):
-- JOIN employees ON manager_id = 2
-- → Sr Eng (id=4), Jr Eng (id=5) both qualify
-- → level = 0 + 1 = 1
-- org_employee adds {Sr Eng level=1, Jr Eng level=1}
--
-- Iteration 3 (recursive):
-- JOIN employees ON manager_id = 4 OR 5
-- → nobody has manager_id 4 or 5
-- → 0 rows returned → STOPS ✅
--
-- Final output:
-- id | name    | level
-- 2  | VP Eng  | 0
-- 4  | Sr Eng  | 1
-- 5  | Jr Eng  | 1
-- ============================================================

-- ============================================================
-- EDGE CASES TO KEEP IN MIND:
-- 1. Stop condition is implicit — no WHERE needed in recursive case.
--    Stops automatically when JOIN returns 0 rows.
--    If data has cycles (A reports to B, B reports to A) →
--    infinite loop → always verify data has no circular references.
--
-- 2. level + 1 not 0 + 1:
--    oe.level + 1 increments correctly each iteration.
--    Hardcoding 0 + 1 = always 1, never increases.
--
-- 3. RECURSIVE keyword placement:
--    Goes in WITH clause only — not in SELECT.
--    SQL Server doesn't need it — detects recursion automatically.
--    PostgreSQL, MySQL 8+, Snowflake, BigQuery all require it.
--
-- 4. UNION ALL not UNION:
--    UNION removes duplicates — slow and wrong for hierarchy.
--    UNION ALL keeps all rows — correct and faster.
-- ============================================================

-- ============================================================
-- PART 2: DATE SPINE FOR GAP-FILLING
-- ============================================================

-- PROBLEM:
-- Time series data often has missing dates — no orders on Sunday,
-- no events on holidays. Dashboards show invisible gaps that
-- mislead stakeholders. Date spine generates every date in a
-- range so missing dates appear as explicit zeros.

-- ============================================================
-- APPROACH:
-- Recursive CTE generates one date per iteration.
-- Base case: start date.
-- Recursive case: add one day to previous date.
-- Stop condition: next date exceeds end date.
-- LEFT JOIN fact table to spine — missing dates become NULL.
-- COALESCE converts NULL to 0 for clean dashboard output.
-- ============================================================

-- Generate every date in 2024
WITH RECURSIVE date_spine AS (
    -- Base case: start date
    SELECT DATE '2024-01-01' AS dt

    UNION ALL

    -- Recursive case: add one day each iteration
    SELECT dt + INTERVAL '1 day'
    FROM date_spine
    WHERE dt + INTERVAL '1 day' <= DATE '2024-12-31'  -- stop condition
)
SELECT dt FROM date_spine;
-- Returns 366 rows (2024 is a leap year)

-- ============================================================
-- GAP-FILL DAILY REVENUE — the real DE use case:
-- ============================================================

WITH RECURSIVE date_spine AS (
    SELECT DATE '2024-01-01' AS dt
    UNION ALL
    SELECT dt + INTERVAL '1 day'
    FROM date_spine
    WHERE dt + INTERVAL '1 day' <= CURRENT_DATE
)
SELECT
    ds.dt                           AS date,
    COALESCE(SUM(o.amount), 0)      AS daily_revenue  -- 0 not NULL for missing days
FROM date_spine ds
LEFT JOIN orders o
    ON o.order_date = ds.dt         -- LEFT JOIN keeps all dates from spine
GROUP BY ds.dt
ORDER BY ds.dt;

-- ============================================================
-- WHY LEFT JOIN NOT INNER JOIN:
-- INNER JOIN → only keeps dates that exist in orders → gaps remain
-- LEFT JOIN  → keeps ALL dates from spine → missing dates show as NULL
-- COALESCE(SUM(amount), 0) → converts NULL to 0 → honest dashboard
-- ============================================================

-- ============================================================
-- PLATFORM ALTERNATIVES (faster than recursive CTE):
-- Use these when available — recursive CTE when portability needed.
--
-- Snowflake:
-- SELECT DATEADD(day, SEQ4(), '2024-01-01') AS dt
-- FROM TABLE(GENERATOR(ROWCOUNT => 366))
--
-- BigQuery:
-- SELECT dt
-- FROM UNNEST(GENERATE_DATE_ARRAY('2024-01-01', '2024-12-31',
--      INTERVAL 1 DAY)) AS dt
--
-- PostgreSQL (built-in, no recursion needed):
-- SELECT generate_series::date AS dt
-- FROM generate_series('2024-01-01', '2024-12-31', INTERVAL '1 day')
--
-- MySQL / portable → use recursive CTE above
-- ============================================================

-- ============================================================
-- KEY PATTERNS — MEMORIZE THESE:
--
-- Recursive CTE structure (always):
--   WITH RECURSIVE cte_name AS (
--       [base case]         -- runs once, starting point
--       UNION ALL
--       [recursive case]    -- references cte_name, runs until 0 rows
--   )
--   SELECT * FROM cte_name;
--
-- Org chart pattern:
--   Base:      WHERE manager_id IS NULL (or specific id)
--   Recursive: JOIN employees ON e.manager_id = oc.id
--   Track:     oc.level + 1 AS level
--
-- Date spine pattern:
--   Base:      SELECT start_date AS dt
--   Recursive: SELECT dt + INTERVAL '1 day' WHERE dt + 1 <= end_date
--   Use:       LEFT JOIN facts ON fact_date = dt + COALESCE to 0
--
-- Real DE use cases:
--   Org chart    → employee hierarchy, reporting structure
--   Date spine   → gap-filling time series for dashboards
--   Category tree → product/subcategory hierarchies
--   Bill of materials → component breakdown for products
--   Data lineage → table dependency graphs (dbt, Airflow)
-- ============================================================

-- ============================================================
-- HOW UNION ALL WORKS INTERNALLY IN RECURSIVE CTEs
-- ============================================================

-- Common misconception: UNION ALL runs every iteration like a loop.
-- Reality: UNION ALL is a combiner that runs ONCE at the very end.
--
-- Internal execution — two separate machines:
--
-- Machine 1 (base case) → runs ONCE → stores result in temp table
-- Machine 2 (recursive) → reads temp table → produces new rows
--                       → replaces temp table → repeats until 0 rows
-- UNION ALL → combines Machine 1 + all Machine 2 outputs at the end
--
-- Example — counter from 1 to 5:
-- WITH RECURSIVE counter AS (
--     SELECT 1 AS n          ← Machine 1: runs once → {n=1}
--     UNION ALL
--     SELECT n + 1           ← Machine 2: reads temp table each time
--     FROM counter
--     WHERE n < 5
-- )
--
-- Timeline:
-- Time 1: base case → {1} stored in temp table
-- Time 2: recursive reads {1} → WHERE 1<5 true → produces {2}
--         temp table replaced with {2}
-- Time 3: recursive reads {2} → WHERE 2<5 true → produces {3}
--         temp table replaced with {3}
-- Time 4: recursive reads {3} → WHERE 3<5 true → produces {4}
-- Time 5: recursive reads {4} → WHERE 4<5 true → produces {5}
-- Time 6: recursive reads {5} → WHERE 5<5 FALSE → 0 rows → STOPS
--
-- UNION ALL combines at end: {1}+{2}+{3}+{4}+{5} → final result
-- 1, 2, 3, 4, 5
--
-- Key points:
-- 1. Base case runs ONCE — not repeated every iteration
-- 2. Recursive part reads ONLY previous iteration's rows
--    not all accumulated rows
-- 3. UNION ALL combines everything at the very end
-- 4. No duplicates when each iteration produces new unique values
-- 5. Stop when recursive part returns 0 rows OR explicit WHERE fails
--
-- Why no duplicates in counter:
-- n=1 → produces 2 (unique)
-- n=2 → produces 3 (unique)
-- Each iteration increments → always new value → never duplicate
-- ============================================================

-- ============================================================
-- BASE CASE — NO FROM NEEDED WHEN GENERATING VALUES:
-- ============================================================

-- When generating a starting value from scratch → no FROM needed
-- SELECT DATE '2026-01-01' AS dt   ← just a value, no table
-- SELECT 1 AS n                    ← just a value, no table
--
-- When reading from real data → FROM needed
-- SELECT id, name FROM employees WHERE manager_id IS NULL
--
-- Rule:
-- Data from table  → need FROM clause
-- Generated value  → no FROM needed (SQL allows SELECT without FROM)
-- ============================================================
