-- Problem: User's Third Transaction
-- Source: DataLemur
-- Link: https://datalemur.com/questions/third-transaction

-- Topic: Window Functions (ROW_NUMBER)
-- Difficulty: Medium
-- Company: Uber

-- Approach:
-- 1. Use ROW_NUMBER() partitioned by user_id ordered by transaction_date
--    to rank each user's transactions chronologically.
-- 2. Wrap in a CTE to reference the row number in WHERE clause.
-- 3. Filter where row_num = 3 to get only the third transaction.
-- 4. Users with fewer than 3 transactions are automatically excluded.

WITH ranked AS (
    SELECT
        user_id,
        spend,
        transaction_date,
        ROW_NUMBER() OVER (
            PARTITION BY user_id
            ORDER BY transaction_date
        ) AS row_num
    FROM transactions
)
SELECT
    user_id,
    spend,
    transaction_date
FROM ranked
WHERE row_num = 3;

--Edge Cases
-- =====================================================
-- EDGE CASES: User's Third Transaction
-- =====================================================

-- EDGE CASE 1: Tie in transaction_date (same date, two transactions)
-- ROW_NUMBER() breaks ties arbitrarily → non-deterministic!
-- Fix: add a tiebreaker column in ORDER BY

ROW_NUMBER() OVER (
    PARTITION BY user_id
    ORDER BY transaction_date, transaction_id  -- tiebreaker
)

-- =====================================================

-- EDGE CASE 2: User has fewer than 3 transactions
-- WHERE row_num = 3 automatically excludes them
-- No extra filter needed — but always mention this in interviews!

-- =====================================================

-- EDGE CASE 3: ROW_NUMBER vs RANK vs DENSE_RANK
-- ROW_NUMBER()  → 1, 2, 3, 4       always unique, no gaps
-- RANK()        → 1, 1, 3           skips after tie
-- DENSE_RANK()  → 1, 1, 2           no gaps after tie
-- For Nth row problems → always ROW_NUMBER ✅

-- =====================================================

-- EDGE CASE 4: Why not use WHERE directly on window function?
-- Window functions are calculated AFTER WHERE clause
-- So this FAILS:

SELECT *,
    ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY transaction_date) AS row_num
FROM transactions
WHERE row_num = 3  -- ❌ ERROR: column row_num does not exist

-- Fix: always wrap in CTE or subquery first ✅

-- =====================================================

-- EDGE CASE 5: CTE vs Subquery — both work, CTE preferred
-- Subquery version:
SELECT user_id, spend, transaction_date
FROM (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY user_id
            ORDER BY transaction_date
        ) AS row_num
    FROM transactions
) ranked
WHERE row_num = 3;

-- CTE preferred because:
-- more readable ✅
-- easier to debug ✅
-- reusable if needed ✅