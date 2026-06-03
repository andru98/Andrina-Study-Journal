-- ============================================================
-- LC 584: Find Customer Referee
-- Difficulty : Easy
-- Topic      : NULL Handling — three-valued logic in WHERE
--
-- ============================================================
-- Problem:
-- Find the names of customers who are NOT referred by the
-- customer with id = 2.
--
-- Table: Customer
-- | id | name | referee_id |
-- |----|------|------------|
-- | 1  | Will | NULL       |
-- | 2  | Jane | NULL       |
-- | 3  | Alex | 2          |
-- | 4  | Bill | NULL       |
-- | 5  | Zack | 1          |
-- | 6  | Mark | 2          |
--
-- Expected output:
-- | name |
-- |------|
-- | Will |
-- | Jane |
-- | Bill |
-- | Zack |
-- ============================================================


-- ------------------------------------------------------------
-- SOLUTION
-- ------------------------------------------------------------
SELECT name
FROM Customer
WHERE referee_id != 2
   OR referee_id IS NULL;


-- ------------------------------------------------------------
-- WHY THIS WORKS — the NULL trap explained
-- ------------------------------------------------------------

-- Most candidates write this and get it wrong:
SELECT name
FROM Customer
WHERE referee_id != 2;
-- This silently drops all NULL rows.
-- NULL != 2 evaluates to NULL — not TRUE.
-- WHERE only keeps rows where condition = TRUE.
-- So customers with no referee are excluded. Wrong.

-- SQL uses three-valued logic: TRUE, FALSE, NULL
-- Any comparison involving NULL returns NULL, never TRUE or FALSE.
--   NULL != 2  → NULL  → row excluded
--   NULL = 2   → NULL  → row excluded
--   NULL = NULL→ NULL  → row excluded  ← common mistake
--
-- The only way to check for NULL is IS NULL or IS NOT NULL.


-- ------------------------------------------------------------
-- EDGE CASES — mention these in interview
-- ------------------------------------------------------------

-- Edge case 1: referee_id IS NULL (no referee)
-- NULL != 2 → NULL → excluded by WHERE without IS NULL clause.
-- Fix: always add OR referee_id IS NULL for NOT IN / != queries.

-- Edge case 2: customer id=2 themselves
-- Jane has referee_id = NULL → passes IS NULL check → included.
-- Correct — Jane was not referred by customer 2.

-- Edge case 3: all customers referred by id=2
-- Every row has referee_id = 2 → all excluded → empty result.
-- No error — empty result set is valid.

-- Edge case 4: empty table
-- Zero rows → query returns empty result safely.

-- Edge case 5: referee_id references a non-existent customer
-- referee_id = 99 and customer 99 doesn't exist.
-- 99 != 2 → TRUE → row included. Query doesn't validate foreign keys.


-- ------------------------------------------------------------
-- ALTERNATIVE — using NOT IN (and why it breaks with NULLs)
-- ------------------------------------------------------------

-- Tempting but dangerous:
SELECT name
FROM Customer
WHERE referee_id NOT IN (2);
-- Works here only because the list (2) has no NULLs.
-- If the subquery returned NULLs, NOT IN returns no rows at all.

-- Example of NOT IN NULL trap:
SELECT name
FROM Customer
WHERE referee_id NOT IN (SELECT id FROM Customer WHERE id IS NULL);
-- Returns 0 rows — because NOT IN with NULLs in the list = NULL for every row.
-- This is why != with OR IS NULL is safer than NOT IN for nullable columns.


-- ------------------------------------------------------------
-- INTERVIEW TALKING POINTS
-- ------------------------------------------------------------
-- Q: Why not just use WHERE referee_id != 2?
-- A: Because NULL != 2 evaluates to NULL in SQL three-valued logic,
--    not TRUE. WHERE excludes NULLs silently — customers with no
--    referee would be dropped from results. We need OR referee_id
--    IS NULL to explicitly include them.

-- Q: What is three-valued logic in SQL?
-- A: SQL conditions evaluate to TRUE, FALSE, or NULL (unknown).
--    WHERE only keeps rows evaluating to TRUE.
--    Key rules:
--      TRUE  OR  NULL = TRUE   (TRUE dominates OR)
--      FALSE AND NULL = FALSE  (FALSE dominates AND)
--      TRUE  AND NULL = NULL   (still unknown)
--      FALSE OR  NULL = NULL   (still unknown)

-- Q: When would you use COALESCE here?
-- A: Alternative approach:
--    WHERE COALESCE(referee_id, 0) != 2
--    Replaces NULL with 0 before comparison. 0 != 2 = TRUE.
--    Both approaches are valid — OR IS NULL is more explicit.
