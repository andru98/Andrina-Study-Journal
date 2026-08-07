-- ============================================================
-- Problem : Classes With More Than 5 Students
-- Source  : LeetCode 596
-- Link    : https://leetcode.com/problems/classes-more-than-5-students/
-- Topic   : GROUP BY / HAVING / COUNT
-- Level   : Easy
-- Date    : 2026-08-05
-- ============================================================

-- PROBLEM STATEMENT:
-- Table: Courses (student varchar, class varchar)
-- (student, class) is the primary key.
-- Find all classes that have AT LEAST 5 students enrolled.
-- Return: class only.

-- ============================================================
-- APPROACH 1: Simple GROUP BY + HAVING (recommended — most concise)
-- GROUP BY collapses all rows per class into one group.
-- COUNT(student) counts how many students are in each group.
-- HAVING filters groups AFTER aggregation — WHERE cannot be used
-- here because WHERE runs before GROUP BY (execution order).
--
-- Why HAVING not WHERE:
-- WHERE runs at step 3 (before GROUP BY at step 4).
-- COUNT(student) doesn't exist yet at step 3.
-- HAVING runs at step 5 (after GROUP BY) → can use COUNT ✅
-- ============================================================

SELECT class
FROM Courses
GROUP BY class
HAVING COUNT(student) >= 5;

-- ============================================================
-- APPROACH 2: CTE (more readable for complex extensions)
-- Useful when you need to reference the count multiple times
-- or add additional filtering/joining on top.
-- ============================================================

WITH class_counts AS (
    SELECT
        class,
        COUNT(student) AS student_count
    FROM Courses
    GROUP BY class
)
SELECT class
FROM class_counts
WHERE student_count >= 5;

-- ============================================================
-- APPROACH 3: Subquery (avoid — unnecessary wrapping)
-- Functionally correct but adds unnecessary complexity.
-- Shown here to document what NOT to do.
-- ============================================================

-- NOT RECOMMENDED:
-- SELECT class FROM (
--     SELECT class, COUNT(student)
--     FROM Courses
--     GROUP BY class
--     HAVING COUNT(student) >= 5
-- ) c
-- Reason: outer SELECT adds nothing — HAVING already filters ❌

-- ============================================================
-- EXAMPLE WALKTHROUGH:
-- Input Courses:
-- student | class
-- A       | Math
-- B       | Math
-- C       | Math
-- D       | Math
-- E       | Math
-- F       | English
-- G       | English
-- H       | English
-- I       | Biology
--
-- After GROUP BY class:
-- class   | COUNT(student)
-- Math    | 5              → HAVING >= 5 ✅ included
-- English | 3              → HAVING >= 5 ❌ excluded
-- Biology | 1              → HAVING >= 5 ❌ excluded
--
-- Output:
-- class
-- Math
-- ============================================================

-- ============================================================
-- COMMON MISTAKES:
--
-- 1. Using WHERE instead of HAVING:
--    WHERE COUNT(student) >= 5  ← ERROR ❌
--    COUNT() is an aggregate — not available at WHERE stage
--    Fix: use HAVING after GROUP BY ✅
--
-- 2. Using > 5 instead of >= 5:
--    HAVING COUNT(student) > 5  ← misses classes with exactly 5
--    Fix: HAVING COUNT(student) >= 5 ✅
--
-- 3. COUNT(*) vs COUNT(student):
--    COUNT(*) = counts all rows including NULLs
--    COUNT(student) = counts non-NULL student values
--    Since (student, class) is primary key → student never NULL
--    Both give same result here, but COUNT(student) is more explicit ✅
--
-- 4. Unnecessary DISTINCT inside COUNT:
--    COUNT(DISTINCT student) ← wrong here
--    (student, class) is primary key → no duplicate students per class
--    DISTINCT adds overhead for no benefit ❌
-- ============================================================

-- ============================================================
-- EXECUTION ORDER — WHY HAVING WORKS, WHERE DOESN'T:
-- 1. FROM Courses
-- 2. WHERE (runs here — aggregates don't exist yet)
-- 3. GROUP BY class (groups formed here)
-- 4. HAVING COUNT(student) >= 5 (aggregates available here ✅)
-- 5. SELECT class
-- 6. ORDER BY
-- ============================================================

-- ============================================================
-- KEY PATTERN — MEMORIZE THIS:
-- "Find groups with count meeting a threshold":
--
--   SELECT group_col
--   FROM table
--   GROUP BY group_col
--   HAVING COUNT(value_col) >= threshold
--
-- Real DE use cases:
-- → Classes with 5+ students (this problem)
-- → Products ordered by 3+ customers
-- → Users active on 7+ days
-- → Queries run more than 100 times
-- → Artists with 5+ tracks in dataset (Spotify pipeline)
-- ============================================================
