-- Problem: Managers with at Least Five Direct Reports
-- Source: LeetCode
-- Link: https://leetcode.com/problems/managers-with-at-least-5-direct-reports/
-- Folder: sql-practice/joins/

-- Topic: Self-referential JOIN + CTE + HAVING
-- Difficulty: Medium

-- Problem Statement:
-- Find names of managers who have at least 5 employees directly reporting to them.
-- managerId in each row points to the id of that employee's manager —
-- the manager is also an employee in the same table.

-- Approach:
-- 1. CTE counts how many times each managerId appears — each appearance = one report.
-- 2. HAVING COUNT(*) >= 5 keeps only managers with five or more direct reports.
--    >= 5 means "at least five" — using > 5 would miss managers with exactly 5.
-- 3. JOIN back to Employee on e2.id = mc.managerId to fetch the manager's name.
--    The manager's identity lives in the id column, not managerId.

WITH managerID_count AS (
    SELECT managerId, COUNT(*) AS direct_report_count
    FROM employee
    GROUP BY managerId
    HAVING COUNT(*) >= 5
)
SELECT e2.name
FROM employee e2
JOIN managerID_count mc ON e2.id = mc.managerId;

-- Edge Cases
-- >= 5 vs > 5              → always re-read "at least N" as >= N
-- e2.id vs e2.managerId    → join on id because the manager IS an employee,
--                            their id is what other rows reference as managerId
-- managerId = NULL          → NULL group in CTE won't match any e2.id (NULL ≠ NULL)
--                            → auto-excluded from result, no fix needed
-- Manager also has a manager → self-referential table handles this naturally
-- No manager has 5+ reports → CTE returns zero rows, result is empty, no error
