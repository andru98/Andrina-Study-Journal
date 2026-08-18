-- ============================================================
-- Problem : Triangle Judgement
-- Source  : LeetCode 610
-- Link    : https://leetcode.com/problems/triangle-judgement/
-- Topic   : CASE WHEN / Triangle Inequality Theorem
-- Level   : Easy
-- Date    : 2026-08-12
-- ============================================================

-- PROBLEM STATEMENT:
-- Table: Triangle (x int, y int, z int)
-- (x, y, z) is the primary key.
-- Each row contains lengths of three line segments.
-- Report whether each set of three segments can form a triangle.

-- ============================================================
-- APPROACH: CASE WHEN with Triangle Inequality Theorem
--
-- Triangle Inequality Theorem:
-- Three sides form a triangle ONLY IF sum of any two sides
-- is STRICTLY GREATER than the third side.
--
-- All three conditions must be true simultaneously:
-- x + y > z  (sum of x and y greater than z)
-- x + z > y  (sum of x and z greater than y)
-- y + z > x  (sum of y and z greater than x)
--
-- If ANY condition fails → not a triangle → 'No'
-- All conditions pass → triangle → 'Yes'
--
-- Common mistakes:
-- → forgetting single quotes around 'Yes'/'No' ❌
-- → forgetting END keyword after CASE ❌
-- → using >= instead of > (equal sides = degenerate triangle) ❌
-- ============================================================

SELECT
    x,
    y,
    z,
    CASE
        WHEN x + y > z
         AND x + z > y
         AND y + z > x
        THEN 'Yes'
        ELSE 'No'
    END AS triangle
FROM Triangle;

-- ============================================================
-- EXAMPLE WALKTHROUGH:
-- Input:
-- x  | y  | z
-- 13 | 15 | 30
-- 10 | 20 | 15
--
-- Row 1: x=13, y=15, z=30
-- x + y = 13 + 15 = 28 > 30? NO ❌ → fails first condition
-- Result: 'No' (not a triangle)
--
-- Row 2: x=10, y=20, z=15
-- x + y = 10 + 20 = 30 > 15? YES ✅
-- x + z = 10 + 15 = 25 > 20? YES ✅
-- y + z = 20 + 15 = 35 > 10? YES ✅
-- Result: 'Yes' (valid triangle)
-- ============================================================

-- ============================================================
-- COMMON MISTAKES:
--
-- 1. Missing quotes around Yes/No:
--    THEN Yes → SQL treats as column name → error ❌
--    THEN 'Yes' → string literal → correct ✅
--
-- 2. Missing END keyword:
--    CASE WHEN ... THEN 'Yes' ELSE 'No' AS triangle ❌
--    CASE WHEN ... THEN 'Yes' ELSE 'No' END AS triangle ✅
--
-- 3. Using >= instead of >:
--    x + y >= z → allows degenerate triangle (flat line) ❌
--    x + y > z  → strict inequality → correct ✅
--
-- 4. Checking only one condition:
--    WHEN x + y > z → only checks one pair ❌
--    Must check ALL three pairs simultaneously ✅
-- ============================================================

-- ============================================================
-- EDGE CASES:
--
-- 1. Equal sides (equilateral):
--    x=5, y=5, z=5
--    5+5=10 > 5 ✅ all three conditions pass → 'Yes' ✅
--
-- 2. One very large side:
--    x=1, y=1, z=100
--    1+1=2 > 100? NO ❌ → 'No' ✅
--
-- 3. Degenerate triangle (sum equals third side):
--    x=3, y=4, z=7
--    3+4=7 > 7? NO (equal not greater) ❌ → 'No' ✅
--    Strict > ensures degenerate cases return 'No' ✅
--
-- 4. Zero values:
--    x=0, y=5, z=5
--    0+5=5 > 5? NO ❌ → 'No' ✅
--    Zero length = not a valid side ✅
-- ============================================================

-- ============================================================
-- KEY PATTERN — MEMORIZE THIS:
-- "Multi-condition classification with CASE WHEN":
--
--   SELECT col1, col2,
--       CASE
--           WHEN condition1 AND condition2 AND condition3
--           THEN 'result_a'
--           ELSE 'result_b'
--       END AS classification
--   FROM table
--
-- Real DE use cases:
-- → Triangle validity (this problem)
-- → Data quality classification (valid/invalid)
-- → Risk categorization (low/medium/high)
-- → SLA breach detection (met/breached)
-- → Caterpillar: equipment health check
--   (all sensors in range → 'Healthy' else 'Alert')
-- ============================================================
