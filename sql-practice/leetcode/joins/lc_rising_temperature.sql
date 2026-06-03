-- ============================================================
-- Rising Temperature (Self Join on Dates)
-- Difficulty : Easy
-- Topic      : Self Join — comparing a row with the previous day
-- Author     : Anna Shrestha
-- ============================================================
-- Problem:
-- Find all records where the temperature is strictly higher
-- than the temperature on the immediately preceding calendar day.
-- If no record exists for the previous day, the record cannot
-- qualify as a rising temperature day.
--
-- Table: Weather
-- | id | record_date | temperature |
-- |----|-------------|-------------|
-- | 1  | 2015-01-01  | 10          |
-- | 2  | 2015-01-02  | 25          |
-- | 3  | 2015-01-03  | 20          |
-- | 4  | 2015-01-04  | 30          |
--
-- Expected output:
-- | id |
-- |----|
-- | 2  |
-- | 4  |
--
-- Why:
-- Jan 2 (25°) > Jan 1 (10°) → qualifies
-- Jan 3 (20°) < Jan 2 (25°) → does not qualify
-- Jan 4 (30°) > Jan 3 (20°) → qualifies
-- ============================================================


-- ------------------------------------------------------------
-- SOLUTION — Self Join on adjacent dates
-- ------------------------------------------------------------
SELECT w1.id
FROM   weather w1
JOIN   weather w2
    ON w1.record_date - INTERVAL '1 day' = w2.record_date
WHERE  w1.temperature > w2.temperature
ORDER  BY w1.id;

-- How the ON condition works:
-- w1 = today's row      (the row being evaluated)
-- w2 = yesterday's row  (the comparison row)
--
-- w1.record_date - 1 day = w2.record_date
-- means: "find the w2 row whose date is exactly one day before w1"
--
-- Rule: the alias with - INTERVAL '1 day' is TODAY
--       the alias without is YESTERDAY
--
-- WHERE then checks: is today hotter than yesterday?


-- ------------------------------------------------------------
-- THE COMMON MISTAKE — ON condition backwards
-- ------------------------------------------------------------

-- Wrong version — this is what most people write first:
SELECT w1.id
FROM   weather w1
JOIN   weather w2
    ON w1.record_date = w2.record_date - INTERVAL '1 day'
WHERE  w1.temperature > w2.temperature
ORDER  BY w1.id;

-- Why it is wrong:
-- w2.record_date - 1 day = w1.record_date
-- This makes w2 = TODAY and w1 = YESTERDAY
-- WHERE w1.temp > w2.temp then checks: is yesterday hotter than today?
-- Completely backwards — returns the wrong rows


-- ------------------------------------------------------------
-- PLATFORM SYNTAX — INTERVAL varies by database
-- ------------------------------------------------------------

-- MySQL
SELECT w1.id
FROM   weather w1
JOIN   weather w2
    ON DATEDIFF(w1.record_date, w2.record_date) = 1
WHERE  w1.temperature > w2.temperature
ORDER  BY w1.id;

-- PostgreSQL
SELECT w1.id
FROM   weather w1
JOIN   weather w2
    ON w1.record_date - INTERVAL '1 day' = w2.record_date
WHERE  w1.temperature > w2.temperature
ORDER  BY w1.id;

-- SQL Server
SELECT w1.id
FROM   weather w1
JOIN   weather w2
    ON DATEDIFF(day, w2.record_date, w1.record_date) = 1
WHERE  w1.temperature > w2.temperature
ORDER  BY w1.id;

-- Snowflake / BigQuery
SELECT w1.id
FROM   weather w1
JOIN   weather w2
    ON w1.record_date = DATEADD(day, 1, w2.record_date)
WHERE  w1.temperature > w2.temperature
ORDER  BY w1.id;

-- Interview note:
-- Always clarify which database the interviewer is using.
-- The logic is identical across platforms — only the date
-- arithmetic syntax changes. DATEDIFF is the safest to explain
-- verbally since it reads like plain English.


