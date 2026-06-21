-- ============================================================
-- Problem : Market Analysis I
-- Source  : LeetCode 1158
-- Link    : https://leetcode.com/problems/market-analysis-i/
-- Topic   : LEFT JOIN / Filter in JOIN vs WHERE / COUNT / COALESCE
-- Level   : Medium
-- Date    : 2026-06-19
-- ============================================================

-- PROBLEM STATEMENT:
-- Table: Users (user_id, join_date, favorite_brand)
-- Table: Orders (order_id, order_date, item_id, buyer_id, seller_id)
-- Table: Items (item_id, item_brand)
-- Find for each user their join date and number of orders in 2019.
-- Return ALL users even if they made no orders in 2019.

-- ============================================================
-- APPROACH:
-- LEFT JOIN keeps all users including those with no 2019 orders.
-- The year filter MUST go in the JOIN condition not in WHERE.
-- Putting YEAR filter in WHERE converts LEFT JOIN to INNER JOIN
-- because WHERE filters out NULL rows (users with no orders).
--
-- Key rule:
-- Filter on RIGHT table column → put in JOIN condition
-- Filter on LEFT table column  → put in WHERE clause
--
-- COUNT(o.order_id) returns 0 for users with no orders
-- because COUNT ignores NULLs automatically.
-- No COALESCE needed for COUNT — it handles NULLs correctly.
-- ============================================================

SELECT
    u.user_id   AS buyer_id,
    u.join_date,
    COUNT(o.order_id) AS orders_in_2019
FROM Users u
LEFT JOIN Orders o
    ON u.user_id = o.buyer_id
    AND YEAR(o.order_date) = 2019      -- ← filter in JOIN not WHERE
GROUP BY u.user_id, u.join_date
ORDER BY u.user_id;

-- ============================================================
-- EXAMPLE WALKTHROUGH:
-- Users:                    Orders:
-- user_id | join_date       order_id | buyer_id | order_date
-- 1       | 2018-01-01      1        | 1        | 2019-08-01
-- 2       | 2018-02-09      2        | 2        | 2019-08-02
-- 3       | 2018-01-19      3        | 2        | 2019-08-03
-- 4       | 2018-05-21      4        | 1        | 2020-01-01 ← 2020
--
-- After LEFT JOIN with AND YEAR = 2019:
-- user 1 → matched order 1 (2019) ✅, order 4 excluded (2020)
-- user 2 → matched orders 2,3 (2019) ✅
-- user 3 → no match → NULL row kept ✅
-- user 4 → no match → NULL row kept ✅
--
-- After COUNT(order_id):
-- user 1 → 1 order
-- user 2 → 2 orders
-- user 3 → 0 (COUNT ignores NULL)
-- user 4 → 0 (COUNT ignores NULL)
--
-- Output:
-- buyer_id | join_date  | orders_in_2019
-- 1        | 2018-01-01 | 1
-- 2        | 2018-02-09 | 2
-- 3        | 2018-01-19 | 0
-- 4        | 2018-05-21 | 0
-- ============================================================

-- ============================================================
-- EDGE CASES TO KEEP IN MIND:
-- 1. Year filter in WHERE instead of JOIN — most common mistake:
--    LEFT JOIN orders o ON u.user_id = o.buyer_id
--    WHERE YEAR(o.order_date) = 2019  ← WRONG
--    Users with no orders have NULL order_date
--    NULL = 2019 → UNKNOWN → row excluded
--    LEFT JOIN becomes INNER JOIN silently
--    Fix: move filter to JOIN condition with AND
--
-- 2. GROUP BY on nullable column:
--    GROUP BY o.buyer_id  ← WRONG — NULL for users with no orders
--    GROUP BY u.user_id   ← CORRECT — always has a value
--
-- 3. COUNT(*) vs COUNT(o.order_id):
--    COUNT(*) counts all rows including NULL rows → returns 1 not 0
--    COUNT(o.order_id) ignores NULLs → returns 0 correctly ✅
--    Always COUNT the right table's column not *
--
-- 4. User with orders only in 2020:
--    AND YEAR = 2019 in JOIN excludes 2020 orders
--    User appears with NULL → COUNT = 0 ✅
--    Correctly shows 0 orders in 2019
-- ============================================================

-- ============================================================
-- KEY PATTERN — MEMORIZE THIS:
-- "Return all rows from left table with conditional count
--  from right table":
--
--   FROM left_table l
--   LEFT JOIN right_table r
--       ON l.id = r.foreign_key
--       AND [condition on right table]   ← filter HERE not WHERE
--   GROUP BY l.id, l.other_cols         ← GROUP BY left table cols
--   SELECT l.id, COUNT(r.id) AS count   ← COUNT right table PK
--
-- Golden rule:
--   RIGHT table filter → JOIN condition (preserves NULLs)
--   LEFT table filter  → WHERE clause (safe to filter)
-- ============================================================
