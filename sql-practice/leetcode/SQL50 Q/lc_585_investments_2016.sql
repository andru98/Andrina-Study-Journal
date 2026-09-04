-- ============================================================
-- Problem : Investments in 2016
-- Source  : LeetCode 585
-- Link    : https://leetcode.com/problems/investments-in-2016/
-- Topic   : GROUP BY / HAVING / IN Subquery / CTE / JOIN
-- Level   : Medium
-- Date    : 2026-08-31
-- ============================================================

-- PROBLEM STATEMENT:
-- Table: Insurance (pid, tiv_2015, tiv_2016, lat, lon)
-- Find SUM(tiv_2016) for policyholders who:
-- 1. Have same tiv_2015 as at least one other policyholder
-- 2. Have unique (lat, lon) location (not shared with anyone)
-- Round result to 2 decimal places

-- ============================================================
-- INTERVIEW APPROACH — HOW TO BREAK DOWN ANY SQL PROBLEM:
--
-- Step 1: Read → identify ALL conditions
--   Condition 1: "same tiv_2015 as others"
--   → tiv_2015 appears more than once
--   → GROUP BY tiv_2015 HAVING COUNT(*) > 1
--
--   Condition 2: "unique location"
--   → (lat, lon) pair appears exactly once
--   → GROUP BY lat, lon HAVING COUNT(*) = 1
--
-- Step 2: Write subquery per condition
-- Step 3: Combine with WHERE ... AND ...
-- Step 4: Apply final aggregation SUM()
--
-- English → SQL translation:
-- "same as others"     → HAVING COUNT > 1
-- "unique/only one"    → HAVING COUNT = 1
-- "at least one other" → HAVING COUNT >= 2
-- "sum of..."          → SUM()
-- "both conditions"    → WHERE cond1 AND cond2
-- ============================================================

-- ============================================================
-- APPROACH 1: IN Subquery (simple, readable)
-- Good for small datasets
-- ============================================================

SELECT ROUND(SUM(tiv_2016)::numeric, 2) AS tiv_2016
FROM Insurance
WHERE tiv_2015 IN (
    -- Condition 1: shared tiv_2015 (appears more than once)
    SELECT tiv_2015
    FROM Insurance
    GROUP BY tiv_2015
    HAVING COUNT(*) > 1
)
AND (lat, lon) IN (
    -- Condition 2: unique location (appears exactly once)
    SELECT lat, lon
    FROM Insurance
    GROUP BY lat, lon
    HAVING COUNT(*) = 1
);

-- ============================================================
-- APPROACH 2: CTE + JOIN (recommended for large datasets)
-- Optimizer builds hash tables once → more efficient
-- Readable, maintainable, partition pruning possible
-- ============================================================

WITH shared_tiv AS (
    -- Condition 1: tiv_2015 shared by multiple policyholders
    SELECT tiv_2015
    FROM Insurance
    GROUP BY tiv_2015
    HAVING COUNT(*) > 1
),
unique_location AS (
    -- Condition 2: (lat, lon) unique to one policyholder
    SELECT lat, lon
    FROM Insurance
    GROUP BY lat, lon
    HAVING COUNT(*) = 1
)
SELECT ROUND(SUM(i.tiv_2016)::numeric, 2) AS tiv_2016
FROM Insurance i
JOIN shared_tiv s ON i.tiv_2015 = s.tiv_2015
JOIN unique_location u ON i.lat = u.lat AND i.lon = u.lon;

-- ============================================================
-- EXAMPLE WALKTHROUGH:
-- Input:
-- pid | tiv_2015 | tiv_2016 | lat | lon
-- 1   | 10       | 5        | 10  | 10
-- 2   | 20       | 20       | 20  | 20
-- 3   | 10       | 30       | 20  | 20
-- 4   | 10       | 40       | 40  | 40
--
-- Condition 1 - shared tiv_2015:
-- tiv_2015=10 → COUNT=3 > 1 ✅ (pid 1,3,4 qualify)
-- tiv_2015=20 → COUNT=1 > 1 ❌ (pid 2 excluded)
--
-- Condition 2 - unique location:
-- lat=10,lon=10 → COUNT=1 = 1 ✅ (pid 1 qualifies)
-- lat=20,lon=20 → COUNT=2 = 1 ❌ (pid 2,3 excluded)
-- lat=40,lon=40 → COUNT=1 = 1 ✅ (pid 4 qualifies)
--
-- Both conditions met:
-- pid 1: shared tiv_2015 ✅, unique location ✅ → include
-- pid 2: NOT shared tiv_2015 ❌ → exclude
-- pid 3: shared tiv_2015 ✅, NOT unique location ❌ → exclude
-- pid 4: shared tiv_2015 ✅, unique location ✅ → include
--
-- SUM = 5 + 40 = 45.00 ✅
-- ============================================================

-- ============================================================
-- POSTGRESQL NOTE — ROUND with float:
-- PostgreSQL ROUND(double precision, int) not supported ❌
-- Must cast to numeric first:
-- ROUND(SUM(tiv_2016)::numeric, 2) ✅
--
-- MySQL:
-- ROUND(SUM(tiv_2016), 2) works directly ✅
-- No cast needed ✅
-- ============================================================

-- ============================================================
-- COMMON MISTAKES:
--
-- 1. Using COUNT(*) = 1 for shared tiv_2015:
--    HAVING COUNT(*) = 1 ← finds UNIQUE values ❌
--    HAVING COUNT(*) > 1 ← finds SHARED values ✅
--
-- 2. Using COUNT(*) > 1 for unique location:
--    HAVING COUNT(*) > 1 ← finds duplicates ❌
--    HAVING COUNT(*) = 1 ← finds unique ✅
--
-- 3. Forgetting ::numeric cast in PostgreSQL:
--    ROUND(SUM(tiv_2016), 2) ← error in PostgreSQL ❌
--    ROUND(SUM(tiv_2016)::numeric, 2) ← correct ✅
--
-- 4. Using single column for location check:
--    WHERE lat IN (...) ← wrong! need lat AND lon together ❌
--    WHERE (lat, lon) IN (...) ← tuple comparison ✅
-- ============================================================

-- ============================================================
-- PERFORMANCE COMPARISON:
--
-- IN Subquery:
-- → loads all matching values into memory
-- → checks each row against list
-- → O(N×M) for large datasets ❌
-- ✅ simple and readable for small data
--
-- CTE + JOIN:
-- → optimizer builds hash tables once ✅
-- → efficient join operations ✅
-- → partition pruning possible ✅
-- → better execution plan ✅
-- ✅ recommended for production large datasets
-- ============================================================

-- ============================================================
-- KEY PATTERN — MEMORIZE THIS:
-- "Filter by two independent GROUP BY conditions":
--
--   WITH condition_1 AS (
--       SELECT col FROM table
--       GROUP BY col
--       HAVING COUNT(*) > 1  -- shared
--   ),
--   condition_2 AS (
--       SELECT col FROM table
--       GROUP BY col
--       HAVING COUNT(*) = 1  -- unique
--   )
--   SELECT AGG(metric)
--   FROM table t
--   JOIN condition_1 ON t.col = condition_1.col
--   JOIN condition_2 ON t.col = condition_2.col
--
-- Real DE use cases:
-- → Insurance investments (this problem) ✅
-- → Find products sold in multiple regions but unique warehouse ✅
-- → Airline: routes with shared fare class but unique departure ✅
-- → Caterpillar: equipment models with shared specs but unique location ✅
-- → Spotify: artists in multiple genres but unique track ✅
-- ============================================================
