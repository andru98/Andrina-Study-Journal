-- ============================================================
-- Advanced SQL: Window Functions & Common Pitfalls
-- Author  : Anna Shrestha
-- Database: PostgreSQL (syntax specific to PostgreSQL 13+)
--           Core concepts apply to BigQuery, Snowflake, Redshift
--           with minor syntax adjustments noted inline
-- Topics  : LAG with calendar gaps | ROWS vs RANGE |
--           LAST_VALUE default frame bug | Sessionisation
-- ============================================================


-- ============================================================
-- CONCEPT 1: LAG vs Calendar Date Join
-- ============================================================
-- Problem:
--   LAG counts rows, not calendar days.
--   If your data has gaps (holidays, failed pipeline runs, weekends),
--   LAG(revenue, 7) gives you "the revenue from 7 rows back"
--   not "revenue from the same day last week."
--   This silently compares the wrong weekdays with no error or warning.
--
-- Fix:
--   Join on order_date - INTERVAL '7 days' for calendar-aware comparisons.
--   When the date 7 days ago is missing, the join returns NULL honestly
--   instead of silently pulling the wrong row.
-- ============================================================

-- Sample data: daily revenue with May 14 missing (public holiday)
CREATE TABLE daily_revenue (
    order_date DATE,
    city       VARCHAR(50),
    revenue    DECIMAL(10,2)
);

INSERT INTO daily_revenue VALUES
('2026-05-12', 'Mumbai', 10000),  -- Monday
('2026-05-13', 'Mumbai', 12000),  -- Tuesday
-- May 14 (Wednesday) missing: public holiday, no pipeline run
('2026-05-15', 'Mumbai', 13000),  -- Thursday
('2026-05-16', 'Mumbai', 15000),  -- Friday
('2026-05-17', 'Mumbai', 20000),  -- Saturday
('2026-05-18', 'Mumbai', 18000),  -- Sunday
('2026-05-19', 'Mumbai', 10500),  -- Monday
('2026-05-20', 'Mumbai', 12800),  -- Tuesday
('2026-05-21', 'Mumbai', 11000),  -- Wednesday
('2026-05-22', 'Mumbai', 14000);  -- Thursday


-- ❌ WRONG: LAG(7) silently shifts to wrong weekday after the gap
--
-- What happens:
--   May 21 (Wednesday) → LAG(7) goes 7 rows back → lands on May 13 (Tuesday)
--   Wednesday is being compared to Tuesday. Wrong. No error anywhere.
--   One missing date corrupts all subsequent comparisons.
--
-- Note: TO_CHAR is PostgreSQL syntax.
--       BigQuery equivalent: FORMAT_DATE('%A', order_date)
--       Snowflake equivalent: DAYNAME(order_date)

SELECT
    order_date,
    TO_CHAR(order_date, 'Day')         AS current_weekday,
    revenue,
    LAG(revenue, 7) OVER (
        ORDER BY order_date
    )                                  AS wrong_last_week_revenue,
    TO_CHAR(
        order_date - INTERVAL '7 days',
        'Day'
    )                                  AS expected_weekday
FROM daily_revenue
ORDER BY order_date;

-- Result shows the shift:
-- May 21 (Wednesday) compares against May 13 (Tuesday) -- WRONG


-- ✅ CORRECT: Join on exact calendar date
--
-- What happens:
--   May 21 joins to May 14 (May 21 - 7 days)
--   May 14 is missing → revenue = NULL  (honest, not wrong)
--   May 22 joins to May 15 → ₹13,000   (correct Thursday vs Thursday)

SELECT
    t.order_date,
    TO_CHAR(t.order_date, 'Day')       AS current_weekday,
    t.revenue                          AS current_revenue,
    last_week.revenue                  AS last_week_revenue,
    ROUND(
        (t.revenue - last_week.revenue)
        / last_week.revenue * 100,
        2
    )                                  AS pct_change
FROM daily_revenue t
LEFT JOIN daily_revenue last_week
    ON  last_week.order_date = t.order_date - INTERVAL '7 days'
    AND last_week.city       = t.city
ORDER BY t.order_date;

-- When last_week.revenue is NULL: no data for that comparison date.
-- This is visible and honest. LAG would have hidden this silently.

-- SUMMARY:
--   LAG(col, 7)                        → 7 rows back → breaks on gaps
--   JOIN ON date - INTERVAL '7 days'   → calendar-aware → NULL on missing dates


