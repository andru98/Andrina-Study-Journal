-- Problem: Customer First $1000 Spend Milestone
-- Source: Interview Pattern / Custom
-- Folder: sql-practice/leetcode/window_functions/

-- Topic: Running Total + Filter After Window + ROW_NUMBER for First Occurrence
-- Difficulty: Medium

-- Problem Statement:
-- Given an orders table with customer_id, order_date, and amount,
-- find the exact date each customer first crossed $1000 in lifetime spend.
-- Return the customer_id, the date they hit the milestone, and their
-- cumulative spend at that point.

-- Approach:
-- 1. CTE cumulative: calculate running total of spend per customer ordered by date.
--    PARTITION BY customer_id resets the running total per customer.
--    ORDER BY order_date accumulates chronologically.
--    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW = strict row-by-row accumulation.
-- 2. CTE milestones: filter cumulative to rows where lifetime_spend >= 1000.
--    This keeps every order AFTER the customer crossed $1000 — multiple rows per customer.
--    Apply ROW_NUMBER() PARTITION BY customer_id ORDER BY order_date to rank those rows.
--    The first crossing gets rn = 1.
--    NOTE: filter WHERE lifetime_spend >= 1000 CANNOT go in CTE 1.
--    Window function results are not available in WHERE of the same query.
--    Must calculate first in CTE 1, then filter in CTE 2.
-- 3. Final SELECT: WHERE rn = 1 keeps only the first milestone row per customer.

WITH cumulative AS (
    SELECT
        customer_id,
        order_date,
        amount,
        SUM(amount) OVER (
            PARTITION BY customer_id
            ORDER BY order_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS lifetime_spend
    FROM orders
),
milestones AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY order_date
        ) AS rn
    FROM cumulative
    WHERE lifetime_spend >= 1000
)
SELECT
    customer_id,
    order_date AS milestone_date,
    lifetime_spend
FROM milestones
WHERE rn = 1;

-- ============================================================
-- WHAT THE OUTPUT LOOKS LIKE
-- ============================================================
-- Sample data for customer 1:
-- order_date | amount | lifetime_spend
-- 2024-01-01 | 400    | 400            ← below 1000
-- 2024-01-15 | 350    | 750            ← below 1000
-- 2024-02-01 | 300    | 1050           ← CROSSED 1000 ← milestone_date
-- 2024-03-01 | 200    | 1250           ← above 1000 but not first crossing
--
-- Final output:
-- customer_id | milestone_date | lifetime_spend
-- 1           | 2024-02-01     | 1050
-- 2           | 2024-02-10     | 1100

-- ============================================================
-- WHY THE FILTER CANNOT GO IN CTE 1
-- ============================================================
-- SQL execution order: FROM → WHERE → SELECT (window functions run here)
-- WHERE runs BEFORE window functions in SELECT.
-- lifetime_spend is a window function result — it does not exist at WHERE stage.
-- Putting WHERE lifetime_spend >= 1000 in CTE 1 throws an error.
-- Rule: always calculate window function first in one CTE,
--       then filter the result in the next CTE or outer query.

-- ============================================================
-- THE REUSABLE PATTERN — first time X happened
-- ============================================================
-- Step 1: Calculate running metric (running total, running count, etc.)
-- Step 2: Filter to rows where the threshold is met (>= 1000, >= 5 orders, etc.)
-- Step 3: ROW_NUMBER() PARTITION BY entity ORDER BY date
-- Step 4: WHERE rn = 1 → first occurrence only
-- Works for: first purchase, first login, first complaint, first milestone

-- Edge Cases
-- Customer never reaches $1000        → filtered out entirely — does not appear in result
--                                       use LEFT JOIN on milestone CTE if you need all customers
-- Single order crosses $1000          → milestone_date = that order date, lifetime_spend = amount
-- Two orders same date cross $1000    → ROW_NUMBER picks one arbitrarily
--                                       add secondary tiebreaker (order_id) for determinism
-- NULL amount in orders               → SUM ignores NULL — running total skips that order
--                                       use COALESCE(amount, 0) if NULL should count as zero
-- Filter in CTE 1 instead of CTE 2   → error — window function alias not available in WHERE
--                                       always filter AFTER calculating the running total
