-- ============================================================
-- Problem : Consecutive Numbers
-- Source  : LeetCode 180
-- Link    : https://leetcode.com/problems/consecutive-numbers/
-- Topic   : LEAD / LAG / Self JOIN / Window Functions
-- Level   : Medium
-- Date    : 2026-08-12
-- ============================================================

-- PROBLEM STATEMENT:
-- Table: Logs (id int autoincrement, num varchar)
-- Find all numbers that appear at least THREE times consecutively.
-- Return result in any order.

-- ============================================================
-- APPROACH 1: LEAD Window Function (recommended — most readable)
--
-- LEAD(num, 1) → looks at next row's num value
-- LEAD(num, 2) → looks at two rows ahead num value
--
-- Logic:
-- For each row check if current num = next num = num after that
-- If all three equal → consecutive three times ✅
--
-- Why DISTINCT:
-- If num=1 appears 5 consecutive times:
-- → rows 1,2,3 all pass WHERE condition
-- → same num returned multiple times ❌
-- → DISTINCT removes duplicates ✅
--
-- Why ORDER BY id:
-- → id is autoincrement → natural order of insertion
-- → consecutive = consecutive by id ✅
-- ============================================================

SELECT DISTINCT num AS ConsecutiveNums
FROM (
    SELECT
        num,
        LEAD(num, 1) OVER (ORDER BY id) AS next1,
        LEAD(num, 2) OVER (ORDER BY id) AS next2
    FROM Logs
) t
WHERE num = next1
  AND num = next2;

-- ============================================================
-- APPROACH 2: Self JOIN (classic approach — works in all SQL versions)
--
-- Three copies of same table:
-- l1 = anchor row (starting row)
-- l2 = one row ahead (l2.id = l1.id + 1)
-- l3 = two rows ahead (l3.id = l1.id + 2)
--
-- JOIN connects consecutive rows by id
-- WHERE checks all three have same num value
-- ============================================================

SELECT DISTINCT l1.num AS ConsecutiveNums
FROM Logs l1
JOIN Logs l2 ON l2.id = l1.id + 1
JOIN Logs l3 ON l3.id = l1.id + 2
WHERE l1.num = l2.num
  AND l1.num = l3.num;

-- ============================================================
-- APPROACH 3: LAG Window Function (looks backwards)
--
-- LAG(num, 1) → looks at previous row's num value
-- LAG(num, 2) → looks at two rows behind num value
--
-- Same logic as LEAD but checking current row
-- against previous two rows instead of next two
-- ============================================================

SELECT DISTINCT num AS ConsecutiveNums
FROM (
    SELECT
        num,
        LAG(num, 1) OVER (ORDER BY id) AS prev1,
        LAG(num, 2) OVER (ORDER BY id) AS prev2
    FROM Logs
) t
WHERE num = prev1
  AND num = prev2;

-- ============================================================
-- EXAMPLE WALKTHROUGH (LEAD approach):
-- Input:
-- id | num
-- 1  |  1
-- 2  |  1
-- 3  |  1
-- 4  |  2
-- 5  |  1
-- 6  |  2
-- 7  |  2
--
-- After LEAD window function:
-- id | num | next1 | next2
-- 1  |  1  |   1   |   1   ← 1=1=1 ✅ consecutive!
-- 2  |  1  |   1   |   2   ← 1=1 but 1≠2 ❌
-- 3  |  1  |   2   |   1   ← 1≠2 ❌
-- 4  |  2  |   1   |   2   ← 2≠1 ❌
-- 5  |  1  |   2   |   2   ← 1≠2 ❌
-- 6  |  2  |   2   |  NULL ← NULL comparison fails ❌
-- 7  |  2  | NULL  |  NULL ← NULL comparison fails ❌
--
-- WHERE num=next1 AND num=next2:
-- → only row 1 passes ✅
-- → DISTINCT → ConsecutiveNums = 1 ✅
-- ============================================================

