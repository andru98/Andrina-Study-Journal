-- Problem: Running Total / Month-to-Date Revenue
-- Source: Interview Pattern / Custom
-- Folder: sql-practice/leetcode/window_functions/

-- Topic: SUM() OVER + PARTITION BY + ROWS BETWEEN + DATE_TRUNC
-- Difficulty: Medium

-- Problem Statement:
-- Given a daily_revenue_summary table with order_date and daily_revenue,
-- calculate the month-to-date (MTD) running total of revenue for each day.
-- The running total resets at the start of every month.

-- Approach:
-- 1. SUM(daily_revenue) OVER (...) calculates a running total.
-- 2. PARTITION BY DATE_TRUNC('month', order_date) groups rows by month.
--    The running total resets to 0 at the start of each new month.
-- 3. ORDER BY order_date inside OVER ensures accumulation goes day by day
--    in chronological order within each month partition.
-- 4. ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW explicitly defines
--    the window frame — include all rows from the start of the partition
--    up to and including the current row. One row added per day.

SELECT
    order_date,
    daily_revenue,
    SUM(daily_revenue) OVER (
        PARTITION BY DATE_TRUNC('month', order_date)
        ORDER BY order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS mtd_revenue
FROM daily_revenue_summary;

-- ============================================================
-- WHAT THE OUTPUT LOOKS LIKE
-- ============================================================
-- order_date  | daily_revenue | mtd_revenue
-- 2024-01-01  | 1000          | 1000          ← Jan day 1, starts fresh
-- 2024-01-02  | 1500          | 2500          ← 1000 + 1500
-- 2024-01-03  | 800           | 3300          ← 2500 + 800
-- 2024-02-01  | 2000          | 2000          ← Feb starts, resets to 0
-- 2024-02-02  | 1200          | 3200          ← 2000 + 1200

-- ============================================================
-- ROWS vs RANGE — why ROWS is the right choice here
-- ============================================================
-- Default frame when ORDER BY is present = RANGE BETWEEN UNBOUNDED PRECEDING
-- AND CURRENT ROW.
--
-- RANGE frame: groups all rows with the same ORDER BY value together.
-- If two rows share the same order_date — both show the end-of-day total,
-- not individual running totals. Good for reporting (end-of-day snapshots).
--
-- ROWS frame: processes strictly row by row regardless of value.
-- Each row gets its own incremental total even if dates are the same.
-- Good for transaction-level accumulation.
--
-- For daily revenue (one row per day guaranteed) — both give identical results.
-- Use ROWS explicitly to make intent clear and avoid surprises if data changes.

-- ============================================================
-- PARTITION BY DATE_TRUNC — how the monthly reset works
-- ============================================================
-- DATE_TRUNC('month', order_date) truncates every date to the first of its month.
-- 2024-01-15 → 2024-01-01
-- 2024-01-28 → 2024-01-01
-- 2024-02-05 → 2024-02-01
--
-- All January dates share the same partition value (2024-01-01).
-- All February dates share the same partition value (2024-02-01).
-- PARTITION BY treats each month as a separate window.
-- SUM resets to 0 at the start of each new partition = monthly reset.

-- ============================================================
-- VARIATION 1 — Running total with NO monthly reset (all-time cumulative)
-- ============================================================
-- Remove PARTITION BY — one window covers the entire table.
-- SUM accumulates from day 1 of all time, never resets.

-- SELECT
--     order_date,
--     daily_revenue,
--     SUM(daily_revenue) OVER (
--         ORDER BY order_date
--         ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
--     ) AS total_revenue_to_date
-- FROM daily_revenue_summary;

-- ============================================================
-- VARIATION 2 — Daily signups with running count of days
-- ============================================================
-- COUNT(*) OVER accumulates the number of rows seen so far.
-- Useful for "how many days since launch" type metrics.

-- SELECT
--     signup_date,
--     new_users,
--     SUM(new_users) OVER (ORDER BY signup_date) AS total_users_to_date,
--     COUNT(*) OVER (ORDER BY signup_date)        AS days_since_launch
-- FROM daily_signups;

-- Edge Cases
-- Two rows same order_date (RANGE default) → both show end-of-day total
--                                             fix: use ROWS frame for row-by-row
-- NULL daily_revenue                       → SUM ignores NULL, running total
--                                             skips that day's contribution
--                                             fix: COALESCE(daily_revenue, 0)
-- Missing dates (gaps in calendar)         → running total jumps correctly,
--                                             no rows inserted for missing dates
-- DATE_TRUNC in MySQL                      → DATE_TRUNC is PostgreSQL/Snowflake/BigQuery
--                                             MySQL equivalent: DATE_FORMAT(order_date, '%Y-%m-01')
--                                             or: order_date - INTERVAL (DAY(order_date)-1) DAY
-- Single day in a month                   → running total = daily_revenue for that day
-- Negative revenue (refunds)              → SUM subtracts correctly, MTD can go down
