-- ============================================================
-- Problem : Find Total Time Spent by Each Employee
-- Source  : LeetCode 1741
-- Link    : https://leetcode.com/problems/find-total-time-spent-by-each-employee/
-- Topic   : Aggregation / GROUP BY
-- Level   : Easy
-- Date    : 2026-06-09
-- ============================================================

-- PROBLEM STATEMENT:
-- Table: Employees (emp_id, event_day, in_time, out_time)
-- Each row represents one work event for an employee on a given day.
-- An employee can have multiple events (check-ins) on the same day.
-- Find the total time in minutes spent by each employee on each day.
-- Return: day, emp_id, total_time (in any order)

-- ============================================================
-- APPROACH:
-- Total time per employee per day = SUM(out_time - in_time)
-- grouped by emp_id and event_day.
-- No window function needed here — GROUP BY collapses rows
-- into one row per employee per day, which is exactly what
-- the problem asks for.
--
-- Key decision: GROUP BY vs Window Function
-- Use GROUP BY when you want one collapsed row per group.
-- Use SUM() OVER() when you want running/cumulative totals
-- while keeping individual rows intact.
-- This problem wants collapsed totals — GROUP BY is correct.
-- ============================================================

SELECT
    event_day          AS day,
    emp_id,
    SUM(out_time - in_time) AS total_time
FROM Employees
GROUP BY emp_id, event_day;

-- ============================================================
-- EXAMPLE WALKTHROUGH:
-- Input:
-- emp_id | event_day  | in_time | out_time
-- 1      | 2020-11-28 | 4       | 32        → 28 mins
-- 1      | 2020-11-28 | 55      | 200       → 145 mins
-- 1      | 2020-12-03 | 1       | 42        → 41 mins
-- 2      | 2020-11-28 | 3       | 33        → 30 mins
-- 2      | 2020-12-09 | 47      | 74        → 27 mins
--
-- Output:
-- day        | emp_id | total_time
-- 2020-11-28 | 1      | 173   (28 + 145)
-- 2020-12-03 | 1      | 41
-- 2020-11-28 | 2      | 30
-- 2020-12-09 | 2      | 27
-- ============================================================

-- ============================================================
-- EDGE CASES TO KEEP IN MIND:
-- 1. Employee has only one event on a day — SUM of one row,
--    still correct, no special handling needed.
-- 2. Multiple events same day — SUM aggregates them correctly.
-- 3. Same employee appears on different days — GROUP BY both
--    emp_id AND event_day ensures each day is separate.
--    Grouping by emp_id alone would merge all days — wrong.
-- 4. out_time is always > in_time per problem constraints,
--    so no negative values to worry about.
-- ============================================================

-- ============================================================
-- COMMON MISTAKE:
-- Using SUM() OVER (PARTITION BY emp_id ORDER BY event_day)
-- gives a cumulative running total across days, not the
-- total for each individual day. For example, emp 1 on
-- Dec-03 would show 173 + 41 = 214 instead of just 41.
-- Always ask: do I need rows preserved (window) or
-- collapsed (GROUP BY)?
-- ============================================================
