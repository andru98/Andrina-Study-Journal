-- ============================================================
-- Problem : Primary Department for Each Employee
-- Source  : LeetCode 1789
-- Link    : https://leetcode.com/problems/primary-department-for-each-employee/
-- Topic   : UNION / GROUP BY / HAVING / Subquery
-- Level   : Easy
-- Date    : 2026-08-11
-- ============================================================

-- PROBLEM STATEMENT:
-- Table: Employee (employee_id, department_id, primary_flag)
-- primary_flag = 'Y' means primary department
-- primary_flag = 'N' means not primary
-- Note: employees with only ONE department always have flag='N'
-- Return: each employee's primary department
--         OR their only department if they have just one

-- ============================================================
-- APPROACH: UNION of two conditions
--
-- Condition 1: Multi-department employees
-- → WHERE primary_flag = 'Y'
-- → directly returns primary department ✅
--
-- Condition 2: Single-department employees
-- → always have primary_flag = 'N' (per problem rules)
-- → cannot use flag to identify them
-- → use subquery: GROUP BY employee_id HAVING COUNT(*) = 1
-- → finds employees with exactly one department ✅
--
-- Why not WHERE primary_flag = 'N':
-- → 'N' means two things:
--   1. single dept employee (want ✅)
--   2. non-primary dept of multi-dept employee (don't want ❌)
-- → cannot distinguish without COUNT ✅
--
-- Why UNION not UNION ALL:
-- → edge case safety — prevents duplicates
-- → single dept employees only appear in Condition 2 (flag='N')
-- → multi-dept employees only appear in Condition 1 (flag='Y')
-- → no duplicates in practice but UNION is safer habit ✅
--
-- Why COUNT(*) not COUNT(department_id):
-- → COUNT(*) counts all rows regardless of NULLs → fastest
-- → COUNT(department_id) skips NULLs → unnecessary check
-- → department_id is part of primary key → never NULL
-- → COUNT(*) preferred for performance ✅
-- ============================================================

SELECT employee_id, department_id
FROM Employee
WHERE primary_flag = 'Y'

UNION

SELECT employee_id, department_id
FROM Employee
WHERE employee_id IN (
    SELECT employee_id
    FROM Employee
    GROUP BY employee_id
    HAVING COUNT(*) = 1
);

-- ============================================================
-- EXAMPLE WALKTHROUGH:
-- Input:
-- employee_id | department_id | primary_flag
-- 1           | 1             | N   ← single dept
-- 2           | 1             | Y   ← primary dept
-- 2           | 2             | N   ← non-primary dept
-- 3           | 3             | N   ← single dept
-- 4           | 2             | N   ← non-primary dept
-- 4           | 3             | Y   ← primary dept
--
-- Condition 1 (primary_flag = 'Y'):
-- → employee 2, dept 1 ✅
-- → employee 4, dept 3 ✅
--
-- Condition 2 (COUNT = 1):
-- Subquery counts per employee:
-- employee 1 → COUNT = 1 → included ✅
-- employee 2 → COUNT = 2 → excluded ✅
-- employee 3 → COUNT = 1 → included ✅
-- employee 4 → COUNT = 2 → excluded ✅
-- Returns: employee 1 dept 1, employee 3 dept 3
--
-- UNION result:
-- employee_id | department_id
-- 1           | 1  ✅
-- 2           | 1  ✅
-- 3           | 3  ✅
-- 4           | 3  ✅
-- ============================================================

-- ============================================================
-- COMMON MISTAKES:
--
-- 1. Using WHERE primary_flag = 'N' for single dept employees:
--    → returns non-primary depts of multi-dept employees too ❌
--    → Fix: use HAVING COUNT(*) = 1 subquery ✅
--
-- 2. GROUP BY employee_id without subquery:
--    → MySQL picks random department_id ❌
--    → Fix: use WHERE employee_id IN (subquery) ✅
--
-- 3. Using UNION ALL instead of UNION:
--    → safe here since no overlap but UNION is better habit ✅
--
-- 4. Trying HAVING COUNT >= 2 for multi-dept employees:
--    → identifies multi-dept employees ✅
--    → but returns ALL their departments not just primary ❌
--    → Fix: WHERE primary_flag = 'Y' is simpler and correct ✅
-- ============================================================

-- ============================================================
-- EDGE CASES:
--
-- 1. Employee with exactly 2 departments:
--    → one has flag='Y', one has flag='N'
--    → Condition 1 returns the 'Y' department ✅
--    → Condition 2 excludes (COUNT=2) ✅
--
-- 2. Employee with only 1 department (flag='N'):
--    → Condition 1 excludes (no 'Y' flag) ✅
--    → Condition 2 includes (COUNT=1) ✅
--
-- 3. All employees in single departments:
--    → Condition 1 returns nothing
--    → Condition 2 returns all ✅
--
-- 4. All employees in multiple departments:
--    → Condition 1 returns all primary depts ✅
--    → Condition 2 returns nothing ✅
-- ============================================================

-- ============================================================
-- KEY PATTERN — MEMORIZE THIS:
-- "Return one row per entity based on multiple conditions":
--
--   SELECT col1, col2 FROM table WHERE explicit_condition
--   UNION
--   SELECT col1, col2 FROM table
--   WHERE col1 IN (
--       SELECT col1 FROM table
--       GROUP BY col1
--       HAVING COUNT(*) = 1
--   )
--
-- Real DE use cases:
-- → Primary department per employee (this problem)
-- → Primary address per customer
-- → Default payment method per user
-- → Primary contact per account (CRM data)
-- → Caterpillar: primary location per equipment unit
-- ============================================================
