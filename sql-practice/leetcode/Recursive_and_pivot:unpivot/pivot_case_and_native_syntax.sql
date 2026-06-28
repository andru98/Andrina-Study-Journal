-- ============================================================
-- Topic    : PIVOT — Reshaping Rows to Columns
-- Covers   : CASE WHEN approach + Native PIVOT syntax
-- Source   : DataVidhya / Interview Pattern
-- Level    : Medium (3-5 years experience)
-- Date     : 2026-06-25
-- ============================================================

-- ============================================================
-- WHAT IS PIVOT?
-- Pivot transforms row-level data into column-level output.
-- Source systems store data in rows (easy to insert).
-- Dashboards and reports need data in columns (easy to read).
--
-- Before pivot — one row per metric per month:
-- month   | metric  | value
-- 2024-01 | revenue | 50000
-- 2024-01 | costs   | 30000
-- 2024-02 | revenue | 55000
-- 2024-02 | costs   | 32000
--
-- After pivot — one row per month, metrics as columns:
-- month   | revenue | costs
-- 2024-01 | 50000   | 30000
-- 2024-02 | 55000   | 32000
-- ============================================================

-- ============================================================
-- PART 1: CASE WHEN + GROUP BY — UNIVERSAL APPROACH
-- Works on every platform: MySQL, PostgreSQL, Snowflake,
-- BigQuery, SQL Server. Use this by default.
-- ============================================================

-- ============================================================
-- APPROACH:
-- Step 1 — CASE WHEN returns value for matching rows, NULL for others
-- Step 2 — SUM/MAX aggregates per group, ignoring NULLs
-- Step 3 — GROUP BY collapses rows into one row per group
--
-- Why SUM not just CASE:
-- Without GROUP BY + SUM you get one row per original row
-- each with NULLs in non-matching columns.
-- SUM ignores NULLs and collapses rows into one per group.
--
-- Why no ELSE in COUNT:
-- COUNT(CASE WHEN status = 'active' THEN 1 END)
-- Non-matching rows return NULL → COUNT ignores NULL ✅
-- COUNT(CASE WHEN status = 'active' THEN 1 ELSE 0 END)
-- Non-matching rows return 0 → COUNT counts 0 too ❌ overcounts
-- ============================================================

-- Basic pivot — single aggregation per column
SELECT
    month,
    SUM(CASE WHEN metric = 'revenue' THEN value END) AS revenue,
    SUM(CASE WHEN metric = 'costs'   THEN value END) AS costs
FROM monthly_metrics
GROUP BY month
ORDER BY month;

-- ============================================================
-- PIVOT WITH COMPUTED COLUMN — profit = revenue - costs
-- Native PIVOT cannot do this in one step — needs subquery wrapper.
-- CASE approach handles it inline cleanly.
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
-- STEP BY STEP WALKTHROUGH (month = 2024-01):
--
-- Raw rows for 2024-01:
-- metric='revenue', value=50000
-- metric='costs',   value=30000
--
-- After CASE WHEN (before GROUP BY):
-- month   | revenue | costs
-- 2024-01 | 50000   | NULL    ← revenue row
-- 2024-01 | NULL    | 30000   ← costs row
--
-- After GROUP BY month + SUM (SUM ignores NULL):
-- month   | revenue | costs  | profit
-- 2024-01 | 50000   | 30000  | 20000
-- ============================================================

-- ============================================================
-- MULTI-COLUMN PIVOT — multiple aggregations per status
-- Native PIVOT can only do ONE aggregation at a time.
-- CASE approach handles COUNT + SUM together cleanly.
-- ============================================================

-- Table: customers (region, status, revenue)
-- status values: 'active', 'churned'
-- Goal: count and sum revenue per status per region

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
-- EXAMPLE WALKTHROUGH:
-- Input:
-- region | status  | revenue
-- North  | active  | 100
-- North  | churned | 50
-- South  | active  | 80
-- South  | churned | 30
--
-- Output:
-- region | active_count | active_revenue | churned_count | churned_revenue
-- North  | 1            | 100            | 1             | 50
-- South  | 1            | 80             | 1             | 30
-- ============================================================

-- ============================================================
-- MAX FOR TEXT PIVOTS — when pivoting non-numeric values
-- SUM fails on text (TypeError). MAX works on text.
-- MAX ignores NULL just like SUM.
-- When only one non-NULL value exists per group,
-- MAX simply returns that one value.
-- ============================================================

