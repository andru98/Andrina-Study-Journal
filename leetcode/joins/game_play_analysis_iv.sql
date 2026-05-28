-- Problem: Game Play Analysis IV
-- Source: LeetCode
-- Link: https://leetcode.com/problems/game-play-analysis-iv/
-- Folder: sql-practice/leetcode/joins/

-- Topic: CTE + LEFT JOIN + DATE_ADD + COUNT DISTINCT
-- Difficulty: Medium

-- Problem Statement:
-- Find the fraction of players that logged in again on the day
-- immediately after the day they first logged in.
-- Round to 2 decimal places.
-- Note: (player_id, event_date) is the primary key — one row per player per day.

-- Approach:
-- 1. CTE gets each player's first login date using MIN(event_date) grouped by player_id.
--    This gives exactly one row per player.
-- 2. LEFT JOIN back to Activity on two conditions in the ON clause:
--    a. Same player_id
--    b. event_date = first_login + exactly 1 day using DATE_ADD
--    Both conditions must be in ON, not WHERE — moving date condition to WHERE
--    silently converts LEFT JOIN to INNER JOIN and drops non-returning players.
-- 3. COUNT(DISTINCT a.player_id) = numerator — players who came back.
--    NULL from right side is ignored by COUNT automatically.
-- 4. COUNT(DISTINCT m.player_id) = denominator — all players.
--    DISTINCT needed on both sides because one CTE row can match multiple
--    Activity rows if a player logged in multiple times on day 2,
--    causing the left row to repeat.
-- 5. ROUND the result to 2 decimal places. No multiplication by 100 needed here
--    since the question asks for a fraction (0.67), not a percentage (66.67).

WITH min_event_date AS (
    SELECT player_id, MIN(event_date) AS first_login
    FROM Activity
    GROUP BY player_id
)
SELECT
    ROUND(
        COUNT(DISTINCT a.player_id) / COUNT(DISTINCT m.player_id)
    , 2) AS fraction
FROM min_event_date m
LEFT JOIN Activity a
    ON m.player_id = a.player_id
    AND a.event_date = DATE_ADD(m.first_login, INTERVAL 1 DAY);

-- ============================================================
-- WHAT THE TABLE LOOKS LIKE AFTER LEFT JOIN
-- ============================================================
-- m.player_id | m.first_login | a.player_id | a.event_date
-- ----------- | ------------- | ----------- | ------------
-- 1           | 2024-01-01    | 1           | 2024-01-02   ← match found
-- 2           | 2024-03-10    | NULL        | NULL         ← no match, kept by LEFT JOIN
-- 3           | 2024-05-01    | 3           | 2024-05-02   ← match found
--
-- COUNT(DISTINCT a.player_id) = 2 (ignores NULL) → numerator
-- COUNT(DISTINCT m.player_id) = 3 (no NULLs)    → denominator
-- fraction = 2/3 = 0.67

-- ============================================================
-- WHY DISTINCT IS NEEDED ON BOTH SIDES
-- ============================================================
-- The primary key is (player_id, event_date) — one row per player per day.
-- So in this specific problem, a player cannot log in twice on the same day.
-- DISTINCT on a.player_id is technically not needed here due to the primary key.
-- DISTINCT on m.player_id is also not needed since CTE already has one row per player.
-- However, adding DISTINCT is defensive coding — if the table had no primary key
-- guarantee, duplicate logins on day 2 would cause left rows to repeat,
-- inflating both counts. Using DISTINCT makes the query safe regardless of data guarantees.

-- Edge Cases
-- Player logs in multiple times on day 2     → primary key prevents this here,
--                                               but COUNT DISTINCT handles it safely
--                                               if the guarantee were removed
-- Player never logs in after first day       → LEFT JOIN keeps them as NULL row,
--                                               COUNT(a.player_id) ignores NULL correctly
-- All players came back next day             → fraction = 1.00
-- No player came back next day              → COUNT(a.player_id) = 0, fraction = 0.00
-- Only one player in table                   → works correctly, fraction = 0 or 1
-- Date condition in WHERE instead of ON      → NULL rows eliminated, LEFT JOIN becomes
--                                               INNER JOIN silently, denominator shrinks,
--                                               fraction becomes wrong
-- DATE_ADD vs +1                             → DATE_ADD(date, INTERVAL 1 DAY) is MySQL
--                                               standard. first_login + INTERVAL 1 DAY
--                                               also works in MySQL. Avoid plain + 1
--                                               on DATE columns — behavior varies by database
