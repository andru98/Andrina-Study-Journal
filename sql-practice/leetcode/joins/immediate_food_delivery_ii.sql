-- Problem: Immediate Food Delivery II
-- Source: LeetCode
-- Link: https://leetcode.com/problems/immediate-food-delivery-ii/
-- Folder: sql-practice/leetcode/joins/

-- Topic: CTE + Subquery JOIN + CASE WHEN + Conditional Aggregation
-- Difficulty: Medium

-- Problem Statement:
-- A delivery order is "immediate" if customer_pref_delivery_date = order_date.
-- Otherwise it is "scheduled".
-- The first order per customer = the row with the earliest order_date.
-- It is guaranteed each customer has exactly one first order.
-- Find the percentage of immediate orders among all customers' first orders,
-- rounded to 2 decimal places.

-- Approach:
-- 1. Find the first order per customer using a subquery with MIN(order_date)
--    grouped by customer_id. This gives one row per customer.
-- 2. JOIN back to the Delivery table to retrieve customer_pref_delivery_date
--    for that specific first order row. Match on both customer_id AND order_date
--    to land on the exact first order row.
-- 3. Wrap in a CTE (first_orders) for readability.
-- 4. In the final SELECT:
--    Numerator   = COUNT(CASE WHEN first_order_date = customer_pref_delivery_date THEN 1 END)
--    Denominator = COUNT(*) — total customers
--    No ELSE needed in COUNT — COUNT ignores NULL automatically.
-- 5. Multiply by 100 and ROUND to 2 decimals.

WITH first_orders AS (
    SELECT
        d.customer_id,
        d.order_date        AS first_order_date,
        d.customer_pref_delivery_date
    FROM Delivery d
    INNER JOIN (
        SELECT customer_id, MIN(order_date) AS first_order_date
        FROM Delivery
        GROUP BY customer_id
    ) first_delivery
        ON d.customer_id = first_delivery.customer_id
        AND d.order_date  = first_delivery.first_order_date
)
SELECT
    ROUND(
        COUNT(CASE WHEN first_order_date = customer_pref_delivery_date THEN 1 END)
        / COUNT(*) * 100
    , 2) AS immediate_percentage
FROM first_orders;

-- ============================================================
-- ALTERNATIVE — Cleaner window function approach
-- ============================================================
-- Instead of JOIN + subquery, use RANK() OVER to rank each
-- customer's orders by date, then filter to rank = 1.
-- Fewer lines, same result, worth knowing for interviews.

-- WITH ranked AS (
--     SELECT
--         customer_id,
--         order_date,
--         customer_pref_delivery_date,
--         RANK() OVER (PARTITION BY customer_id ORDER BY order_date) AS rk
--     FROM Delivery
-- )
-- SELECT
--     ROUND(
--         COUNT(CASE WHEN order_date = customer_pref_delivery_date THEN 1 END)
--         / COUNT(*) * 100
--     , 2) AS immediate_percentage
-- FROM ranked
-- WHERE rk = 1;

-- Edge Cases
-- Guaranteed one first order per customer    → no tie-handling needed per problem statement
--                                              but in real data, ties would cause duplicate
--                                              rows in the JOIN — always clarify this assumption
-- All first orders are immediate             → returns 100.00
-- No immediate first orders                  → COUNT(CASE WHEN) = 0, result = 0.00
-- One customer in table                      → works correctly, percentage = 0 or 100
-- ELSE 0 in COUNT(CASE WHEN)                 → never use it — COUNT counts 0s and inflates numerator
-- GROUP BY customer_id + customer_pref_delivery_date in subquery
--                                            → wrong — one customer can have different pref dates
--                                              across orders, causing duplicate customer rows
--                                              always GROUP BY customer_id only in the MIN subquery
-- Integer division truncation (MySQL)        → COUNT returns integer, dividing two integers
--                                              can truncate. Multiply by 100 first or use * 1.0
--                                              ROUND handles it here but worth knowing
