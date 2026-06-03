-- ============================================================
-- LC 175: Combine Two Tables
-- Difficulty : Easy
-- Topic      : CTE + LEFT JOIN — preserving all rows
-- Author     : Anna Shrestha
-- ============================================================
-- Problem:
-- Write a query to report the firstName, lastName, city, and
-- state of each person. If a person has no address, report
-- NULL for city and state.
--
-- Table: Person
-- | personId | firstName | lastName |
-- |----------|-----------|----------|
-- | 1        | Wang      | Fang     |
-- | 2        | Alice     | Bob      |
--
-- Table: Address
-- | addressId | personId | city          | state      |
-- |-----------|----------|---------------|------------|
-- | 1         | 2        | New York City | New York   |
-- | 2         | 3        | Leetcode      | California |
--
-- Expected output:
-- | firstName | lastName | city          | state    |
-- |-----------|----------|---------------|----------|
-- | Wang      | Fang     | NULL          | NULL     |
-- | Alice     | Bob      | New York City | New York |
-- ============================================================


-- ------------------------------------------------------------
-- SOLUTION — CTE + LEFT JOIN
-- ------------------------------------------------------------
WITH person_address AS (
    SELECT
        p.firstName,
        p.lastName,
        a.city,
        a.state
    FROM Person p
    LEFT JOIN Address a
        ON p.personId = a.personId
)
SELECT firstName, lastName, city, state
FROM person_address;


-- ------------------------------------------------------------
-- WHY LEFT JOIN NOT INNER JOIN
-- ------------------------------------------------------------

-- INNER JOIN version — wrong for this problem:
WITH person_address AS (
    SELECT p.firstName, p.lastName, a.city, a.state
    FROM Person p
    INNER JOIN Address a ON p.personId = a.personId
)
SELECT firstName, lastName, city, state
FROM person_address;
-- Wang has no address → INNER JOIN drops Wang entirely.
-- Problem requires Wang to appear with NULL city and state.

-- LEFT JOIN keeps ALL rows from the left table (Person).
-- When no matching address exists, city and state = NULL.
-- Always use LEFT JOIN when "include all rows even without a match."


-- ------------------------------------------------------------
-- DIRECT JOIN VERSION — also valid, CTE adds readability
-- ------------------------------------------------------------
SELECT
    p.firstName,
    p.lastName,
    a.city,
    a.state
FROM Person p
LEFT JOIN Address a
    ON p.personId = a.personId;

-- Interview note:
-- Both versions produce identical results.
-- CTE version separates data preparation from data retrieval —
-- easier to extend, debug, and read in production pipelines.
-- Direct JOIN is fine for simple queries.


-- ------------------------------------------------------------
-- EDGE CASES — mention these in interview
-- ------------------------------------------------------------

-- Edge case 1: Person with no address
-- Wang has no entry in Address table.
-- LEFT JOIN keeps Wang — city and state return NULL.
-- This is the core requirement of the problem.

-- Edge case 2: Address with no matching person
-- Address has personId = 3 but Person table has no id = 3.
-- LEFT JOIN starts from Person — orphan addresses are dropped.
-- If orphan addresses also needed: use FULL OUTER JOIN.
--   SELECT p.firstName, p.lastName, a.city, a.state
--   FROM Person p
--   FULL OUTER JOIN Address a ON p.personId = a.personId;
-- Note: MySQL does not support FULL OUTER JOIN natively.

-- Edge case 3: Person with multiple addresses
-- If Person id=1 has two addresses:
--   | 1 | 1 | New York | NY |
--   | 2 | 1 | Los Angeles | CA |
-- Wang appears TWICE — one row per address.
-- Fix with ROW_NUMBER() to pick one address per person:
WITH ranked_addresses AS (
    SELECT
        personId,
        city,
        state,
        ROW_NUMBER() OVER (PARTITION BY personId ORDER BY addressId) AS rn
    FROM Address
),
person_address AS (
    SELECT
        p.firstName,
        p.lastName,
        a.city,
        a.state
    FROM Person p
    LEFT JOIN ranked_addresses a
        ON p.personId = a.personId
        AND a.rn = 1        -- keep only first address per person
)
SELECT firstName, lastName, city, state
FROM person_address;

-- Edge case 4: Empty Person table
-- Zero persons → LEFT JOIN returns zero rows. Safe, no error.

-- Edge case 5: Empty Address table
-- All persons have no match → all city/state columns = NULL.
-- All persons still appear in result. Correct.


-- ------------------------------------------------------------
-- INTERVIEW TALKING POINTS
-- ------------------------------------------------------------
-- Q: Why LEFT JOIN instead of INNER JOIN?
-- A: INNER JOIN only returns rows with a match on both sides.
--    Persons without an address would be dropped entirely.
--    LEFT JOIN keeps all persons and returns NULL for missing
--    address columns — which is exactly what the problem requires.

-- Q: Why wrap in a CTE instead of writing a direct JOIN?
-- A: Both produce the same result. CTE separates the join logic
--    from the final SELECT — easier to read, test, and extend.
--    In production pipelines I use CTEs for anything beyond
--    a simple single-table query.

-- Q: What if a person has multiple addresses?
-- A: LEFT JOIN produces one row per address — person gets
--    duplicated. I would use ROW_NUMBER() partitioned by
--    personId to pick one address per person, then filter
--    WHERE rn = 1 in the final SELECT.

-- Q: What is the difference between LEFT JOIN and FULL OUTER JOIN?
-- A: LEFT JOIN keeps all rows from the left table only.
--    FULL OUTER JOIN keeps all rows from both tables —
--    unmatched rows on either side get NULLs.
--    Use FULL OUTER JOIN for complete reconciliation between
--    two datasets — similar to two-way EXCEPT.
