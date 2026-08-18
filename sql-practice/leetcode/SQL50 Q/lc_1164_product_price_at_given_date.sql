-- ============================================================
-- Problem : Product Price at a Given Date
-- Source  : LeetCode 1164
-- Link    : https://leetcode.com/problems/product-price-at-a-given-date/
-- Topic   : Window Functions / ROW_NUMBER / CTE / LEFT JOIN / COALESCE
-- Level   : Medium
-- Date    : 2026-08-17
-- ============================================================

-- PROBLEM STATEMENT:
-- Table: Products (product_id, new_price, change_date)
-- (product_id, change_date) is the primary key.
-- All products start with price = 10.
-- Find the price of ALL products on 2019-08-16.

-- ============================================================
-- KEY INSIGHT:
-- "Price on 2019-08-16" = most recent price change
-- ON OR BEFORE 2019-08-16 (not exactly on that date)
--
-- Two cases to handle:
-- Case 1: Product has price change on/before Aug 16
--         → use most recent (latest) price ✅
-- Case 2: Product has NO price change before Aug 16
--         → use default price = 10 ✅
--
-- Why <= not =:
-- = Aug 16 → only returns products changed EXACTLY on Aug 16
-- <= Aug 16 → finds most recent price as of Aug 16 ✅
-- Products changed Aug 10, Aug 14 etc would be missed with =
-- ============================================================

-- ============================================================
-- APPROACH 1: ROW_NUMBER() Window Function (RECOMMENDED)
-- Most efficient for large datasets — single table scan
-- No subquery loading all pairs into memory
-- Optimizer can use index on change_date ✅
-- ============================================================

WITH ranked_prices AS (
    SELECT
        product_id,
        new_price,
        ROW_NUMBER() OVER (
            PARTITION BY product_id
            ORDER BY change_date DESC  -- newest first
        ) AS rn
    FROM Products
    WHERE change_date <= '2019-08-16'  -- only consider changes on/before target date
)
SELECT
    p.product_id,
    COALESCE(r.new_price, 10) AS price  -- default 10 if no changes before Aug 16
FROM (SELECT DISTINCT product_id FROM Products) p
LEFT JOIN ranked_prices r
    ON p.product_id = r.product_id
    AND r.rn = 1  -- only keep latest price per product ✅
ORDER BY p.product_id;

-- ============================================================
-- APPROACH 2: Subquery with IN (less efficient for large data)
-- Loads all (product_id, MAX_date) pairs into memory
-- O(N×M) complexity — avoid for large datasets ❌
-- Shown here for comparison only
-- ============================================================

WITH latest_price AS (
    SELECT product_id, new_price AS price
    FROM Products
    WHERE (product_id, change_date) IN (
        SELECT product_id, MAX(change_date)
        FROM Products
        WHERE change_date <= '2019-08-16'
        GROUP BY product_id  -- one row per product ✅
    )
)
SELECT
    p.product_id,
    COALESCE(l.price, 10) AS price
FROM (SELECT DISTINCT product_id FROM Products) p
LEFT JOIN latest_price l ON p.product_id = l.product_id
ORDER BY p.product_id;

-- ============================================================
-- EXAMPLE WALKTHROUGH (ROW_NUMBER approach):
-- Input Products:
-- product_id | new_price | change_date
-- 1          | 20        | 2019-08-14
-- 2          | 50        | 2019-08-14
-- 1          | 30        | 2019-08-15
-- 1          | 35        | 2019-08-16
-- 2          | 65        | 2019-08-17  ← after target date, excluded
-- 3          | 20        | 2019-08-18  ← after target date, excluded
--
-- After WHERE change_date <= '2019-08-16':
-- product_id | new_price | change_date
-- 1          | 20        | 2019-08-14
-- 2          | 50        | 2019-08-14
-- 1          | 30        | 2019-08-15
-- 1          | 35        | 2019-08-16
-- (product 3 has no rows → excluded)
--
-- After ROW_NUMBER() PARTITION BY product_id ORDER BY change_date DESC:
-- product_id | new_price | change_date | rn
-- 1          | 35        | 2019-08-16  | 1  ← latest ✅
-- 1          | 30        | 2019-08-15  | 2
-- 1          | 20        | 2019-08-14  | 3
-- 2          | 50        | 2019-08-14  | 1  ← latest ✅
--
-- WHERE rn = 1:
-- product_id | new_price
-- 1          | 35
-- 2          | 50
--
-- LEFT JOIN all distinct products + COALESCE:
-- product_id | price
-- 1          | 35   ← from ranked_prices ✅
-- 2          | 50   ← from ranked_prices ✅
-- 3          | 10   ← NULL → COALESCE → default 10 ✅
-- ============================================================

