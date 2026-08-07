-- ============================================================
-- Problem : Find Followers Count
-- Source  : LeetCode 1729
-- Link    : https://leetcode.com/problems/find-followers-count/
-- Topic   : GROUP BY / COUNT / ORDER BY
-- Level   : Easy
-- Date    : 2026-08-05
-- ============================================================

-- PROBLEM STATEMENT:
-- Table: Followers (user_id int, follower_id int)
-- (user_id, follower_id) is the primary key.
-- For each user, return the number of followers.
-- Return result ordered by user_id ascending.

-- ============================================================
-- APPROACH: GROUP BY + COUNT (optimal — single pass)
-- GROUP BY user_id collapses all follower rows per user.
-- COUNT(follower_id) counts how many followers each user has.
-- ORDER BY user_id ASC returns results in ascending order.
--
-- Why COUNT(follower_id) not COUNT(*):
-- Both give same result here since (user_id, follower_id)
-- is the primary key → follower_id is never NULL.
-- COUNT(follower_id) is more semantically explicit —
-- we are counting followers, not rows. ✅
-- ============================================================

SELECT
    user_id,
    COUNT(follower_id) AS followers_count
FROM Followers
GROUP BY user_id
ORDER BY user_id ASC;

-- ============================================================
-- EXAMPLE WALKTHROUGH:
-- Input Followers:
-- user_id | follower_id
-- 0       | 1
-- 1       | 0
-- 2       | 0
-- 2       | 1
--
-- After GROUP BY user_id:
-- user_id | COUNT(follower_id)
-- 0       | 1   → user 0 has 1 follower (follower_id=1)
-- 1       | 1   → user 1 has 1 follower (follower_id=0)
-- 2       | 2   → user 2 has 2 followers (follower_id=0,1)
--
-- After ORDER BY user_id ASC:
-- user_id | followers_count
-- 0       | 1
-- 1       | 1
-- 2       | 2
-- ============================================================

-- ============================================================
-- COMMON MISTAKES:
--
-- 1. Forgetting ORDER BY:
--    Problem explicitly asks for user_id ascending
--    Missing ORDER BY → wrong answer on LeetCode ❌
--
-- 2. COUNT(*) vs COUNT(follower_id):
--    Both correct here since primary key prevents NULLs
--    COUNT(follower_id) is more explicit and readable ✅
--
-- 3. Selecting follower_id instead of counting it:
--    SELECT user_id, follower_id → lists pairs, not counts ❌
--    SELECT user_id, COUNT(follower_id) → correct ✅
--
-- 4. Missing GROUP BY:
--    COUNT without GROUP BY → one total count for all users ❌
--    GROUP BY user_id → separate count per user ✅
-- ============================================================

-- ============================================================
-- EDGE CASES:
--
-- 1. User with no followers:
--    → user_id won't appear in Followers table at all
--    → GROUP BY only groups existing rows
--    → user with 0 followers simply not in output
--    → problem doesn't ask to include 0-follower users ✅
--
-- 2. User following themselves:
--    → (user_id=1, follower_id=1) is valid row
--    → counted as 1 follower ✅
--    → primary key allows this since it's a unique pair
--
-- 3. Large number of followers per user:
--    → COUNT handles any number ✅
--    → no performance concern for this query
--
-- 4. Single user with many followers:
--    user_id=5 followed by 1000 users
--    → GROUP BY creates one group for user_id=5
--    → COUNT = 1000 ✅
-- ============================================================

-- ============================================================
-- KEY PATTERN — MEMORIZE THIS:
-- "Count related records per entity":
--
--   SELECT entity_id, COUNT(related_id) AS count_col
--   FROM table
--   GROUP BY entity_id
--   ORDER BY entity_id ASC
--
-- Real DE use cases:
-- → Followers per user (this problem)
-- → Orders per customer
-- → Tracks per artist (Spotify pipeline Gold layer)
-- → Events per device (IoT telemetry)
-- → Transactions per account
-- ============================================================