-- ============================================================
-- CONCEPT 2: ROWS vs RANGE — Window Frame Behaviour
-- ============================================================
-- Problem:
--   When ORDER BY is present in a window function,
--   SQL silently applies RANGE as the default frame (not ROWS).
--   RANGE groups all rows with the same ORDER BY value together,
--   treating them as "the same position."
--   This pulls in rows you do not expect — including future rows
--   with the same date — silently producing wrong totals.
--
-- Fix:
--   Always write ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
--   explicitly when you want a clean row-by-row calculation.
-- ============================================================

-- Sample data: two orders on May 2 and two on May 3 (duplicate dates)
CREATE TABLE orders_with_duplicates (
    row_num    INT,
    order_date DATE,
    revenue    DECIMAL(10,2)
);

INSERT INTO orders_with_duplicates VALUES
(1, '2026-05-01', 100),
(2, '2026-05-02', 200),
(3, '2026-05-02', 300),  -- same date as row 2
(4, '2026-05-03', 400),
(5, '2026-05-03', 500),  -- same date as row 4
(6, '2026-05-04', 600);


-- ❌ RANGE (SQL default when ORDER BY is present):
--
-- RANGE treats all rows with the same order_date as "the same position."
-- For row 2 (May 2): window includes ALL May 2 rows (rows 2 and 3)
-- even though row 3 physically comes AFTER row 2.
-- The running total jumps ahead then repeats on the duplicate row.
--
-- Expected: 100, 300, 600, 1000, 1500, 2100
-- Actual:   100, 600, 600, 1500, 1500, 2100  ← jumps and repeats

SELECT
    row_num,
    order_date,
    revenue,
    SUM(revenue) OVER (
        ORDER BY order_date
        RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        -- This is identical to writing:
        -- SUM(revenue) OVER (ORDER BY order_date)
        -- SQL applies RANGE silently as the default
    ) AS range_running_total
FROM orders_with_duplicates
ORDER BY row_num;


-- ✅ ROWS: each physical row is its own independent position
--
-- ROWS does not care about values — only position numbers.
-- Row 2 is row 2 regardless of its date.
-- No surprises. Completely predictable.
--
-- Result: 100, 300, 600, 1000, 1500, 2100  ← correct

