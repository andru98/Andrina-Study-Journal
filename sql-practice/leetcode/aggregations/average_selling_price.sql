-- Problem: Average Selling Price
-- Source: LeetCode
-- Link: https://leetcode.com/problems/average-selling-price/

-- Topic: LEFT JOIN + Range JOIN + Weighted Average + IFNULL
-- Difficulty: Easy (but thinks like a Medium)

-- Problem Statement:
-- You have a Prices table that stores the price of each product
-- within a specific date range (start_date to end_date). You also
-- have a UnitsSold table that records how many units of each product
-- were sold on each purchase_date.
-- Find the average selling price for each product.
-- Products with no sales at all should show average_price = 0.
-- Round the result to 2 decimal places.

-- Why this is trickier than it looks:
-- A product can have different prices at different times.
-- Each sale needs to be matched to the price that was active
-- on the day of that sale — not just any price for that product.
-- Also, a product might exist in Prices but have zero sales,
-- and those products still need to appear in the result with 0.

-- Approach:
-- 1. Start from Prices as the left table so every product appears
--    in the result even if it has no sales in UnitsSold.
-- 2. LEFT JOIN UnitsSold using TWO conditions in the ON clause:
--    a. Match on product_id (same product)
--    b. Match purchase_date BETWEEN start_date AND end_date
--       so each sale is matched to its correct price period only.
--    NOTE: The date condition must be in the ON clause, NOT WHERE.
--    Putting it in WHERE would eliminate NULL rows from the LEFT JOIN
--    and turn it into an INNER JOIN — products with no sales disappear.
-- 3. Use weighted average formula: SUM(price * units) / SUM(units)
--    instead of AVG(price). Simple AVG ignores how many units were
--    sold at each price — the volume of sales must weight the average.
-- 4. Wrap the division in IFNULL(..., 0) to handle products with
--    no sales. When UnitsSold is empty or has no match, both
--    SUM(price * units) and SUM(units) return NULL, making the
--    division NULL. IFNULL converts that NULL to 0.
-- 5. GROUP BY product_id to get one average per product.

SELECT
    p.product_id,
    ROUND(
        IFNULL(SUM(p.price * u.units) / SUM(u.units), 0)
    , 2) AS average_price
FROM Prices p
LEFT JOIN UnitsSold u
    ON p.product_id = u.product_id
    AND u.purchase_date BETWEEN p.start_date AND p.end_date
GROUP BY p.product_id;

-- ============================================================
-- WHY WEIGHTED AVERAGE AND NOT AVG(price)
-- ============================================================
-- Simple AVG(price) treats all price periods as equally important.
-- But if a product sold 900 units at $5 and 100 units at $50,
-- the average price the customer actually paid is closer to $5,
-- not the midpoint of $27.50.
--
-- Simple AVG    = (5 + 50) / 2 = 27.50  ← ignores volume, wrong
-- Weighted AVG  = (900×5 + 100×50) / 1000 = 9.50 ← correct
--
-- Weighted average = SUM(price × units) / SUM(units)
-- This is the standard formula used in finance and business
-- reporting whenever you need to account for volume at each price.

-- ============================================================
-- WHY DATE CONDITION MUST BE IN ON CLAUSE NOT WHERE
-- ============================================================
-- ON clause filters BEFORE the join happens.
--   → NULL rows from LEFT JOIN are still preserved after the filter.
--   → Products with no sales keep their NULL row → show as 0.
--
-- WHERE clause filters AFTER the join happens.
--   → NULL rows fail the date comparison (NULL BETWEEN x AND y = NULL)
--   → Those rows get eliminated → products with no sales disappear.
--   → LEFT JOIN behaves exactly like INNER JOIN. Wrong result.

-- ============================================================
-- EDGE CASES
-- ============================================================

-- Edge Case 1: Product exists in Prices but UnitsSold is completely empty
-- LEFT JOIN creates a NULL row on the right side for every product.
-- SUM(price * NULL) = NULL. SUM(NULL) = NULL. NULL/NULL = NULL.
-- IFNULL(NULL, 0) = 0. Final answer = 0.00. Correct. ✅

-- Edge Case 2: Product exists in Prices but has no matching sales
-- in the date range (sales exist for other products, not this one).
-- Same behavior as Edge Case 1 — NULL row preserved, IFNULL gives 0.

-- Edge Case 3: Integer division truncating decimals (MySQL specific)
-- In MySQL, dividing two integers returns an integer by default.
-- SUM(price * units) and SUM(units) are both integers here.
-- MySQL handles this correctly inside ROUND() most of the time,
-- but if you ever see truncation, fix it by forcing float division:
-- IFNULL(SUM(p.price * u.units) * 1.0 / SUM(u.units), 0)

-- Edge Case 4: Same product sold multiple times on the same date
-- UnitsSold can have duplicate rows (table description says so).
-- SUM(units) correctly adds all of them up — no special handling needed.

-- Edge Case 5: purchase_date falls outside all price ranges for a product
-- The date condition in ON fails — no match found for that sale.
-- That sale row does not contribute to the average.
-- In real production this would be a data quality issue worth flagging.
