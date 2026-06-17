-- ============================================================
-- Problem : Consecutive Numbers
-- Source  : LeetCode 180
-- Link    : https://leetcode.com/problems/consecutive-numbers/
-- Topic   : Window Functions / LAG / CTE
-- Level   : Medium
-- Date    : 2026-06-14
-- ============================================================

-- PROBLEM STATEMENT:
-- Table: Logs (id, num)
-- Find all numbers that appear at least 3 times consecutively.
-- Return the result in any order.

-- ============================================================
-- APPROACH:
-- Use LAG() to look back at the previous two rows:
--   LAG(num, 1) → value from 1 row before current row
--   LAG(num, 2) → value from 2 rows before current row
--
-- If current num = previous num = two rows back num
-- → number appears 3 times consecutively → qualifies
--
-- Use DISTINCT in final SELECT — same number can qualify
-- multiple times (rows 3, 4, 5 all qualify for same number)
-- DISTINCT ensures each number appears only once in output.
--
-- Key decision: LAG over self-JOIN
-- Self-JOIN approach needs three copies of the table and
-- explicit id arithmetic (id+1, id+2) which breaks if ids
-- are not consecutive. LAG works correctly regardless of
-- gaps in id sequence.
-- ============================================================

WITH consecutive_check AS (
    SELECT
        id,
        num,
        LAG(num, 1) OVER (ORDER BY id) AS prev_num,
        LAG(num, 2) OVER (ORDER BY id) AS prev_prev_num
    FROM Logs
)
SELECT DISTINCT num AS ConsecutiveNums
FROM consecutive_check
WHERE num = prev_num
  AND num = prev_prev_num;

-- ============================================================
-- EXAMPLE WALKTHROUGH:
-- Input:
-- id | num
-- 1  | 1
-- 2  | 1
-- 3  | 1
-- 4  | 2
-- 5  | 1
-- 6  | 2
-- 7  | 2
--
-- After CTE (consecutive_check):
-- id | num | prev_num | prev_prev_num | qualifies?
-- 1  | 1   | NULL     | NULL          | ❌ NULL comparisons fail
-- 2  | 1   | 1        | NULL          | ❌ prev_prev_num is NULL
-- 3  | 1   | 1        | 1             | ✅ all three match
-- 4  | 2   | 1        | 1             | ❌ 2 ≠ 1
-- 5  | 1   | 2        | 1             | ❌ 1 ≠ 2
-- 6  | 2   | 1        | 2             | ❌ 2 ≠ 1
-- 7  | 2   | 2        | 1             | ❌ 2 ≠ 1
--
-- After WHERE filter:
-- num = 1 (only row 3 qualifies)
--
-- After DISTINCT:
-- ConsecutiveNums
-- 1 ✅
-- ============================================================

-- ============================================================
-- EDGE CASES TO KEEP IN MIND:
-- 1. First two rows always have NULL from LAG:
--    LAG on row 1 → NULL (no previous row)
--    LAG on row 2 → NULL for LAG(num,2) (only one previous row)
--    NULL = num → evaluates to NULL (not true) → correctly excluded
--    No special NULL handling needed — SQL three-valued logic
--    handles this automatically.
--
-- 2. Only one or two rows in entire table:
--    Maximum consecutive count = 2, never reaches 3.
--    Query returns empty result set — correct behavior.
--
-- 3. All rows same number:
--    id | num          Rows 3,4,5 all qualify.
--    1  | 5            Without DISTINCT → output: 5,5,5
--    2  | 5            With DISTINCT    → output: 5 ✅
--    3  | 5
--    4  | 5
--    5  | 5
--
-- 4. Multiple numbers appear consecutively:
--    id | num
--    1  | 1            Both 1 and 2 qualify.
--    2  | 1            Output: 1, 2
--    3  | 1
--    4  | 2
--    5  | 2
--    6  | 2
--
-- 5. Non-consecutive IDs (gaps in id sequence):
--    id | num
--    1  | 1
--    3  | 1    ← id 2 missing
--    5  | 1
--    LAG orders by id correctly — still compares adjacent rows
--    in id order. Works correctly regardless of id gaps.
-- ============================================================

-- ============================================================
-- WHY LAG OVER SELF-JOIN:
-- Self-JOIN alternative:
-- SELECT DISTINCT l1.num
-- FROM Logs l1
-- JOIN Logs l2 ON l1.id = l2.id - 1
-- JOIN Logs l3 ON l1.id = l3.id - 2
-- WHERE l1.num = l2.num AND l1.num = l3.num;
--
-- Problem with self-JOIN:
-- Relies on id being consecutive (id, id-1, id-2)
-- If ids have gaps (1, 3, 5) → misses consecutive numbers
-- LAG does not have this problem — it looks at actual
-- adjacent rows regardless of id values.
-- ============================================================

-- ============================================================
-- KEY PATTERN — MEMORIZE THIS:
-- "Find values appearing N times consecutively":
--   1. LAG(col, 1) OVER (ORDER BY sequence_col) → one row back
--      LAG(col, 2) OVER (ORDER BY sequence_col) → two rows back
--   2. WHERE col = lag1 AND col = lag2 → all three match
--   3. SELECT DISTINCT → each qualifying value once only
--
-- Extension — 4 consecutive:
--   Add LAG(col, 3) and include in WHERE condition
-- ============================================================