SELECT
    row_num,
    order_date,
    revenue,
    SUM(revenue) OVER (
        ORDER BY order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS rows_running_total
FROM orders_with_duplicates
ORDER BY row_num;


-- SIDE BY SIDE to see the difference clearly:
--
-- row  date    revenue  ROWS_total  RANGE_total  difference
--  1   May 1   100      100         100
--  2   May 2   200      300         600          ← RANGE pulled in row 3 (future!)
--  3   May 2   300      600         600          ← RANGE same as row 2
--  4   May 3   400      1000        1500         ← RANGE pulled in row 5 (future!)
--  5   May 3   500      1500        1500         ← RANGE same as row 4
--  6   May 4   600      2100        2100

SELECT
    row_num,
    order_date,
    revenue,
    SUM(revenue) OVER (
        ORDER BY order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS rows_total,
    SUM(revenue) OVER (
        ORDER BY order_date
        RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS range_total
FROM orders_with_duplicates
ORDER BY row_num;

-- SUMMARY:
--   ROWS  → physical row position → safe with duplicates → use by default
--   RANGE → grouped by value → duplicates treated as same position → use intentionally
--   SQL default = RANGE (not ROWS) → always be explicit


-- ============================================================
-- CONCEPT 3: LAST_VALUE broken by default frame + Partition vs Running SUM
-- ============================================================
-- Problem 1 (LAST_VALUE):
--   LAST_VALUE with ORDER BY only sees rows up to the current row
--   due to the default frame (UNBOUNDED PRECEDING to CURRENT ROW).
--   So it always returns the current row's own value instead of
--   the last value in the partition.
--   FIRST_VALUE works fine; LAST_VALUE always needs an explicit frame fix.
--
-- Problem 2 (SUM):
--   SUM without ORDER BY → sees all rows → same partition total on every row.
--   SUM with ORDER BY + default frame → sees rows up to current → running total.
--   Add ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
--   if you want a partition total while keeping ORDER BY.
-- ============================================================

CREATE TABLE daily_orders (
    order_date DATE,
    city       VARCHAR(50),
    revenue    DECIMAL(10,2)
);

INSERT INTO daily_orders VALUES
('2026-05-01', 'Mumbai', 100),
('2026-05-02', 'Mumbai', 200),
('2026-05-03', 'Mumbai', 300),
('2026-05-04', 'Mumbai', 400);


-- ❌ WRONG: LAST_VALUE with default frame
--
-- On May 1: window sees only May 1 → "last" = May 1 itself → returns 100
-- On May 2: window sees May 1-2   → "last" = May 2 itself → returns 200
-- Returns the current row's own value every time. Useless.

SELECT
    order_date,
    revenue,
    LAST_VALUE(revenue) OVER (
        PARTITION BY city
        ORDER BY order_date
        -- default frame silently applied:
        -- RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS wrong_last_value
FROM daily_orders
ORDER BY order_date;
-- Result: 100, 200, 300, 400  ← just mirrors the revenue column


-- ✅ CORRECT: FIRST_VALUE and LAST_VALUE with explicit frames

SELECT
    order_date,
    revenue,
    FIRST_VALUE(revenue) OVER (
        PARTITION BY city
        ORDER BY order_date
        -- FIRST_VALUE works fine with default frame:
        -- frame always starts at the beginning so first row is always visible
    )                                  AS first_day_revenue,

    LAST_VALUE(revenue) OVER (
        PARTITION BY city
        ORDER BY order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        -- Must extend frame to end of partition so LAST_VALUE
        -- can actually see the last row
    )                                  AS last_day_revenue
FROM daily_orders
ORDER BY order_date;
-- first_day_revenue: 100, 100, 100, 100  ← correct (May 1 repeated)
-- last_day_revenue:  400, 400, 400, 400  ← correct (May 4 repeated)


-- ✅ Partition total vs Running total: SUM behaviour with and without ORDER BY

SELECT
    order_date,
    revenue,

    -- No ORDER BY: window sees ALL rows in partition → same total on every row
    SUM(revenue) OVER (
        PARTITION BY city
    )                                  AS partition_total,

    -- With ORDER BY + default frame: window grows row by row → running total
    SUM(revenue) OVER (
        PARTITION BY city
        ORDER BY order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                  AS running_total,

    -- With ORDER BY + extended frame: still sees all rows → partition total
    SUM(revenue) OVER (
        PARTITION BY city
        ORDER BY order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    )                                  AS partition_total_with_order
FROM daily_orders
ORDER BY order_date;

-- partition_total:          1000, 1000, 1000, 1000  ← same every row
-- running_total:            100,  300,  600,  1000  ← grows each row
-- partition_total_with_order: 1000, 1000, 1000, 1000 ← same as no ORDER BY

-- SUMMARY:
--   FIRST_VALUE → default frame is fine           ✓
--   LAST_VALUE  → always add UNBOUNDED FOLLOWING  ✓
--   SUM no ORDER BY      → partition total
--   SUM with ORDER BY    → running total (default frame)
--   SUM with UNBOUNDED FOLLOWING → partition total


-- ============================================================
-- CONCEPT 4: Sessionisation using LAG + Flag + Running SUM
-- ============================================================
-- Business problem:
--   Group user events into sessions. A new session starts when
--   a user has been inactive for more than 30 minutes.
--
-- Pattern (memorise this for interviews):
--   Step 1 → LAG to find previous event time per user
--   Step 2 → EXTRACT(EPOCH) to calculate gap in minutes
--   Step 3 → CASE flag: 1 if new session starts, 0 if continuing
--   Step 4 → Running SUM of flags = session_id
--
-- Why NULL is flagged as 1:
--   LAG returns NULL for the first event per user (no previous event exists).
--   The first event is by definition the start of session 1.
--   If NULL were treated as 0, session 1 would never be created
--   and every session number would be off by one.
--
-- Why running SUM works as a session counter:
--   Every time flag = 1, the running SUM increments.
--   Between flags (flag = 0), the SUM stays the same.
--   This assigns session IDs cleanly with no loops or procedural code.
--
-- Note: EXTRACT(EPOCH FROM interval) is PostgreSQL syntax.
--       BigQuery equivalent: TIMESTAMP_DIFF(event_time, prev_time, MINUTE)
--       Snowflake equivalent: DATEDIFF('minute', prev_time, event_time)
-- ============================================================

CREATE TABLE events (
    user_id    VARCHAR(10),
    event_time TIMESTAMP
);

INSERT INTO events VALUES
-- user_A: three sessions (gaps at 10:51 and 11:40)
('user_A', '2026-05-26 10:00:00'),
('user_A', '2026-05-26 10:05:00'),
('user_A', '2026-05-26 10:20:00'),
('user_A', '2026-05-26 10:51:00'),  -- 31 min gap → new session
('user_A', '2026-05-26 10:55:00'),
('user_A', '2026-05-26 11:40:00'),  -- 45 min gap → new session
-- user_B: two sessions (gap at 10:00)
('user_B', '2026-05-26 09:00:00'),
('user_B', '2026-05-26 09:15:00'),
('user_B', '2026-05-26 10:00:00'),  -- 45 min gap → new session
('user_B', '2026-05-26 10:10:00');


WITH event_gaps AS (
    -- Step 1 & 2: find previous event and calculate gap in minutes
    SELECT
        user_id,
        event_time,
        LAG(event_time) OVER (
            PARTITION BY user_id
            ORDER BY event_time
        )                              AS prev_event_time,

        -- EXTRACT(EPOCH FROM interval) converts time difference to seconds
        -- Dividing by 60.0 gives minutes as a decimal
        -- Returns NULL when LAG returns NULL (first event per user)
        EXTRACT(EPOCH FROM (
            event_time - LAG(event_time) OVER (
                PARTITION BY user_id
                ORDER BY event_time
            )
        )) / 60.0                      AS minutes_since_last
    FROM events
),

session_flags AS (
    -- Step 3: flag every session boundary
    SELECT
        *,
        CASE
            WHEN minutes_since_last IS NULL  -- first event per user = new session
              OR minutes_since_last > 30     -- inactivity > 30 min = new session
            THEN 1
            ELSE 0
        END                            AS new_session_flag
    FROM event_gaps
)

-- Step 4: running SUM of flags = session_id
-- Each flag=1 increments the counter. flag=0 keeps it the same.
-- Using ROWS explicitly (not default RANGE) for clean row-by-row counting.
-- Note: ROUND(...::NUMERIC, 1) is PostgreSQL casting syntax
SELECT
    user_id,
    event_time,
    prev_event_time,
    ROUND(minutes_since_last::NUMERIC, 1)  AS minutes_since_last,
    new_session_flag,
    SUM(new_session_flag) OVER (
        PARTITION BY user_id
        ORDER BY event_time
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                      AS session_id
FROM session_flags
ORDER BY user_id, event_time;


-- EXPECTED OUTPUT:
-- user_id  event_time  minutes_since_last  new_session_flag  session_id
-- user_A   10:00:00    NULL                1                 1  ← session 1
-- user_A   10:05:00    5.0                 0                 1
-- user_A   10:20:00    15.0                0                 1
-- user_A   10:51:00    31.0                1                 2  ← session 2
-- user_A   10:55:00    4.0                 0                 2
-- user_A   11:40:00    45.0                1                 3  ← session 3
-- user_B   09:00:00    NULL                1                 1  ← session 1
-- user_B   09:15:00    15.0                0                 1
-- user_B   10:00:00    45.0                1                 2  ← session 2
-- user_B   10:10:00    10.0                0                 2


-- ============================================================
-- QUICK REFERENCE CARD
-- ============================================================

-- 1. LAG for calendar comparisons
--    LAG(col, 7)                        → 7 rows back → breaks when gaps exist
--    JOIN ON date - INTERVAL '7 days'   → exact calendar date → NULL on missing

-- 2. ROWS vs RANGE
--    ROWS  → physical row count → safe with duplicates → use by default
--    RANGE → grouped by value  → pulls in duplicates silently → use intentionally
--    SQL default when ORDER BY present = RANGE (not ROWS)
--    Always write the frame explicitly for predictable results

-- 3. LAST_VALUE
--    FIRST_VALUE → works with default frame                          ✓
--    LAST_VALUE  → always add ROWS BETWEEN UNBOUNDED PRECEDING
--                  AND UNBOUNDED FOLLOWING                           ✓

-- 4. SUM behaviour
--    No ORDER BY              → partition total (same on every row)
--    With ORDER BY            → running total (grows each row)
--    With UNBOUNDED FOLLOWING → partition total (override the default)

-- 5. Sessionisation pattern
--    LAG → gap in minutes → CASE flag (NULL=1, >30=1, else 0)
--    → Running SUM of flags = session_id
--    NULL must be 1: first event has no previous = session 1 must start somewhere
