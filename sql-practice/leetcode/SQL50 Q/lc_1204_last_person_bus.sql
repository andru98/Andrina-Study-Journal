-- ============================================================
-- Problem : Last Person to Fit in the Bus
-- Source  : LeetCode 1204
-- Link    : https://leetcode.com/problems/last-person-to-fit-in-the-bus/
-- Topic   : Window Functions / Running Total / SUM OVER
-- Level   : Medium
-- Date    : 2026-08-17
-- ============================================================

-- PROBLEM STATEMENT:
-- Table: Queue (person_id, person_name, weight, turn)
-- Bus weight limit = 1000 kg
-- People board in turn order (turn=1 first)
-- Find the last person who can board without exceeding 1000 kg

-- ============================================================
-- KEY INSIGHT:
-- Need CUMULATIVE (running) weight — not individual weight
-- Individual weight <= 1000 is WRONG ❌
-- → person weighing 300 might still exceed limit
--   if previous people already used 800 kg
--
-- Correct approach:
-- → SUM(weight) OVER (ORDER BY turn) = running total
-- → find last row where running total <= 1000 ✅
-- ============================================================

-- ============================================================
-- APPROACH: SUM() Window Function (running total)
--
-- Step 1: Calculate cumulative weight per turn using
--         SUM(weight) OVER (ORDER BY turn)
-- Step 2: Filter rows where cumulative <= 1000
-- Step 3: Get person with HIGHEST cumulative weight
--         (= last person who fits) using ORDER BY DESC LIMIT 1
-- ============================================================

WITH cumulative AS (
    SELECT
        person_name,
        weight,
        turn,
        SUM(weight) OVER (ORDER BY turn) AS cumulative_weight
    FROM Queue
)
SELECT person_name
FROM cumulative
WHERE cumulative_weight <= 1000
ORDER BY cumulative_weight DESC
LIMIT 1;  -- last person who fits ✅

-- PostgreSQL alternative (ANSI standard):
-- FETCH FIRST 1 ROW ONLY instead of LIMIT 1

-- ============================================================
-- EXAMPLE WALKTHROUGH:
-- Input Queue (ordered by turn):
-- turn | person_name | weight
-- 1    | Alice       | 250
-- 2    | Alex        | 350
-- 3    | John Cena   | 400
-- 4    | Marie       | 200
-- 5    | Bob         | 175
-- 6    | Winston     | 500
--
-- After SUM(weight) OVER (ORDER BY turn):
-- turn | person_name | weight | cumulative_weight
-- 1    | Alice       | 250    | 250   ← <= 1000 ✅
-- 2    | Alex        | 350    | 600   ← <= 1000 ✅
-- 3    | John Cena   | 400    | 1000  ← <= 1000 ✅ last!
-- 4    | Marie       | 200    | 1200  ← > 1000 ❌ excluded
-- 5    | Bob         | 175    | 1375  ← > 1000 ❌ excluded
-- 6    | Winston     | 500    | 1875  ← > 1000 ❌ excluded
--
-- WHERE cumulative_weight <= 1000:
-- Alice (250), Alex (600), John Cena (1000)
--
-- ORDER BY cumulative_weight DESC LIMIT 1:
-- John Cena (1000) ← highest cumulative = last to board ✅
-- ============================================================

-- ============================================================
-- COMMON MISTAKES:
--
-- 1. Filtering by individual weight:
--    WHERE weight <= 1000 ← wrong! ❌
--    → person weighing 300 might exceed limit
--      if previous people used 800 kg already
--    Fix: use cumulative weight ✅
--
-- 2. Not ordering by turn in window function:
--    SUM(weight) OVER () ← sums all rows, no order ❌
--    SUM(weight) OVER (ORDER BY turn) ← running total ✅
--
-- 3. Using MAX(cumulative_weight) instead of LIMIT 1:
--    SELECT MAX(cumulative_weight) → gives number not name ❌
--    ORDER BY cumulative_weight DESC LIMIT 1 → gives name ✅
--
-- 4. Forgetting WHERE cumulative_weight <= 1000:
--    Without filter → returns last person in queue
--    not last person who FITS ❌
-- ============================================================

-- ============================================================
-- EDGE CASES:
--
-- 1. First person exactly at limit (weight = 1000):
--    → cumulative = 1000 <= 1000 ✅ boards
--    → next person makes it > 1000 → excluded ✅
--
-- 2. Only one person fits:
--    → cumulative after turn 1 <= 1000 ✅
--    → cumulative after turn 2 > 1000
--    → returns person from turn 1 ✅
--
-- 3. All persons fit:
--    → all cumulative weights <= 1000
--    → returns last person in queue ✅
--
-- 4. First person guaranteed to fit (per problem):
--    → no need to handle empty result ✅
-- ============================================================

-- ============================================================
-- KEY PATTERN — MEMORIZE THIS:
-- "Find last item in sequence where running total
--  doesn't exceed threshold":
--
--   WITH running AS (
--       SELECT col1, col2,
--           SUM(value_col) OVER (ORDER BY sequence_col)
--           AS running_total
--       FROM table
--   )
--   SELECT col1
--   FROM running
--   WHERE running_total <= threshold
--   ORDER BY running_total DESC
--   LIMIT 1
--
-- Real DE use cases:
-- → Last person to fit on bus (this problem) ✅
-- → Last item to fit in storage capacity
-- → Running budget — last project within budget
-- → Cumulative load factor per flight (Airline RM) ✅
-- → Equipment capacity utilization (Caterpillar IoT) ✅
-- → Streaming data: last event within time window
-- ============================================================
