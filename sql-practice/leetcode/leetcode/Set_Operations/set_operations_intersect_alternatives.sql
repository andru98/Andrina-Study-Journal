-- ============================================================
-- SET OPERATIONS — INTERSECT / UNION / EXCEPT
-- Interview Patterns: INTERSECT vs GROUP BY vs Self Join
-- Author : Anna Shrestha
-- Topics : UNION, UNION ALL, INTERSECT, EXCEPT,
--          Self Join alternative, GROUP BY alternative,
--          scaling to N periods
-- ============================================================


-- ------------------------------------------------------------
-- SETUP: sample tables used throughout this file
-- ------------------------------------------------------------
--
-- sales table
-- | product_id | sale_month |
-- |------------|------------|
-- | A          | 2024-01    |
-- | A          | 2024-02    |
-- | B          | 2024-01    |
-- | C          | 2024-01    |
--
-- watchlist_monday : TSLA, NVDA, AMD, SPY
-- watchlist_tuesday: NVDA, AMD, AAPL, MSFT
-- ------------------------------------------------------------


-- ============================================================
-- SECTION 1 — SET OPERATION SYNTAX
-- ============================================================

-- Rule that applies to ALL set operations:
-- Both SELECT statements must return the same number of columns
-- and matching data types. Violating this causes a syntax error.


-- ------------------------------------------------------------
-- 1A. UNION — all rows from both, duplicates removed
-- ------------------------------------------------------------
SELECT symbol FROM watchlist_monday
UNION
SELECT symbol FROM watchlist_tuesday;
-- Result: TSLA, NVDA, AMD, SPY, AAPL, MSFT

-- Interview note:
-- UNION removes duplicates by sorting and comparing all rows.
-- Use when you need a clean deduplicated combined list.


-- ------------------------------------------------------------
-- 1B. UNION ALL — all rows from both, duplicates kept
-- ------------------------------------------------------------
SELECT symbol FROM watchlist_monday
UNION ALL
SELECT symbol FROM watchlist_tuesday;
-- Result: TSLA, NVDA, AMD, SPY, NVDA, AMD, AAPL, MSFT
-- NVDA and AMD appear twice — once from each list

-- Interview note:
-- UNION ALL is faster than UNION — it skips the dedup sort step.
-- Prefer UNION ALL when you know data has no duplicates, or when
-- you deliberately need duplicates (e.g. counting total appearances).


-- ------------------------------------------------------------
-- 1C. INTERSECT — only rows that appear in BOTH
-- ------------------------------------------------------------
SELECT symbol FROM watchlist_monday
INTERSECT
SELECT symbol FROM watchlist_tuesday;
-- Result: NVDA, AMD

-- Interview note:
-- INTERSECT = only the overlap. Think Venn diagram centre.
-- Not supported in MySQL — use JOIN or GROUP BY alternative instead.


-- ------------------------------------------------------------
-- 1D. EXCEPT — rows in first set but NOT in second
-- ------------------------------------------------------------
SELECT symbol FROM watchlist_monday
EXCEPT
SELECT symbol FROM watchlist_tuesday;
-- Result: TSLA, SPY  (on Monday but not Tuesday)

-- Reverse: what was added on Tuesday that wasn't on Monday?
SELECT symbol FROM watchlist_tuesday
EXCEPT
SELECT symbol FROM watchlist_monday;
-- Result: AAPL, MSFT

-- Interview note:
-- EXCEPT order matters — it is not symmetric.
-- Called MINUS in Oracle SQL. Same behaviour, different keyword.


-- ============================================================
-- SECTION 2 — INTERSECT ALTERNATIVES
-- (asked in interviews: "rewrite without INTERSECT")
-- ============================================================

-- Problem: find products sold in BOTH January AND February


-- ------------------------------------------------------------
-- 2A. INTERSECT — simplest, least scalable
-- ------------------------------------------------------------
SELECT product_id FROM sales WHERE sale_month = '2024-01'
INTERSECT
SELECT product_id FROM sales WHERE sale_month = '2024-02';


-- ------------------------------------------------------------
-- 2B. SELF JOIN alternative
-- ------------------------------------------------------------
-- How it works:
-- 1. SQL aliases the same table twice: jan and feb
-- 2. Generates every possible jan-row × feb-row combination
-- 3. Keeps only pairs where ALL three ON conditions pass:
--    - product_id matches on both sides
--    - jan side must be a Jan row
--    - feb side must be a Feb row
-- 4. DISTINCT removes duplicates from messy source data

