-- ============================================================
-- Problem : Find Users With Valid E-Mails
-- Source  : LeetCode 1517
-- Link    : https://leetcode.com/problems/find-users-with-valid-e-mails/
-- Topic   : Regular Expressions / REGEXP / Pattern Matching
-- Level   : Easy
-- Date    : 2026-09-09
-- ============================================================

-- PROBLEM STATEMENT:
-- Table: Users (user_id, name, mail)
-- Valid email rules:
-- 1. Prefix starts with a letter (a-z, A-Z)
-- 2. Prefix can contain letters, digits, _ . -
-- 3. Domain must be exactly @leetcode.com

-- ============================================================
-- KEY INSIGHT: Regular Expressions
-- LIKE is too simple for complex patterns ❌
-- REGEXP/~ handles complex validation rules ✅
--
-- Pattern built step by step:
-- ^ = start of string
-- [a-zA-Z] = first char must be letter
-- [a-zA-Z0-9._-]* = zero or more valid prefix chars
-- @leetcode = literal text
-- \. = literal dot (escaped)
-- com = literal text
-- $ = end of string
-- ============================================================

-- ============================================================
-- MySQL Solution (REGEXP)
-- ============================================================

SELECT user_id, name, mail
FROM Users
WHERE mail REGEXP '^[a-zA-Z][a-zA-Z0-9._-]*@leetcode\\.com$';

-- ============================================================
-- PostgreSQL Solution (~)
-- ============================================================

SELECT user_id, name, mail
FROM Users
WHERE mail ~ '^[a-zA-Z][a-zA-Z0-9._-]*@leetcode\.com$';

-- ============================================================
-- PATTERN BREAKDOWN:
-- ^              → start of string
-- [a-zA-Z]       → first char = letter only ✅
-- [a-zA-Z0-9._-]* → zero or more:
--                    letters (upper/lower)
--                    digits (0-9)
--                    underscore (_)
--                    period (.)
--                    dash (-)
-- @leetcode      → literal @leetcode
-- \.             → literal dot (. means any char in regex!)
-- com            → literal com
-- $              → end of string
-- ============================================================

-- ============================================================
-- EXAMPLE WALKTHROUGH:
-- winston@leetcode.com    → ^ w ✅ [win...] ✅ @leetcode.com ✅
-- jonathanisgreat         → no @leetcode.com ❌
-- bella-@leetcode.com     → - allowed in prefix ✅
-- sally.come@leetcode.com → . allowed in prefix ✅
-- quarz#2020@leetcode.com → # NOT in allowed chars ❌
-- david69@gmail.com       → @gmail not @leetcode ❌
-- .shapo@leetcode.com     → starts with . not letter ❌
-- ============================================================

-- ============================================================
-- REGEX OPERATORS:
--
-- MySQL:
-- REGEXP 'pattern'  → case insensitive match
-- NOT REGEXP        → does not match
--
-- PostgreSQL:
-- ~   'pattern'     → case sensitive match ✅
-- ~*  'pattern'     → case insensitive match
-- !~  'pattern'     → does NOT match
-- !~* 'pattern'     → does NOT match (case insensitive)
--
-- MySQL vs PostgreSQL syntax:
-- MySQL:      REGEXP '^pattern\\.com$'  ← double backslash
-- PostgreSQL: ~      '^pattern\.com$'   ← single backslash ✅
-- ============================================================

-- ============================================================
-- REGEX SPECIAL CHARACTERS:
-- ^        → start of string
-- $        → end of string
-- .        → any single character (careful!)
-- \.       → literal dot (escaped) ✅
-- [abc]    → any of a, b, c
-- [a-z]    → any lowercase letter
-- [A-Z]    → any uppercase letter
-- [0-9]    → any digit
-- [a-zA-Z0-9] → any letter or digit
-- *        → zero or more of previous
-- +        → one or more of previous
-- ?        → zero or one of previous
-- ============================================================

-- ============================================================
-- COMMON MISTAKES:
--
-- 1. Using . instead of \. for domain:
--    @leetcode.com → . matches ANY character ❌
--    @leetcode\.com → . literal dot ✅
--
-- 2. Not anchoring with ^ and $:
--    Without ^: "xwinston@leetcode.com" matches ❌
--    Without $: "winston@leetcode.com.evil" matches ❌
--    With both: exact match required ✅
--
-- 3. Wrong backslash count:
--    MySQL: \\.  (double) ✅
--    PostgreSQL: \. (single) ✅
--
-- 4. Using LIKE instead of REGEXP:
--    LIKE can't express "starts with letter" ❌
--    REGEXP handles complex rules ✅
-- ============================================================

-- ============================================================
-- KEY PATTERN — MEMORIZE THIS:
-- "Validate string format with regex":
--
-- MySQL:      WHERE col REGEXP '^[a-zA-Z][chars]*@domain\\.com$'
-- PostgreSQL: WHERE col ~ '^[a-zA-Z][chars]*@domain\.com$'
--
-- Real DE use cases:
-- → Email validation (this problem) ✅
-- → Phone number format validation ✅
-- → Validate booking reference format ✅
-- → Check IATA airport codes (3 uppercase letters) ✅
-- → Validate patient ID format in healthcare ✅
-- → Silver layer: validate data format before saving ✅
-- ============================================================
