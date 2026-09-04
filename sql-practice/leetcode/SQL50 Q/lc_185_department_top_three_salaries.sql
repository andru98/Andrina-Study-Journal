-- ============================================================
-- Problem : Department Top Three Salaries
-- Source  : LeetCode 185
-- Link    : https://leetcode.com/problems/department-top-three-salaries/
-- Topic   : DENSE_RANK / Window Functions / CTE / JOIN
-- Level   : Hard
-- Date    : 2026-09-02
-- ============================================================

-- PROBLEM STATEMENT:
-- Table: Employee (id, name, salary, departmentId)
-- Table: Department (id, name)
-- Find employees with top 3 UNIQUE salaries per department
-- Multiple employees can share same salary (tied rank)

-- ============================================================
-- KEY INSIGHT:
-- "Top 3 UNIQUE salaries" → use DENSE_RANK not RANK
--
-- RANK vs DENSE_RANK:
-- Salaries: 90000, 85000, 85000, 70000
--
-- RANK():
-- → 90000 = rank 1
-- → 85000 = rank 2
-- → 85000 = rank 2
-- → 70000 = rank 4 ← SKIPS rank 3 ❌
-- → Will (70000) excluded ❌ wrong!
--
-- DENSE_RANK():
-- → 90000 = rank 1
-- → 85000 = rank 2
-- → 85000 = rank 2
-- → 70000 = rank 3 ← no skip ✅
-- → Will (70000) included ✅ correct!
--
-- PARTITION BY department:
-- → ranking resets for each department ✅
-- → IT ranked separately from Sales ✅
-- ============================================================

-- ============================================================
-- APPROACH 1: Two CTEs (readable, self-documenting)
-- ============================================================

WITH enriched_employees AS (
    -- Join employees with department names
    SELECT
        e.name     AS Employee,
        e.salary   AS Salary,
        d.name     AS Department,
        d.id       AS department_id
    FROM Employee e
    INNER JOIN Department d ON e.departmentId = d.id
),
ranked_salaries AS (
    -- Rank employees by salary within each department
    SELECT
        Department,
        Employee,
        Salary,
        DENSE_RANK() OVER (
            PARTITION BY department_id    -- reset rank per department ✅
            ORDER BY Salary DESC          -- highest salary = rank 1 ✅
        ) AS ranking
    FROM enriched_employees
)
SELECT Department, Employee, Salary
FROM ranked_salaries
WHERE ranking <= 3                        -- top 3 unique salaries ✅
ORDER BY Department, Salary DESC;

-- ============================================================
-- APPROACH 2: Single CTE (more concise)
-- Partition by department id (integer) not name (string)
-- → integer comparison faster than string ✅
-- ============================================================

WITH ranked_salaries AS (
    SELECT
        d.name  AS Department,
        e.name  AS Employee,
        e.salary AS Salary,
        DENSE_RANK() OVER (
            PARTITION BY d.id             -- integer partition = faster ✅
            ORDER BY e.salary DESC
        ) AS ranking
    FROM Employee e
    INNER JOIN Department d ON e.departmentId = d.id
)
SELECT Department, Employee, Salary
FROM ranked_salaries
WHERE ranking <= 3
ORDER BY Department, Salary DESC;

-- ============================================================
-- EXAMPLE WALKTHROUGH:
-- IT Department (d.id = 1):
-- Employee | Salary | DENSE_RANK
-- Max      | 90000  | 1 ✅ top 3
-- Joe      | 85000  | 2 ✅ top 3
-- Randy    | 85000  | 2 ✅ top 3 (tied with Joe)
-- Will     | 70000  | 3 ✅ top 3
-- Janet    | 69000  | 4 ❌ excluded
--
-- Sales Department (d.id = 2):
-- Employee | Salary | DENSE_RANK
-- Henry    | 80000  | 1 ✅ top 3
-- Sam      | 60000  | 2 ✅ top 3
-- (only 2 employees → no rank 3, that's fine) ✅
--
-- Final output:
-- IT    | Max   | 90000
-- IT    | Joe   | 85000
-- IT    | Randy | 85000
-- IT    | Will  | 70000
-- Sales | Henry | 80000
-- Sales | Sam   | 60000
-- ============================================================

-- ============================================================
-- COMMON MISTAKES:
--
-- 1. Using RANK instead of DENSE_RANK:
--    RANK skips numbers after ties ❌
--    → 90000=1, 85000=2, 85000=2, 70000=4
--    → rank 3 missing → Will excluded ❌
--    Fix: DENSE_RANK preserves consecutive ranking ✅
--
-- 2. Using ROW_NUMBER instead of DENSE_RANK:
--    ROW_NUMBER gives unique rank to each row ❌
--    → 90000=1, 85000=2, 85000=3, 70000=4
--    → Joe and Randy get different ranks ❌
--    → only one of them included ❌
--    Fix: DENSE_RANK groups same salaries ✅
--
-- 3. PARTITION BY department name not id:
--    PARTITION BY d.name → string comparison ❌ slower
--    PARTITION BY d.id → integer comparison ✅ faster
--
-- 4. Forgetting tied salaries:
--    Both Joe AND Randy earn 85000 → both rank 2 ✅
--    Both included in top 3 ✅
--    Problem says "unique salaries" not "unique employees"
-- ============================================================

-- ============================================================
-- RANK vs DENSE_RANK vs ROW_NUMBER recap:
--
-- Salaries: 90000, 85000, 85000, 70000
--
-- ROW_NUMBER:  1, 2, 3, 4  ← unique, no ties
-- RANK:        1, 2, 2, 4  ← ties share rank, gap after
-- DENSE_RANK:  1, 2, 2, 3  ← ties share rank, no gap ✅
--
-- Use ROW_NUMBER: unique sequential numbering
-- Use RANK:       gaps after ties acceptable
-- Use DENSE_RANK: ties share rank, no gaps ✅ (this problem)
-- ============================================================

-- ============================================================
-- KEY PATTERN — MEMORIZE THIS:
-- "Top N per group with ties":
--
--   WITH ranked AS (
--       SELECT col,
--              DENSE_RANK() OVER (
--                  PARTITION BY group_col
--                  ORDER BY metric DESC
--              ) AS ranking
--       FROM table
--       JOIN ...
--   )
--   SELECT col FROM ranked
--   WHERE ranking <= N
--
-- Real DE use cases:
-- → Top 3 salaries per department (this problem) ✅
-- → Top 3 routes by revenue per region ✅
-- → Top 3 seat types by conversion per airline ✅
-- → Top 3 products by sales per category ✅
-- → Caterpillar: top 3 equipment by utilization per site ✅
-- → Airline RM: top 3 fare classes by revenue per route ✅
-- ============================================================