SELECT DISTINCT jan.product_id
FROM   sales jan
INNER JOIN sales feb
    ON  jan.product_id   = feb.product_id   -- condition 1: same product
    AND jan.sale_month   = '2024-01'        -- condition 2: jan side = Jan
    AND feb.sale_month   = '2024-02';       -- condition 3: feb side = Feb

-- Interview note:
-- The alias names (jan, feb) are chosen by the developer for readability.
-- SQL does not know or enforce their meaning — the ON conditions do.
-- Use when you need extra columns from either month in the result.


-- ------------------------------------------------------------
-- 2C. GROUP BY alternative — most scalable
-- ------------------------------------------------------------
-- How it works:
-- 1. Filter to only the months we care about
-- 2. Group by product
-- 3. Count how many DISTINCT months each product appears in
-- 4. HAVING keeps only products present in ALL required months

SELECT product_id
FROM   sales
WHERE  sale_month IN ('2024-01', '2024-02')
GROUP BY product_id
HAVING COUNT(DISTINCT sale_month) = 2;

-- Interview note:
-- COUNT(DISTINCT sale_month) counts unique months per product group.
-- = 2 means the product appeared in exactly both months.
-- DISTINCT is essential — without it, a product sold 5 times in Jan
-- would inflate the count and give wrong results.


-- ============================================================
-- SECTION 3 — SCALING TO N PERIODS
-- (the senior DE answer interviewers want to hear)
-- ============================================================

-- Problem: find products sold in ALL 12 months of 2024

-- INTERSECT approach — requires 12 stacked queries. Not practical.
-- Self Join approach — requires 12 aliases and 24 ON conditions. Unusable.

-- GROUP BY approach — one query, change one number:
SELECT product_id
FROM   sales
WHERE  sale_month BETWEEN '2024-01' AND '2024-12'
GROUP BY product_id
HAVING COUNT(DISTINCT sale_month) = 12;

-- Real world extension — products sold in at least 6 out of 12 months:
SELECT product_id
FROM   sales
WHERE  sale_month BETWEEN '2024-01' AND '2024-12'
GROUP BY product_id
HAVING COUNT(DISTINCT sale_month) >= 6;

-- Interview note:
-- This is why senior DEs prefer GROUP BY for this pattern.
-- INTERSECT stacks queries linearly — O(n) queries for n periods.
-- GROUP BY stays one query regardless of how many periods.
-- In a real pipeline with 12+ months, INTERSECT is unmaintainable.


-- ============================================================
-- SECTION 4 — APPLIED TO TRADING JOURNAL
-- (demonstrates domain-specific thinking in interviews)
-- ============================================================

-- Which setups appeared in BOTH winning AND losing trades?
-- (shows the setup has edge but also risk — worth reviewing)
SELECT setup
FROM   trades
WHERE  trade_result IN ('Win', 'Loss')
GROUP BY setup
HAVING COUNT(DISTINCT trade_result) = 2;

-- Which symbols were traded on BOTH Monday AND Friday?
-- (Friday has stricter rules — flag these for review)
SELECT DISTINCT mon.symbol
FROM   trades mon
INNER JOIN trades fri
    ON  mon.symbol              = fri.symbol
    AND DAYOFWEEK(mon.trade_date) = 2    -- Monday
    AND DAYOFWEEK(fri.trade_date) = 6;   -- Friday

-- Tickers on watchlist this week but NOT last week (new additions):
SELECT symbol FROM watchlist_this_week
EXCEPT
SELECT symbol FROM watchlist_last_week;


-- ============================================================
-- SECTION 5 — REQUIREMENTS FOR ALL SET OPERATIONS
-- ============================================================

-- Every set operation (UNION, INTERSECT, EXCEPT) requires:

-- Rule 1: Same number of columns
-- Both queries must return the same number of columns.
-- This breaks:
--   SELECT product_id, sale_month FROM sales
--   INTERSECT
--   SELECT product_id FROM sales;            -- ❌ column count mismatch

-- Rule 2: Compatible data types
-- Corresponding columns must be compatible types.
-- Column 1 of query 1 matches with column 1 of query 2, and so on.
-- This breaks:
--   SELECT product_id, sale_month FROM sales      -- sale_month is DATE
--   UNION
--   SELECT product_id, revenue   FROM sales;      -- revenue is INT ❌

-- Rule 3: Column names come from the first query
-- The result set uses column names from the first SELECT only.
-- Second query column names are ignored.

SELECT product_id, sale_month  FROM sales WHERE sale_month = '2024-01'
UNION
SELECT product_id, revenue     FROM sales WHERE sale_month = '2024-02';
-- Result column names: product_id, sale_month   ← from first query
-- Even though second query says 'revenue', the header shows 'sale_month'

