-- ============================================================
-- Problem : Fix Names in a Table
-- Source  : LeetCode 1667
-- Link    : https://leetcode.com/problems/fix-names-in-a-table/
-- Topic   : String Functions / SUBSTRING / UPPER / LOWER / CONCAT
-- Level   : Easy
-- Date    : 2026-06-11
-- ============================================================

-- PROBLEM STATEMENT:
-- Table: Users (user_id, name)
-- The name column contains inconsistent capitalization.
-- Fix names so only the first letter is uppercase
-- and the rest are lowercase.
-- Return result ordered by user_id.

-- ============================================================
-- APPROACH:
-- Split the name into two parts:
-- Part 1 → first character only → UPPER()
-- Part 2 → everything from position 2 to end → LOWER()
-- Combine both parts with CONCAT()
--
-- Key decision: SUBSTRING + UPPER + LOWER not INITCAP()
-- INITCAP() would work in PostgreSQL and Snowflake but
-- LeetCode uses MySQL which does not support INITCAP().
-- The SUBSTRING approach works on every platform.
--
-- SUBSTRING(name, 2) with no length argument returns
-- everything from position 2 to the end of the string.
-- SQL positions are 1-based unlike Python which is 0-based.
-- ============================================================

SELECT
    user_id,
    CONCAT(
        UPPER(SUBSTRING(name, 1, 1)),  -- first letter uppercased
        LOWER(SUBSTRING(name, 2))       -- rest of name lowercased
    ) AS name
FROM Users
ORDER BY user_id;

-- ============================================================
-- EXAMPLE WALKTHROUGH:
-- Input:
-- user_id | name
-- 1       | aLice
-- 2       | bOB
--
-- Row 1: name = "aLice"
--   SUBSTRING("aLice", 1, 1) → "a"
--   UPPER("a")               → "A"
--   SUBSTRING("aLice", 2)    → "Lice"
--   LOWER("Lice")            → "lice"
--   CONCAT("A", "lice")      → "Alice"
--
-- Row 2: name = "bOB"
--   SUBSTRING("bOB", 1, 1)   → "b"
--   UPPER("b")               → "B"
--   SUBSTRING("bOB", 2)      → "OB"
--   LOWER("OB")              → "ob"
--   CONCAT("B", "ob")        → "Bob"
--
-- Output:
-- user_id | name
-- 1       | Alice
-- 2       | Bob
-- ============================================================

-- ============================================================
-- EDGE CASES TO KEEP IN MIND:
-- 1. Single character name — "a"
--    SUBSTRING("a", 1, 1) → "a" → UPPER → "A"
--    SUBSTRING("a", 2)    → ""  → LOWER → ""
--    CONCAT("A", "")      → "A" ✅ works correctly
-- 2. Already correct case — "Alice"
--    Still runs through the same transformation
--    Result is still "Alice" ✅ idempotent
-- 3. All uppercase — "ALICE"
--    UPPER("A") → "A", LOWER("LICE") → "lice"
--    Result: "Alice" ✅
-- 4. NULL name — CONCAT returns NULL
--    Add COALESCE if NULLs are possible:
--    CONCAT(UPPER(SUBSTRING(COALESCE(name,''), 1, 1)),
--           LOWER(SUBSTRING(COALESCE(name,''), 2)))
-- ============================================================

-- ============================================================
-- PLATFORM NOTES:
-- MySQL (LeetCode default) → use this SUBSTRING approach
-- PostgreSQL / Snowflake   → INITCAP(name) works but
--                            capitalizes every word, not just first
-- BigQuery                 → INITCAP(name) also available
--
-- INITCAP alternative (PostgreSQL/Snowflake only):
-- SELECT user_id, INITCAP(LOWER(name)) AS name
-- FROM Users ORDER BY user_id;
-- ============================================================

-- ============================================================
-- KEY PATTERN — MEMORIZE THIS:
-- Capitalize first letter only:
--   CONCAT(UPPER(SUBSTRING(col, 1, 1)), LOWER(SUBSTRING(col, 2)))
--
-- String chaining order for cleaning:
--   1. TRIM first — remove whitespace
--   2. Case normalize — UPPER/LOWER/INITCAP
--   3. CONCAT — combine cleaned parts
-- ============================================================
