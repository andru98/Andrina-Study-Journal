-- Problem: Cumulative Purchases by Product Type
-- Source: DataLemur (Amazon Interview Question)
-- Link: https://datalemur.com/questions/amazon-cumulative-purchases

-- Topic: Window Functions (SUM OVER)
-- Difficulty: Medium

-- Problem Statement:
-- Given a table of Amazon customer transactions, write a query to get
-- the cumulative number of products purchased for each product type,
-- ordered by order date. The output should include order_date,
-- product_type, and cumulative_purchases.

-- Approach:
-- 1. Use SUM() as a window function (not aggregate) to keep all rows visible.
-- 2. PARTITION BY product_type so the running total resets per product type.
-- 3. ORDER BY order_date ASC inside OVER so the sum accumulates chronologically.
-- 4. No GROUP BY needed — window function does not collapse rows.
-- 5. Final ORDER BY order_date to present results chronologically.

SELECT
    order_date,
    product_type,
    SUM(quantity) OVER (
        PARTITION BY product_type
        ORDER BY order_date ASC
    ) AS cumulative_purchases
FROM total_trans
ORDER BY order_date ASC;

-- ============================================================
-- EDGE CASES
-- ============================================================

-- Edge Case 1: Same product type, same order_date (tie dates)
-- If two rows share the same product_type AND order_date,
-- SUM() OVER with ORDER BY date includes BOTH rows in the
-- cumulative total for that date (default frame = RANGE).
-- This means both rows show the same cumulative value —
-- which is actually CORRECT behavior (both happened "that day").
-- But if you want row-by-row strict accumulation (each row
-- gets a different cumulative), use ROWS instead of RANGE:
--
-- SUM(quantity) OVER (
--     PARTITION BY product_type
--     ORDER BY order_date ASC
--     ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
-- )
--
-- Clarify with interviewer: "Should same-date rows show the
-- same cumulative total or different?" Part 1 — Tiebreaker Fix adding a tiebreaker to ORDER BY is the cleanest fix.
--SUM(quantity) OVER (
   -- PARTITION BY product_type
   -- ORDER BY order_date ASC, order_id ASC  -- order_id as tiebreaker
)
--Now even if two rows share the same date, order_id breaks the tie — every row has a unique position. SQL processes them strictly one by one.

-- Edge Case 2: NULL quantity values
-- If quantity is NULL for a row, SUM() ignores NULLs by default.
-- The cumulative total simply skips that row's contribution.
-- Fix if needed: COALESCE(quantity, 0) to treat NULL as 0.
--
-- SUM(COALESCE(quantity, 0)) OVER (
--     PARTITION BY product_type
--     ORDER BY order_date ASC
-- )

-- Edge Case 3: NULL order_date
-- If order_date is NULL, ORDER BY places NULLs last (most databases).
-- Those rows get the final cumulative total, which may be misleading.
-- Fix: filter out NULL dates early.
--
-- WHERE order_date IS NOT NULL

-- Edge Case 4: Only one row for a product type
-- Works perfectly. The cumulative total = that row's quantity.
-- No special handling needed.

-- Edge Case 5: Negative quantities (returns/refunds)
-- SUM() will subtract correctly — cumulative total can go down.
-- This is usually correct behavior for returns data.
-- Clarify with interviewer if returns should be excluded.