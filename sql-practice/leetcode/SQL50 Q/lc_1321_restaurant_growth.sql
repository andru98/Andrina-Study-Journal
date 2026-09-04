-- ============================================================
-- Problem : Restaurant Growth (Moving Average)
-- Source  : LeetCode 1321
-- Link    : https://leetcode.com/problems/restaurant-growth/
-- Topic   : Window Functions / SUM OVER / AVG OVER / OFFSET
-- Level   : Medium
-- Date    : 2026-08-26
-- ============================================================

-- PROBLEM STATEMENT:
-- Table: Customer (customer_id, name, visited_on, amount)
-- (customer_id, visited_on) is primary key
-- Compute 7-day moving average of daily total amount
-- (current day + 6 days before)
-- average_amount rounded to 2 decimal places
-- Return ordered by visited_on ascending

-- ============================================================
-- KEY INSIGHT:
-- Multiple customers can visit same day
-- → must SUM amounts per day FIRST (daily_totals CTE)
-- → then apply 7-day window on daily totals
--
-- Why OFFSET not WHERE for filtering first 6 days:
-- WHERE filters rows BEFORE window function sees them
-- → window only sees filtered rows → wrong calculation ❌
-- OFFSET applied AFTER window calculation
-- → window sees ALL rows → correct 7-day window ✅
--
-- ROWS BETWEEN 6 PRECEDING AND CURRENT ROW:
-- → current row + 6 rows before = 7 rows total ✅
-- → sliding window moves one day at a time ✅
-- ============================================================

-- ============================================================
-- APPROACH 1: OFFSET (cleanest solution) ✅
-- ============================================================

WITH day_sum_table AS (
    SELECT
        visited_on,
        SUM(amount) AS day_sum
    FROM Customer
    GROUP BY visited_on
    ORDER BY visited_on
)
SELECT
    visited_on,
    SUM(day_sum) OVER (
        ORDER BY visited_on
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS amount,
    ROUND(AVG(day_sum) OVER (
        ORDER BY visited_on
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2) AS average_amount
FROM day_sum_table
OFFSET 6;  -- skip first 6 incomplete windows ✅

-- ============================================================
-- APPROACH 2: Subquery with ROW_NUMBER filter
-- Window runs on ALL rows first → then filter ✅
-- ============================================================

SELECT visited_on, amount, average_amount
FROM (
    SELECT
        visited_on,
        ROW_NUMBER() OVER (ORDER BY visited_on) AS rn,
        SUM(day_sum) OVER (
            ORDER BY visited_on
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) AS amount,
        ROUND(AVG(day_sum) OVER (
            ORDER BY visited_on
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ), 2) AS average_amount
    FROM (
        SELECT visited_on, SUM(amount) AS day_sum
        FROM Customer
        GROUP BY visited_on
    ) daily
) t
WHERE rn >= 7  -- filter AFTER window calculated ✅
ORDER BY visited_on;

-- ============================================================
-- EXAMPLE WALKTHROUGH:
-- Input (after GROUP BY visited_on):
-- visited_on  | day_sum
-- 2019-01-01  | 100
-- 2019-01-02  | 110
-- 2019-01-03  | 120
-- 2019-01-04  | 130
-- 2019-01-05  | 110
-- 2019-01-06  | 140
-- 2019-01-07  | 150
-- 2019-01-08  | 80
-- 2019-01-09  | 110
-- 2019-01-10  | 280  ← 130+150 (two customers) ✅
--
-- 7-day windows:
-- Jan 07: 100+110+120+130+110+140+150 = 860 / 7 = 122.86 ✅
-- Jan 08: 110+120+130+110+140+150+80  = 840 / 7 = 120.00 ✅
-- Jan 09: 120+130+110+140+150+80+110  = 840 / 7 = 120.00 ✅
-- Jan 10: 130+110+140+150+80+110+280  = 1000/ 7 = 142.86 ✅
--
-- OFFSET 6: skip Jan 01-06 (incomplete windows) ✅
-- Show from Jan 07 onwards ✅
-- ============================================================

-- ============================================================
-- COMMON MISTAKES:
--
-- 1. Not grouping by day first:
--    → window runs on individual customer rows ❌
--    → Jan 10 has 2 customers → treated as 2 separate days ❌
--    → Fix: GROUP BY visited_on first ✅
--
-- 2. Using WHERE rn >= 7 directly on window:
--    → WHERE filters BEFORE window sees rows ❌
--    → window only sees 4 rows instead of 10 ❌
--    → Fix: wrap in subquery OR use OFFSET ✅
--
-- 3. Missing ORDER BY in OVER():
--    → undefined row order → wrong window ❌
--    → Fix: ORDER BY visited_on in OVER() ✅
--
-- 4. Using LIMIT 6 instead of OFFSET 6:
--    → LIMIT 6: returns FIRST 6 rows ❌
--    → OFFSET 6: SKIPS first 6 rows ✅
-- ============================================================

-- ============================================================
-- OFFSET vs LIMIT:
--
-- LIMIT n  → return first n rows
-- OFFSET n → skip first n rows
-- LIMIT 3 OFFSET 6 → skip 6, return next 3 (pagination)
--
-- SQL Execution Order:
-- 1. FROM/CTE
-- 2. WHERE      ← filters before window ❌
-- 3. GROUP BY
-- 4. HAVING
-- 5. SELECT     ← window functions execute here
-- 6. ORDER BY
-- 7. LIMIT/OFFSET ← applied after window ✅
-- ============================================================

-- ============================================================
-- ROWS vs RANGE (for missing dates):
--
-- ROWS BETWEEN 6 PRECEDING:
-- → counts 6 physical rows back
-- → wrong if dates have gaps ❌
--
-- RANGE BETWEEN INTERVAL '6 days' PRECEDING:
-- → looks back 6 actual calendar days
-- → correct with date gaps ✅
-- → problem guarantees no gaps so ROWS works ✅
--
-- Production use (sensor data with gaps):
-- SUM(value) OVER (
--     ORDER BY date
--     RANGE BETWEEN INTERVAL '6 days' PRECEDING
--               AND CURRENT ROW
-- )
-- ============================================================

-- ============================================================
-- KEY PATTERN — MEMORIZE THIS:
-- "N-day moving average with daily aggregation":
--
--   WITH daily AS (
--       SELECT date_col, SUM(value_col) AS daily_total
--       FROM table
--       GROUP BY date_col
--   )
--   SELECT date_col,
--       SUM(daily_total) OVER (
--           ORDER BY date_col
--           ROWS BETWEEN N-1 PRECEDING AND CURRENT ROW
--       ) AS rolling_sum,
--       ROUND(AVG(daily_total) OVER (
--           ORDER BY date_col
--           ROWS BETWEEN N-1 PRECEDING AND CURRENT ROW
--       ), 2) AS rolling_avg
--   FROM daily
--   OFFSET N-1;  -- skip incomplete windows
--
-- Real DE use cases:
-- → Restaurant 7-day revenue trend (this problem) ✅
-- → 30-day moving average stock price ✅
-- → Weekly active users (WAU) calculation ✅
-- → Spotify: 7-day rolling track plays per artist ✅
-- → Caterpillar: 24-hour rolling sensor readings ✅
-- → Airline RM: 7-day booking pace per route ✅
-- ============================================================
