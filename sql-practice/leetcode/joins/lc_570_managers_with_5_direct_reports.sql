-- ============================================================
-- Problem : Managers with at Least 5 Direct Reports
-- Source  : LeetCode 570
-- Link    : https://leetcode.com/problems/managers-with-at-least-5-direct-reports/
-- Topic   : Self JOIN / GROUP BY / HAVING
-- Level   : Medium
-- Date    : 2026-06-23
-- ============================================================

-- PROBLEM STATEMENT:
-- Table: Employee (id, name, department, managerId)
-- Find managers who have at least 5 direct reports.
-- Return: name only.

-- ============================================================
-- APPROACH 1: Self JOIN (demonstrates deeper SQL knowledge)
-- Join the Employee table to itself — e1 represents employees,
-- e2 represents managers. Each employee row in e1 connects to
-- their manager row in e2 via e1.managerId = e2.id.
-- After JOIN, manager John appears once per employee who reports
-- to him. GROUP BY manager then COUNT(e1.id) gives total
-- direct reports per manager. HAVING filters to >= 5.
--
-- Key insight: GROUP BY e2.id, e2.name defines manager groups.
-- COUNT(e1.id) counts employee rows INSIDE each manager group —
-- GROUP BY and COUNT operate independently. You group by manager
-- but count employees within that group.
--
-- Why COUNT(e1.id) not COUNT(e2.id):
-- e1 = employees reporting to manager — semantically correct to count these.
-- e2 = manager rows — repeats once per employee so also gives same
-- count here, but counting e1 is more explicit and correct.
-- ============================================================

-- Approach 1: Self JOIN
SELECT e2.name
FROM Employee e1
INNER JOIN Employee e2
    ON e1.managerId = e2.id
GROUP BY e2.id, e2.name
HAVING COUNT(e1.id) >= 5;

-- ============================================================
-- APPROACH 2: Subquery (simpler, equally valid)
-- Find all managerIds that appear 5+ times (5+ direct reports),
-- then look up the name of those managers.
-- ============================================================

SELECT name
FROM Employee
WHERE id IN (
    SELECT managerId
    FROM Employee
    GROUP BY managerId
    HAVING COUNT(*) >= 5
);

-- ============================================================
-- EXAMPLE WALKTHROUGH:
-- Input:
-- id | name  | department | managerId
-- 1  | John  | A          | NULL
-- 2  | Dan   | A          | 1
-- 3  | James | A          | 1
-- 4  | Amy   | A          | 1
-- 5  | Anne  | A          | 1
-- 6  | Ron   | B          | 1
--
-- After INNER JOIN e1.managerId = e2.id:
-- e1.id | e1.name | e1.managerId | e2.id | e2.name
-- 2     | Dan     | 1            | 1     | John
-- 3     | James   | 1            | 1     | John
-- 4     | Amy     | 1            | 1     | John
-- 5     | Anne    | 1            | 1     | John
-- 6     | Ron     | 1            | 1     | John
--
-- After GROUP BY e2.id, e2.name:
-- Group: John (e2.id=1) → 5 rows → COUNT(e1.id) = 5
--
-- HAVING COUNT(e1.id) >= 5:
-- John → 5 >= 5 → included ✅
--
-- Output:
-- name
-- John
-- ============================================================

-- ============================================================
-- EDGE CASES TO KEEP IN MIND:
-- 1. >= 5 not > 5:
--    > 5 means 6 or more — misses managers with exactly 5 reports
--    >= 5 means 5 or more ✅ correct threshold
--
-- 2. GROUP BY e2.id AND e2.name — not just e2.name:
--    Two managers could have same name in different departments
--    GROUP BY name alone merges them → wrong count
--    Always GROUP BY the unique identifier (id) + display column (name)
--
-- 3. INNER JOIN excludes employees with NULL managerId:
--    John has managerId = NULL → not included in e1 side
--    Correct — John is a manager not a direct report of anyone
--    NULL managerId means top of hierarchy
--
-- 4. Manager with exactly 5 reports — both approaches handle correctly:
--    Self JOIN: COUNT(e1.id) = 5 → HAVING >= 5 → included ✅
--    Subquery: COUNT(*) = 5 → HAVING >= 5 → included ✅
-- ============================================================

-- ============================================================
-- SELF JOIN CONCEPT — MEMORIZE THIS:
-- A self join joins a table to itself using two aliases.
-- Classic use cases:
--   1. Employee-Manager hierarchy (this problem)
--   2. Finding rows that match other rows in same table
--   3. Comparing current row to previous/next row
--
-- Pattern:
--   FROM table alias1
--   JOIN table alias2
--   ON alias1.foreign_key = alias2.primary_key
--
-- alias1 = child rows (employees)
-- alias2 = parent rows (managers)
-- ============================================================

-- ============================================================
-- KEY PATTERN — MEMORIZE THIS:
-- "Find parents with at least N children in same table":
--   1. Self JOIN: child.parent_id = parent.id
--   2. GROUP BY parent.id, parent.name
--   3. HAVING COUNT(child.id) >= N
--
-- Alternative — subquery:
--   WHERE id IN (
--       SELECT parent_id FROM table
--       GROUP BY parent_id
--       HAVING COUNT(*) >= N
--   )
-- ============================================================
