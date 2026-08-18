-- ============================================================
-- Problem : The Number of Employees Which Report to Each Employee
-- Source  : LeetCode 1731
-- Link    : https://leetcode.com/problems/the-number-of-employees-which-report-to-each-employee/
-- Topic   : Self JOIN / GROUP BY / ROUND / AVG
-- Level   : Easy
-- Date    : 2026-08-10
-- ============================================================

-- PROBLEM STATEMENT:
-- Table: Employees (employee_id, name, reports_to, age)
-- A manager = employee with at least 1 direct report.
-- Return: manager's employee_id, name, reports_count,
--         average_age of reports rounded to nearest integer.
-- Order by employee_id ascending.

-- ============================================================
-- APPROACH: Self JOIN (employee table joined to itself)
-- m alias = manager side (the person being reported TO)
-- e alias = employee side (the person who reports)
--
-- JOIN condition: m.employee_id = e.reports_to
-- → finds all employees who report to each manager
--
-- INNER JOIN automatically excludes non-managers:
-- → employees with no reports have no matching rows in e
-- → excluded from result ✅ (problem says managers only)
--
-- ROUND(AVG(e.age), 0) rounds to nearest integer:
-- → AVG(41, 36) = 38.5 → ROUND(38.5, 0) = 39 ✅
--
-- Why COUNT(e.employee_id) not COUNT(e.reports_to):
-- → COUNT(e.employee_id) counts employees (never NULL — PK)
-- → COUNT(e.reports_to) counts references (could be NULL)
-- → e.employee_id is safer and more semantically correct ✅
-- ============================================================

SELECT
    m.employee_id,
    m.name,
    COUNT(e.employee_id)    AS reports_count,
    ROUND(AVG(e.age), 0)    AS average_age
FROM Employees m
JOIN Employees e
    ON m.employee_id = e.reports_to
GROUP BY
    m.employee_id,
    m.name
ORDER BY m.employee_id;

-- ============================================================
-- EXAMPLE WALKTHROUGH:
-- Input:
-- employee_id | name    | reports_to | age
-- 9           | Hercy   | null       | 43
-- 6           | Alice   | 9          | 41
-- 4           | Bob     | 9          | 36
-- 2           | Winston | null       | 37
--
-- Self JOIN (m.employee_id = e.reports_to):
-- m.emp_id | m.name | e.emp_id | e.age
-- 9        | Hercy  | 6        | 41    ← Alice reports to Hercy
-- 9        | Hercy  | 4        | 36    ← Bob reports to Hercy
-- (Alice, Bob, Winston have no reports → excluded by INNER JOIN)
--
-- After GROUP BY + aggregation:
-- employee_id | name  | COUNT | AVG(age)        | ROUND
-- 9           | Hercy | 2     | (41+36)/2 = 38.5 | 39 ✅
-- ============================================================

-- ============================================================
-- COMMON MISTAKES:
--
-- 1. Missing m.name in GROUP BY:
--    GROUP BY m.employee_id only → SQL error in strict mode ❌
--    m.name in SELECT but not in GROUP BY → ambiguous
--    Fix: GROUP BY m.employee_id, m.name ✅
--
-- 2. Not rounding average age:
--    AVG(e.age) → 38.5 ❌ (problem asks nearest integer)
--    ROUND(AVG(e.age), 0) → 39 ✅
--
-- 3. Using LEFT JOIN instead of INNER JOIN:
--    LEFT JOIN → includes employees with no reports (count=0)
--    Problem asks for managers only (at least 1 report)
--    INNER JOIN → automatically excludes non-managers ✅
--
-- 4. Missing ORDER BY:
--    Problem explicitly asks for employee_id ascending
--    Always include ORDER BY when problem specifies order ✅
-- ============================================================

-- ============================================================
-- EDGE CASES:
--
-- 1. Manager with one direct report:
--    COUNT = 1, AVG = that employee's age ✅
--
-- 2. Manager with many reports (e.g. 10 employees):
--    COUNT = 10, AVG calculated across all 10 ages ✅
--
-- 3. Employee reporting to non-existent manager:
--    → reports_to has no matching employee_id
--    → INNER JOIN excludes these rows ✅
--
-- 4. Chain of managers (A → B → C):
--    → B is manager of C (direct report)
--    → A is manager of B (direct report)
--    → each level counted independently ✅
--    → problem says "directly" reports only
-- ============================================================

-- ============================================================
-- KEY PATTERN — MEMORIZE THIS:
-- "Hierarchy/reporting structure in same table":
--
--   SELECT parent.id, parent.name,
--          COUNT(child.id) AS child_count,
--          ROUND(AVG(child.metric), 0) AS avg_metric
--   FROM table parent
--   JOIN table child ON parent.id = child.parent_id
--   GROUP BY parent.id, parent.name
--   ORDER BY parent.id
--
-- Real DE use cases:
-- → Manager direct reports (this problem)
-- → Category → subcategory counts
-- → Parent → child node aggregations
-- → Org chart analytics
-- → Caterpillar: machine → component reporting hierarchy
-- ============================================================
