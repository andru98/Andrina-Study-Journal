-- Problem: Not Boring Movies
-- Source: LeetCode
-- Link: https://leetcode.com/problems/not-boring-movies/

-- Topic: Filtering + Modulo + ORDER BY
-- Difficulty: Easy

-- Problem Statement:
-- Given a Cinema table with movie id, name, description, and rating,
-- find all movies that have an odd-numbered id AND a description
-- that is not 'Boring'. Return results ordered by rating descending.

-- Approach:
-- 1. Use modulo operator (id % 2 <> 0) to isolate odd-numbered ids.
--    Odd numbers always have a remainder of 1 when divided by 2.
--    So id % 2 = 1 means odd. id % 2 = 0 means even — we exclude those.
-- 2. Filter out rows where description = 'Boring' using <> operator.
--    <> means "not equal to" — same as != in most databases.
-- 3. Order the result by rating in descending order so highest
--    rated movies appear first.

SELECT id, movie, description, rating
FROM Cinema
WHERE id % 2 <> 0
  AND description <> 'Boring'
ORDER BY rating DESC;

-- ============================================================
-- WHY id % 2 <> 0 WORKS
-- ============================================================
-- Modulo (%) gives the remainder after division.
-- id = 1 → 1 % 2 = 1 → odd  ✅ keep
-- id = 2 → 2 % 2 = 0 → even ❌ exclude
-- id = 3 → 3 % 2 = 1 → odd  ✅ keep
-- id = 4 → 4 % 2 = 0 → even ❌ exclude
-- Writing <> 0 is cleaner than writing = 1
-- because it reads naturally as "remainder is not zero = odd"

-- ============================================================
-- <> vs != — Know Both for Interviews
-- ============================================================
-- Both mean "not equal to" and work in MySQL, PostgreSQL, SQL Server.
-- <> is the SQL standard — preferred in interviews and production code.
-- != is more familiar to developers coming from Python or Java.
-- Either works here. I used <> to stay consistent with SQL standards.

-- ============================================================
-- EDGE CASES
-- ============================================================

-- Edge Case 1: description column has mixed case (e.g. 'boring', 'BORING')
-- String comparison in MySQL is case-insensitive by default.
-- 'Boring' = 'boring' = 'BORING' in MySQL — all get filtered out.
-- In PostgreSQL it is case-sensitive — 'boring' would NOT be filtered
-- if the column stores 'Boring'. Use LOWER() to be safe across databases:
-- AND LOWER(description) <> 'boring'

-- Edge Case 2: description is NULL
-- WHERE description <> 'Boring' does NOT catch NULL rows.
-- NULL <> 'Boring' evaluates to NULL, not TRUE — so NULL rows
-- pass through the filter and appear in results.
-- If NULL descriptions should also be excluded, add:
-- AND description IS NOT NULL

-- Edge Case 3: No movies satisfy both conditions
-- Query returns empty result. No error — just empty. Correct behavior.

-- Edge Case 4: Multiple movies with same rating
-- ORDER BY rating DESC does not guarantee a stable order among ties.
-- Add a secondary sort if consistent ordering matters:
-- ORDER BY rating DESC, id ASC
