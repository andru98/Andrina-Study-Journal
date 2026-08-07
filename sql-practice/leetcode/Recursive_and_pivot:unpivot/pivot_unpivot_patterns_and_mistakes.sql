-- ============================================================
-- Topic    : PIVOT & UNPIVOT — Complete Patterns and Common Mistakes
-- Covers   : CASE WHEN pivot, UNION ALL unpivot, CROSS JOIN unpivot,
--            Native PIVOT/UNPIVOT syntax, Common mistakes with examples
-- Source   : DataVidhya / Interview Pattern
-- Level    : Medium (3-5 years experience)
-- Date     : 2026-06-29
-- ============================================================

-- ============================================================
-- PART 1: PIVOT — ROWS TO COLUMNS
-- ============================================================

-- ============================================================
-- APPROACH 1: CASE WHEN + GROUP BY (Universal — works everywhere)
-- ============================================================

-- Source data (long format):
-- month   | metric  | value
-- 2024-01 | revenue | 50000
-- 2024-01 | costs   | 30000
-- 2024-02 | revenue | 55000
-- 2024-02 | costs   | 32000

-- Goal: one row per month, metrics as columns

-- Basic pivot — numeric values use SUM
SELECT
    month,
    SUM(CASE WHEN metric = 'revenue' THEN value END) AS revenue,
    SUM(CASE WHEN metric = 'costs'   THEN value END) AS costs
FROM monthly_metrics
GROUP BY month
ORDER BY month;

-- ============================================================
-- Pivot with computed column — profit = revenue - costs
-- Native PIVOT cannot do this inline — needs subquery wrapper
-- CASE approach handles it in one SELECT
-- ============================================================

SELECT
    month,
    SUM(CASE WHEN metric = 'revenue' THEN value END)   AS revenue,
    SUM(CASE WHEN metric = 'costs'   THEN value END)   AS costs,
    SUM(CASE WHEN metric = 'revenue' THEN value END)
    - SUM(CASE WHEN metric = 'costs' THEN value END)   AS profit
FROM monthly_metrics
GROUP BY month
ORDER BY month;

-- ============================================================
-- Multi-column pivot — multiple aggregations per category
-- Native PIVOT handles only ONE aggregation at a time
-- CASE approach handles COUNT + SUM together cleanly
-- ============================================================

SELECT
    region,
    COUNT(CASE WHEN status = 'active'  THEN 1 END)       AS active_count,
    SUM(CASE WHEN status = 'active'    THEN revenue END)  AS active_revenue,
    COUNT(CASE WHEN status = 'churned' THEN 1 END)        AS churned_count,
    SUM(CASE WHEN status = 'churned'   THEN revenue END)  AS churned_revenue
FROM customers
GROUP BY region
ORDER BY region;

-- ============================================================
-- Categorical pivot — text values use MAX not SUM
-- SUM on text errors or produces garbage depending on platform
-- MAX ignores NULL and returns the single non-NULL value per group
-- ============================================================

-- Internals step by step:
-- Data:
-- user_id | category | value
-- 1       | status   | active
-- 1       | tier     | premium
--
-- After CASE WHEN (before GROUP BY):
-- user_id | status  | tier
-- 1       | active  | NULL    ← status row
-- 1       | NULL    | premium ← tier row
--
-- After GROUP BY + MAX:
-- MAX(status) = MAX('active', NULL) = 'active'   ← ignores NULL
-- MAX(tier)   = MAX(NULL, 'premium') = 'premium' ← ignores NULL
--
-- user_id | status | tier
-- 1       | active | premium ✅

SELECT
    user_id,
    MAX(CASE WHEN category = 'status' THEN value END) AS status,
    MAX(CASE WHEN category = 'tier'   THEN value END) AS tier
FROM user_attributes
GROUP BY user_id
ORDER BY user_id;

-- ============================================================
-- APPROACH 2: Native PIVOT — SQL Server syntax
-- Cleaner for simple single-aggregation pivots
-- Platform specific — SQL Server, Snowflake, Oracle only
-- ============================================================

SELECT month, revenue, costs
FROM monthly_metrics
PIVOT (
    SUM(value)                          -- one aggregation only
    FOR metric IN ([revenue], [costs])  -- square brackets for SQL Server
) AS pvt
ORDER BY month;

-- ============================================================
-- Native PIVOT — Snowflake syntax
-- Single quotes not square brackets
-- ============================================================

SELECT *
FROM monthly_metrics
PIVOT (
    SUM(value)
    FOR metric IN ('revenue', 'costs')  -- single quotes for Snowflake
)
ORDER BY month;

-- ============================================================
-- PART 2: UNPIVOT — COLUMNS TO ROWS
-- ============================================================

