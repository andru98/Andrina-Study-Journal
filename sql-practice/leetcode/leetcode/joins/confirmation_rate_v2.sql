-- Problem: Confirmation Rate
-- Source: LeetCode
-- Link: https://leetcode.com/problems/confirmation-rate/
-- Folder: sql-practice/joins/

-- Topic: LEFT JOIN + COUNT(CASE WHEN) + IFNULL + GROUP BY
-- Difficulty: Medium

-- Problem Statement:
-- Find confirmation rate per user = confirmed messages / total messages.
-- Users who never requested any confirmation should show rate = 0, not disappear.

-- Approach:
-- 1. LEFT JOIN from Signups to Confirmations — keeps all users even with no confirmations.
--    INNER JOIN would drop users with no rows in Confirmations entirely.
-- 2. COUNT(CASE WHEN action = 'confirmed' THEN 1 END) = confirmed messages only.
--    No ELSE needed — COUNT ignores NULL, timeout rows return NULL and are skipped.
-- 3. COUNT(*) = total rows including the NULL row LEFT JOIN creates for inactive users.
--    This gives 0/1 = 0 for users with no confirmations — correct behavior.
-- 4. IFNULL not needed here because 0/1 = 0, not NULL.
--    But if COUNT(*) could be 0 (e.g. empty join), wrap with IFNULL(..., 0).
-- 5. GROUP BY s.user_id to get one row per user.

SELECT
    s.user_id,
    ROUND(COUNT(CASE WHEN action = 'confirmed' THEN 1 END) / COUNT(*), 2) AS confirmation_rate
FROM Signups s
LEFT JOIN Confirmations c ON s.user_id = c.user_id
GROUP BY s.user_id;

-- Edge Cases
-- User with no confirmations   → LEFT JOIN creates NULL row, numerator = 0,
--                                denominator = 1 (COUNT* counts the row), rate = 0.00
-- ELSE 0 in COUNT(CASE WHEN)   → never use it, 0 is not NULL, COUNT inflates numerator
-- Date condition in WHERE       → if filtering Confirmations in WHERE, NULL rows get
--                                eliminated — LEFT JOIN becomes INNER JOIN silently
-- All messages are timeout      → numerator = 0, rate = 0.00 correctly
-- All messages are confirmed    → rate = 1.00 correctly
-- NULL in action column         → CASE WHEN fails → returns NULL → COUNT ignores it → safe
