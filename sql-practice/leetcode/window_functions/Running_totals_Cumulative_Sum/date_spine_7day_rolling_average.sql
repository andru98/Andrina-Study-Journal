-- Problem: 7-Day Rolling Average with Gap Filling (Date Spine)
-- Source: Interview Pattern / Custom
-- Folder: sql-practice/leetcode/window_functions/

-- Topic: generate_series + LEFT JOIN + COALESCE + Rolling Average Window
-- Difficulty: Hard
-- Database: PostgreSQL / Snowflake (generate_series not available in MySQL)

-- Problem Statement:
-- Given a daily_metrics table with event_date and daily_active_users,
-- calculate the 7-day rolling average of DAU for every calendar date.
-- The table may have missing dates (days with no activity have no row).
-- Missing dates must be filled with 0 before calculating the rolling average,
-- otherwise the window covers wrong calendar days.

-- Why gap filling matters:
-- ROWS BETWEEN 6 PRECEDING AND CURRENT ROW counts 6 DATA ROWS back,
-- not 6 CALENDAR DAYS back. If Jan 3 is missing, the window for Jan 8
-- goes back to Dec 28 instead of Jan 2 — wrong average entirely.
-- Filling gaps first ensures each window always covers exactly 7 calendar days.

-- Approach:
-- 1. date_spine CTE: generate every calendar date in the range using generate_series.
--    No gaps — every date exists as a row.
-- 2. filled CTE: LEFT JOIN date_spine to daily_metrics on event_date.
--    Missing dates get NULL from the right side.
--    COALESCE(dm.daily_active_users, 0) converts NULL to 0.
--    Now every calendar date has a row with either real data or 0.
-- 3. Final SELECT: apply AVG() OVER with ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
--    on the gap-filled data. Window always covers exactly 7 calendar days.

WITH date_spine AS (
    SELECT generate_series(
        '2024-01-01'::date,
        '2024-12-31'::date,
        '1 day'
    ) AS dt
),
filled AS (
    SELECT
        ds.dt                                        AS event_date,
        COALESCE(dm.daily_active_users, 0)           AS daily_active_users
    FROM date_spine ds
    LEFT JOIN daily_metrics dm ON ds.dt = dm.event_date
)
SELECT
    event_date,
    daily_active_users,
    AVG(daily_active_users) OVER (
        ORDER BY event_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS seven_day_avg
FROM filled;

-- ============================================================
-- WHAT THE OUTPUT LOOKS LIKE
-- ============================================================
-- event_date | daily_active_users | seven_day_avg
-- 2024-01-01 | 100                | 100.00       ← only 1 day, partial window
-- 2024-01-02 | 120                | 110.00       ← 2 days
-- 2024-01-03 | 0                  | 73.33        ← gap filled with 0
-- 2024-01-04 | 90                 | 77.50        ← 4 days
-- 2024-01-05 | 130                | 88.00        ← 5 days
-- 2024-01-06 | 95                 | 89.17        ← 6 days
-- 2024-01-07 | 115                | 92.86        ← first full 7-day window
-- 2024-01-08 | 140                | 98.57        ← window slides: Jan2 to Jan8

-- ============================================================
-- ROWS BETWEEN 6 PRECEDING AND CURRENT ROW — sliding window
-- ============================================================
-- 6 PRECEDING = at most 6 rows before the current row
-- CURRENT ROW = the current row
-- Total = 7 rows maximum
--
-- Jan 7 window: Jan 1 to Jan 7 = 7 rows (first full window)
-- Jan 8 window: Jan 2 to Jan 8 = 7 rows (Jan 1 dropped, Jan 8 added)
-- Jan 9 window: Jan 3 to Jan 9 = 7 rows (Jan 2 dropped, Jan 9 added)
--
-- Compare with UNBOUNDED PRECEDING:
-- Jan 8 window: Jan 1 to Jan 8 = 8 rows (keeps growing)
-- Jan 9 window: Jan 1 to Jan 9 = 9 rows (never drops old rows)
-- UNBOUNDED PRECEDING = cumulative total, never resets

-- ============================================================
-- PARTIAL WINDOW BEHAVIOR — first 6 days
-- ============================================================
-- Days 1-6 have fewer than 7 rows in their window.
-- AVG calculates over available rows — partial average.
-- If you want NULL instead of partial average, wrap with CASE WHEN:
--
-- CASE
--     WHEN COUNT(*) OVER (ORDER BY event_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) = 7
--     THEN AVG(daily_active_users) OVER (ORDER BY event_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)
-- END AS seven_day_avg
--
-- Returns NULL for first 6 days — only shows average when full 7-day window available

-- ============================================================
-- MYSQL ALTERNATIVE — no generate_series, use recursive CTE
-- ============================================================
-- WITH RECURSIVE date_spine AS (
--     SELECT '2024-01-01' AS dt
--     UNION ALL
--     SELECT DATE_ADD(dt, INTERVAL 1 DAY)
--     FROM date_spine
--     WHERE dt < '2024-12-31'
-- )

-- Edge Cases
-- Missing date in middle of range    → filled with 0 via COALESCE — window unaffected
-- Missing date at start of range     → filled with 0 — partial window still correct
-- NULL daily_active_users in table   → COALESCE converts to 0 before window runs
-- No gap filling done                → ROWS frame counts data rows not calendar days
--                                       rolling average covers wrong date range silently
-- generate_series availability       → PostgreSQL, Snowflake, BigQuery only
--                                       MySQL needs recursive CTE instead
-- Choosing 0 vs NULL for gaps        → depends on business question
--                                       0 = product existed but nobody showed up
--                                       NULL = product did not exist yet (pre-launch)
--                                       clarify with interviewer before choosing COALESCE default