-- Source data (wide format):
-- month   | revenue | costs | headcount
-- 2024-01 | 50000   | 30000 | 100
-- 2024-02 | 55000   | 32000 | 110

-- Goal: one row per month per metric

-- ============================================================
-- APPROACH 1: UNION ALL (Universal — works everywhere)
-- Reads table once per column — verbose but safe with NULLs
-- ============================================================

SELECT month, 'revenue'   AS metric, revenue   AS value FROM monthly_wide
UNION ALL
SELECT month, 'costs'     AS metric, costs     AS value FROM monthly_wide
UNION ALL
SELECT month, 'headcount' AS metric, headcount AS value FROM monthly_wide
ORDER BY month, metric;

-- ============================================================
-- APPROACH 2: CROSS JOIN + CASE (Cleaner — reads table once)
-- More efficient than UNION ALL for many columns
-- ============================================================

-- How it works:
-- Step 1: metric list subquery creates 3 rows (one per column name)
-- Step 2: CROSS JOIN pairs every data row with every metric name
--         monthly_wide has 2 rows, metric list has 3 rows
--         2 x 3 = 6 rows total
-- Step 3: CASE picks the right column value for each pair

SELECT
    w.month,
    m.metric,
    CASE m.metric
        WHEN 'revenue'   THEN w.revenue
        WHEN 'costs'     THEN w.costs
        WHEN 'headcount' THEN w.headcount
    END AS value
FROM monthly_wide w
CROSS JOIN (
    SELECT 'revenue'   AS metric
    UNION ALL SELECT 'costs'
    UNION ALL SELECT 'headcount'
) m
ORDER BY w.month, m.metric;

-- Why CROSS JOIN is cleaner than UNION ALL:
-- UNION ALL: reads table 3 times (once per column) — verbose
-- CROSS JOIN: reads table ONCE, metric list multiplies rows — efficient
-- Adding a new column:
-- UNION ALL: add another SELECT ... FROM monthly_wide
-- CROSS JOIN: just add one more row to metric list

-- ============================================================
-- APPROACH 3: Native UNPIVOT — SQL Server syntax
-- WARNING: silently drops NULL values (documented behavior)
-- Use UNION ALL or CROSS JOIN if NULLs must be preserved
-- ============================================================

SELECT month, metric, value
FROM monthly_wide
UNPIVOT (
    value               -- new column to hold values
    FOR metric IN       -- new column to hold column names
    (revenue, costs, headcount)  -- which columns become rows
) AS unpvt
ORDER BY month, metric;

-- ============================================================
-- PART 3: COMMON MISTAKES WITH EXAMPLES
-- ============================================================

-- ============================================================
-- MISTAKE 1: Forgetting GROUP BY in CASE pivot
-- Result: one row instead of one per group
-- ============================================================

-- WRONG — no GROUP BY
SELECT
    month,
    SUM(CASE WHEN metric = 'revenue' THEN value END) AS revenue,
    SUM(CASE WHEN metric = 'costs'   THEN value END) AS costs
FROM monthly_metrics;
-- Returns ONE row — all months collapsed together
-- month   | revenue | costs
-- 2024-01 | 105000  | 62000 ← wrong: all months summed ❌

-- CORRECT — with GROUP BY
SELECT
    month,
    SUM(CASE WHEN metric = 'revenue' THEN value END) AS revenue,
    SUM(CASE WHEN metric = 'costs'   THEN value END) AS costs
FROM monthly_metrics
GROUP BY month  -- ← required
ORDER BY month;
-- month   | revenue | costs
-- 2024-01 | 50000   | 30000 ✅
-- 2024-02 | 55000   | 32000 ✅

-- ============================================================
-- MISTAKE 2: SUM on text values — use MAX or MIN instead
-- ============================================================

-- WRONG — SUM on text
SELECT
    user_id,
    SUM(CASE WHEN category = 'status' THEN value END) AS status
FROM user_attributes
GROUP BY user_id;
-- PostgreSQL: ERROR — cannot sum text ❌
-- MySQL: silently returns 0 ❌ garbage result

-- CORRECT — MAX on text
SELECT
    user_id,
    MAX(CASE WHEN category = 'status' THEN value END) AS status
FROM user_attributes
GROUP BY user_id;
-- Returns 'active' correctly ✅
-- MAX ignores NULL and returns the single non-NULL value

-- ============================================================
-- MISTAKE 3: Pivoting high cardinality columns
-- 1000 distinct values = 1000 columns = data modeling problem
-- ============================================================

-- WRONG approach — pivoting product_id with 1000 distinct values
-- SELECT order_id,
--        SUM(CASE WHEN product_id = 'P001' THEN quantity END) AS P001,
--        SUM(CASE WHEN product_id = 'P002' THEN quantity END) AS P002,
--        -- ... 998 more columns ❌
-- This is a data modeling problem not a pivot problem