-- ============================================================
-- SELF JOIN WALKTHROUGH:
--
-- Step 1: JOIN l1 with l2 (l2.id = l1.id + 1):
-- l1.id | l1.num | l2.id | l2.num
-- 1     |   1    |   2   |   1
-- 2     |   1    |   3   |   1
-- 3     |   1    |   4   |   2
-- 4     |   2    |   5   |   1
-- 5     |   1    |   6   |   2
-- 6     |   2    |   7   |   2
-- (id=7 has no l2 match → excluded)
--
-- Step 2: JOIN with l3 (l3.id = l1.id + 2):
-- l1.id | l1.num | l2.num | l3.num
-- 1     |   1    |   1    |   1
-- 2     |   1    |   1    |   2
-- 3     |   1    |   2    |   1
-- 4     |   2    |   1    |   2
-- 5     |   1    |   2    |   2
-- (id=6,7 have no l3 match → excluded)
--
-- Step 3: WHERE l1.num = l2.num AND l1.num = l3.num:
-- l1.id=1: 1=1=1 ✅ MATCH → ConsecutiveNums = 1
-- l1.id=2: 1=1 but 1≠2 ❌
-- l1.id=3: 1≠2 ❌
-- l1.id=4: 2≠1 ❌
-- l1.id=5: 1≠2 ❌
--
-- DISTINCT result: ConsecutiveNums = 1 ✅
-- ============================================================

-- ============================================================
-- COMMON MISTAKES:
--
-- 1. Forgetting DISTINCT:
--    → same num returned multiple times if appears 4+ times
--    → DISTINCT ensures unique results ✅
--
-- 2. Using wrong JOIN condition:
--    ON l1.id = l2.id - 1 → confusing direction ❌
--    ON l2.id = l1.id + 1 → clearer intent ✅
--
-- 3. Using LEAD without ORDER BY:
--    LEAD(num) OVER () → undefined order → wrong results ❌
--    LEAD(num) OVER (ORDER BY id) → correct order ✅
--
-- 4. Not handling NULL from LEAD at end of table:
--    Last rows have NULL for LEAD values
--    NULL = NULL is FALSE in SQL → automatically excluded ✅
--    No special NULL handling needed
-- ============================================================

-- ============================================================
-- EDGE CASES:
--
-- 1. Same number appears exactly 3 times consecutively:
--    → one match → returned once ✅
--
-- 2. Same number appears 5 times consecutively:
--    → rows 1,2,3 all match
--    → DISTINCT returns it once ✅
--
-- 3. Number appears 3 times but NOT consecutively:
--    → 1,2,1,2,1 → never three in a row ❌
--    → correctly excluded ✅
--
-- 4. All rows same number:
--    → all consecutive → returned once via DISTINCT ✅
--
-- 5. Only one or two rows in table:
--    → LEAD returns NULL → no match possible ✅
-- ============================================================

-- ============================================================
-- APPROACH COMPARISON:
--
-- LEAD/LAG:
-- ✅ most readable and modern
-- ✅ no self joins needed
-- ✅ scales well
-- ✅ preferred in interviews
--
-- Self JOIN:
-- ✅ works in all SQL versions (no window functions needed)
-- ✅ explicit and easy to understand visually
-- ❌ slower on large tables (three table scans)
-- ❌ harder to extend to N consecutive rows
--
-- Best for interviews: LEAD approach
-- Mention Self JOIN as alternative to show breadth ✅
-- ============================================================

-- ============================================================
-- KEY PATTERN — MEMORIZE THIS:
-- "Find consecutive same values in sequence":
--
-- LEAD approach:
--   SELECT DISTINCT col AS result
--   FROM (
--       SELECT col,
--           LEAD(col, 1) OVER (ORDER BY id) AS next1,
--           LEAD(col, 2) OVER (ORDER BY id) AS next2
--       FROM table
--   ) t
--   WHERE col = next1 AND col = next2
--
-- Self JOIN approach:
--   SELECT DISTINCT t1.col AS result
--   FROM table t1
--   JOIN table t2 ON t2.id = t1.id + 1
--   JOIN table t3 ON t3.id = t1.id + 2
--   WHERE t1.col = t2.col AND t1.col = t3.col
--
-- Real DE use cases:
-- → Consecutive log entries with same error ← monitoring ✅
-- → Three consecutive days with same status ← anomaly detection
-- → Consecutive sensor readings above threshold ← Caterpillar IoT ✅
-- → Three consecutive days of declining revenue ← airline RM ✅
-- ============================================================
