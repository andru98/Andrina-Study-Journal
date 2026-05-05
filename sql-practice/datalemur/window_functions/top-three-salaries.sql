-- Problem: Top Three Salaries
-- Source: DataLemur
-- Link: https://datalemur.com/questions/top-three-salaries

-- Topic: Window Functions (DENSE_RANK)
-- Difficulty: Medium

-- Approach:
-- 1. Use DENSE_RANK() to rank salaries within each department.
-- 2. Partition by department_id to ensure ranking resets per department.
-- 3. Order salaries in descending order so highest salaries get rank 1.
-- 4. Filter to keep only ranks 1–3.
-- 5. Join with department table to return department names.

WITH ranked_salary AS (
    SELECT
        name,
        salary,
        department_id,
        DENSE_RANK() OVER (
            PARTITION BY department_id
            ORDER BY salary DESC
        ) AS ranking
    FROM employee
)
SELECT
    d.department_name,
    s.name,
    s.salary
FROM ranked_salary AS s
JOIN department AS d
    ON s.department_id = d.department_id
WHERE s.ranking <= 3
ORDER BY
    d.department_name ASC,
    s.salary DESC,
    s.name ASC;
