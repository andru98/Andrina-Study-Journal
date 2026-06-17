-- ============================================================
-- Problem : Restaurant Growth
-- Source  : LeetCode 1321
-- Link    : https://leetcode.com/problems/restaurant-growth/
-- Topic   : Window Functions / SUM OVER / AVG OVER / ROWS BETWEEN
-- Level   : Medium
-- Date    : 2026-06-14
-- ============================================================

-- PROBLEM STATEMENT:
-- Table: Customer (customer_id, name, visited_on, amount)
-- Compute the 7-day moving average of amount spent.
-- For each day (from the 7th day onwards):
-- - Total amount spent in the last 7 days
-- - Average amount (rounded to 2 decimal places)
-- Return ordered by visited_on.

-- ============================================================
-- APPROACH:
-- Step 1 — Aggregate total amount per date using GROUP BY.
--          Multiple customers can visit on the same date.
--          Must collapse to one row per date before windowing.
-- Step 2 — Apply SUM() and AVG() with ROWS BETWEEN 6 PRECEDING
--          AND CURRENT ROW to compute 7-day rolling totals.
--          No PARTITION BY — window must roll across ALL dates.
-- Step 3 — Use ROW_NUMBER() to number each date sequentially.
--          Filter WHERE row_num >= 7 to skip the first 6 days
--          which don't have a full 7-day window yet.
--
-- Key decisions:
-- 1. GROUP BY date first — table has multiple rows per date
--    (one per customer). Without grouping, window operates on
--    customer rows not daily totals → wrong results.
-- 2. No PARTITION BY in window functions — PARTITION BY visited_on
--    would reset the window per date, giving only that day's
--    amount instead of the 7-day rolling sum.
-- 3. ROWS BETWEEN 6 PRECEDING AND CURRENT ROW = 7 rows total
--    (current row + 6 rows before it).
-- ============================================================

WITH daily_totals AS (
    -- Step 1: collapse multiple customers per day into one daily total
    SELECT
        visited_on,
        SUM(amount) AS daily_amount
    FROM Customer
    GROUP BY visited_on
),
moving_avg AS (
    -- Step 2: apply 7-day rolling window across all dates
    SELECT
        visited_on,
        SUM(daily_amount) OVER (
            ORDER BY visited_on
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        )                                                    AS amount,
        ROUND(AVG(daily_amount) OVER (
            ORDER BY visited_on
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ), 2)                                                AS average_amount,
        ROW_NUMBER() OVER (ORDER BY visited_on)              AS row_num
    FROM daily_totals
)
-- Step 3: only return days with a full 7-day window
SELECT visited_on, amount, average_amount
FROM moving_avg
WHERE row_num >= 7
ORDER BY visited_on;

-- ============================================================
-- EXAMPLE WALKTHROUGH:
-- Input (simplified):
-- visited_on  | amount (per customer)
-- 2019-01-01  | 100
-- 2019-01-02  | 110
-- 2019-01-03  | 120
-- 2019-01-04  | 130
-- 2019-01-05  | 110
-- 2019-01-06  | 140
-- 2019-01-07  | 150
-- 2019-01-08  | 80  (two customers: 50 + 30)
--
-- After daily_totals CTE (one row per date):
-- 2019-01-01 | 100
-- 2019-01-02 | 110
-- ...
-- 2019-01-07 | 150
-- 2019-01-08 | 80
--
-- After moving_avg CTE (row_num < 7 skipped):
-- 2019-01-07 | amount=860 | avg=122.86
--   (100+110+120+130+110+140+150=860, 860/7=122.86)
-- 2019-01-08 | amount=840 | avg=120.00
--   (110+120+130+110+140+150+80=840, 840/7=120.00)
-- ============================================================

-- ============================================================
-- EDGE CASES TO KEEP IN MIND:
-- 1. Multiple customers same day — GROUP BY visited_on in
--    daily_totals CTE handles this. Without it, window
--    function operates on individual customer rows → wrong.
-- 2. PARTITION BY visited_on is WRONG here — it resets the
--    window per date giving only that day's amount.
--    No PARTITION BY = window rolls across all dates ✅
-- 3. WHERE row_num >= 7 skips first 6 days correctly.
--    Day 1-6 have incomplete 7-day windows — including them
--    would give misleading averages.
-- 4. ROWS BETWEEN 6 PRECEDING AND CURRENT ROW = 7 rows.
--    Common mistake: ROWS BETWEEN 7 PRECEDING gives 8 rows.
--    Count: current(1) + preceding(6) = 7 ✅
-- 5. ROUND(..., 2) rounds to 2 decimal places as required.
--    Without ROUND, MySQL may return many decimal places.
-- ============================================================

-- ============================================================
-- COMMON MISTAKES:
-- 1. Missing GROUP BY date first → window operates on customer
--    rows not daily totals → wrong rolling sum
-- 2. Adding PARTITION BY visited_on → resets window per date
--    → gives individual day amount not 7-day rolling sum
-- 3. Using ROWS BETWEEN 7 PRECEDING → 8 rows not 7
-- 4. Using WHERE amount >= 7 instead of row_num >= 7
--    → completely wrong filter logic
-- 5. Second WITH keyword for second CTE → syntax error
--    Always chain CTEs with comma not second WITH
-- ============================================================

-- ============================================================
-- KEY PATTERN — MEMORIZE THIS:
-- N-day rolling window follows this structure:
--   1. GROUP BY date → daily_totals (one row per date)
--   2. SUM/AVG OVER (ORDER BY date ROWS BETWEEN N-1 PRECEDING
--      AND CURRENT ROW) → rolling calculation
--   3. ROW_NUMBER() OVER (ORDER BY date) → rn
--   4. WHERE rn >= N → skip incomplete windows
--
-- ROWS BETWEEN N-1 PRECEDING AND CURRENT ROW = N rows total
-- 7-day window → ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
-- 30-day window → ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
-- ============================================================
