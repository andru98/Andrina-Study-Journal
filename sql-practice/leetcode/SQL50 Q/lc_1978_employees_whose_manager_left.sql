-- ============================================================
-- Problem : Employees Whose Manager Left the Company
-- Source  : LeetCode 1978
-- Link    : https://leetcode.com/problems/employees-whose-manager-left-the-company/
-- Topic   : Subquery / NOT IN / LEFT JOIN / NULL handling
-- Level   : Easy
-- Date    : 2026-08-24
-- ============================================================

-- PROBLEM STATEMENT:
-- Table: Employees (employee_id, name, manager_id, salary)
-- Find employees where:
-- 1. salary < 30000
-- 2. manager left the company (manager_id not in Employees table)
-- Return ordered by employee_id

-- ============================================================
-- KEY INSIGHT:
-- Manager "left" means:
-- → employee still has manager_id set
-- → BUT that manager_id no longer exists in Employees table
--
-- Two cases to handle:
-- → manager_id IS NULL = employee has no manager (CEO etc)
--   must EXCLUDE these ✅
-- → manager_id NOT IN current employees = manager left ✅
--
-- Why manager_id IS NOT NULL check:
-- → NULL NOT IN (...) = UNKNOWN in SQL (not FALSE)
-- → would silently exclude these rows ❌
-- → explicit NULL check makes intent clear ✅
-- ============================================================

-- ============================================================
-- APPROACH 1: NOT IN Subquery
-- Simple and readable
-- Subquery returns all current employee IDs
-- NOT IN checks if manager is still in company
-- ============================================================

SELECT employee_id
FROM Employees
WHERE salary < 30000
  AND manager_id IS NOT NULL
  AND manager_id NOT IN (
      SELECT employee_id
      FROM Employees
  )
ORDER BY employee_id;

-- ============================================================
-- APPROACH 2: LEFT JOIN + NULL Check (recommended for large data)
-- Single pass join more efficient than subquery
-- NULL on joined side = manager not found = manager left
-- Better performance with index on employee_id
-- ============================================================

SELECT e.employee_id
FROM Employees e
LEFT JOIN Employees m
    ON e.manager_id = m.employee_id
WHERE e.salary < 30000
  AND e.manager_id IS NOT NULL
  AND m.employee_id IS NULL
ORDER BY e.employee_id;

-- ============================================================
-- EXAMPLE WALKTHROUGH:
-- Input Employees:
-- employee_id | name    | manager_id | salary
-- 1           | Alice   | NULL       | 50000  ← CEO (no manager)
-- 2           | Bob     | 1          | 25000  ← manager exists
-- 3           | Charlie | 5          | 28000  ← manager_id=5 gone!
-- 4           | Diana   | 1          | 35000  ← salary too high
--
-- NOT IN subquery returns: (1, 2, 3, 4) ← current employee IDs
--
-- Check each employee:
-- Employee 1: salary=50000 > 30000 ❌
-- Employee 2: salary=25000 ✅, manager_id=1 IN (1,2,3,4) ❌
-- Employee 3: salary=28000 ✅, manager_id=5 NOT IN (1,2,3,4) ✅
-- Employee 4: salary=35000 > 30000 ❌
--
-- Result: employee_id = 3 ✅
-- ============================================================

-- ============================================================
-- LEFT JOIN WALKTHROUGH:
--
-- Self join on manager_id = employee_id:
-- e.id | e.manager_id | m.employee_id
-- 1    | NULL         | NULL  ← no manager
-- 2    | 1            | 1     ← manager exists
-- 3    | 5            | NULL  ← manager gone! ✅
-- 4    | 1            | 1     ← manager exists
--
-- WHERE m.employee_id IS NULL:
-- → only employee 3 qualifies ✅
-- → also filtered by salary < 30000 ✅
-- → also filtered by manager_id IS NOT NULL ✅
-- ============================================================

-- ============================================================
-- COMMON MISTAKES:
--
-- 1. Forgetting manager_id IS NOT NULL:
--    NULL NOT IN (...) = UNKNOWN (not FALSE) in SQL
--    → rows with NULL manager_id silently excluded ❌
--    Fix: add explicit manager_id IS NOT NULL check ✅
--
-- 2. Using INNER JOIN instead of LEFT JOIN:
--    INNER JOIN only returns matching rows ❌
--    LEFT JOIN keeps all left rows, NULL where no match ✅
--
-- 3. Confusing which table is e and which is m:
--    e = employees (the ones we want to find)
--    m = managers (checking if they exist)
--    m.employee_id IS NULL = manager not found ✅
--
-- 4. Forgetting ORDER BY employee_id:
--    Problem requires ordered output ✅
-- ============================================================

-- ============================================================
-- PERFORMANCE COMPARISON:
--
-- NOT IN subquery:
-- ✅ readable and simple
-- ❌ loads all employee_ids into memory
-- ❌ NULL handling tricky
-- ✅ fine for small tables
--
-- LEFT JOIN + NULL:
-- ✅ single pass join
-- ✅ optimizer uses index on employee_id
-- ✅ explicit NULL handling
-- ✅ preferred for large tables in production
-- ✅ industry standard pattern
-- ============================================================

-- ============================================================
-- KEY PATTERN — MEMORIZE THIS:
-- "Find rows where related record no longer exists":
--
-- NOT IN approach:
--   WHERE foreign_key NOT IN (SELECT primary_key FROM table)
--   AND foreign_key IS NOT NULL  ← always add this!
--
-- LEFT JOIN approach (preferred):
--   LEFT JOIN table t ON e.foreign_key = t.primary_key
--   WHERE t.primary_key IS NULL  ← NULL = no match = gone
--
-- Real DE use cases:
-- → Employees whose manager left (this problem) ✅
-- → Orders with deleted customers ✅
-- → Tracks with removed artists ✅
-- → Equipment with decommissioned sensors (Caterpillar) ✅
-- → Bookings with cancelled flights (Airline RM) ✅
-- ============================================================