-- ============================================================
-- COMMON MISTAKES:
--
-- 1. Using = instead of <=:
--    WHERE change_date = '2019-08-16' ← misses earlier changes ❌
--    WHERE change_date <= '2019-08-16' ← correct ✅
--
-- 2. GROUP BY product_id AND new_price in CTE:
--    GROUP BY product_id, new_price ← multiple rows per product ❌
--    GROUP BY product_id ← one row per product ✅
--
-- 3. Forgetting COALESCE for default price:
--    Products with no changes return NULL from LEFT JOIN
--    COALESCE(price, 10) → default price = 10 ✅
--
-- 4. Using MAX(new_price) instead of latest price:
--    MAX(new_price) → highest price ever ❌
--    ROW_NUMBER() ORDER BY change_date DESC → latest price ✅
--
-- 5. Using INNER JOIN instead of LEFT JOIN:
--    INNER JOIN → excludes products with no price changes ❌
--    LEFT JOIN → keeps all products, NULL for no changes ✅
-- ============================================================

-- ============================================================
-- PERFORMANCE COMPARISON:
--
-- ROW_NUMBER() approach:
-- ✅ Single table scan
-- ✅ Partition + sort → efficient with index on change_date
-- ✅ No subquery materialization
-- ✅ Scales well for millions of rows
-- ✅ Preferred in production
--
-- IN subquery approach:
-- ❌ Loads all (product_id, MAX_date) pairs into memory
-- ❌ Each row checked against in-memory list
-- ❌ O(N×M) complexity for large datasets
-- ✅ Readable and correct for small datasets
-- ❌ Avoid for production large-scale pipelines
-- ============================================================

-- ============================================================
-- EDGE CASES:
--
-- 1. Product with multiple changes before Aug 16:
--    → ROW_NUMBER rn=1 picks the latest ✅
--
-- 2. Product with NO changes before Aug 16:
--    → LEFT JOIN returns NULL
--    → COALESCE returns 10 ✅
--
-- 3. Product with change EXACTLY on Aug 16:
--    → <= includes Aug 16 → included ✅
--
-- 4. Product with only future changes (after Aug 16):
--    → WHERE excludes future changes
--    → LEFT JOIN returns NULL → price = 10 ✅
--
-- 5. All products have same price change date:
--    → ROW_NUMBER correctly partitions by product_id ✅
-- ============================================================

-- ============================================================
-- KEY PATTERN — MEMORIZE THIS:
-- "Find most recent record per group as of a specific date":
--
--   WITH ranked AS (
--       SELECT col1, col2,
--           ROW_NUMBER() OVER (
--               PARTITION BY group_col
--               ORDER BY date_col DESC
--           ) AS rn
--       FROM table
--       WHERE date_col <= target_date
--   )
--   SELECT p.group_col, COALESCE(r.col2, default_val)
--   FROM (SELECT DISTINCT group_col FROM table) p
--   LEFT JOIN ranked r
--       ON p.group_col = r.group_col
--       AND r.rn = 1
--
-- Real DE use cases:
-- → Product price as of date (this problem) ✅
-- → Employee salary as of date
-- → Exchange rate as of date
-- → SCD Type 2 current record lookup
-- → Latest sensor reading per device (Caterpillar IoT) ✅
-- → Most recent booking status per flight (Airline RM) ✅
-- ============================================================
