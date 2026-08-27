-- ============================================================
-- Problem : Movie Rating
-- Source  : LeetCode 1341
-- Link    : https://leetcode.com/problems/movie-rating/
-- Topic   : UNION ALL / Subquery / JOIN / AVG / COUNT / DATE filter
-- Level   : Medium
-- Date    : 2026-08-25
-- ============================================================

-- PROBLEM STATEMENT:
-- Table: Movies (movie_id, title)
-- Table: Users (user_id, name)
-- Table: MovieRating (movie_id, user_id, rating, created_at)
--
-- Find:
-- 1. User who rated the most movies
--    (tie → lexicographically smaller name)
-- 2. Movie with highest avg rating in February 2020
--    (tie → lexicographically smaller title)
-- Return both results in one column "results"

-- ============================================================
-- KEY INSIGHT:
-- Two separate questions → two separate subqueries
-- Combined with UNION ALL (not UNION):
-- → UNION removes duplicates ← wrong here ❌
-- → UNION ALL keeps both rows ✅
--
-- Tie-breaking with ORDER BY:
-- → ORDER BY metric DESC, name ASC
-- → highest metric first ✅
-- → if tie → alphabetical name ✅
-- → LIMIT 1 → picks winner ✅
--
-- February 2020 filter:
-- → created_at >= '2020-02-01'
-- → created_at < '2020-03-01'
-- → catches ALL February dates safely ✅
-- ============================================================

-- Part 1: User with most movie ratings
-- Part 2: Movie with highest avg rating in Feb 2020
SELECT u.name AS results
FROM (
    SELECT u.name,
           COUNT(mr.movie_id) AS rating_count
    FROM MovieRating mr
    INNER JOIN Users u ON mr.user_id = u.user_id
    GROUP BY u.name                         -- group by name for SELECT ✅
    ORDER BY rating_count DESC, u.name ASC  -- tie: lexicographic ✅
    LIMIT 1
) t

UNION ALL

SELECT m.title AS results
FROM (
    SELECT m.title,
           AVG(mr.rating) AS avg_rating
    FROM Movies m
    INNER JOIN MovieRating mr ON m.movie_id = mr.movie_id
    WHERE mr.created_at >= '2020-02-01'
      AND mr.created_at <  '2020-03-01'     -- February 2020 only ✅
    GROUP BY m.title
    ORDER BY avg_rating DESC, m.title ASC   -- tie: lexicographic ✅
    LIMIT 1
) t2;

-- ============================================================
-- EXAMPLE WALKTHROUGH:
-- Part 1 - Count ratings per user:
-- user   | rating_count
-- Daniel | 3  ← most ratings ✅
-- Monica | 3  ← tied but Daniel < Monica lexicographically ✅
-- Maria  | 2
-- James  | 1
-- ORDER BY count DESC, name ASC → Daniel first → LIMIT 1 ✅
--
-- Part 2 - Avg rating per movie in Feb 2020:
-- Avengers: ratings [4, 2] → avg = 3.0
-- Frozen 2: ratings [5, 2] → avg = 3.5 ✅
-- Joker:    ratings [3, 4] → avg = 3.5 (tie!)
-- Frozen 2 vs Joker → Frozen 2 < Joker lexicographically ✅
--
-- Final output:
-- results
-- Daniel    ← most ratings ✅
-- Frozen 2  ← highest avg in Feb 2020 ✅
-- ============================================================

-- ============================================================
-- COMMON MISTAKES:
--
-- 1. Using UNION instead of UNION ALL:
--    UNION removes duplicates ← wrong ❌
--    If Daniel rated Frozen 2 → appears in both results
--    UNION would remove one → wrong output ❌
--    UNION ALL keeps both rows always ✅
--
-- 2. Wrong GROUP BY:
--    GROUP BY mr.user_id → can't SELECT u.name ❌
--    GROUP BY u.name → correct ✅
--
-- 3. Wrong February filter:
--    WHERE MONTH(created_at) = 2 AND YEAR(created_at) = 2020
--    → works in MySQL but not PostgreSQL ❌
--    WHERE created_at >= '2020-02-01' AND < '2020-03-01'
--    → works in all databases ✅
--
-- 4. Missing tie-breaker in ORDER BY:
--    ORDER BY rating_count DESC → random tie resolution ❌
--    ORDER BY rating_count DESC, u.name ASC → correct ✅
--
-- 5. GROUP BY movie_id instead of title:
--    GROUP BY m.movie_id → can't use title in ORDER BY ❌
--    GROUP BY m.title → correct ✅
-- ============================================================

-- ============================================================
-- DATE FILTER ALTERNATIVES:
--
-- Option 1 (safest - all databases):
-- WHERE created_at >= '2020-02-01' AND created_at < '2020-03-01'
--
-- Option 2 (MySQL):
-- WHERE YEAR(created_at) = 2020 AND MONTH(created_at) = 2
--
-- Option 3 (PostgreSQL):
-- WHERE DATE_TRUNC('month', created_at) = '2020-02-01'
--
-- Option 1 recommended:
-- → works in all databases ✅
-- → optimizer can use index on created_at ✅
-- → YEAR/MONTH functions prevent index use ❌
-- ============================================================

-- ============================================================
-- KEY PATTERN — MEMORIZE THIS:
-- "Two separate questions → UNION ALL":
--
--   SELECT result FROM (
--       SELECT col, metric
--       FROM table
--       JOIN ...
--       GROUP BY col
--       ORDER BY metric DESC, col ASC  ← tie-breaker
--       LIMIT 1
--   ) t1
--   UNION ALL
--   SELECT result FROM (
--       SELECT col, metric
--       FROM table
--       JOIN ...
--       WHERE date_filter
--       GROUP BY col
--       ORDER BY metric DESC, col ASC  ← tie-breaker
--       LIMIT 1
--   ) t2
--
-- Real DE use cases:
-- → Top user + top product in same report ✅
-- → Best performing region + worst performing region ✅
-- → Most active artist + highest rated album (Spotify) ✅
-- → Busiest route + most profitable route (Airline RM) ✅
-- → Most utilized equipment + lowest performing (Caterpillar) ✅
-- ============================================================
