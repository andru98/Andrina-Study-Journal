-- ============================================================
-- Problem : Product Price at a Given Date
-- Source  : LeetCode 1164
-- Link    : https://leetcode.com/problems/product-price-at-a-given-date/
-- Topic   : Window Functions / RANK / NOT EXISTS / UNION
-- Level   : Medium
-- Date    : 2026-06-19
-- ============================================================

-- PROBLEM STATEMENT:
-- Table: Products (product_id, new_price, change_date)
-- Each row = a product's price was changed to new_price on change_date.
-- Find the price of all products on 2019-08-16.
-- Assume price before any change is 10 (default).

-- ============================================================
-- APPROACH:
-- Two groups of products exist on 2019-08-16:
--
-- Group 1: Products with at least one price change ON or BEFORE
--          2019-08-16. Price = most recent change before that date.
--          Use RANK() OVER (PARTITION BY product_id ORDER BY
--          change_date DESC) to find latest change per product.
--          WHERE rn = 1 gives the most recent row.
--
-- Group 2: Products with NO price change before 2019-08-16.
--          Price = 10 (default).
--          Use NOT EXISTS to find these products safely.
--          NOT EXISTS preferred over NOT IN — safe with NULLs.
--
-- UNION combines both groups into final result.
--
-- Why RANK() not MAX(change_date) with GROUP BY:
-- MAX() gives the latest date but loses the price on that date.
-- RANK() keeps the full row including new_price.
-- ============================================================

WITH latest_changes AS (
    SELECT
        product_id,
        new_price,
        RANK() OVER (
            PARTITION BY product_id
            ORDER BY change_date DESC
        ) AS rn
    FROM Products
    WHERE change_date <= '2019-08-16'   -- only changes on or before target date
)
-- Group 1: products with changes before target date
SELECT product_id, new_price AS price
FROM latest_changes
WHERE rn = 1

UNION

-- Group 2: products with NO changes before target date → default price 10
SELECT DISTINCT product_id, 10 AS price
FROM Products p1
WHERE NOT EXISTS (
    SELECT 1
    FROM Products p2
    WHERE p2.product_id = p1.product_id
    AND p2.change_date <= '2019-08-16'
)
ORDER BY product_id;

-- ============================================================
-- EXAMPLE WALKTHROUGH:
-- Input:
-- product_id | new_price | change_date
-- 1          | 20        | 2019-08-14
-- 2          | 50        | 2019-08-14
-- 1          | 30        | 2019-08-15
-- 1          | 35        | 2019-08-16
-- 2          | 65        | 2019-08-17  ← after target, excluded
-- 3          | 20        | 2019-08-18  ← after target, excluded
--
-- After CTE (changes on or before Aug 16):
-- product_id | new_price | change_date | rn
-- 1          | 35        | 2019-08-16  | 1  ← most recent ✅
-- 1          | 30        | 2019-08-15  | 2
-- 1          | 20        | 2019-08-14  | 3
-- 2          | 50        | 2019-08-14  | 1  ← most recent ✅
--
-- Group 1 (rn=1): product 1 → 35, product 2 → 50
--
-- Group 2 (NOT EXISTS before Aug 16):
-- product 3 → no changes before Aug 16 → price 10 ✅
--
-- Final output:
-- product_id | price
-- 1          | 35
-- 2          | 50
-- 3          | 10
-- ============================================================

-- ============================================================
-- EDGE CASES TO KEEP IN MIND:
-- 1. Product changed multiple times before target date:
--    RANK() ORDER BY change_date DESC → rn=1 = most recent ✅
--    Correctly picks latest price not first or any random one
--
-- 2. Product changed exactly ON target date:
--    WHERE change_date <= '2019-08-16' includes that day ✅
--    <= not < — price on the target date counts
--
-- 3. Product never changed at all (not just before target date):
--    NOT EXISTS finds it correctly
--    DISTINCT needed — product appears multiple times if it had
--    any changes after the target date
--
-- 4. NOT IN vs NOT EXISTS for Group 2:
--    NOT IN (SELECT product_id ...) → dangerous if NULL product_id
--    NOT EXISTS → safe regardless of NULLs ✅
--    Always prefer NOT EXISTS for anti-join patterns
--
-- 5. Why UNION not UNION ALL:
--    No product can be in both groups simultaneously
--    A product either had a change before Aug 16 or it didn't
--    UNION and UNION ALL give same result here
--    UNION ALL is slightly faster — no deduplication needed
--    Both are correct — UNION ALL preferred for performance
-- ============================================================

-- ============================================================
-- KEY PATTERNS — MEMORIZE THESE:
-- 1. "Latest value per group":
--    RANK() OVER (PARTITION BY id ORDER BY date DESC) WHERE rn=1
--    Never use MAX(date) with GROUP BY — loses the associated value
--
-- 2. "Default value when no history exists":
--    UNION with hardcoded default for NOT EXISTS group
--    SELECT DISTINCT id, 10 AS price WHERE NOT EXISTS (...)
--
-- 3. "Filter before window function":
--    WHERE change_date <= target in CTE
--    Not after — window function must only see relevant rows
--
-- 4. "NOT EXISTS over NOT IN":
--    Always safer — NULL-proof
--    Short-circuits on first match found
-- ============================================================
