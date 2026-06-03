-- Problem: Monthly Transactions I
-- Source: LeetCode
-- Link: https://leetcode.com/problems/monthly-transactions-i/
-- Folder: sql-practice/aggregations/

-- Topic: DATE_FORMAT + COUNT(CASE WHEN) + SUM(CASE WHEN) + GROUP BY
-- Difficulty: Medium

-- Problem Statement:
-- For each month and country, find:
-- total transaction count, approved transaction count,
-- total transaction amount, approved transaction amount.

-- Approach:
-- 1. DATE_FORMAT(trans_date, '%Y-%m') extracts year-month together (e.g. 2018-12).
--    EXTRACT(MONTH FROM date) gives only month number — loses year context.
-- 2. COUNT(*) = all transactions per group regardless of state.
-- 3. COUNT(CASE WHEN state = 'approved' THEN 1 END) = approved count only.
--    No ELSE 0 — COUNT ignores NULL, non-approved rows return NULL automatically.
-- 4. SUM(amount) = total amount for all transactions.
-- 5. SUM(CASE WHEN state = 'approved' THEN amount ELSE 0 END) = approved total.
--    ELSE 0 is correct here — SUM needs 0 for non-matching rows, not NULL.
-- 6. GROUP BY must repeat the DATE_FORMAT expression to match SELECT exactly.

SELECT
    DATE_FORMAT(trans_date, '%Y-%m') AS month,
    country,
    COUNT(*) AS trans_count,
    COUNT(CASE WHEN state = 'approved' THEN 1 END) AS approved_count,
    SUM(amount) AS trans_total_amount,
    SUM(CASE WHEN state = 'approved' THEN amount ELSE 0 END) AS approved_total_amount
FROM Transactions
GROUP BY DATE_FORMAT(trans_date, '%Y-%m'), country;

-- Edge Cases
-- EXTRACT vs DATE_FORMAT        → EXTRACT gives 12, DATE_FORMAT gives 2018-12.
--                                 Always use DATE_FORMAT when year context matters.
-- GROUP BY must match SELECT    → GROUP BY month alias fails in MySQL sometimes,
--                                 repeat the full expression to be safe.
-- SUM CASE WHEN with ELSE 0     → correct for SUM, 0 contributes nothing to total.
-- COUNT CASE WHEN without ELSE  → correct for COUNT, NULL rows auto-excluded.
-- NULL amount                   → SUM ignores NULLs by default, result unaffected.
-- No approved transactions      → approved_count = 0, approved_total_amount = 0 correctly.
-- country = NULL                → NULL forms its own group in GROUP BY — intentional,
--                                 represents transactions with unknown country.
