-- ============================================================
-- Problem : Human Traffic of Stadium
-- Source  : LeetCode 601
-- Link    : https://leetcode.com/problems/human-traffic-of-stadium/
-- Topic   : Window Functions / LAG / LEAD / CTE
-- Level   : Hard
-- Date    : 2026-06-17
-- ============================================================

-- PROBLEM STATEMENT:
-- Table: Stadium (id, visit_date, people)
-- id is the primary key. Dates are consecutive.
-- Find all rows where 3 or more consecutive ids
-- have people >= 100.
-- Return result ordered by visit_date.

-- ============================================================
-- APPROACH:
-- Every row in a consecutive group of 3+ is either:
--   Case 1: FIRST  — current + next two rows all >= 100
--   Case 2: MIDDLE — previous + current + next row all >= 100
--   Case 3: LAST   — previous two + current row all >= 100
--
-- These three cases cover every possible position in any
-- consecutive group regardless of length (3, 4, 5, 100 rows).
-- First row → always caught by Case 1.
-- Last row  → always caught by Case 3.
-- Middle rows → caught by Case 2 (and often Case 1 or 3 too).
--
-- Step 1 — Filter people >= 100 in CTE first.
--          LAG/LEAD must only see qualifying rows as neighbors.
--          Without this filter, a row below 100 would appear
--          as a neighbor and break the consecutive check.
-- Step 2 — Apply LAG(people,1), LAG(people,2) for previous
--          rows and LEAD(people,1), LEAD(people,2) for next rows.
-- Step 3 — WHERE checks all three cases with OR.
--          One row satisfying any case = qualifies.
--
-- No DISTINCT needed — id is the primary key so each row
-- is already unique. OR conditions on the same row never
-- produce duplicates.
-- ============================================================

WITH stadium_check AS (
    SELECT
        id,
        visit_date,
        people,
        LAG(people, 2)  OVER (ORDER BY id) AS prev2,
        LAG(people, 1)  OVER (ORDER BY id) AS prev1,
        LEAD(people, 1) OVER (ORDER BY id) AS next1,
        LEAD(people, 2) OVER (ORDER BY id) AS next2
    FROM Stadium
    WHERE people >= 100   -- filter qualifying rows first
)
SELECT id, visit_date, people
FROM stadium_check
WHERE
    -- Case 1: current row is FIRST of consecutive group
    (next1 >= 100 AND next2 >= 100)
    OR
    -- Case 2: current row is MIDDLE of consecutive group
    (prev1 >= 100 AND next1 >= 100)
    OR
    -- Case 3: current row is LAST of consecutive group
    (prev1 >= 100 AND prev2 >= 100)
ORDER BY visit_date;

-- ============================================================
-- EXAMPLE WALKTHROUGH:
-- Input:
-- id | visit_date | people
-- 1  | 2017-01-01 | 10     ← below 100, filtered out
-- 2  | 2017-01-02 | 109
-- 3  | 2017-01-03 | 150
-- 4  | 2017-01-04 | 99     ← below 100, filtered out
-- 5  | 2017-01-05 | 145
-- 6  | 2017-01-06 | 1455
-- 7  | 2017-01-07 | 199
-- 8  | 2017-01-08 | 188
--
-- After CTE (only rows with people >= 100):
-- id | people | prev2 | prev1 | next1 | next2
-- 2  | 109    | NULL  | NULL  | 150   | NULL   ← id 4 filtered
-- 3  | 150    | NULL  | 109   | NULL  | NULL   ← id 4 filtered
-- 5  | 145    | NULL  | NULL  | 1455  | 199
-- 6  | 1455   | NULL  | 145   | 199   | 188
-- 7  | 199    | 145   | 1455  | 188   | NULL
-- 8  | 188    | 1455  | 199   | NULL  | NULL
--
-- Case checks:
-- id 2: Case1 → next1=150>=100, next2=NULL → ❌ (NULL fails)
--        Case2 → prev1=NULL → ❌
--        Case3 → prev1=NULL → ❌ → NOT included (only 2 consecutive)
-- id 3: All cases fail → NOT included
-- id 5: Case1 → next1=1455>=100, next2=199>=100 → ✅ included
-- id 6: Case1 → next1=199>=100, next2=188>=100 → ✅ included
--        Case2 → prev1=145>=100, next1=199>=100 → ✅ included
-- id 7: Case2 → prev1=1455>=100, next1=188>=100 → ✅ included
--        Case3 → prev1=1455>=100, prev2=145>=100 → ✅ included
-- id 8: Case3 → prev1=199>=100, prev2=1455>=100 → ✅ included
--
-- Output:
-- id | visit_date | people
-- 5  | 2017-01-05 | 145
-- 6  | 2017-01-06 | 1455
-- 7  | 2017-01-07 | 199
-- 8  | 2017-01-08 | 188
-- ============================================================

