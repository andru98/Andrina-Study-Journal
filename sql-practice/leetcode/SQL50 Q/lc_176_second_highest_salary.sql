-- ============================================================
-- Problem : Second Highest Salary
-- Source  : LeetCode 176
-- Link    : https://leetcode.com/problems/second-highest-salary/
-- Topic   : DENSE_RANK / NULL Handling / Scalar Subquery / OFFSET
-- Level   : Medium
-- Date    : 2026-09-02
-- ============================================================

-- PROBLEM STATEMENT:
-- Table: Employee (id, salary)
-- Find second highest DISTINCT salary
-- Return NULL if no second highest salary exists

-- ============================================================
-- KEY INSIGHT: NULL Handling
-- Problem wants NULL (not empty result) when no second salary
--
-- Wrong approaches (return empty result):
-- SELECT salary WHERE rnk=2 → empty if no second ❌
-- SELECT DISTINCT salary WHERE rnk=2 → still empty ❌
--
-- Correct approaches (return NULL):
-- MAX(salary) on empty set → NULL ✅
-- Scalar subquery on empty set → NULL ✅
-- IFNULL/COALESCE wrapper → NULL ✅
--
-- DISTINCT vs MAX for NULL:
-- DISTINCT → removes duplicates but empty = empty ❌
-- MAX() → aggregates, empty set returns NULL ✅
-- ============================================================

-- ============================================================
-- APPROACH 1: DENSE_RANK + MAX (handles NULL automatically)
-- MAX() on empty result = NULL ✅
-- DISTINCT not needed — MAX returns single value ✅
-- ============================================================

WITH ranking AS (
    SELECT salary,
           DENSE_RANK() OVER (ORDER BY salary DESC) AS rnk
    FROM Employee
)
SELECT MAX(salary) AS SecondHighestSalary  -- NULL if no rows ✅
FROM ranking
WHERE rnk = 2;

-- ============================================================
-- APPROACH 2: Scalar Subquery + OFFSET (clean and simple)
-- Outer SELECT always returns one row ✅
-- Inner returns nothing → outer shows NULL ✅
-- ============================================================

SELECT (
    SELECT DISTINCT salary
    FROM Employee
    ORDER BY salary DESC
    LIMIT 1 OFFSET 1         -- skip highest, take next ✅
) AS SecondHighestSalary;

-- ============================================================
-- APPROACH 3: Subquery with MAX + IFNULL
-- Explicit NULL handling ✅
-- ============================================================

SELECT IFNULL(
    (SELECT DISTINCT salary
     FROM Employee
     ORDER BY salary DESC
     LIMIT 1 OFFSET 1),
    NULL
) AS SecondHighestSalary;

-- ============================================================
-- EXAMPLE WALKTHROUGH:
-- Input: salaries = 300, 200, 200, 100
--
-- Approach 1 (DENSE_RANK):
-- salary | rnk
-- 300    | 1
-- 200    | 2  ← two rows (duplicates)
-- 200    | 2
-- 100    | 3
-- WHERE rnk=2 → two rows (200, 200)
-- MAX(200, 200) → 200 ✅ one value, no DISTINCT needed
--
-- Approach 2 (OFFSET):
-- ORDER BY DESC: 300, 200, 200, 100
-- LIMIT 1 OFFSET 1 → skip 300, take 200 ✅
-- DISTINCT → 200 (deduped) ✅
--
-- NULL case (one employee: salary=100):
-- Approach 1: WHERE rnk=2 → no rows → MAX() → NULL ✅
-- Approach 2: OFFSET 1 → no rows → scalar → NULL ✅
-- ============================================================

-- ============================================================
-- WHY DISTINCT NOT NEEDED WITH MAX:
--
-- Without DISTINCT:
-- SELECT salary WHERE rnk=2 → 200, 200 (duplicates) ❌
-- → need DISTINCT for single value
--
-- With MAX():
-- SELECT MAX(salary) WHERE rnk=2 → MAX(200,200) → 200 ✅
-- → automatically returns single value
-- → DISTINCT unnecessary ✅
--
-- WHY DISTINCT NEEDED IN SCALAR SUBQUERY:
-- SELECT salary ORDER BY DESC LIMIT 1 OFFSET 1
-- → might return 200 (fine, LIMIT 1 ensures one row)
-- → but DISTINCT ensures we skip duplicate highest ✅
-- Example: 300, 300, 200
-- Without DISTINCT: OFFSET 1 → 300 (second 300) ❌ wrong!
-- With DISTINCT: OFFSET 1 → 200 ✅ correct!
-- ============================================================

-- ============================================================
-- NULL HANDLING METHODS:
--
-- MAX() on empty set:
-- SELECT MAX(salary) FROM table WHERE false
-- → NULL ✅ automatic
--
-- Scalar subquery:
-- SELECT (SELECT ... LIMIT 1 OFFSET 1)
-- → NULL if inner returns nothing ✅
--
-- IFNULL():
-- IFNULL(value, NULL) → returns NULL if value is NULL ✅
-- IFNULL(value, 0) → returns 0 if NULL ✅
--
-- COALESCE():
-- COALESCE(value1, value2, ...) → first non-NULL ✅
-- COALESCE(salary, NULL) → same as IFNULL ✅
-- ============================================================

-- ============================================================
-- OFFSET explained:
-- LIMIT n OFFSET m:
-- → skip first m rows
-- → return next n rows
--
-- ORDER BY salary DESC: 300, 200, 100
-- LIMIT 1 OFFSET 0 → 300 (highest) ✅
-- LIMIT 1 OFFSET 1 → 200 (second highest) ✅
-- LIMIT 1 OFFSET 2 → 100 (third highest) ✅
-- LIMIT 1 OFFSET 3 → nothing → NULL ✅
-- ============================================================

-- ============================================================
-- COMMON MISTAKES:
--
-- 1. No NULL handling:
--    SELECT salary WHERE rnk=2 → empty not NULL ❌
--    Fix: use MAX() or scalar subquery ✅
--
-- 2. Forgetting DISTINCT in OFFSET approach:
--    Salaries: 300, 300, 200
--    Without DISTINCT: OFFSET 1 → 300 ❌ (second duplicate)
--    With DISTINCT: OFFSET 1 → 200 ✅ (true second highest)
--
-- 3. Using RANK instead of DENSE_RANK:
--    RANK: 300=1, 200=2, 200=2, 100=4 (gap) ✅ still works here
--    DENSE_RANK: 300=1, 200=2, 200=2, 100=3 ✅ safer
-- ============================================================

-- ============================================================
-- KEY PATTERN — MEMORIZE THIS:
-- "Nth highest value with NULL handling":
--
-- Option A: DENSE_RANK + MAX
--   WITH ranked AS (
--       SELECT val, DENSE_RANK() OVER (ORDER BY val DESC) AS rnk
--       FROM table
--   )
--   SELECT MAX(val) FROM ranked WHERE rnk = N;
--
-- Option B: Scalar subquery + OFFSET
--   SELECT (
--       SELECT DISTINCT val
--       FROM table
--       ORDER BY val DESC
--       LIMIT 1 OFFSET N-1
--   ) AS result;
--
-- Real DE use cases:
-- → Second highest salary (this problem) ✅
-- → Second highest RASK route in airline ✅
-- → Third best performing fare class ✅
-- → Nth highest revenue day ✅
-- → Caterpillar: second most utilized equipment ✅
-- ============================================================
