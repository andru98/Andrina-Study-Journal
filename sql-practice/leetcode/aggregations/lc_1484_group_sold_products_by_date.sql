-- ============================================================
-- Problem : Group Sold Products By The Date
-- Source  : LeetCode 1484
-- Link    : https://leetcode.com/problems/group-sold-products-by-the-date/
-- Topic   : String Functions / GROUP_CONCAT / GROUP BY
-- Level   : Easy
-- Date    : 2026-06-14
-- ============================================================

-- PROBLEM STATEMENT:
-- Table: Activities (sell_date, product)
-- For each date find:
-- 1. Number of distinct products sold
-- 2. Names of products sorted alphabetically and
--    separated by comma (no duplicates)
-- Return ordered by sell_date.

-- ============================================================
-- APPROACH:
-- GROUP BY sell_date to aggregate per date.
-- COUNT(DISTINCT product) to count unique products only —
-- same product can appear multiple times on same date.
-- GROUP_CONCAT(DISTINCT product ORDER BY product ASC SEPARATOR ',')
-- to combine unique product names alphabetically into one string.
--
-- Key decision: COUNT(DISTINCT product) not COUNT(product)
-- COUNT(product) counts all rows including duplicates.
-- COUNT(DISTINCT product) counts unique products only.
-- Problem asks for "number of distinct products" — DISTINCT needed.
-- GROUP_CONCAT also needs DISTINCT to remove duplicate names
-- from the concatenated string.
--
-- Business logic note: if question asked "how many times
-- products were sold" (total transactions) → use COUNT(product)
-- without DISTINCT. Always clarify in interviews which is needed.
-- ============================================================

SELECT
    sell_date,
    COUNT(DISTINCT product)                                        AS num_sold,
    GROUP_CONCAT(DISTINCT product ORDER BY product ASC SEPARATOR ',') AS products
FROM Activities
GROUP BY sell_date
ORDER BY sell_date;

-- ============================================================
-- EXAMPLE WALKTHROUGH:
-- Input:
-- sell_date  | product
-- 2020-05-30 | Headphone
-- 2020-05-30 | Basketball
-- 2020-05-30 | Headphone   ← duplicate
-- 2020-06-01 | Bible
-- 2020-06-02 | Pencil
-- 2020-06-02 | Mask
--
-- After GROUP BY sell_date:
-- 2020-05-30 → products: Headphone, Basketball, Headphone
--   COUNT(DISTINCT product)    → 2  (Basketball, Headphone)
--   GROUP_CONCAT(DISTINCT ...) → 'Basketball,Headphone' (sorted)
--
-- 2020-06-01 → products: Bible
--   COUNT(DISTINCT product)    → 1
--   GROUP_CONCAT(DISTINCT ...) → 'Bible'
--
-- 2020-06-02 → products: Pencil, Mask
--   COUNT(DISTINCT product)    → 2
--   GROUP_CONCAT(DISTINCT ...) → 'Mask,Pencil' (sorted alphabetically)
--
-- Output:
-- sell_date  | num_sold | products
-- 2020-05-30 | 2        | Basketball,Headphone
-- 2020-06-01 | 1        | Bible
-- 2020-06-02 | 2        | Mask,Pencil
-- ============================================================

-- ============================================================
-- EDGE CASES TO KEEP IN MIND:
-- 1. Duplicate products on same date — DISTINCT in both
--    COUNT and GROUP_CONCAT handles this correctly.
--    Without DISTINCT: COUNT = 3 and string = 'Basketball,Headphone,Headphone'
--    With DISTINCT:    COUNT = 2 and string = 'Basketball,Headphone' ✅
-- 2. Single product per date — COUNT = 1, GROUP_CONCAT = just that product.
--    No edge case — works correctly.
-- 3. ORDER BY sell_date at the end ensures dates are returned
--    in chronological order as expected by the problem.
-- 4. SEPARATOR ',' produces no space between products.
--    'Basketball,Headphone' not 'Basketball, Headphone'
--    Match exactly what the expected output shows.
-- ============================================================

-- ============================================================
-- PLATFORM COMPARISON — STRING AGGREGATION:
-- MySQL      → GROUP_CONCAT(col ORDER BY col SEPARATOR ',')
-- PostgreSQL → STRING_AGG(col, ',' ORDER BY col)
-- Snowflake  → LISTAGG(col, ',') WITHIN GROUP (ORDER BY col)
-- BigQuery   → STRING_AGG(col, ',' ORDER BY col)
--
-- GROUP_CONCAT is MySQL specific — LeetCode defaults to MySQL.
-- In interviews always confirm the platform before writing
-- string aggregation functions.
-- ============================================================

-- ============================================================
-- KEY PATTERN — MEMORIZE THIS:
-- "For each group, combine values into one comma-separated string"
-- MySQL:      GROUP_CONCAT(DISTINCT col ORDER BY col SEPARATOR ',')
-- PostgreSQL: STRING_AGG(DISTINCT col, ',' ORDER BY col)
--
-- Always pair with GROUP BY on the grouping column.
-- Always use DISTINCT when duplicates should be excluded.
-- Always use ORDER BY inside the function for consistent output.
-- ============================================================