-- ------------------------------------------------------------
-- EDGE CASES — mention these in interview
-- ------------------------------------------------------------

-- Edge case 1: Gap in dates — no record for the previous day
-- | 1 | Jan 1 | 10° |
-- | 2 | Jan 3 | 30° |  ← Jan 2 is missing
--
-- Jan 3 - 1 day = Jan 2. No Jan 2 row exists in w2.
-- JOIN finds no match → Jan 3 row is dropped from result.
-- Correct — problem says "if no previous day record exists,
-- it cannot qualify." INNER JOIN handles this automatically.

-- Edge case 2: What if we used LEFT JOIN instead?
SELECT w1.id
FROM   weather w1
LEFT JOIN weather w2
    ON w1.record_date - INTERVAL '1 day' = w2.record_date
WHERE  w1.temperature > w2.temperature
ORDER  BY w1.id;
-- When no previous day exists: w2.temperature = NULL
-- NULL comparison: w1.temperature > NULL → NULL → row excluded
-- Result is identical to INNER JOIN for this problem.
-- INNER JOIN is cleaner and makes intent explicit.

-- Edge case 3: Duplicate dates for the same station
-- The constraint says this won't happen.
-- But in production if it could happen:
SELECT DISTINCT w1.id
FROM   weather w1
JOIN   weather w2
    ON w1.record_date - INTERVAL '1 day' = w2.record_date
WHERE  w1.temperature > w2.temperature
ORDER  BY w1.id;
-- DISTINCT removes duplicate ids if one date had multiple rows
-- and the JOIN produced duplicate results.

-- Edge case 4: All temperatures equal
-- | 1 | Jan 1 | 20° |
-- | 2 | Jan 2 | 20° |
-- WHERE w1.temp > w2.temp → 20 > 20 → FALSE
-- No rows returned. Problem says "strictly higher" — correct.

-- Edge case 5: Only one row in the table
-- No previous day exists for any row.
-- JOIN finds no matches → empty result. Safe, no error.

-- Edge case 6: Temperatures can be negative (winter data)
-- | 1 | Jan 1 | -5° |
-- | 2 | Jan 2 | -2° |
-- WHERE -2 > -5 → TRUE → Jan 2 qualifies. Handled correctly.


-- ------------------------------------------------------------
-- ALTERNATIVE — using LAG() window function
-- ------------------------------------------------------------
-- More readable for senior interviews. Covered in window functions.

SELECT id
FROM (
    SELECT
        id,
        temperature,
        LAG(temperature) OVER (ORDER BY record_date) AS prev_temp
    FROM weather
) ranked
WHERE temperature > prev_temp;

-- Interview note:
-- LAG() is cleaner and avoids the join entirely.
-- It reads the previous row's temperature directly.
-- Self join is the classic approach — LAG is the senior approach.
-- Mention both and explain the tradeoff.


-- ------------------------------------------------------------
-- INTERVIEW TALKING POINTS
-- ------------------------------------------------------------
-- Q: Why self join and not a subquery?
-- A: A correlated subquery would work but scans the table once
--    per row — O(n²). Self join with proper indexing on
--    record_date is O(n log n). For large weather datasets
--    the join is significantly faster.

-- Q: Why INNER JOIN and not LEFT JOIN?
-- A: INNER JOIN naturally excludes rows with no previous day —
--    which is exactly what the problem requires. LEFT JOIN
--    would also work here since the NULL comparison in WHERE
--    filters those rows anyway, but INNER JOIN makes the intent
--    explicit and is cleaner.

-- Q: What index would help this query?
-- A: An index on record_date speeds up the self join lookup.
--    A composite index on (record_date, temperature) would
--    allow an index-only scan — no table access needed.

-- Q: How would you solve this with window functions?
-- A: LAG(temperature) OVER (ORDER BY record_date) gives the
--    previous day's temperature directly. Filter WHERE
--    temperature > prev_temp. No join needed — cleaner and
--    easier to extend to multi-day comparisons.
