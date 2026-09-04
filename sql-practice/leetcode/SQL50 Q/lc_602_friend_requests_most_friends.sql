-- ============================================================
-- Problem : Friend Requests II: Who Has the Most Friends
-- Source  : LeetCode 602
-- Link    : https://leetcode.com/problems/friend-requests-ii-who-has-the-most-friends/
-- Topic   : UNION ALL / GROUP BY / HAVING / Subquery
-- Level   : Medium
-- Date    : 2026-08-26
-- ============================================================

-- PROBLEM STATEMENT:
-- Table: RequestAccepted (requester_id, accepter_id, accept_date)
-- Find person with most friends and their friend count
-- Friendship is bidirectional:
-- → person can be friend as requester OR accepter
-- → must count BOTH sides ✅

-- ============================================================
-- KEY INSIGHT:
-- Person appears in TWO places:
-- → as requester_id (sent friend request) ✅
-- → as accepter_id (received friend request) ✅
-- Both count as friendships!
--
-- Example: Person 3
-- → accepter from person 1 ✅
-- → accepter from person 2 ✅
-- → requester to person 4 ✅
-- → total = 3 friends ✅
--
-- Solution: UNION ALL combines both sides
-- → every person ID in one column
-- → GROUP BY + COUNT = total friends ✅
-- ============================================================

-- ============================================================
-- APPROACH 1: Original (one person with most friends)
-- UNION ALL combines requester + accepter IDs
-- GROUP BY counts total per person
-- ORDER BY + LIMIT 1 gets winner
-- ============================================================

SELECT id, COUNT(*) AS num
FROM (
    SELECT requester_id AS id FROM RequestAccepted
    UNION ALL
    SELECT accepter_id  AS id FROM RequestAccepted
) all_friends
GROUP BY id
ORDER BY num DESC
LIMIT 1;

-- ============================================================
-- APPROACH 2: Follow Up (multiple people with same max friends)
-- HAVING COUNT(*) = MAX keeps ALL tied people
-- More robust than LIMIT 1 ✅
-- ============================================================

SELECT id, COUNT(*) AS num
FROM (
    SELECT requester_id AS id FROM RequestAccepted
    UNION ALL
    SELECT accepter_id  AS id FROM RequestAccepted
) all_friends
GROUP BY id
HAVING COUNT(*) = (
    -- Find maximum friend count across all people
    SELECT MAX(friend_count)
    FROM (
        SELECT COUNT(*) AS friend_count
        FROM (
            SELECT requester_id AS id FROM RequestAccepted
            UNION ALL
            SELECT accepter_id  AS id FROM RequestAccepted
        ) t
        GROUP BY id
    ) counts
)
ORDER BY num DESC;

-- ============================================================
-- EXAMPLE WALKTHROUGH:
-- Input:
-- requester_id | accepter_id
-- 1            | 2
-- 1            | 3
-- 2            | 3
-- 3            | 4
--
-- UNION ALL result:
-- id    ← all person IDs from both columns
-- 1     ← requester
-- 1     ← requester
-- 2     ← requester
-- 3     ← requester
-- 2     ← accepter
-- 3     ← accepter
-- 3     ← accepter
-- 4     ← accepter
--
-- GROUP BY id + COUNT(*):
-- id | num
-- 1  | 2   ← sent to 2,3
-- 2  | 2   ← sent to 3, received from 1
-- 3  | 3   ← received from 1,2 + sent to 4 ✅ MAX!
-- 4  | 1   ← received from 3
--
-- ORDER BY num DESC LIMIT 1:
-- id=3, num=3 ✅
-- ============================================================

-- ============================================================
-- COMMON MISTAKES:
--
-- 1. Counting only one side:
--    SELECT requester_id, COUNT(*) → misses accepter side ❌
--    SELECT accepter_id, COUNT(*)  → misses requester side ❌
--    Fix: UNION ALL both sides ✅
--
-- 2. Using UNION instead of UNION ALL:
--    UNION removes duplicates ← wrong here ❌
--    Person 1 sent TWO requests → should count as 2 ✅
--    UNION ALL keeps all rows → correct count ✅
--
-- 3. Using LIMIT 1 for follow up:
--    LIMIT 1 → only one person if tied ❌
--    HAVING COUNT(*) = MAX → all tied people ✅
--
-- 4. Using WHERE instead of HAVING:
--    WHERE filters BEFORE GROUP BY ❌
--    → can't use COUNT(*) in WHERE ❌
--    HAVING filters AFTER GROUP BY ✅
--    → can use COUNT(*) ✅
-- ============================================================

-- ============================================================
-- UNION vs UNION ALL recap:
--
-- UNION:     removes duplicates (slower)
-- UNION ALL: keeps all rows (faster) ✅
--
-- Use UNION ALL when:
-- → duplicates are meaningful (counting occurrences) ✅
-- → performance matters ✅
-- → combining same-structure results ✅
--
-- Use UNION when:
-- → want distinct results only ✅
-- → reference/category tables ✅
-- ============================================================

-- ============================================================
-- KEY PATTERN — MEMORIZE THIS:
-- "Count bidirectional relationships":
--
--   SELECT id, COUNT(*) AS connections
--   FROM (
--       SELECT from_id AS id FROM table
--       UNION ALL
--       SELECT to_id AS id FROM table
--   ) all_connections
--   GROUP BY id
--   ORDER BY connections DESC
--   LIMIT 1
--
-- Real DE use cases:
-- → Friend connections (this problem) ✅
-- → Email sender + receiver count ✅
-- → Flight origin + destination traffic ✅
-- → Airline RM: busiest airports (departures + arrivals) ✅
-- → Caterpillar: most connected equipment nodes ✅
-- → Spotify: artists with most collaborations ✅
-- ============================================================
