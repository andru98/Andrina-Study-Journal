-- ============================================================
-- Problem : Biggest Single Number
-- Source  : LeetCode 619
-- Link    : https://leetcode.com/problems/biggest-single-number/
-- Topic   : GROUP BY / HAVING / MAX / NULL handling
-- Level   : Easy
-- Date    : 2026-08-05
-- ============================================================

-- PROBLEM STATEMENT:
-- Table: MyNumbers (num int)
-- A single number = appears exactly once in the table.
-- Find the largest single number.
-- If no single number exists, return null.

-- ============================================================
-- APPROACH 1: Subquery + MAX (recommended)
-- Step 1: GROUP BY num → HAVING COUNT = 1 finds all single numbers.
-- Step 2: MAX() on those single numbers returns the largest.
-- Step 3: MAX() returns NULL automatically when no rows exist —
--         no special NULL handling needed ✅
--
-- Why not DISTINCT:
-- DISTINCT removes duplicate rows but loses COUNT information.
-- Cannot tell which numbers appeared once vs multiple times.
-- GROUP BY + HAVING COUNT = 1 is the correct approach ✅
-- ============================================================

SELECT MAX(num) AS num
FROM (
    SELECT num
    FROM MyNumbers
    GROUP BY num
    HAVING COUNT(num) = 1
) single_numbers;

-- ============================================================
-- APPROACH 2: CTE (more readable — same performance)
-- ============================================================

WITH single_numbers AS (
    SELECT num
    FROM MyNumbers
    GROUP BY num
    HAVING COUNT(num) = 1
)
SELECT MAX(num) AS num
FROM single_numbers;

-- ============================================================
-- EXAMPLE WALKTHROUGH:
-- Input:
-- num: 8, 8, 3, 3, 1, 4, 5, 6
--
-- After GROUP BY num:
-- num | COUNT(num)
-- 1   | 1          → HAVING COUNT = 1 ✅ single
-- 3   | 2          → HAVING COUNT = 1 ❌ excluded
-- 4   | 1          → HAVING COUNT = 1 ✅ single
-- 5   | 1          → HAVING COUNT = 1 ✅ single
-- 6   | 1          → HAVING COUNT = 1 ✅ single
-- 8   | 2          → HAVING COUNT = 1 ❌ excluded
--
-- Single numbers: [1, 4, 5, 6]
-- MAX(num) = 6 ✅
--
-- Example 2 (no single numbers):
-- num: 8, 8, 7, 7, 3, 3, 3
-- All numbers appear more than once
-- HAVING COUNT = 1 → no rows returned
-- MAX() of empty set = NULL ✅ automatic
-- ============================================================

-- ============================================================
-- COMMON MISTAKES:
--
-- 1. Using DISTINCT instead of GROUP BY + HAVING:
--    SELECT DISTINCT num FROM MyNumbers → removes duplicates
--    but can't filter by appearance count ❌
--    Fix: GROUP BY num HAVING COUNT(num) = 1 ✅
--
-- 2. Not handling NULL case:
--    MAX() returns NULL automatically when no rows ✅
--    No IFNULL or COALESCE needed for this problem
--
-- 3. Using HAVING COUNT(num) > 1 (wrong direction):
--    > 1 finds duplicates not singles ❌
--    = 1 finds numbers appearing exactly once ✅
--
-- 4. Forgetting MAX — returning all single numbers:
--    Problem asks for LARGEST single number (one row)
--    not all single numbers ✅
-- ============================================================

-- ============================================================
-- EDGE CASES:
--
-- 1. All numbers are duplicates:
--    → HAVING COUNT = 1 returns no rows
--    → MAX(num) = NULL ✅
--
-- 2. All numbers are single (appear once):
--    → HAVING COUNT = 1 returns all rows
--    → MAX returns largest ✅
--
-- 3. Only one number in table:
--    → appears once → COUNT = 1
--    → MAX returns that number ✅
--
-- 4. Single number is 0 or negative:
--    → MAX handles any integer value ✅
--    → works correctly for negative numbers
--
-- 5. Multiple numbers tied for largest:
--    → not possible — problem guarantees num values
--       but MAX handles ties by returning the value once ✅
-- ============================================================

-- ============================================================
-- KEY PATTERN — MEMORIZE THIS:
-- "Find max/min value that meets a frequency condition":
--
--   SELECT MAX/MIN(col) AS result
--   FROM (
--       SELECT col
--       FROM table
--       GROUP BY col
--       HAVING COUNT(col) = N  -- frequency condition
--   ) filtered
--
-- MAX/MIN returns NULL automatically when no rows ✅
-- No special NULL handling needed
--
-- Real DE use cases:
-- → Largest product sold only once
-- → Most recent event type that occurred exactly once
-- → Highest salary that only one employee earns
-- → Most popular song with exactly one play (anomaly detection)
-- ============================================================
