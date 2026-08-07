-- ============================================================
-- Problem : Product Sales Analysis III
-- Source  : LeetCode 1070
-- Link    : https://leetcode.com/problems/product-sales-analysis-iii/
-- Topic   : CTE / MIN / GROUP BY / JOIN
-- Level   : Medium
-- Date    : 2026-08-05
-- ============================================================

-- PROBLEM STATEMENT:
-- Table: Sales (sale_id, product_id, year, quantity, price)
-- (sale_id, year) is the primary key.
-- Find all sales that occurred in the FIRST year each product was sold.
-- Return: product_id, first_year, quantity, price.

-- ============================================================
-- APPROACH 1: CTE + JOIN (recommended — most readable)
-- Step 1: Find the earliest year per product using MIN(year).
-- Step 2: Join back to Sales on BOTH product_id AND year
--         to retrieve only rows from that first year.
--
-- Key insight: JOIN must include both product_id AND year conditions.
-- Joining on product_id alone returns ALL years for each product —
-- the year condition filters to first-year rows only.
--
-- Why CTE not subquery:
-- CTE is more readable and reusable. Both approaches are
-- equivalent in performance for this problem.
-- ============================================================

WITH first_year_per_product AS (
    SELECT
        product_id,
        MIN(year) AS first_year
    FROM Sales
    GROUP BY product_id
)
SELECT
    f.product_id,
    f.first_year,
    s.quantity,
    s.price
FROM first_year_per_product f
INNER JOIN Sales s
    ON f.product_id = s.product_id
    AND s.year = f.first_year  -- ← critical: filter to first year only
ORDER BY f.product_id;

-- ============================================================
-- APPROACH 2: Subquery (more compact, equally correct)
-- ============================================================

SELECT
    product_id,
    year AS first_year,
    quantity,
    price
FROM Sales
WHERE (product_id, year) IN (
    SELECT product_id, MIN(year)
    FROM Sales
    GROUP BY product_id
);

-- ============================================================
-- EXAMPLE WALKTHROUGH:
-- Input Sales:
-- sale_id | product_id | year | quantity | price
-- 1       | 100        | 2008 | 10       | 5000
-- 2       | 100        | 2009 | 12       | 5000
-- 7       | 200        | 2011 | 15       | 9000
--
-- Step 1 — CTE (first_year_per_product):
-- product_id | first_year
-- 100        | 2008       ← MIN(2008, 2009) = 2008
-- 200        | 2011       ← only one year
--
-- Step 2 — JOIN on product_id AND year:
-- Product 100: matches sale_id=1 (year=2008) ✅
--              does NOT match sale_id=2 (year=2009 ≠ 2008) ✅
-- Product 200: matches sale_id=7 (year=2011) ✅
--
-- Output:
-- product_id | first_year | quantity | price
-- 100        | 2008       | 10       | 5000
-- 200        | 2011       | 15       | 9000
-- ============================================================

-- ============================================================
-- COMMON MISTAKE — joining on product_id only:
--
-- WRONG:
-- FROM first_year_per_product f
-- INNER JOIN Sales s ON f.product_id = s.product_id
-- → returns ALL years for each product
-- → product 100 returns both 2008 AND 2009 rows ❌
-- → first_year column always shows 2008 (from CTE)
--   but quantity=12 sneaks in from 2009 row
--
-- FIX: always join on BOTH product_id AND year ✅
-- ============================================================

-- ============================================================
-- EDGE CASES:
--
-- 1. Product sold only once:
--    → MIN(year) = that one year
--    → JOIN returns that single row ✅
--
-- 2. Multiple sales SAME product SAME first year:
--    Input:
--    product_id=100, year=2008, quantity=10, price=5000 (sale_id=1)
--    product_id=100, year=2008, quantity=20, price=4000 (sale_id=3)
--    → BOTH rows returned (same first year, different sales) ✅
--    → (sale_id, year) is primary key so both are valid rows
--
-- 3. Product with many years:
--    product_id=300, years: 2005, 2008, 2010, 2015
--    → first_year = 2005
--    → only 2005 rows returned ✅
--    → 2008, 2010, 2015 rows excluded ✅
--
-- 4. NULL year values:
--    → MIN() ignores NULLs automatically
--    → rows with NULL year excluded from results
--    → safe without extra handling ✅
--
-- 5. DISTINCT not needed in CTE:
--    → GROUP BY already returns one row per product_id
--    → DISTINCT is redundant and adds overhead ❌
-- ============================================================

-- ============================================================
-- KEY PATTERN — MEMORIZE THIS:
-- "Find rows matching the minimum/maximum value per group":
--
-- Pattern 1 (CTE + JOIN):
--   WITH extremes AS (
--       SELECT group_col, MIN/MAX(value_col) AS extreme_val
--       FROM table
--       GROUP BY group_col
--   )
--   SELECT t.*
--   FROM extremes e
--   JOIN table t
--       ON e.group_col = t.group_col
--       AND t.value_col = e.extreme_val  -- ← both conditions!
--
-- Pattern 2 (tuple subquery — MySQL/PostgreSQL):
--   WHERE (group_col, value_col) IN (
--       SELECT group_col, MIN/MAX(value_col)
--       FROM table
--       GROUP BY group_col
--   )
--
-- Real DE use cases:
-- → First purchase per customer
-- → Latest record per device (IoT telemetry)
-- → First login per user per day
-- → Earliest event per session
-- ============================================================
