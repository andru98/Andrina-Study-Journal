-- ============================================================
-- Problem : Histogram of Tweets
-- Source  : DataLemur
-- Link    : https://datalemur.com/questions/sql-histogram-tweets
-- Topic   : Aggregation / GROUP BY / CTE
-- Level   : Easy
-- Date    : 2026-06-09
-- ============================================================

-- PROBLEM STATEMENT:
-- Table: tweets (user_id, tweet_date, tweet_count)
-- Find the number of users who tweeted 1 time, 2 times,
-- 3 times etc. in 2022.
-- Output: tweet_bucket, users_num

-- ============================================================
-- APPROACH:
-- Step 1 — Find total tweets per user in 2022 using GROUP BY.
--          This gives one row per user with their total count.
-- Step 2 — Group those totals into buckets and count how many
--          users fall into each bucket.
--
-- Key decision: GROUP BY not Window Function
-- Final output needs ONE collapsed row per user total, then
-- ONE collapsed row per bucket. No row-level detail needed.
-- SUM() OVER() would keep individual rows — wrong tool here.
-- ============================================================

WITH tweets_per_user AS (
    SELECT
        user_id,
        SUM(tweet_count) AS tweet_bucket
    FROM tweets
    WHERE YEAR(tweet_date) = 2022
    GROUP BY user_id
)
SELECT
    tweet_bucket,
    COUNT(user_id) AS users_num
FROM tweets_per_user
GROUP BY tweet_bucket
ORDER BY tweet_bucket;

-- ============================================================
-- EXAMPLE WALKTHROUGH:
-- Input:
-- user_id | tweet_date | tweet_count
-- 1       | 2022-01-01 | 3
-- 1       | 2022-06-15 | 2
-- 2       | 2022-03-10 | 1
-- 3       | 2022-07-20 | 5
--
-- After CTE (tweets_per_user):
-- user_id | tweet_bucket
-- 1       | 5   (3 + 2)
-- 2       | 1
-- 3       | 5
--
-- Final output:
-- tweet_bucket | users_num
-- 1            | 1   (user 2)
-- 5            | 2   (users 1 and 3)
-- ============================================================

-- ============================================================
-- EDGE CASES TO KEEP IN MIND:
-- 1. Filter WHERE YEAR = 2022 is critical — missing it counts
--    all tweets ever, not just 2022. Easy to forget under time
--    pressure.
-- 2. Users with 0 tweets in 2022 won't appear in the tweets
--    table — they are correctly excluded from output since the
--    problem only asks about users who tweeted.
-- 3. tweet_bucket = total per user for the whole year, not a
--    running total. Don't reach for SUM() OVER() here.
-- 4. A user can have multiple rows in the raw table (one per
--    day they tweeted) — the CTE collapses them into one total
--    per user before bucketing.
-- ============================================================

-- ============================================================
-- COMMON MISTAKE:
-- Using SUM(tweet_count) OVER (PARTITION BY user_id) instead
-- of GROUP BY. Window function keeps one row per original
-- tweet entry — you'd end up bucketing individual tweet rows
-- instead of user totals. Always ask: do I need rows preserved
-- (window) or collapsed (GROUP BY)?
-- ============================================================