-- Interview note:
-- These 3 rules apply to ALL set operations without exception.
-- Interviewers test rule 2 and 3 most — type mismatch and column
-- naming are the two most common mistakes candidates make.


-- ============================================================
-- SECTION 6 — TWO-WAY EXCEPT (Full Reconciliation)
-- ============================================================

-- Problem: you have two tables that SHOULD have the same data.
-- You need to find ALL differences — rows missing from either side.
--
-- One-way EXCEPT only finds differences in one direction.
-- Two-way EXCEPT runs EXCEPT in both directions and combines results.
-- Together they give a complete picture of what is different.

-- Real world use case:
-- You load yesterday's trades from your broker into a database.
-- Your internal system also recorded trades.
-- They should match. Find every discrepancy.

-- Broker table (source of truth)
-- | trade_id | symbol | pnl  |
-- |----------|--------|------|
-- | T001     | TSLA   | 5.0  |
-- | T002     | NVDA   | 3.0  |
-- | T003     | AMD    | -2.0 |

-- Internal system table
-- | trade_id | symbol | pnl  |
-- |----------|--------|------|
-- | T001     | TSLA   | 5.0  |
-- | T002     | NVDA   | 8.0  |  ← pnl mismatch
-- | T004     | SPY    | 1.0  |  ← T004 exists internally but not in broker

-- Direction 1: in broker but NOT in internal system (missing internally)
SELECT trade_id, symbol, pnl, 'missing from internal' AS difference
FROM   broker_trades
EXCEPT
SELECT trade_id, symbol, pnl
FROM   internal_trades

UNION ALL

-- Direction 2: in internal system but NOT in broker (extra or wrong)
SELECT trade_id, symbol, pnl, 'missing from broker' AS difference
FROM   internal_trades
EXCEPT
SELECT trade_id, symbol, pnl
FROM   broker_trades;

-- Result:
-- | trade_id | symbol | pnl  | difference             |
-- |----------|--------|------|------------------------|
-- | T003     | AMD    | -2.0 | missing from internal  |  ← T003 not in internal
-- | T002     | NVDA   | 3.0  | missing from broker    |  ← pnl mismatch (3 vs 8)
-- | T002     | NVDA   | 8.0  | missing from broker    |  ← same trade, wrong pnl
-- | T004     | SPY    | 1.0  | missing from broker    |  ← T004 not in broker

-- Interview note:
-- EXCEPT compares entire rows — if even one column differs (like pnl),
-- it treats the rows as completely different. This is why T002 appears
-- twice — the broker version (3.0) and the internal version (8.0) are
-- treated as two distinct rows with no match.
-- This pattern is used in production for data pipeline reconciliation,
-- audit checks, and data quality validation between source and target.

-- Cleaner production version using CTE:
WITH
    missing_from_internal AS (
        SELECT trade_id, symbol, pnl, 'missing from internal' AS difference
        FROM   broker_trades
        EXCEPT
        SELECT trade_id, symbol, pnl
        FROM   internal_trades
    ),
    missing_from_broker AS (
        SELECT trade_id, symbol, pnl, 'missing from broker' AS difference
        FROM   internal_trades
        EXCEPT
        SELECT trade_id, symbol, pnl
        FROM   broker_trades
    )
SELECT * FROM missing_from_internal
UNION ALL
SELECT * FROM missing_from_broker
ORDER BY trade_id, difference;

-- Interview note:
-- CTE version is preferred in production — easier to read, debug,
-- and extend. If a recruiter asks "how would you find data quality
-- issues between two pipeline stages?" — this is the answer.


-- ============================================================
-- SECTION 7 — QUICK REFERENCE COMPARISON
-- ============================================================

-- | Approach   | Use when                              | Limitation              |
-- |------------|---------------------------------------|-------------------------|
-- | INTERSECT  | Quick, readable, 2 sets only          | Not in MySQL, hard to   |
-- |            |                                       | scale beyond 2 periods  |
-- | SELF JOIN  | Need extra columns from either side   | Verbose for 3+ periods  |
-- | GROUP BY   | Scaling to 3+ periods, production SQL | Slightly less readable  |
-- |            | Most flexible, one query always       | for simple 2-set cases  |

-- Rule of thumb:
-- 2 sets, quick query    → INTERSECT (if supported by your DB)
-- Need joined columns    → Self Join
-- 3+ periods, production → GROUP BY with HAVING COUNT(DISTINCT ...)