-- Table: user_attributes (user_id, category, value)
-- category values: 'status', 'tier'
SELECT
    user_id,
    MAX(CASE WHEN category = 'status' THEN value END) AS status,
    MAX(CASE WHEN category = 'tier'   THEN value END) AS tier
FROM user_attributes
GROUP BY user_id
ORDER BY user_id;

-- ============================================================
-- PART 2: NATIVE PIVOT SYNTAX
-- Cleaner for simple single-aggregation pivots.
-- Platform specific — SQL Server, Snowflake, Oracle only.
-- Cannot do multiple aggregations or computed columns inline.
-- ============================================================

-- ============================================================
-- SQL SERVER / AZURE SYNAPSE SYNTAX:
-- Square brackets [] around pivot values
-- Alias required after closing parenthesis
-- ============================================================

SELECT month, revenue, costs
FROM monthly_metrics
PIVOT (
    SUM(value)                      -- one aggregation only
    FOR metric IN ([revenue], [costs])  -- square brackets for SQL Server
) AS pvt
ORDER BY month;

-- ============================================================
-- SNOWFLAKE SYNTAX:
-- Single quotes around pivot values (not square brackets)
-- SELECT * works — returns all columns automatically
-- ============================================================

SELECT *
FROM monthly_metrics
PIVOT (
    SUM(value)
    FOR metric IN ('revenue', 'costs')  -- single quotes for Snowflake
)
ORDER BY month;

-- ============================================================
-- NATIVE PIVOT WITH COMPUTED COLUMN — needs subquery wrapper:
-- Cannot compute profit inline with native PIVOT.
-- Must wrap in subquery then compute outside.
-- This is why CASE approach is preferred for complex pivots.
-- ============================================================

SELECT
    month,
    revenue,
    costs,
    revenue - costs AS profit          -- computed AFTER pivot
FROM (
    SELECT month, value, metric
    FROM monthly_metrics
) src
PIVOT (
    SUM(value)
    FOR metric IN ([revenue], [costs])
) AS pvt
ORDER BY month;

-- ============================================================
-- CASE vs NATIVE PIVOT COMPARISON:
--
-- Feature                    CASE approach   Native PIVOT
-- Works on all platforms     YES             SQL Server, Snowflake, Oracle only
-- Multiple aggregations      YES             NO — one only
-- Computed columns inline    YES             NO — needs subquery wrapper
-- Text values (status/tier)  YES (MAX)       Limited
-- Clean syntax               Verbose         Compact
-- Recommended for            Complex pivots  Simple single-aggregation pivots
--
-- Interview answer:
-- "I prefer CASE WHEN + GROUP BY over native PIVOT — it works on
--  every platform, supports multiple aggregations per column, and
--  allows computed columns like profit = revenue - costs inline.
--  Native PIVOT is cleaner syntax but limited to one aggregation
--  and only works on SQL Server, Snowflake, and Oracle."
-- ============================================================

-- ============================================================
-- COUNT(*) vs COUNT(column) IN PIVOT — important gotcha:
--
-- COUNT(*)         → counts ALL rows including NULL values → overcounts
-- COUNT(revenue)   → counts only non-NULL revenue rows → correct
-- COUNT(CASE WHEN status = 'active' THEN 1 END)
--                  → returns NULL for non-matching rows
--                  → COUNT ignores NULL → counts only active rows ✅
--
-- Always use COUNT(column) or COUNT(CASE WHEN ... THEN 1 END)
-- Never use COUNT(*) in pivot aggregations
-- ============================================================

-- ============================================================
-- KEY PATTERNS — MEMORIZE THESE:
--
-- Numeric pivot (SUM):
--   SUM(CASE WHEN col = 'value' THEN numeric_col END) AS alias
--
-- Count pivot (COUNT):
--   COUNT(CASE WHEN col = 'value' THEN 1 END) AS alias
--   ← no ELSE — let non-matching return NULL so COUNT ignores them
--
-- Text pivot (MAX):
--   MAX(CASE WHEN col = 'value' THEN text_col END) AS alias
--
-- Computed column:
--   SUM(CASE WHEN col = 'revenue' THEN val END)
--   - SUM(CASE WHEN col = 'costs' THEN val END) AS profit
--
-- Always GROUP BY the non-pivot column (month, region, user_id)
-- ============================================================

-- ============================================================
-- REAL DE USE CASES:
-- 1. Monthly revenue dashboard — metrics as columns per month
-- 2. Customer segmentation — active/churned counts per region
-- 3. A/B test results — control/treatment metrics side by side
-- 4. Survey responses — question answers as columns per respondent
-- 5. Time series comparison — daily values as columns per week
-- ============================================================