-- ============================================================
-- PROVING IT WORKS FOR 6 CONSECUTIVE ROWS:
-- ids 2-7 all have people >= 100:
--
-- id | prev2 | prev1 | next1 | next2 | qualifies via
-- 2  | NULL  | NULL  | 150   | 200   | Case 1 ✅
-- 3  | NULL  | 120   | 200   | 180   | Case 1 ✅, Case 2 ✅
-- 4  | 120   | 150   | 180   | 140   | Case 1 ✅, Case 2 ✅, Case 3 ✅
-- 5  | 150   | 200   | 140   | 110   | Case 1 ✅, Case 2 ✅, Case 3 ✅
-- 6  | 200   | 180   | 110   | NULL  | Case 2 ✅, Case 3 ✅
-- 7  | 180   | 140   | NULL  | NULL  | Case 3 ✅
--
-- All 6 rows captured regardless of streak length.
-- ============================================================

-- ============================================================
-- EDGE CASES TO KEEP IN MIND:
-- 1. NULL propagation in LAG/LEAD:
--    First two rows → LAG returns NULL → NULL >= 100 = NULL
--    Last two rows  → LEAD returns NULL → NULL >= 100 = NULL
--    NULL comparisons evaluate to NULL (not true) → correctly
--    excluded from cases that require those neighbors.
--    No special NULL handling needed — three-valued logic works.
--
-- 2. Filter people >= 100 in CTE not in outer WHERE:
--    If you filter in outer WHERE after LAG/LEAD, the window
--    functions still see the below-100 rows as neighbors.
--    Example: id 4 (people=99) would appear as prev1 for id 5
--    making id 5's Case 2 fail even though 5,6,7 are consecutive.
--    Always filter BEFORE applying window functions.
--
-- 3. Exactly 2 consecutive rows — should NOT qualify:
--    ids 2,3 both >= 100 but id 4 < 100 (filtered out)
--    id 2: next1=150>=100 but next2=NULL → Case 1 fails
--    id 3: prev1=109>=100 but next1=NULL → Case 2 fails
--           prev2=NULL → Case 3 fails
--    Correctly excluded ✅
--
-- 4. No DISTINCT needed — id is primary key:
--    Each row appears exactly once in the table.
--    OR conditions on the same row do not duplicate it.
--    Unlike LC 180 where num was not unique, here id is
--    the primary key so results are already unique.
--
-- 5. ORDER BY visit_date not id in final output:
--    Problem asks for result ordered by visit_date.
--    Since dates are consecutive with ids, both give same
--    result here — but always follow what problem specifies.
-- ============================================================

-- ============================================================
-- KEY PATTERN — MEMORIZE THIS:
-- "Find rows belonging to a group of N+ consecutive rows
--  where all satisfy a condition":
--   1. Filter qualifying rows in CTE WHERE clause first
--   2. LAG(col, 1), LAG(col, 2) for previous rows
--      LEAD(col, 1), LEAD(col, 2) for next rows
--   3. Three cases cover all positions:
--      Case 1 (first):  next1 AND next2 satisfy condition
--      Case 2 (middle): prev1 AND next1 satisfy condition
--      Case 3 (last):   prev1 AND prev2 satisfy condition
--   4. WHERE case1 OR case2 OR case3
--   5. ORDER BY as required
--
-- Works for ANY streak length — 3, 4, 5, 100 consecutive rows.
-- Each row is either first, middle, or last — three cases cover all.
-- ============================================================
