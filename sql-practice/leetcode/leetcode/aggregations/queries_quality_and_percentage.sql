-- Problem: Queries Quality and Percentage
-- Source: LeetCode
-- Link: https://leetcode.com/problems/queries-quality-and-percentage/
-- Folder: sql-practice/aggregations/

-- Topic: Aggregation + AVG + COUNT(CASE WHEN) + GROUP BY
-- Difficulty: Easy

-- Problem Statement:
-- Quality = average of (rating / position) per query_name, rounded to 2 decimals.
-- Poor query percentage = percentage of rows where rating < 3, rounded to 2 decimals.

-- Approach:
-- 1. AVG(rating/position) gives quality — MySQL divides as float here.
-- 2. COUNT(CASE WHEN rating < 3 THEN 1 END) counts poor queries only.
--    No ELSE needed — COUNT ignores NULL, so non-matching rows are excluded.
-- 3. COUNT(rating) = total queries per query_name (denominator).
-- 4. Multiply by 100 and ROUND both metrics to 2 decimals.
-- 5. GROUP BY query_name to get one row per query type.

SELECT
    query_name,
    ROUND(AVG(rating / position), 2) AS quality,
    ROUND(COUNT(CASE WHEN rating < 3 THEN 1 END) / COUNT(rating) * 100, 2) AS poor_query_percentage
FROM queries
GROUP BY query_name;

-- Edge Cases
-- ELSE 0 in COUNT(CASE WHEN) → never use it, COUNT counts 0s and inflates numerator
-- NULL rating rows            → COUNT(rating) skips NULLs → safe denominator
-- position = 0               → division by zero in AVG(rating/position)
--                               Fix: NULLIF(position, 0) if data is untrusted
-- All ratings >= 3            → poor_query_percentage = 0 correctly
-- Duplicate rows in table     → problem says table may have duplicates,
--                               no deduplication needed per problem statement
