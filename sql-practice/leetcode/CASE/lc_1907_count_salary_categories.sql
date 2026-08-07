-- ============================================================
-- Problem : Count Salary Categories
-- Source  : LeetCode 1907
-- Link    : https://leetcode.com/problems/count-salary-categories/
-- Topic   : CASE WHEN / CTE / LEFT JOIN / Zero Count Handling
-- Level   : Medium
-- Date    : 2026-06-29
-- ============================================================

-- PROBLEM STATEMENT:
-- Table: Accounts (account_id, income)
-- Categorize accounts into three salary categories:
--   'Low Salary'     → income < 20000
--   'Average Salary' → 20000 <= income <= 50000
--   'High Salary'    → income > 50000
-- Return count per category.
-- CRITICAL: Return ALL three categories even if count = 0.

-- ============================================================
-- APPROACH:
-- Step 1 — Create a reference table with all three categories
--          using UNION ALL. This guarantees all categories
--          appear in output even with zero accounts.
--
-- Step 2 — Categorize each account using CASE WHEN in a
--          second CTE. Maps income ranges to category names.
--
-- Step 3 — LEFT JOIN categories to categorized accounts.
--          LEFT JOIN keeps all categories including those
--          with no matching accounts (zero count).
--
-- Step 4 — COUNT(a.account_id) returns 0 for categories
--          with no accounts because COUNT ignores NULL
--          automatically — no COALESCE needed.
--
-- Key decision: reference table + LEFT JOIN pattern
-- Simple GROUP BY on categorized data would miss categories
-- with zero accounts — they simply would not appear in output.
-- Reference table ensures all three always appear.
-- ============================================================

WITH categories AS (
    -- Step 1: reference table — guarantees all categories present
    SELECT 'Low Salary'     AS category
    UNION ALL
    SELECT 'Average Salary' AS category
    UNION ALL
    SELECT 'High Salary'    AS category
),
categorized AS (
    -- Step 2: assign each account to a category
    SELECT
        account_id,
        CASE
            WHEN income < 20000                 THEN 'Low Salary'
            WHEN income BETWEEN 20000 AND 50000 THEN 'Average Salary'
            WHEN income > 50000                 THEN 'High Salary'
        END AS category
    FROM Accounts
)
-- Step 3 & 4: LEFT JOIN to preserve zero-count categories
SELECT
    c.category,
    COUNT(a.account_id) AS accounts_count
FROM categories c
LEFT JOIN categorized a ON c.category = a.category
GROUP BY c.category
ORDER BY c.category;

-- ============================================================
-- EXAMPLE WALKTHROUGH:
-- Input:
-- account_id | income
-- 3          | 108939  ← High Salary
-- 2          | 12747   ← Low Salary
-- 8          | 87709   ← High Salary
-- 6          | 91796   ← High Salary
--
-- After categories CTE:
-- category
-- Low Salary
-- Average Salary
-- High Salary
--
-- After categorized CTE:
-- account_id | category
-- 3          | High Salary
-- 2          | Low Salary
-- 8          | High Salary
-- 6          | High Salary
--
-- After LEFT JOIN:
-- category       | account_id
-- Low Salary     | 2          ← matched
-- Average Salary | NULL       ← no match → COUNT = 0
-- High Salary    | 3, 8, 6    ← matched
--
-- After COUNT + GROUP BY:
-- category       | accounts_count
-- Average Salary | 0  ✅ preserved despite zero accounts
-- High Salary    | 3
-- Low Salary     | 1
-- ============================================================

-- ============================================================
-- EDGE CASES TO KEEP IN MIND:
-- 1. Zero count categories MUST appear — most common mistake
--    Simple GROUP BY on categorized data silently drops them
--    Reference table + LEFT JOIN is the correct pattern
--
-- 2. COUNT(a.account_id) not COUNT(*):
--    COUNT(*) would return 1 for NULL rows ← wrong
--    COUNT(a.account_id) ignores NULL → returns 0 ✅
--
-- 3. BETWEEN is inclusive on both ends:
--    BETWEEN 20000 AND 50000 = income >= 20000 AND income <= 50000
--    income = 20000 → Average Salary ✅
--    income = 50000 → Average Salary ✅
--
-- 4. CASE WHEN order matters — exhaustive coverage:
--    income < 20000  → Low Salary
--    20000-50000     → Average Salary
--    income > 50000  → High Salary
--    No overlap, no gap — every income covered exactly once
--
-- 5. NULL income values:
--    If income is NULL → no CASE WHEN matches → category = NULL
--    NULL category → does not join to any reference category
--    COUNT = 0 for that account → excluded from all categories
--    Add explicit NULL handling if business requires it
-- ============================================================

-- ============================================================
-- ALTERNATIVE — UNION ALL approach (no CTEs needed):
-- Less readable but also valid
-- ============================================================

SELECT 'Low Salary' AS category,
       COUNT(*) AS accounts_count
FROM Accounts WHERE income < 20000

UNION ALL

SELECT 'Average Salary',
       COUNT(*)
FROM Accounts WHERE income BETWEEN 20000 AND 50000

UNION ALL

SELECT 'High Salary',
       COUNT(*)
FROM Accounts WHERE income > 50000

ORDER BY category;

-- Note: This approach reads Accounts table 3 times
-- CTE approach reads it once — more efficient at scale
-- Both return correct results including zero counts ✅

-- ============================================================
-- KEY PATTERN — MEMORIZE THIS:
-- "Return all categories even with zero counts":
--
--   WITH reference_table AS (
--       SELECT 'Category A' AS category
--       UNION ALL SELECT 'Category B'
--       UNION ALL SELECT 'Category C'
--   ),
--   categorized AS (
--       SELECT id, CASE ... END AS category
--       FROM source_table
--   )
--   SELECT r.category, COUNT(c.id) AS count
--   FROM reference_table r
--   LEFT JOIN categorized c ON r.category = c.category
--   GROUP BY r.category;
--
-- This pattern appears in:
-- → Salary band analysis
-- → Order status reporting
-- → Age group demographics
-- → Any report requiring all categories regardless of data
-- ============================================================
