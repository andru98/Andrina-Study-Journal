-- ============================================================
-- Problem : Spotify Listening Percentiles
-- Source  : DataLemur (Medium)
-- Topic   : Window Functions / PERCENT_RANK / CTE / GROUP BY
-- Level   : Medium
-- Date    : 2026-06-11
-- ============================================================

-- PROBLEM STATEMENT:
-- Table: listening_habits (user_id, song_id, listen_count)
-- Find the top 25% of users by total listen count.
-- Return user_id and total_listen_count.
-- Order by total_listen_count descending.

-- ============================================================
-- APPROACH:
-- Step 1 — Aggregate total listen count per user with SUM
--          and GROUP BY. One user can have many rows (one
--          per song) — must collapse to one row per user first.
-- Step 2 — Use PERCENT_RANK() to rank users by their total
--          listen count. No PARTITION BY needed — ranking
--          is across all users globally.
-- Step 3 — Filter WHERE listen_percentage >= 0.75 to keep
--          only users in the top 25%.
--
-- Key decision: PERCENT_RANK not NTILE(4)
-- NTILE(4) divides by row count — equal-sized buckets
-- regardless of value distribution. If data is skewed,
-- NTILE puts low-listen users in the same bucket as
-- high-listen users.
-- PERCENT_RANK is position-based — a user at >= 0.75
-- genuinely has a higher count than 75% of all users.
-- For "top 25%" questions, PERCENT_RANK is more precise.
--
-- Key mistake to avoid: do NOT apply PERCENT_RANK before
-- aggregating. Ranking individual rows gives each song
-- its own rank — not each user. Always GROUP BY first,
-- then rank the aggregated result.
-- ============================================================

WITH total_listens AS (
    SELECT
        user_id,
        SUM(listen_count) AS total_listen_count
    FROM listening_habits
    GROUP BY user_id
),
percent_listen AS (
    SELECT
        user_id,
        total_listen_count,
        PERCENT_RANK() OVER (
            ORDER BY total_listen_count
        ) AS listen_percentage
    FROM total_listens
)
SELECT
    user_id,
    total_listen_count
FROM percent_listen
WHERE listen_percentage >= 0.75
ORDER BY total_listen_count DESC;

-- ============================================================
-- EXAMPLE WALKTHROUGH:
-- Input:
-- user_id | song_id | listen_count
-- 1       | s1      | 20
-- 1       | s2      | 30
-- 2       | s1      | 10
-- 3       | s3      | 80
-- 4       | s2      | 15
--
-- After CTE 1 (total_listens):
-- user_id | total_listen_count
-- 1       | 50   (20 + 30)
-- 2       | 10
-- 3       | 80
-- 4       | 15
--
-- After CTE 2 (PERCENT_RANK ORDER BY total_listen_count):
-- user_id | total | listen_percentage
-- 2       | 10    | 0.0000  ← lowest
-- 4       | 15    | 0.3333
-- 1       | 50    | 0.6667
-- 3       | 80    | 1.0000  ← highest
--
-- Filter listen_percentage >= 0.75:
-- user_id | total_listen_count
-- 3       | 80   ← only user in top 25%
--
-- Final output ordered by total_listen_count DESC:
-- user_id | total_listen_count
-- 3       | 80
-- ============================================================

-- ============================================================
-- EDGE CASES TO KEEP IN MIND:
-- 1. Must SUM before ranking — one user has multiple rows
--    (one per song). Ranking without GROUP BY gives each
--    song row its own rank, not each user. Always aggregate
--    first when the table has multiple rows per entity.
-- 2. Use >= 0.75 not > 0.75 — includes users exactly at
--    the 75th percentile boundary. > 0.75 silently excludes
--    them, leaving them in neither the top 25% nor bottom 75%.
-- 3. PERCENT_RANK of last row = 1.0 always. With 4 users,
--    only the user with the highest total qualifies at >= 0.75.
--    With more users, more will qualify as the distribution
--    spreads out.
-- 4. Users with identical total_listen_count get the same
--    PERCENT_RANK value — both included or both excluded
--    together. This is the correct behaviour.
-- 5. No PARTITION BY — ranking is global across all users,
--    not within groups. Only add PARTITION BY if the question
--    asks for top 25% within each category or region.
-- ============================================================

-- ============================================================
-- NTILE ALTERNATIVE — also valid, different tradeoff:
-- WITH total_listens AS (
--     SELECT user_id, SUM(listen_count) AS total_listen_count
--     FROM listening_habits GROUP BY user_id
-- ),
-- bucketed AS (
--     SELECT user_id, total_listen_count,
--            NTILE(4) OVER (ORDER BY total_listen_count DESC) AS quartile
--     FROM total_listens
-- )
-- SELECT user_id, total_listen_count
-- FROM bucketed
-- WHERE quartile = 1
-- ORDER BY total_listen_count DESC;
--
-- NTILE(4) divides by row count equally — bucket 1 always
-- has exactly 25% of users regardless of value distribution.
-- PERCENT_RANK >= 0.75 is position-based — more precise
-- for skewed data. Both are acceptable interview answers
-- but be ready to explain the tradeoff.
-- ============================================================

-- ============================================================
-- KEY PATTERN — MEMORIZE THIS:
-- "Top X% of users by metric" follows this structure:
--   1. GROUP BY entity + SUM/COUNT metric → one row per entity
--   2. PERCENT_RANK() OVER (ORDER BY metric) → 0 to 1 ranking
--   3. WHERE pct_rank >= (1 - X/100) → filter top X%
--      Top 10% → >= 0.90
--      Top 25% → >= 0.75
--      Top 20% → >= 0.80
--
-- Common mistake: skipping step 1 and ranking raw rows
-- Always ask: does this table have multiple rows per entity?
-- If yes → GROUP BY first, then rank.
-- ============================================================
