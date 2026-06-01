-- ============================================================
-- LC 627: Swap Sex of Employees
-- Difficulty : Easy
-- Topic      : CASE WHEN inside UPDATE
-- Author     : Anna Shrestha
-- ============================================================
-- Problem:
-- Update the Salary table so that all 'm' values in the sex
-- column become 'f' and all 'f' values become 'm'.
-- Must be done in a single UPDATE — no temp tables allowed.
--
-- Table: Salary
-- | id | name  | sex  | salary |
-- |----|-------|------|--------|
-- | 1  | A     | m    | 2500   |
-- | 2  | B     | f    | 1500   |
-- | 3  | C     | m    | 5500   |
-- | 4  | D     | f    | 500    |
--
-- Expected output after update:
-- | id | name  | sex  | salary |
-- |----|-------|------|--------|
-- | 1  | A     | f    | 2500   |
-- | 2  | B     | m    | 1500   |
-- | 3  | C     | f    | 5500   |
-- | 4  | D     | m    | 500    |
-- ============================================================


-- ------------------------------------------------------------
-- SOLUTION — simple CASE form inside UPDATE SET
-- ------------------------------------------------------------
UPDATE Salary
SET sex = CASE sex
    WHEN 'm' THEN 'f'
    WHEN 'f' THEN 'm'
END;

-- Why this works:
-- CASE evaluates sex for every row individually.
-- When sex = 'm' it returns 'f'. When sex = 'f' it returns 'm'.
-- SET assigns that return value back to the sex column.
-- All rows are updated in one pass — no temp table needed.


-- ------------------------------------------------------------
-- ALTERNATIVE — IF() in MySQL only
-- ------------------------------------------------------------
UPDATE Salary
SET sex = IF(sex = 'm', 'f', 'm');

-- Interview note:
-- IF() is MySQL-specific. CASE WHEN is ANSI SQL — works on
-- MySQL, PostgreSQL, SQL Server, Snowflake, BigQuery.
-- Always prefer CASE WHEN for portability across platforms.


-- ------------------------------------------------------------
-- EDGE CASES — mention these in interview
-- ------------------------------------------------------------

-- Edge case 1: What if sex column has values other than 'm'/'f'?
-- Without ELSE, unmatched rows return NULL — data corruption.
-- Defensive version with ELSE to preserve unknown values:
UPDATE Salary
SET sex = CASE sex
    WHEN 'm' THEN 'f'
    WHEN 'f' THEN 'm'
    ELSE sex           -- unknown values stay unchanged
END;

-- Edge case 2: What if the table is empty?
-- UPDATE runs 0 rows — no error, no data changed. Safe.

-- Edge case 3: What if sex column allows NULL?
-- CASE does not match NULL with WHEN 'm' or WHEN 'f'.
-- NULL rows would return NULL from CASE (no ELSE) — stays NULL.
-- With ELSE sex — NULL stays NULL. Both are safe for this problem.

-- Edge case 4: Can we SELECT first to verify before updating?
SELECT
    id,
    name,
    sex AS current_sex,
    CASE sex
        WHEN 'm' THEN 'f'
        WHEN 'f' THEN 'm'
        ELSE sex
    END AS sex_after_swap
FROM Salary;
-- Always good practice in production to SELECT preview before UPDATE.


-- ------------------------------------------------------------
-- INTERVIEW TALKING POINTS
-- ------------------------------------------------------------
-- Q: Why use CASE instead of two separate UPDATE statements?
-- A: Two separate UPDATeS would overwrite each other.
--    UPDATE 1 changes all 'm' to 'f'.
--    UPDATE 2 then changes all 'f' to 'm' — including the ones
--    just changed in UPDATE 1. Every row ends up as 'm'. Wrong.
--    CASE evaluates and swaps in one atomic pass.

-- Q: What is the time complexity?
-- A: O(n) — one full table scan, one row update per row.

-- Q: What keyword replaces EXCEPT in Oracle?
-- A: Not relevant here, but IF() in MySQL becomes
--    DECODE() in Oracle, IIF() in SQL Server.
--    CASE WHEN is the universal option.
