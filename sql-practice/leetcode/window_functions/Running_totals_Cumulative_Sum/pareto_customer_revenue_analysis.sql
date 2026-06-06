-- Problem: Customer Revenue Pareto Analysis
-- Source: Interview Pattern / Custom
-- Folder: sql-practice/leetcode/window_functions/

-- Topic: Multiple Window Functions + SUM OVER () + ROW_NUMBER + Cumulative Percentage
-- Difficulty: Hard

-- Problem Statement:
-- Given an orders table with customer_id and amount, find for each customer:
-- 1. Their total spend ranked from highest to lowest
-- 2. What customer percentile they fall in (top 25%, top 50% etc.)
-- 3. What percentage of total revenue is accumulated up to that customer
-- This is the classic Pareto analysis — "top 20% of customers generate 80% of revenue"

-- Approach:
-- 1. CTE customer_revenue: aggregate total spend per customer using SUM + GROUP BY.
--    One row per customer.
-- 2. CTE ranked: run four window functions on the aggregated result:
--    a. ROW_NUMBER() ORDER BY total_spend DESC → rank by highest spender
--    b. SUM(total_spend) OVER (ORDER BY total_spend DESC ROWS UNBOUNDED PRECEDING AND CURRENT ROW)
--       → running total of revenue as you go down the ranked list
--    c. SUM(total_spend) OVER () → grand total, same number on every row
--       Empty OVER() = entire table as one window, no partitioning
--    d. COUNT(*) OVER () → total customer count, same on every row
-- 3. Final SELECT derives two business metrics:
--    customer_percentile = rank / total_customers * 100
--    revenue_pct_cumulative = cumulative_revenue / grand_total * 100
--    Multiply by 100.0 (not 100) to force float division — avoids integer truncation

WITH customer_revenue AS (
    SELECT
        customer_id,
        SUM(amount) AS total_spend
    FROM orders
    GROUP BY customer_id
),
ranked AS (
    SELECT
        customer_id,
        total_spend,
        ROW_NUMBER() OVER (ORDER BY total_spend DESC) AS rank,
        SUM(total_spend) OVER (
            ORDER BY total_spend DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_revenue,
        SUM(total_spend) OVER ()    AS grand_total,
        COUNT(*) OVER ()            AS total_customers
    FROM customer_revenue
)
SELECT
    customer_id,
    total_spend,
    rank,
    ROUND(100.0 * rank / total_customers, 2)           AS customer_percentile,
    ROUND(100.0 * cumulative_revenue / grand_total, 2) AS revenue_pct_cumulative
FROM ranked
ORDER BY rank;

-- ============================================================
-- WHAT THE OUTPUT LOOKS LIKE
-- ============================================================
-- customer_id | total_spend | rank | customer_percentile | revenue_pct_cumulative
-- 1           | 5000        | 1    | 25.00               | 52.63
-- 2           | 3000        | 2    | 50.00               | 84.21
-- 3           | 1000        | 3    | 75.00               | 94.74
-- 4           | 500         | 4    | 100.00              | 100.00
--
-- Reading row 2: top 50% of customers generated 84.21% of revenue
-- Classic Pareto — small group of customers drives most revenue

-- ============================================================
-- KEY CONCEPT — SUM() OVER () WITH EMPTY PARENTHESES
-- ============================================================
-- SUM(total_spend) OVER () — no ORDER BY, no PARTITION BY
-- Treats the entire result set as one window
-- Returns the same grand total on every single row
-- This is how you get a denominator without a subquery or JOIN
-- Same pattern works for COUNT(*) OVER () for total row count

-- ============================================================
-- WHY 100.0 NOT 100
-- ============================================================
-- In SQL: 1 / 4 = 0 (integer division, truncates)
--         1 / 4.0 = 0.25 (float division, correct)
-- Multiplying by 100.0 forces the entire expression to float
-- Always use 100.0 when calculating percentages to avoid silent truncation

-- ============================================================
-- INTERVIEW FOLLOW-UP — how to find customers above 80% revenue threshold
-- ============================================================
-- Wrap the final SELECT in another CTE and filter:
-- WHERE revenue_pct_cumulative <= 80
-- This gives you the exact customers who together make up the top 80% of revenue

-- Edge Cases
-- Two customers same total_spend    → ROW_NUMBER gives different ranks (no ties)
--                                     use DENSE_RANK if you want tied customers
--                                     to share the same percentile
-- One customer only                  → rank = 1, percentile = 100, revenue = 100%
-- NULL amount in orders              → SUM ignores NULL — COALESCE(amount, 0) if needed
-- Customer with zero total spend     → appears at bottom of ranking correctly
-- Integer division truncation        → always multiply by 100.0 not 100
