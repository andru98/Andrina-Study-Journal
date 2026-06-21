-- ============================================================
-- Problem : Customers Who Never Order
-- Source  : LeetCode 183
-- Link    : https://leetcode.com/problems/customers-who-never-order/
-- Topic   : Anti-Join / NOT IN / NOT EXISTS / LEFT JOIN
-- Level   : Easy
-- Date    : 2026-06-19
-- ============================================================

-- PROBLEM STATEMENT:
-- Table: Customers (id, name)
-- Table: Orders (id, customerId)
-- Find all customers who never placed an order.

-- ============================================================
-- THREE APPROACHES — all produce same result, different tradeoffs
-- ============================================================

-- ============================================================
-- APPROACH 1: NOT IN
-- Simple and readable but dangerous with NULLs.
-- If any customerId in Orders is NULL, entire result is empty.
-- SQL three-valued logic: NULL = NULL → UNKNOWN not TRUE
-- Use only when you are 100% certain no NULLs exist in subquery.
-- ============================================================

SELECT name
FROM Customers
WHERE id NOT IN (
    SELECT customerId
    FROM Orders
);

-- ============================================================
-- APPROACH 2: NOT EXISTS (Production Default)
-- Safer than NOT IN — EXISTS checks row existence not equality.
-- NULL values in Orders.customerId do not affect result.
-- Short-circuit execution — stops scanning after first match found.
-- Preferred approach in production pipelines.
-- ============================================================

SELECT name
FROM Customers c
WHERE NOT EXISTS (
    SELECT 1
    FROM Orders o
    WHERE o.customerId = c.id
);

-- ============================================================
-- APPROACH 3: LEFT JOIN + IS NULL
-- Keep all customers, NULL on right side = no order exists.
-- Must check IS NULL on primary key (o.id) not nullable column.
-- Checking IS NULL on a nullable column (e.g. amount) gives
-- false positives — a customer with a NULL amount would appear
-- as having no orders even though they do.
-- ============================================================

SELECT c.name
FROM Customers c
LEFT JOIN Orders o ON c.id = o.customerId
WHERE o.id IS NULL;

-- ============================================================
-- EXAMPLE WALKTHROUGH:
-- Customers:          Orders:
-- id | name           id | customerId
-- 1  | Joe            1  | 3
-- 2  | Henry          2  | 1
-- 3  | Sam
-- 4  | Max
--
-- Joe (id=1)   → has order → excluded
-- Henry (id=2) → no order  → included ✅
-- Sam (id=3)   → has order → excluded
-- Max (id=4)   → no order  → included ✅
--
-- Output:
-- name
-- Henry
-- Max
-- ============================================================

-- ============================================================
-- EDGE CASES TO KEEP IN MIND:
-- 1. NULL in Orders.customerId with NOT IN:
--    NOT IN (1, 2, NULL) → SQL checks: id NOT IN NULL → UNKNOWN
--    Entire result becomes empty — all customers disappear
--    Fix: use NOT EXISTS instead
--
-- 2. LEFT JOIN — check IS NULL on primary key not data column:
--    WHERE o.customerId IS NULL  ← WRONG if customerId can be NULL
--    WHERE o.id IS NULL          ← CORRECT — primary key never NULL
--
-- 3. All customers have orders → empty result set
--    All three approaches correctly return empty table
--
-- 4. Empty Orders table → all customers returned
--    NOT IN: NOT IN (empty set) → always true → all customers ✅
--    NOT EXISTS: no rows exist → NOT EXISTS true → all customers ✅
--    LEFT JOIN: all NULLs on right → all customers ✅
-- ============================================================

-- ============================================================
-- PERFORMANCE COMPARISON:
-- NOT IN     → builds entire subquery list in memory first
--              slow for millions of orders
--              dangerous with NULLs
--
-- NOT EXISTS → correlated subquery, runs once per customer
--              short-circuits on first match found
--              safe with NULLs
--              modern optimizers often rewrite to same plan as JOIN
--
-- LEFT JOIN  → set-based operation, often fastest
--              optimizer handles large tables well
--              most explicit and readable for anti-joins
--
-- In practice: modern optimizers (PostgreSQL, MySQL 8+, Snowflake)
-- often compile all three to the same execution plan.
-- Use EXPLAIN to verify before optimizing.
-- ============================================================

-- ============================================================
-- KEY PATTERN — MEMORIZE THIS:
-- Anti-join = "find rows in A with no match in B"
--
-- Default choice: NOT EXISTS (safe with NULLs, readable)
-- Alternative:    LEFT JOIN + IS NULL on primary key
-- Avoid:          NOT IN when subquery column can contain NULLs
--
-- Interview one-liner:
-- "NOT EXISTS is safer than NOT IN because EXISTS checks row
--  existence not value equality — NULLs don't affect the result.
--  LEFT JOIN + IS NULL is equally safe when checking the primary key."
-- ============================================================
