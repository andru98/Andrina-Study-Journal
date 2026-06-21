-- ============================================================
-- Problem : User Activity for the Past 30 Days I
-- Source  : LeetCode 1141
-- Link    : https://leetcode.com/problems/user-activity-for-the-past-30-days-i/
-- Topic   : Date Functions / INTERVAL / COUNT DISTINCT / GROUP BY
-- Level   : Easy
-- Date    : 2026-06-19
-- ============================================================

-- PROBLEM STATEMENT:
-- Table: Activity (user_id, session_id, activity_date, activity_type)
-- Find the daily active users for the 30-day period
-- ending on 2019-07-27 (inclusive).
-- A user is active on a day if they have at least one activity.
-- Return: day, active_users

-- ============================================================
-- APPROACH:
-- Step 1 — Filter the 30-day window ending July 27 inclusive.
--          Use DATE_SUB for MySQL compatibility (LeetCode default).
--          Window: June 28 to July 27 = 30 days.
--          activity_date <= '2019-07-27' (inclusive end)
--          activity_date > DATE_SUB('2019-07-27', INTERVAL 30 DAY)
--          (exclusive start — > not >= gives exactly 30 days)
--
-- Step 2 — COUNT(DISTINCT user_id) per day.
--          One user can have multiple activities on same day.
--          DISTINCT ensures they count as 1 active user not many.
--
-- Step 3 — GROUP BY activity_date to get one row per day.
--
-- Key decision: activity_date is DATE not TIMESTAMP so
-- DATE_SUB is safe — no boundary crossing issue.
-- DATEDIFF boundary gotcha only affects TIMESTAMP columns.
-- ============================================================

SELECT
    activity_date                  AS day,
    COUNT(DISTINCT user_id)        AS active_users
FROM Activity
WHERE activity_date <= '2019-07-27'
  AND activity_date > DATE_SUB('2019-07-27', INTERVAL 30 DAY)
GROUP BY activity_date
ORDER BY activity_date;

-- ============================================================
-- EXAMPLE WALKTHROUGH:
-- DATE_SUB('2019-07-27', INTERVAL 30 DAY) = '2019-06-27'
-- Window: activity_date > '2019-06-27' AND <= '2019-07-27'
-- = June 28 to July 27 inclusive = exactly 30 days
--
-- Input:
-- user_id | activity_date | activity_type
-- 1       | 2019-07-20    | open_session
-- 1       | 2019-07-20    | scroll_down   ← same user same day
-- 1       | 2019-07-20    | end_session   ← same user same day
-- 2       | 2019-07-20    | open_session
-- 2       | 2019-07-21    | send_message
-- 2       | 2019-07-21    | end_session
-- 3       | 2019-06-25    | open_session  ← outside window, excluded
-- 3       | 2019-06-25    | end_session   ← outside window, excluded
--
-- After WHERE filter (June 28 - July 27):
-- user 1 → July 20 (3 rows but COUNT DISTINCT = 1)
-- user 2 → July 20, July 21
-- user 3 → excluded (June 25 outside window)
--
-- After GROUP BY + COUNT DISTINCT:
-- day        | active_users
-- 2019-07-20 | 2   (users 1 and 2)
-- 2019-07-21 | 1   (user 2 only)
-- ============================================================

-- ============================================================
-- EDGE CASES TO KEEP IN MIND:
-- 1. Multiple activities same user same day:
--    COUNT(*) would return 3 for user 1 on July 20 — wrong
--    COUNT(DISTINCT user_id) correctly returns 1 ✅
--
-- 2. Date window boundary — > not >=:
--    > '2019-06-27' excludes June 27 itself
--    >= '2019-06-27' would include June 27 → 31 days not 30
--    Always use > for exclusive start of window
--
-- 3. Days with zero active users not returned:
--    GROUP BY only returns dates that exist in filtered data
--    If no activity on a day → that day won't appear in output
--    Problem doesn't require zero-activity days so this is correct
--
-- 4. activity_date is DATE not TIMESTAMP:
--    No timezone or time component issues
--    DATE_SUB on DATE column is safe and precise
-- ============================================================

-- ============================================================
-- PLATFORM SYNTAX COMPARISON:
-- MySQL (LeetCode):
--   WHERE activity_date > DATE_SUB('2019-07-27', INTERVAL 30 DAY)
--
-- PostgreSQL:
--   WHERE activity_date > DATE '2019-07-27' - INTERVAL '30 days'
--
-- Snowflake:
--   WHERE activity_date > DATEADD(day, -30, '2019-07-27'::date)
--
-- BigQuery:
--   WHERE activity_date > DATE_SUB(DATE '2019-07-27', INTERVAL 30 DAY)
-- ============================================================

-- ============================================================
-- KEY PATTERN — MEMORIZE THIS:
-- "Daily active users in rolling N-day window":
--   1. WHERE date <= end_date
--      AND date > DATE_SUB(end_date, INTERVAL N DAY)
--   2. COUNT(DISTINCT user_id) — not COUNT(*)
--   3. GROUP BY date
--   4. ORDER BY date
--
-- Always use COUNT DISTINCT for "active users" — one user
-- can have many events on same day but counts as 1.
-- ============================================================
