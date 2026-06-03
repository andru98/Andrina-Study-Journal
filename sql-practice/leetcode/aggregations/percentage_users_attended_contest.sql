-- Problem: Percentage of Users Attended a Contest
-- Source: LeetCode
-- Link: https://leetcode.com/problems/percentage-of-users-attended-a-contest/
-- Folder: sql-practice/aggregations/

-- Topic: Aggregation + Scalar Subquery + ORDER BY tiebreaker
-- Difficulty: Easy

-- Problem Statement:
-- Find the percentage of users registered in each contest,
-- rounded to 2 decimal places. Order by percentage descending,
-- then by contest_id ascending as tiebreaker.

-- Approach:
-- 1. COUNT(user_id) per contest from Register table = numerator.
-- 2. Total users = scalar subquery on Users table = denominator.
--    Runs once, cached — not a correlated subquery, no performance issue.
-- 3. Multiply by 100 and ROUND to 2 decimals.
-- 4. ORDER BY percentage DESC, contest_id ASC handles ties correctly.

SELECT
    contest_id,
    ROUND(COUNT(user_id) / (SELECT COUNT(*) FROM Users) * 100, 2) AS percentage
FROM Register
GROUP BY contest_id
ORDER BY percentage DESC, contest_id ASC;

-- Edge Cases
-- NULL user_id in Register     → COUNT(user_id) ignores NULLs, safe
-- No users in Users table      → division by zero → add NULLIF protection if needed:
--                                 ROUND(COUNT(user_id) / NULLIF((SELECT COUNT(*) FROM Users), 0) * 100, 2)
-- Contest with zero registrations → won't appear (not in Register table)
-- Two contests same percentage → ORDER BY contest_id ASC breaks the tie correctly
