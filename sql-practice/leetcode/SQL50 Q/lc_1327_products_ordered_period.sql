-- ============================================================
-- Problem : List the Products Ordered in a Period
-- Source  : LeetCode 1327
-- Link    : https://leetcode.com/problems/list-the-products-ordered-in-a-period/
-- Topic   : SUM vs COUNT / Date Filter / GROUP BY / HAVING
-- Level   : Easy
-- Date    : 2026-09-08
-- ============================================================

-- PROBLEM STATEMENT:
-- Table: Products (product_id, product_name, product_category)
-- Table: Orders (product_id, order_date, unit)
-- Find products with at least 100 units ordered in February 2020
-- Return product_name and total units

-- ============================================================
-- KEY INSIGHT:
-- COUNT(unit) = counts number of ROWS ❌
-- SUM(unit)   = adds up unit values ✅
--
-- Product 1 has two February orders: 60 + 70 = 130
-- COUNT → 2 (two rows) ❌ wrong!
-- SUM   → 130 (total units) ✅ correct!
--
-- Date filter: use < '2020-03-01' not <= '2020-02-28'
-- → 2020 is a leap year → February has 29 days!
-- → <= '2020-02-28' misses Feb 29 ❌
-- → < '2020-03-01' catches all February ✅
-- ============================================================

SELECT
    p.product_name,
    SUM(o.unit) AS unit              -- sum units not count rows ✅
FROM Products p
INNER JOIN Orders o ON p.product_id = o.product_id
WHERE o.order_date >= '2020-02-01'
  AND o.order_date <  '2020-03-01'  -- safer than <= '2020-02-28' ✅
GROUP BY p.product_name
HAVING SUM(o.unit) >= 100;          -- filter after aggregation ✅

-- ============================================================
-- EXAMPLE WALKTHROUGH:
-- Product 1 (Leetcode Solutions) February orders:
-- 2020-02-05: 60 units
-- 2020-02-10: 70 units
-- SUM = 130 >= 100 ✅ included
--
-- Product 2 (Jewels of Stringology) February orders:
-- 2020-02-11: 80 units
-- SUM = 80 < 100 ❌ excluded
--
-- Product 3 (HP) February orders:
-- 2020-02-17: 2 units
-- 2020-02-24: 3 units
-- SUM = 5 < 100 ❌ excluded
--
-- Product 4 (Lenovo) - no February orders → excluded ❌
--
-- Product 5 (Leetcode Kit) February orders:
-- 2020-02-25: 50 units
-- 2020-02-27: 50 units
-- SUM = 100 >= 100 ✅ included
-- ============================================================

-- ============================================================
-- COUNT vs SUM — key difference:
--
-- COUNT(col) → counts number of non-NULL rows
-- SUM(col)   → adds up the values in the column
--
-- Example:
-- order rows: unit=60, unit=70
-- COUNT(unit) = 2   ← two rows ❌
-- SUM(unit)   = 130 ← sixty plus seventy ✅
--
-- Use COUNT for: "how many orders?"
-- Use SUM for:   "how many total units?"
-- ============================================================

-- ============================================================
-- DATE FILTER — leap year gotcha:
--
-- 2020 is a leap year → February has 29 days!
--
-- WRONG: o.order_date <= '2020-02-28'
-- → misses February 29, 2020 ❌
--
-- CORRECT: o.order_date < '2020-03-01'
-- → catches all days in February ✅
-- → works for both leap and non-leap years ✅
--
-- Best practice: always use < first_day_of_next_month
-- → January: < '2020-02-01'
-- → February: < '2020-03-01'
-- → December: < '2021-01-01'
-- ============================================================

-- ============================================================
-- COMMON MISTAKES:
--
-- 1. COUNT instead of SUM:
--    HAVING COUNT(unit) >= 100 ← counts rows not units ❌
--    Fix: HAVING SUM(unit) >= 100 ✅
--
-- 2. Wrong date filter for February:
--    <= '2020-02-28' ← misses leap day ❌
--    Fix: < '2020-03-01' ✅
--
-- 3. WHERE instead of HAVING for aggregation:
--    WHERE SUM(unit) >= 100 ← can't use aggregate in WHERE ❌
--    Fix: HAVING SUM(unit) >= 100 ✅
--
-- 4. Missing date filter:
--    → includes orders from all months ❌
--    Fix: always filter date before aggregating ✅
-- ============================================================

-- ============================================================
-- KEY PATTERN — MEMORIZE THIS:
-- "Sum values per group with minimum threshold":
--
--   SELECT dim_col, SUM(measure_col) AS total
--   FROM fact_table
--   JOIN dim_table ON ...
--   WHERE date_col >= 'start' AND date_col < 'next_month'
--   GROUP BY dim_col
--   HAVING SUM(measure_col) >= threshold;
--
-- Real DE use cases:
-- → Products with 100+ units in period (this problem) ✅
-- → Routes with 1000+ bookings in month ✅
-- → Artists with 10000+ streams in week ✅
-- → Equipment with 100+ hours usage in quarter ✅
-- → Fare classes with $1M+ revenue in month ✅
-- ============================================================
