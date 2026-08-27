-- ============================================================
-- Problem : Exchange Seats
-- Source  : LeetCode 626
-- Link    : https://leetcode.com/problems/exchange-seats/
-- Topic   : CASE WHEN / Modulo / Subquery
-- Level   : Medium
-- Date    : 2026-08-24
-- ============================================================

-- PROBLEM STATEMENT:
-- Table: Seat (id, student)
-- id is primary key, starts from 1, increments continuously
-- Swap seat IDs of every two consecutive students
-- If total students is odd, last student keeps their seat
-- Return ordered by id ascending

-- ============================================================
-- KEY INSIGHT:
-- Pattern for swapping:
-- → odd id → new id = id + 1 (swap up)
-- → even id → new id = id - 1 (swap down)
-- → EXCEPT: last student if total count is odd → keep same id
--
-- Three cases handled by CASE WHEN:
-- 1. Last student with odd id → stays (check FIRST)
-- 2. Any other odd id → id + 1
-- 3. Any even id → id - 1
--
-- Why last check comes FIRST in CASE:
-- → CASE evaluates conditions top to bottom
-- → if general odd rule checked first:
--   id=5 (last) → 5+1=6 ❌ wrong
-- → last student check must come before general odd rule ✅
-- ============================================================

SELECT
    CASE
        WHEN id % 2 = 1 AND id = (SELECT MAX(id) FROM Seat)
            THEN id        -- last student, odd total → stay ✅
        WHEN id % 2 = 1
            THEN id + 1    -- odd id → swap up ✅
        ELSE
            id - 1         -- even id → swap down ✅
    END AS id,
    student
FROM Seat
ORDER BY id;

-- ============================================================
-- EXAMPLE WALKTHROUGH:
-- Input:
-- id | student
-- 1  | Alice
-- 2  | Bob
-- 3  | Charlie
-- 4  | David
-- 5  | Eve
--
-- MAX(id) = 5 (odd total)
--
-- CASE evaluation per row:
-- id=1: odd AND not last → 1+1=2 ✅
-- id=2: even → 2-1=1 ✅
-- id=3: odd AND not last → 3+1=4 ✅
-- id=4: even → 4-1=3 ✅
-- id=5: odd AND id=MAX(id) → stays 5 ✅
--
-- Output (ordered by new id):
-- id | student
-- 1  | Bob      ← was id=2
-- 2  | Alice    ← was id=1
-- 3  | David    ← was id=4
-- 4  | Charlie  ← was id=3
-- 5  | Eve      ← stayed same ✅
-- ============================================================

-- ============================================================
-- EDGE CASES:
--
-- 1. Odd number of students (5):
--    → last student (id=5) stays ✅
--    → MAX(id) = 5 → detected correctly ✅
--
-- 2. Even number of students (4):
--    → all students paired and swapped ✅
--    → last student (id=4) is even → swaps down ✅
--    → MAX(id)=4 is even → first CASE condition never triggers
--
-- 3. Single student (id=1):
--    → id=1, odd AND id=MAX(id) → stays 1 ✅
--
-- 4. Two students:
--    → id=1 (odd, not last) → becomes 2 ✅
--    → id=2 (even) → becomes 1 ✅
-- ============================================================

-- ============================================================
-- COMMON MISTAKES:
--
-- 1. Wrong order of CASE conditions:
--    WHEN id % 2 = 1 THEN id + 1  ← catches last student too ❌
--    WHEN id % 2 = 1 AND id = MAX(id) THEN id ← too late ❌
--    Fix: always check specific case before general case ✅
--
-- 2. Using COUNT instead of MAX for last student check:
--    id = (SELECT COUNT(*) FROM Seat) ← works ONLY if no gaps
--    id = (SELECT MAX(id) FROM Seat)  ← works always ✅
--    Problem says no gaps so both work, but MAX is safer ✅
--
-- 3. Forgetting ORDER BY id:
--    Result must be ordered by new id ascending ✅
--
-- 4. Using id % 2 != 0 instead of id % 2 = 1:
--    Both work for positive integers ✅
--    id % 2 = 1 more explicit and readable ✅
-- ============================================================

-- ============================================================
-- ALTERNATIVE — Using MOD() function:
-- Some databases use MOD() instead of %:

SELECT
    CASE
        WHEN MOD(id, 2) = 1 AND id = (SELECT MAX(id) FROM Seat)
            THEN id
        WHEN MOD(id, 2) = 1
            THEN id + 1
        ELSE
            id - 1
    END AS id,
    student
FROM Seat
ORDER BY id;

-- MOD(id, 2) = id % 2 → same result ✅
-- MySQL uses both % and MOD() ✅
-- PostgreSQL uses % ✅
-- ============================================================

-- ============================================================
-- KEY PATTERN — MEMORIZE THIS:
-- "Conditional column transformation with edge case":
--
--   SELECT
--       CASE
--           WHEN specific_condition THEN special_value  ← first
--           WHEN general_condition  THEN general_value  ← second
--           ELSE default_value
--       END AS column_name
--   FROM table
--
-- Rule: always check SPECIFIC conditions before GENERAL ones
-- Most specific → least specific (top to bottom) ✅
--
-- Real DE use cases:
-- → Seat swapping (this problem) ✅
-- → Alternating row labeling (odd/even) ✅
-- → Time slot swapping in scheduling systems ✅
-- → Shift rotation in workforce management ✅
-- → Equipment ID reassignment (Caterpillar) ✅
-- ============================================================
