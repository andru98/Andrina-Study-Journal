-- ============================================================
-- Problem : Fix Names in a Table
-- Source  : LeetCode 1667
-- Link    : https://leetcode.com/problems/fix-names-in-a-table/
-- Topic   : String Functions / CONCAT / UPPER / LOWER / SUBSTRING
-- Level   : Easy
-- Date    : 2026-09-02
-- ============================================================

-- PROBLEM STATEMENT:
-- Table: Users (user_id, name)
-- Fix names so first character is uppercase, rest lowercase
-- Return ordered by user_id

-- ============================================================
-- KEY INSIGHT:
-- Split name into two parts:
-- Part 1: first character → UPPER ✅
-- Part 2: remaining characters → LOWER ✅
-- Combine with CONCAT ✅
-- ============================================================

-- ============================================================
-- APPROACH 1: SUBSTRING (flexible, works everywhere)
-- ============================================================

SELECT
    user_id,
    CONCAT(
        UPPER(SUBSTRING(name, 1, 1)),  -- first char uppercase ✅
        LOWER(SUBSTRING(name, 2))      -- rest lowercase ✅
    ) AS name
FROM Users
ORDER BY user_id;

-- ============================================================
-- APPROACH 2: LEFT (cleaner for first N chars)
-- ============================================================

SELECT
    user_id,
    CONCAT(
        UPPER(LEFT(name, 1)),          -- first char uppercase ✅
        LOWER(SUBSTRING(name, 2))      -- rest lowercase ✅
    ) AS name
FROM Users
ORDER BY user_id;

-- ============================================================
-- APPROACH 3: INITCAP (PostgreSQL only)
-- Cleanest but not universal
-- ============================================================

SELECT
    user_id,
    INITCAP(LOWER(name)) AS name      -- lowercase first then capitalize ✅
FROM Users
ORDER BY user_id;
-- Note: LOWER first handles ALL_CAPS input correctly ✅
-- INITCAP alone on "aLICE" → "Alice" ✅
-- But safe to LOWER first → INITCAP ✅

-- ============================================================
-- EXAMPLE WALKTHROUGH:
-- Input: name = "aLice"
--
-- SUBSTRING(name, 1, 1) = "a"  ← first character
-- UPPER("a")            = "A"  ← uppercase ✅
-- SUBSTRING(name, 2)    = "Lice" ← from position 2
-- LOWER("Lice")         = "lice" ← lowercase ✅
-- CONCAT("A", "lice")   = "Alice" ✅
--
-- Input: name = "bOB"
-- SUBSTRING("bOB", 1, 1) = "b" → UPPER → "B"
-- SUBSTRING("bOB", 2)    = "OB" → LOWER → "ob"
-- CONCAT("B", "ob")      = "Bob" ✅
-- ============================================================

-- ============================================================
-- STRING FUNCTIONS REFERENCE:
--
-- SUBSTRING(str, start, length):
-- → SUBSTRING("aLice", 1, 1) = "a"    ← pos 1, len 1
-- → SUBSTRING("aLice", 2)    = "Lice" ← from pos 2, rest
-- → SUBSTRING("aLice", 2, 3) = "Lic"  ← pos 2, len 3
--
-- LEFT(str, n):
-- → LEFT("aLice", 1) = "a"   ← first 1 char
-- → LEFT("aLice", 3) = "aLi" ← first 3 chars
--
-- RIGHT(str, n):
-- → RIGHT("aLice", 3) = "ice" ← last 3 chars
--
-- UPPER(str): → all uppercase
-- LOWER(str): → all lowercase
-- LENGTH(str): → string length
-- CONCAT(str1, str2): → combine strings
-- ============================================================

-- ============================================================
-- COMMON MISTAKES:
--
-- 1. Forgetting LOWER for rest of name:
--    CONCAT(UPPER(LEFT(name,1)), SUBSTRING(name,2))
--    → "aLice" → "ALice" ❌ (rest not lowercased)
--    Fix: wrap SUBSTRING in LOWER() ✅
--
-- 2. Wrong SUBSTRING position:
--    SUBSTRING(name, 0, 1) ← some DBs start at 0 ❌
--    SUBSTRING(name, 1, 1) ← SQL starts at 1 ✅
--
-- 3. Using INITCAP in MySQL:
--    INITCAP not supported in MySQL ❌
--    Use CONCAT + UPPER + LOWER instead ✅
-- ============================================================

-- ============================================================
-- KEY PATTERN — MEMORIZE THIS:
-- "Proper case a string":
--
--   CONCAT(
--       UPPER(LEFT(name, 1)),
--       LOWER(SUBSTRING(name, 2))
--   )
--
-- Real DE use cases:
-- → Fix user names (this problem) ✅
-- → Standardize city names in address data ✅
-- → Clean airline route names ✅
-- → Normalize passenger names in booking data ✅
-- → Data quality fix in Silver layer ✅
-- ============================================================
