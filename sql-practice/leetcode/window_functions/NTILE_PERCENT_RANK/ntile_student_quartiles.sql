-- ============================================================
-- Problem : Student Score Quartiles
-- Source  : Practice Problem
-- Topic   : Window Functions / NTILE
-- Level   : Easy
-- Date    : 2026-06-09
-- ============================================================

-- PROBLEM STATEMENT:
-- Table: students (student_id, score)
-- Divide students into 4 quartiles based on score.
-- Highest score = bucket 1, lowest score = bucket 4.
-- Return: student_id, score, score_quartile

-- ============================================================
-- APPROACH:
-- NTILE(4) divides rows into 4 roughly equal groups by count.
-- ORDER BY score DESC puts highest scores in bucket 1.
-- No PARTITION BY needed — one group across all students.
--
-- Key decision: NTILE not PERCENT_RANK
-- The question asks "which bucket does this student belong to"
-- not "what percentile rank is this score". NTILE returns
-- a bucket number 1-4. PERCENT_RANK returns a 0-1 fraction.
-- ============================================================

SELECT
    student_id,
    score,
    NTILE(4) OVER (ORDER BY score DESC) AS score_quartile
FROM students
ORDER BY score DESC;

-- ============================================================
-- EXAMPLE WALKTHROUGH:
-- Input (8 students):
-- student_id | score
-- S-001      | 95
-- S-002      | 88
-- S-003      | 82
-- S-004      | 79
-- S-005      | 74
-- S-006      | 68
-- S-007      | 61
-- S-008      | 55
--
-- 8 rows / 4 buckets = 2 rows each, no remainder
--
-- Output:
-- student_id | score | score_quartile
-- S-001      | 95    | 1   ← top 25%
-- S-002      | 88    | 1
-- S-003      | 82    | 2
-- S-004      | 79    | 2
-- S-005      | 74    | 3
-- S-006      | 68    | 3
-- S-007      | 61    | 4
-- S-008      | 55    | 4   ← bottom 25%
-- ============================================================

-- ============================================================
-- UNEVEN ROWS EXAMPLE:
-- If there were 9 students instead of 8:
-- 9 / 4 = 2 remainder 1
-- Bucket 1: 3 rows  ← gets the extra row
-- Bucket 2: 2 rows
-- Bucket 3: 2 rows
-- Bucket 4: 2 rows
-- Remainder always distributes one extra row to the first
-- buckets. Buckets never differ by more than 1 row.
-- ============================================================

-- ============================================================
-- EDGE CASES TO KEEP IN MIND:
-- 1. ORDER BY direction matters completely:
--    DESC → bucket 1 = highest scores (most common in interviews)
--    ASC  → bucket 1 = lowest scores
--    Always be explicit about direction.
-- 2. NTILE ignores value distribution — divides by row count.
--    If scores cluster between 90-95 and 30-40, NTILE still
--    splits into equal-sized groups regardless of gaps.
--    Use CASE with manual thresholds for value-based buckets.
-- 3. Small dataset warning — NTILE(4) on 3 rows gives
--    buckets of 1, 1, 1, 0. Meaningless analytically.
--    Use NTILE when dataset has at least 10x the bucket count.
-- 4. Ties — two students with the same score get different
--    bucket numbers based on their row order. NTILE does not
--    handle ties specially. Use RANK() if ties need equal treatment.
-- ============================================================

-- ============================================================
-- COMMON MISTAKE:
-- Using PERCENT_RANK for this problem. PERCENT_RANK returns
-- a 0-1 fraction (0.0, 0.25, 0.50, 0.75, 1.0) not a bucket
-- number. When the question asks "which quartile group",
-- use NTILE. When the question asks "what percentile rank",
-- use PERCENT_RANK.
-- ============================================================