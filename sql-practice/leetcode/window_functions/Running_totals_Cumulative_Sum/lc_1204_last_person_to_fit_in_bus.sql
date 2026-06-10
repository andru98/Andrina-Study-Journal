-- ============================================================
-- Problem : Last Person to Fit in the Bus
-- Source  : LeetCode 1204
-- Link    : https://leetcode.com/problems/last-person-to-fit-in-the-bus/
-- Topic   : Window Functions / Running Total / CTE
-- Level   : Medium
-- Date    : 2026-06-09
-- ============================================================

-- PROBLEM STATEMENT:
-- Table: Queue (person_id, person_name, weight, turn)
-- People board a bus one at a time in order of their turn number.
-- The bus has a weight limit of 1000 kg.
-- Only one person boards per turn.
-- Find the person_name of the LAST person who can board
-- without the total weight exceeding 1000 kg.
-- It is guaranteed the first person alone does not exceed 1000 kg.

-- ============================================================
-- APPROACH:
-- Step 1 — Calculate cumulative (running) weight as each
--          person boards, ordered by turn using
--          SUM(weight) OVER (ORDER BY turn).
-- Step 2 — Filter to rows where cumulative weight <= 1000.
--          These are all people who can fit on the bus.
-- Step 3 — The last person among those = the one with the
--          highest cumulative weight still under the limit.
--          ORDER BY total_weight DESC LIMIT 1 gets them.
-- ============================================================

WITH running_total AS (
    SELECT
        person_name,
        SUM(weight) OVER (ORDER BY turn) AS total_weight
    FROM Queue
)
SELECT person_name
FROM running_total
WHERE total_weight <= 1000
ORDER BY total_weight DESC
LIMIT 1;

-- ============================================================
-- EXAMPLE WALKTHROUGH:
-- Input (sorted by turn):
-- turn | person_name | weight | cumulative_weight
-- 1    | Alice       | 250    | 250
-- 2    | Alex        | 350    | 600
-- 3    | John Cena   | 400    | 1000   ← last person who fits
-- 4    | Marie       | 200    | 1200   ← exceeds limit
-- 5    | Bob         | 175    | 1375   ← exceeds limit
-- 6    | Winston     | 500    | 1875   ← exceeds limit
--
-- Filter total_weight <= 1000 → Alice, Alex, John Cena
-- ORDER BY total_weight DESC LIMIT 1 → John Cena
--
-- Output: John Cena
-- ============================================================

-- ============================================================
-- EDGE CASES TO KEEP IN MIND:
-- 1. Only one person fits — they have the highest total_weight
--    under 1000. Query still returns correctly.
-- 2. Everyone fits — last person by turn order is returned.
--    total_weight DESC LIMIT 1 handles this correctly.
-- 3. person_id not needed in SELECT — only person_name
--    is required in output. Keep queries lean.
-- 4. The ORDER BY inside OVER() determines boarding order,
--    not the final ORDER BY. These serve different purposes —
--    don't confuse them.
-- 5. Guaranteed first person does not exceed 1000 kg alone,
--    so the result set is never empty.
-- ============================================================

-- ============================================================
-- KEY PATTERN — MEMORIZE THIS:
-- Running total problems follow this structure:
--   1. SUM(value) OVER (ORDER BY sequence_col) → cumulative total
--   2. Filter WHERE cumulative_total <= threshold
--   3. Pick the boundary row with ORDER BY DESC LIMIT 1
--
-- This pattern appears in: budget allocation, capacity limits,
-- revenue milestones, weight/volume constraints.
-- ============================================================

-- ============================================================
-- ALTERNATIVE APPROACH (without CTE):
-- SELECT person_name
-- FROM (
--     SELECT person_name,
--            SUM(weight) OVER (ORDER BY turn) AS total_weight
--     FROM Queue
-- ) t
-- WHERE total_weight <= 1000
-- ORDER BY total_weight DESC
-- LIMIT 1;
--
-- CTE version is preferred for readability in interviews.
-- ============================================================
