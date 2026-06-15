-- ============================================================
-- Problem : Department Top Three Salaries
-- Source  : LeetCode 185
-- Link    : https://leetcode.com/problems/department-top-three-salaries/
-- Topic   : Window Functions / DENSE_RANK / CTE / JOIN
-- Level   : Hard
-- Date    : 2026-06-11
-- ============================================================

-- PROBLEM STATEMENT:
-- Table: Employee (employee_id, name, salary, departmentId)
-- Table: Department (id, name)
-- Find employees who earn one of the top 3 unique salaries
-- in their department.
-- Return: Department, Employee, Salary

-- ============================================================
-- APPROACH:
-- Step 1 — JOIN Employee and Department tables to get
--          department name alongside each employee.
--          Alias both name columns to avoid ambiguity.
-- Step 2 — Use DENSE_RANK() OVER (PARTITION BY department
--          ORDER BY salary DESC) to rank salaries within
--          each department.
-- Step 3 — Filter WHERE salary_rank <= 3 to keep only
--          employees in the top 3 salary tiers.
--
-- Key decision: DENSE_RANK not RANK
-- If two employees share the same salary they get the same rank.
-- RANK() skips numbers after ties: 1, 1, 3, 4
-- DENSE_RANK() does not skip: 1, 1, 2, 3
-- Problem asks for top 3 UNIQUE salaries — DENSE_RANK ensures
-- the 3rd unique salary tier is always captured correctly.
-- ============================================================

WITH joined_data AS (
    SELECT
        e.name   AS employee_name,
        e.salary,
        d.name   AS department_name
    FROM Employee e
    INNER JOIN Department d ON e.departmentId = d.id
),
ranked_salaries AS (
    SELECT
        employee_name,
        department_name,
        salary,
        DENSE_RANK() OVER (
            PARTITION BY department_name
            ORDER BY salary DESC
        ) AS salary_rank
    FROM joined_data
)
SELECT
    department_name AS Department,
    employee_name   AS Employee,
    salary          AS Salary
FROM ranked_salaries
WHERE salary_rank <= 3
ORDER BY department_name, salary DESC;

-- ============================================================
-- EXAMPLE WALKTHROUGH:
-- Input:
-- Employee:
-- id | name  | salary | departmentId
-- 1  | Joe   | 85000  | 1
-- 2  | Henry | 80000  | 2
-- 3  | Sam   | 60000  | 2
-- 4  | Max   | 90000  | 1
-- 5  | Janet | 69000  | 1
-- 6  | Randy | 85000  | 1
-- 7  | Will  | 70000  | 1
--
-- Department:
-- id | name
-- 1  | IT
-- 2  | Sales
--
-- After JOIN:
-- employee | salary | department
-- Joe      | 85000  | IT
-- Max      | 90000  | IT
-- Janet    | 69000  | IT
-- Randy    | 85000  | IT
-- Will     | 70000  | IT
-- Henry    | 80000  | Sales
-- Sam      | 60000  | Sales
--
-- After DENSE_RANK per department:
-- Max   | 90000 | IT    | rank 1
-- Joe   | 85000 | IT    | rank 2
-- Randy | 85000 | IT    | rank 2  ← same salary, same rank
-- Will  | 70000 | IT    | rank 3
-- Janet | 69000 | IT    | rank 4  ← excluded
-- Henry | 80000 | Sales | rank 1
-- Sam   | 60000 | Sales | rank 2
--
-- Final output (salary_rank <= 3):
-- Department | Employee | Salary
-- IT         | Max      | 90000
-- IT         | Joe      | 85000
-- IT         | Randy    | 85000
-- IT         | Will     | 70000
-- Sales      | Henry    | 80000
-- Sales      | Sam      | 60000
-- ============================================================

-- ============================================================
-- EDGE CASES TO KEEP IN MIND:
-- 1. Two employees same salary same department — DENSE_RANK
--    gives them identical rank. Both qualify if rank <= 3.
--    This is correct — both earn the same salary tier.
-- 2. Department with fewer than 3 unique salaries — all
--    employees qualify. WHERE salary_rank <= 3 still works
--    correctly — it just returns all available ranks.
-- 3. Always alias both name columns when joining two tables
--    that share a column name — e.name AS employee_name,
--    d.name AS department_name. Without aliases the query
--    is ambiguous and may error or return wrong results.
-- 4. INNER JOIN excludes employees with NULL departmentId
--    and departments with no employees. If business logic
--    requires keeping unassigned employees use LEFT JOIN.
-- ============================================================

-- ============================================================
-- WHY DENSE_RANK NOT RANK:
-- Salaries in IT: 90000, 85000, 85000, 70000, 69000
--
-- RANK():       1, 2, 2, 4, 5  ← skips 3, rank 4 = 4th salary
-- DENSE_RANK(): 1, 2, 2, 3, 4  ← no gaps, rank 3 = 3rd unique salary
--
-- With RANK() and filter <= 3:
-- ranks 1, 2, 2 qualify → misses Will at 70000 (rank 4)
-- even though only 3 UNIQUE salary values exist above him
--
-- With DENSE_RANK() and filter <= 3:
-- ranks 1, 2, 2, 3 qualify → correctly includes Will
-- because 70000 is the 3rd unique salary tier
-- ============================================================

-- ============================================================
-- KEY PATTERN — MEMORIZE THIS:
-- "Top N within a group" with ties handled correctly:
--   1. JOIN to get all needed columns with clear aliases
--   2. DENSE_RANK() OVER (PARTITION BY group ORDER BY metric DESC)
--   3. Filter WHERE dense_rank_col <= N
--
-- Use DENSE_RANK when: top N unique values (ties share rank)
-- Use RANK when: top N positions (ties skip positions)
-- Use ROW_NUMBER when: exactly N rows regardless of ties
-- ============================================================
