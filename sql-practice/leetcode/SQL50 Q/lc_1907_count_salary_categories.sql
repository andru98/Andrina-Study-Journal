-- ============================================================
-- Problem : Count Salary Categories
-- Source  : LeetCode 1907
-- Link    : https://leetcode.com/problems/count-salary-categories/
-- Topic   : CASE WHEN / UNION ALL / LEFT JOIN / COUNT
-- Level   : Medium
-- Date    : 2026-08-20
-- ============================================================

-- PROBLEM STATEMENT:
-- Table: Accounts (account_id, income)
-- Calculate number of bank accounts per salary category:
-- "Low Salary"     : income < 20000
-- "Average Salary" : income >= 20000 AND income <= 50000
-- "High Salary"    : income > 50000
-- All three categories must appear even if count = 0

-- ============================================================
-- KEY INSIGHT:
-- Must return ALL three categories even if no accounts exist
-- → cannot GROUP BY category_classify alone ❌
--   (missing categories won't appear)
-- → need reference table with all categories ✅
--   then LEFT JOIN actual data onto it
--
-- Two CTEs:
-- 1. category_left → all three categories (reference table)
-- 2. category_classify → classify each account into category
--
-- LEFT JOIN from category_left:
-- → keeps all 3 categories always ✅
-- → COUNT = 0 for empty categories ✅
--
-- COUNT(cc.account_id) not COUNT(*):
-- → COUNT(*) counts NULL rows → empty category = 1 ❌
-- → COUNT(account_id) skips NULL → empty category = 0 ✅
-- ============================================================

WITH category_left AS (
    -- Reference table: all three categories always present
    SELECT 'Low Salary' AS category
    UNION ALL
    SELECT 'Average Salary'
    UNION ALL
    SELECT 'High Salary'
),
category_classify AS (
    -- Classify each account into salary category
    SELECT
        account_id,
        CASE
            WHEN income < 20000
                THEN 'Low Salary'
            WHEN income >= 20000 AND income <= 50000
                THEN 'Average Salary'
            WHEN income > 50000
                THEN 'High Salary'
        END AS category
    FROM Accounts
)
SELECT
    c.category,
    COUNT(cc.account_id) AS accounts_count
FROM category_left c
LEFT JOIN category_classify cc ON c.category = cc.category
GROUP BY c.category;

-- ============================================================
-- EXAMPLE WALKTHROUGH:
-- Input Accounts:
-- account_id | income
-- 3          | 108939  ← High Salary
-- 2          | 12747   ← Low Salary
-- 8          | 87709   ← High Salary
-- 6          | 91796   ← High Salary
--
-- category_left (reference):
-- category
-- Low Salary
-- Average Salary
-- High Salary
--
-- category_classify:
-- account_id | category
-- 3          | High Salary
-- 2          | Low Salary
-- 8          | High Salary
-- 6          | High Salary
--
-- After LEFT JOIN + GROUP BY:
-- category       | accounts_count
-- Low Salary     | 1  ← account 2 ✅
-- Average Salary | 0  ← no accounts → NULL → COUNT = 0 ✅
-- High Salary    | 3  ← accounts 3,8,6 ✅
-- ============================================================

-- ============================================================
-- COMMON MISTAKES:
--
-- 1. Case sensitivity mismatch:
--    category_left: 'Low Salary' (capital)
--    CASE WHEN: 'low salary' (lowercase) ← JOIN fails ❌
--    Fix: match case exactly in both CTEs ✅
--
-- 2. Using COUNT(*) instead of COUNT(account_id):
--    COUNT(*) → NULL rows counted → empty category = 1 ❌
--    COUNT(cc.account_id) → NULL skipped → empty = 0 ✅
--
-- 3. Starting LEFT JOIN from category_classify:
--    → missing categories not returned ❌
--    → must start from category_left (reference table) ✅
--
-- 4. Wrong CASE WHEN logic:
--    WHEN income < 20000 AND income > 50000 → impossible ❌
--    Correct ranges:
--    < 20000 → Low ✅
--    >= 20000 AND <= 50000 → Average ✅
--    > 50000 → High ✅
--
-- 5. Missing UNION ALL (using UNION):
--    UNION removes duplicates (slower) ❌
--    UNION ALL keeps all rows (faster) ✅
--    For static reference values → always use UNION ALL ✅
-- ============================================================

-- ============================================================
-- EDGE CASES:
--
-- 1. No accounts in a category:
--    → LEFT JOIN returns NULL for account_id
--    → COUNT(cc.account_id) = 0 ✅
--
-- 2. Income exactly at boundary (20000 or 50000):
--    → 20000: >= 20000 → Average Salary ✅
--    → 50000: <= 50000 → Average Salary ✅
--    → inclusive range handled correctly ✅
--
-- 3. All accounts in same category:
--    → other two categories return 0 ✅
--    → reference table ensures they appear ✅
-- ============================================================

-- ============================================================
-- KEY PATTERN — MEMORIZE THIS:
-- "Count per category, ensure all categories appear":
--
--   WITH reference_categories AS (
--       SELECT 'Category A' AS category UNION ALL
--       SELECT 'Category B' UNION ALL
--       SELECT 'Category C'
--   ),
--   classified AS (
--       SELECT id, CASE WHEN ... END AS category
--       FROM table
--   )
--   SELECT r.category, COUNT(c.id) AS count
--   FROM reference_categories r
--   LEFT JOIN classified c ON r.category = c.category
--   GROUP BY r.category
--
-- Real DE use cases:
-- → Salary categories (this problem) ✅
-- → Order status counts (pending/shipped/delivered) ✅
-- → Pipeline health dashboard (success/warning/error) ✅
-- → Equipment status report (Caterpillar IoT) ✅
--   "active/maintenance/offline counts per day"
-- → Booking class distribution (Airline RM) ✅
--   "seats by fare class: Y/B/M/K/Q"
-- ============================================================
