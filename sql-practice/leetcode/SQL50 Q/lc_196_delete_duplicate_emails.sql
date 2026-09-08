-- ============================================================
-- Problem : Delete Duplicate Emails
-- Source  : LeetCode 196
-- Link    : https://leetcode.com/problems/delete-duplicate-emails/
-- Topic   : DELETE / Subquery / MIN / Self Join
-- Level   : Easy
-- Date    : 2026-09-02
-- ============================================================

-- PROBLEM STATEMENT:
-- Table: Person (id, email)
-- Delete duplicate emails keeping row with smallest id
-- Must use DELETE statement not SELECT

-- ============================================================
-- KEY INSIGHT:
-- SELECT DISTINCT = shows unique view, table unchanged ❌
-- DELETE = permanently removes rows from table ✅
--
-- Strategy:
-- 1. Find minimum id per email (rows to KEEP)
-- 2. Delete all rows NOT in that list
--
-- MySQL issue:
-- Cannot reference same table in subquery directly ❌
-- Must wrap in another subquery ✅
-- ============================================================

-- ============================================================
-- APPROACH 1: DELETE + NOT IN subquery (PostgreSQL)
-- ============================================================

DELETE FROM Person
WHERE id NOT IN (
    SELECT MIN(id)
    FROM Person
    GROUP BY email
);

-- ============================================================
-- APPROACH 2: DELETE + NOT IN with wrapper (MySQL)
-- MySQL doesn't allow subquery on same table directly ❌
-- Wrap in another subquery to fix ✅
-- ============================================================

DELETE FROM Person
WHERE id NOT IN (
    SELECT min_id
    FROM (
        SELECT MIN(id) AS min_id
        FROM Person
        GROUP BY email
    ) t                          -- alias required in MySQL ✅
);

-- ============================================================
-- APPROACH 3: Self JOIN (alternative)
-- Delete rows where another row has same email but smaller id
-- ============================================================

DELETE p1
FROM Person p1
JOIN Person p2
    ON p1.email = p2.email       -- same email ✅
    AND p1.id > p2.id;           -- p1 has larger id → delete ✅

-- ============================================================
-- EXAMPLE WALKTHROUGH:
-- Input:
-- id | email
-- 1  | john@example.com
-- 2  | bob@example.com
-- 3  | john@example.com  ← duplicate!
--
-- Find MIN(id) per email:
-- email             | MIN(id)
-- john@example.com  | 1  ← keep ✅
-- bob@example.com   | 2  ← keep ✅
--
-- NOT IN (1, 2):
-- id=1 → IN list → keep ✅
-- id=2 → IN list → keep ✅
-- id=3 → NOT IN list → DELETE ✅
--
-- Result:
-- id | email
-- 1  | john@example.com ✅
-- 2  | bob@example.com  ✅
-- ============================================================

-- ============================================================
-- SELF JOIN WALKTHROUGH:
-- p1 id=3, p2 id=1:
-- → same email (john@example.com) ✅
-- → p1.id(3) > p2.id(1) ✅
-- → delete p1 (id=3) ✅
--
-- p1 id=1, p2 id=3:
-- → same email ✅
-- → p1.id(1) > p2.id(3) ❌ (1 not > 3)
-- → keep p1 (id=1) ✅
-- ============================================================

-- ============================================================
-- SELECT vs DELETE — key difference:
--
-- SELECT DISTINCT email FROM Person:
-- → shows unique emails ✅
-- → Person table UNCHANGED ❌
-- → duplicates still exist ❌
-- → like looking through messy drawer ❌
--
-- DELETE duplicate rows:
-- → permanently removes rows ✅
-- → Person table MODIFIED ✅
-- → duplicates gone ✅
-- → actually cleaning the drawer ✅
-- ============================================================

-- ============================================================
-- COMMON MISTAKES:
--
-- 1. Using SELECT DISTINCT instead of DELETE:
--    → table unchanged ❌
--    → problem requires DELETE ✅
--
-- 2. MySQL subquery on same table error:
--    DELETE FROM Person WHERE id NOT IN (
--        SELECT MIN(id) FROM Person GROUP BY email
--    ) ← MySQL error ❌
--    Fix: wrap in another subquery with alias ✅
--
-- 3. Deleting wrong rows:
--    WHERE id IN (MIN ids) ← deletes rows to KEEP ❌
--    WHERE id NOT IN (MIN ids) ← deletes duplicates ✅
--
-- 4. Forgetting alias in MySQL wrapper:
--    FROM (...) ← MySQL requires alias ❌
--    FROM (...) t ← alias required ✅
-- ============================================================

-- ============================================================
-- KEY PATTERN — MEMORIZE THIS:
-- "Delete duplicates keeping minimum id":
--
-- PostgreSQL:
--   DELETE FROM table
--   WHERE id NOT IN (
--       SELECT MIN(id) FROM table GROUP BY unique_col
--   );
--
-- MySQL (wrapped):
--   DELETE FROM table
--   WHERE id NOT IN (
--       SELECT min_id FROM (
--           SELECT MIN(id) AS min_id
--           FROM table GROUP BY unique_col
--       ) t
--   );
--
-- Self JOIN (universal):
--   DELETE t1 FROM table t1
--   JOIN table t2
--       ON t1.unique_col = t2.unique_col
--       AND t1.id > t2.id;
--
-- Real DE use cases:
-- → Delete duplicate emails (this problem) ✅
-- → Remove duplicate bookings (keep first) ✅
-- → Clean duplicate sensor readings ✅
-- → Deduplicate patient records in healthcare ✅
-- → Remove duplicate airline bookings ✅
-- ============================================================