-- CORRECT approach — keep as rows
SELECT order_id, product_id, SUM(quantity) AS total_qty
FROM orders
GROUP BY order_id, product_id
ORDER BY order_id, product_id;
-- Clean rows, queryable, maintainable ✅

-- ============================================================
-- MISTAKE 4: NULL handling in native UNPIVOT
-- Native UNPIVOT silently drops rows where value is NULL
-- Use UNION ALL to preserve NULLs
-- ============================================================

-- Data:
-- month   | revenue | costs
-- 2024-01 | 50000   | NULL  ← NULL costs
-- 2024-02 | 55000   | 32000

-- WRONG — native UNPIVOT drops NULLs silently
-- SELECT month, metric, value
-- FROM monthly_revenue
-- UNPIVOT (value FOR metric IN (revenue, costs)) AS unpvt;
--
-- Output (Jan costs row MISSING — no warning):
-- month   | metric  | value
-- 2024-01 | revenue | 50000  ← Jan costs dropped ❌
-- 2024-02 | revenue | 55000
-- 2024-02 | costs   | 32000

-- CORRECT — UNION ALL preserves NULLs
SELECT month, 'revenue' AS metric, revenue AS value FROM monthly_revenue
UNION ALL
SELECT month, 'costs'   AS metric, costs   AS value FROM monthly_revenue
ORDER BY month, metric;
-- month   | metric  | value
-- 2024-01 | costs   | NULL   ← preserved ✅
-- 2024-01 | revenue | 50000
-- 2024-02 | costs   | 32000
-- 2024-02 | revenue | 55000

-- ============================================================
-- MISTAKE 5: Mismatched column types in native UNPIVOT
-- All columns must share same data type — CAST first
-- ============================================================

-- Data:
-- product_id | price | category
-- 1          | 100   | Electronics  ← INT vs VARCHAR

-- WRONG — type mismatch
-- SELECT product_id, metric, value
-- FROM products
-- UNPIVOT (value FOR metric IN (price, category)) AS unpvt;
-- ERROR: cannot unpivot INT and VARCHAR ❌

-- CORRECT — CAST all to same type first
SELECT product_id, metric, value
FROM (
    SELECT
        product_id,
        CAST(price AS VARCHAR) AS price,  -- convert INT to VARCHAR
        category                           -- already VARCHAR
    FROM products
) src
UNPIVOT (value FOR metric IN (price, category)) AS unpvt
ORDER BY product_id, metric;
-- product_id | metric   | value
-- 1          | category | Electronics ✅
-- 1          | price    | 100         ✅

-- ============================================================
-- PIVOT vs UNPIVOT — MIRROR IMAGE COMPARISON:
--
-- PIVOT:   values in a column → become column names
-- UNPIVOT: column names → become values in a column
--
-- PIVOT syntax:   SUM(value) FOR metric IN ([revenue], [costs])
-- UNPIVOT syntax: value FOR metric IN (revenue, costs)
--
-- Same FOR col IN (...) structure — direction reverses
-- PIVOT:   metric column VALUES become new COLUMNS
-- UNPIVOT: existing COLUMNS become VALUES in metric column
-- ============================================================

-- ============================================================
-- CASE vs NATIVE — WHEN TO USE:
--
-- Feature                    CASE approach   Native PIVOT/UNPIVOT
-- Works on all platforms     YES             SQL Server, Snowflake, Oracle
-- Multiple aggregations      YES             NO — one only
-- Computed columns inline    YES             NO — needs subquery wrapper
-- NULL preservation          YES             NO — native UNPIVOT drops NULLs
-- Recommended for            Complex pivots  Simple single-aggregation pivots
-- ============================================================

-- ============================================================
-- KEY PATTERNS — MEMORIZE THESE:
--
-- Numeric pivot:   SUM(CASE WHEN col = 'val' THEN numeric_col END)
-- Count pivot:     COUNT(CASE WHEN col = 'val' THEN 1 END)
--                  ← no ELSE — let non-matching return NULL
-- Text pivot:      MAX(CASE WHEN col = 'val' THEN text_col END)
-- Computed col:    SUM(revenue_case) - SUM(costs_case) AS profit
--
-- UNPIVOT with UNION ALL:
--   SELECT id, 'col1' AS metric, col1 AS value FROM table
--   UNION ALL
--   SELECT id, 'col2' AS metric, col2 AS value FROM table
--
-- UNPIVOT with CROSS JOIN:
--   FROM table w
--   CROSS JOIN (SELECT 'col1' AS metric UNION ALL SELECT 'col2') m
--   CASE m.metric WHEN 'col1' THEN w.col1 WHEN 'col2' THEN w.col2 END
-- ============================================================
