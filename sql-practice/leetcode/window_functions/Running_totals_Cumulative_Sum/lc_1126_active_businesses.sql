-- ============================================================
-- Problem : Active Businesses
-- Source  : LeetCode 1126
-- Link    : https://leetcode.com/problems/active-businesses/
-- Topic   : Window Functions / AVG OVER / GROUP BY / HAVING
-- Level   : Medium
-- Date    : 2026-06-09
-- ============================================================

-- PROBLEM STATEMENT:
-- Table: Events (business_id, event_type, occurences)
-- The average activity for an event_type = AVG(occurences)
-- across all businesses that have that event_type.
-- Find all businesses that have MORE THAN ONE event_type
-- where their occurences strictly exceeds the average
-- activity for that event_type.
-- Output: business_id

-- ============================================================
-- APPROACH:
-- Step 1 — Use AVG(occurences) OVER (PARTITION BY event_type)
--          to bring the average for each event_type down to
--          every row. This lets us compare each business's
--          occurences against its event_type average.
-- Step 2 — Filter WHERE occurences > avg_event_type.
--          These are all rows where a business beats the average
--          for that event_type.
-- Step 3 — GROUP BY business_id and use HAVING COUNT > 1
--          to keep only businesses that beat the average in
--          more than one event_type.
--
-- Key insight: This problem needs BOTH window function AND
-- GROUP BY. Window function first to compare row vs group
-- average, then GROUP BY to collapse and count qualifying
-- event types per business.
-- ============================================================

WITH avg_activity AS (
    SELECT
        business_id,
        event_type,
        occurences,
        AVG(occurences) OVER (PARTITION BY event_type) AS avg_event_type
    FROM Events
)
SELECT business_id
FROM avg_activity
WHERE occurences > avg_event_type
GROUP BY business_id
HAVING COUNT(event_type) > 1;

-- ============================================================
-- EXAMPLE WALKTHROUGH:
-- Input:
-- business_id | event_type | occurences
-- 1           | click      | 100
-- 2           | click      | 60
-- 3           | click      | 80        → avg click = 80
-- 1           | view       | 200
-- 2           | view       | 120
-- 3           | view       | 150       → avg view = 156.6
--
-- After CTE (avg_activity):
-- business_id | event_type | occurences | avg_event_type
-- 1           | click      | 100        | 80    ← beats avg ✓
-- 2           | click      | 60         | 80    ← does not
-- 3           | click      | 80         | 80    ← does not (not strictly greater)
-- 1           | view       | 200        | 156.6 ← beats avg ✓
-- 2           | view       | 120        | 156.6 ← does not
-- 3           | view       | 150        | 156.6 ← does not
--
-- After WHERE occurences > avg_event_type:
-- business_id | event_type
-- 1           | click
-- 1           | view
--
-- After GROUP BY + HAVING COUNT > 1:
-- business_id
-- 1           ← beats average in 2 event types
-- ============================================================

-- ============================================================
-- EDGE CASES TO KEEP IN MIND:
-- 1. Business beats average in exactly 1 event_type — correctly
--    excluded by HAVING COUNT(event_type) > 1.
-- 2. Strictly greater than (>) not >= — a business with
--    occurences exactly equal to average does not qualify.
-- 3. AVG() OVER() includes all businesses for that event_type
--    in the average calculation — this is correct behavior,
--    you want the global average per event_type.
-- 4. NULL occurences — AVG() ignores NULLs automatically so
--    average calculation remains correct.
-- 5. A business appears in only one event_type total — after
--    WHERE filter it has at most 1 row, HAVING COUNT > 1
--    correctly excludes it.
-- ============================================================

-- ============================================================
-- KEY PATTERN — MEMORIZE THIS:
-- "Compare each row against its group average, then filter
--  groups by how many rows qualified" follows this structure:
--   1. AVG() OVER (PARTITION BY group_col) → row-level average
--   2. WHERE row_value > avg_value → filter qualifying rows
--   3. GROUP BY entity + HAVING COUNT > threshold → final filter
--
-- This pattern appears in: sales performance above average,
-- products outperforming category average, employees above
-- department average.
-- ============================================================
