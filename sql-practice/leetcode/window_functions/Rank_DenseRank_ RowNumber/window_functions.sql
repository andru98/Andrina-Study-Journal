-- ============================================================
-- SQL Practice Questions — Interview Prep
-- Author  : Anna Shrestha
-- Database: PostgreSQL 13+
--           Notes on BigQuery/Snowflake equivalents included
-- Topics  : Isolation levels | JOINs | Window functions |
--           Sessionisation | LAG pitfalls | ROWS vs RANGE
-- Format  : Each question has:
--           → Business context (why this matters in real DE work)
--           → Setup (sample data)
--           → Question
--           → Answer with explanation
-- ============================================================


-- ============================================================
-- SECTION 1: ISOLATION LEVELS
-- ============================================================
-- Interview context:
--   OLTP databases (PostgreSQL, MySQL) run hundreds of transactions
--   simultaneously. Without isolation, transactions interfere with
--   each other. Isolation levels control how much interference
--   is allowed — trading safety for performance.
--
-- OLTP vs OLAP one-liner:
--   OLTP → transactional system, heavy CRUD, ACID enforced,
--          one row at a time (PostgreSQL, MySQL)
--   OLAP → analytical system, heavy reads, schema on write,
--          millions of rows at once (Snowflake, BigQuery)
-- ============================================================

-- ── Sample data for isolation level examples ──────────────

CREATE TABLE bank_accounts (
    account_id VARCHAR(10),
    owner      VARCHAR(50),
    balance    DECIMAL(10,2)
);

INSERT INTO bank_accounts VALUES
('ACC001', 'Anna',  10000.00),
('ACC002', 'Raj',    5000.00),
('ACC003', 'Priya',  8000.00);

CREATE TABLE orders_status (
    order_id   INT,
    status     VARCHAR(20),
    amount     DECIMAL(10,2)
);

INSERT INTO orders_status VALUES
(1001, 'pending',   450.00),
(1002, 'pending',   820.00),
(1003, 'delivered', 290.00);


-- ── Q1: What is a dirty read? When does it happen? ────────
--
-- Answer:
--   A dirty read happens when Transaction B reads data that
--   Transaction A has written but NOT yet committed.
--   If Transaction A rolls back, Transaction B acted on
--   data that never officially existed.
--
-- Real example: loan approval based on an uncommitted bonus credit.

-- Isolation level that prevents it: Read Committed and above.

-- Simulating the scenario (conceptual — PostgreSQL prevents this
-- at Read Committed, which is the default):

-- Transaction A (runs first, does NOT commit yet):
--   UPDATE bank_accounts SET balance = 50000 WHERE account_id = 'ACC001';
--   -- Anna's balance is now 50000 in memory but NOT committed

-- Transaction B (runs concurrently at Read Uncommitted):
--   SELECT balance FROM bank_accounts WHERE account_id = 'ACC001';
--   -- At Read Uncommitted: returns 50000 (dirty read — wrong)
--   -- At Read Committed:   returns 10000 (safe — sees committed value only)

-- Transaction A then:
--   ROLLBACK; -- bonus was a mistake, balance back to 10000
--   -- Transaction B already made a decision based on 50000 that never existed


-- ── Q2: What is a non-repeatable read? ────────────────────
--
-- Answer:
--   Reading the SAME ROW twice in one transaction and getting
--   different values because another transaction updated and
--   committed that row between your two reads.
--   The data is real (committed) but it changed mid-transaction.
--
-- Key distinction from dirty read:
--   Dirty read    → other transaction NOT yet committed
--   Non-repeatable → other transaction DID commit, but mid-way through yours
--
-- Real example: flight price changes between checking and paying.

-- Isolation level that prevents it: Repeatable Read and above.

-- Simulating the scenario (conceptual):

-- Transaction A:
--   SELECT status FROM orders_status WHERE order_id = 1001;
--   -- Returns: 'pending'   ← first read

-- Transaction B (runs and commits between A's two reads):
--   UPDATE orders_status SET status = 'delivered' WHERE order_id = 1001;
--   COMMIT;

-- Transaction A (same transaction, reads again):
--   SELECT status FROM orders_status WHERE order_id = 1001;
--   -- At Read Committed:  returns 'delivered' ← non-repeatable read
--   -- At Repeatable Read: returns 'pending'   ← row locked, change blocked


-- ── Q3: What is a phantom read? ───────────────────────────
--
-- Answer:
--   Running the SAME QUERY twice and getting a DIFFERENT NUMBER
--   OF ROWS because another transaction inserted or deleted rows
--   matching your WHERE condition between your two reads.
--
-- Key distinction from non-repeatable read:
--   Non-repeatable → same row, different VALUE  (update)
--   Phantom        → same query, different ROW COUNT (insert/delete)
--
-- Real example: counting people in a room, someone walks in silently.

-- Isolation level that prevents it: Serializable only.

-- Simulating the scenario (conceptual):

-- Transaction A:
--   SELECT COUNT(*) FROM orders_status WHERE amount > 500;
--   -- Returns: 1 (only order 1002 at ₹820)   ← first read

-- Transaction B (runs and commits):
--   INSERT INTO orders_status VALUES (1004, 'pending', 750.00);
--   COMMIT;

-- Transaction A (same transaction, same query):
--   SELECT COUNT(*) FROM orders_status WHERE amount > 500;
--   -- At Repeatable Read: returns 2  ← phantom row appeared (order 1004)
--   -- At Serializable:    returns 1  ← range locked, insert was blocked


-- ── Q4: The four isolation levels — summary query ─────────
--
-- Isolation level   | Dirty Read | Non-Repeatable | Phantom | Speed
-- Read Uncommitted  |  possible  |   possible     | possible| fastest
-- Read Committed    | prevented  |   possible     | possible| fast (PG default)
-- Repeatable Read   | prevented  |  prevented     | possible| medium (MySQL default)
-- Serializable      | prevented  |  prevented     | prevented| slowest

-- Check current isolation level in PostgreSQL:
SHOW transaction_isolation;

-- Set isolation level for a transaction:
BEGIN;
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
-- ... your queries here ...
COMMIT;

-- When to use each:
--   Read Committed  → default for most OLTP workloads (safe + performant)
--   Repeatable Read → reports that read same row multiple times
--   Serializable    → financial systems, bank transfers, payroll


-- ============================================================
-- SECTION 2: JOIN TYPES
-- ============================================================
-- Interview context:
--   JOINs are how you combine data from multiple tables.
--   Wrong JOIN type silently drops rows — classic silent pipeline bug.
--   Example: INNER JOIN on delivery table drops cash-on-delivery
--   orders with no delivery record yet → revenue understated.
-- ============================================================

-- ── Sample data ───────────────────────────────────────────

CREATE TABLE customers (
    customer_id INT,
    name        VARCHAR(50),
    city        VARCHAR(50)
);

CREATE TABLE customer_orders (
    order_id    INT,
    customer_id INT,
    amount      DECIMAL(10,2)
);

INSERT INTO customers VALUES
(1, 'Anna',  'Mumbai'),
(2, 'Raj',   'Delhi'),
(3, 'Priya', 'Pune'),
(4, 'Kiran', 'Chennai');  -- no orders yet

INSERT INTO customer_orders VALUES
(101, 1, 500.00),   -- Anna's order
(102, 2, 300.00),   -- Raj's order
(103, 2, 800.00),   -- Raj's second order
(104, 5, 200.00);   -- customer_id=5 doesn't exist in customers


-- ── Q5: INNER JOIN — only matching rows on both sides ─────

SELECT
    c.name,
    o.order_id,
    o.amount
FROM customers c
INNER JOIN customer_orders o
    ON c.customer_id = o.customer_id;

-- Result:
-- Anna   101   500.00  ← matched
-- Raj    102   300.00  ← matched
-- Raj    103   800.00  ← matched
-- Kiran dropped: no order          (unmatched left side)
-- order 104 dropped: no customer   (unmatched right side)
--
-- Use when: you only want rows that have a match in BOTH tables.
-- Risk:     silently drops rows without a match — no error, no warning.


-- ── Q6: LEFT JOIN — all rows from left, NULL if no match ──

SELECT
    c.name,
    o.order_id,
    o.amount
FROM customers c
LEFT JOIN customer_orders o
    ON c.customer_id = o.customer_id;

-- Result:
-- Anna   101    500.00  ← matched
-- Raj    102    300.00  ← matched
-- Raj    103    800.00  ← matched
-- Kiran  NULL   NULL    ← kept with NULLs (no order, but customer exists)
-- order 104 still dropped (unmatched right side)
--
-- Use when: you want ALL rows from the left table, matched or not.
-- Real DE use case: find customers who have NEVER placed an order.

-- Finding customers with no orders using LEFT JOIN:
SELECT
    c.customer_id,
    c.name,
    c.city
FROM customers c
LEFT JOIN customer_orders o
    ON c.customer_id = o.customer_id
WHERE o.order_id IS NULL;
-- Returns: Kiran (the only customer with no orders)


-- ── Q7: RIGHT JOIN — all rows from right, NULL if no match

SELECT
    c.name,
    o.order_id,
    o.amount
FROM customers c
RIGHT JOIN customer_orders o
    ON c.customer_id = o.customer_id;

-- Result:
-- Anna   101   500.00  ← matched
-- Raj    102   300.00  ← matched
-- Raj    103   800.00  ← matched
-- NULL   104   200.00  ← kept with NULLs (order exists but no customer)
-- Kiran dropped (unmatched left side)
--
-- Use when: you want ALL rows from the right table, matched or not.
-- Real DE use case: find orders with no matching customer record
--                  (signals a data quality problem).
--
-- Practical note: RIGHT JOIN is rarely written in production.
-- The same result can always be rewritten as a LEFT JOIN
-- by swapping the table order — which is more readable:

SELECT
    c.name,
    o.order_id,
    o.amount
FROM customer_orders o
LEFT JOIN customers c
    ON o.customer_id = c.customer_id;
-- Identical result to the RIGHT JOIN above


-- ── Q8: The silent pipeline bug — wrong JOIN drops revenue ─
--
-- Real scenario: calculating GMV from orders + payments + delivery.
-- Cash-on-delivery orders have no delivery record until rider arrives.
-- INNER JOIN silently drops them → revenue understated.

CREATE TABLE pipeline_orders (
    order_id     INT,
    order_value  DECIMAL(10,2),
    payment_type VARCHAR(20)
);

CREATE TABLE delivery_records (
    delivery_id  INT,
    order_id     INT,
    status       VARCHAR(20)
);

INSERT INTO pipeline_orders VALUES
(1001, 300.00, 'UPI'),
(1002, 500.00, 'Card'),
(1003, 200.00, 'Cash'),   -- cash on delivery, no delivery record yet
(1004, 400.00, 'UPI');

INSERT INTO delivery_records VALUES
(1, 1001, 'Delivered'),
(2, 1002, 'Delivered'),
(3, 1004, 'Delivered');
-- Order 1003 (cash) has no delivery record

-- ❌ WRONG: INNER JOIN silently drops order 1003
SELECT SUM(o.order_value) AS wrong_gmv
FROM pipeline_orders o
INNER JOIN delivery_records d
    ON o.order_id = d.order_id;
-- Result: ₹1200 (missing ₹200 from order 1003)

-- ✅ CORRECT: LEFT JOIN keeps all orders
SELECT SUM(o.order_value) AS correct_gmv
FROM pipeline_orders o
LEFT JOIN delivery_records d
    ON o.order_id = d.order_id;
-- Result: ₹1400 (all orders included)

-- The row count sanity check would catch this:
-- ₹1200 vs last week's ₹1400 = 14% drop → within ±25% but still worth checking
-- Revenue sanity check: ₹1200 vs same weekday ₹1400 = 14% drop → investigate


-- ============================================================
-- SECTION 3: LAG AND CALENDAR DATE COMPARISONS
-- ============================================================
-- Interview context:
--   LAG counts rows, not days. If data has gaps (holidays, failed
--   pipeline runs), LAG(revenue, 7) gives you "7 rows back" which
--   could be a different weekday. Use a self-join for calendar accuracy.
-- ============================================================

CREATE TABLE revenue_with_gaps (
    order_date DATE,
    city       VARCHAR(50),
    revenue    DECIMAL(10,2)
);

INSERT INTO revenue_with_gaps VALUES
('2026-05-12', 'Mumbai', 10000),  -- Monday
('2026-05-13', 'Mumbai', 12000),  -- Tuesday
-- May 14 (Wednesday) missing: holiday
('2026-05-15', 'Mumbai', 13000),  -- Thursday
('2026-05-16', 'Mumbai', 15000),  -- Friday
('2026-05-17', 'Mumbai', 20000),  -- Saturday
('2026-05-18', 'Mumbai', 18000),  -- Sunday
('2026-05-19', 'Mumbai', 10500),  -- Monday
('2026-05-20', 'Mumbai', 12800),  -- Tuesday
('2026-05-21', 'Mumbai', 11000),  -- Wednesday
('2026-05-22', 'Mumbai', 14000);  -- Thursday


-- ── Q9: Wrong — LAG(7) silently compares wrong weekday ────

SELECT
    order_date,
    TO_CHAR(order_date, 'Day')         AS current_weekday,
    revenue,
    LAG(revenue, 7) OVER (
        ORDER BY order_date
    )                                  AS wrong_last_week_revenue,
    -- May 21 (Wed) compares against May 13 (Tue) after the gap
    TO_CHAR(order_date - 7, 'Day')     AS expected_weekday
FROM revenue_with_gaps
ORDER BY order_date;

-- Note: TO_CHAR is PostgreSQL. BigQuery: FORMAT_DATE('%A', order_date)


-- ── Q10: Correct — self-join on exact calendar date ───────

SELECT
    t.order_date,
    TO_CHAR(t.order_date, 'Day')       AS weekday,
    t.revenue                          AS current_revenue,
    lw.revenue                         AS last_week_revenue,
    -- NULL when last week date is missing (honest, not wrong)
    ROUND(
        (t.revenue - lw.revenue)
        / lw.revenue * 100,
        2
    )                                  AS pct_change
FROM revenue_with_gaps t
LEFT JOIN revenue_with_gaps lw
    ON  lw.order_date = t.order_date - INTERVAL '7 days'
    AND lw.city       = t.city
ORDER BY t.order_date;

-- When last week's date is missing: pct_change = NULL (visible and honest)
-- LAG would have given a number — just the wrong one


-- ============================================================
-- SECTION 4: ROWS vs RANGE IN WINDOW FRAMES
-- ============================================================
-- Interview context:
--   SQL default when ORDER BY is present = RANGE (not ROWS).
--   RANGE groups all rows with the same ORDER BY value together.
--   With duplicate dates this silently pulls in future rows
--   making running totals jump and repeat unexpectedly.
-- ============================================================

CREATE TABLE orders_duplicates (
    row_num    INT,
    order_date DATE,
    revenue    DECIMAL(10,2)
);

INSERT INTO orders_duplicates VALUES
(1, '2026-05-01', 100),
(2, '2026-05-02', 200),
(3, '2026-05-02', 300),  -- duplicate date
(4, '2026-05-03', 400),
(5, '2026-05-03', 500),  -- duplicate date
(6, '2026-05-04', 600);


-- ── Q11: RANGE (default) vs ROWS — side by side ───────────

SELECT
    row_num,
    order_date,
    revenue,
    -- ROWS: each physical row is independent — predictable
    SUM(revenue) OVER (
        ORDER BY order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                  AS rows_running_total,
    -- RANGE: groups duplicate dates — silently includes future rows
    SUM(revenue) OVER (
        ORDER BY order_date
        RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        -- This is also what SQL uses silently when you write:
        -- SUM(revenue) OVER (ORDER BY order_date)
    )                                  AS range_running_total
FROM orders_duplicates
ORDER BY row_num;

-- Expected ROWS:  100, 300, 600, 1000, 1500, 2100  ← correct
-- Actual RANGE:   100, 600, 600, 1500, 1500, 2100  ← jumps and repeats
--
-- RANGE row 2 (May 2, ₹200) sees both May 2 rows (200+300) from start = 600
-- RANGE row 3 (May 2, ₹300) sees same window as row 2           = 600
-- Rule: always write ROWS explicitly. Never rely on the RANGE default.


-- ============================================================
-- SECTION 5: LAST_VALUE DEFAULT FRAME BUG
-- ============================================================
-- Interview context:
--   LAST_VALUE with ORDER BY only sees rows up to the current row
--   due to the default frame. It returns the current row's own
--   value every time — not the partition's last value.
--   FIRST_VALUE works fine with the default. LAST_VALUE does not.
-- ============================================================

CREATE TABLE daily_sales (
    sale_date DATE,
    city      VARCHAR(50),
    revenue   DECIMAL(10,2)
);

INSERT INTO daily_sales VALUES
('2026-05-01', 'Mumbai', 100),
('2026-05-02', 'Mumbai', 200),
('2026-05-03', 'Mumbai', 300),
('2026-05-04', 'Mumbai', 400);


-- ── Q12: LAST_VALUE broken vs fixed ───────────────────────

SELECT
    sale_date,
    revenue,
    -- ❌ WRONG: returns current row's own value (useless)
    LAST_VALUE(revenue) OVER (
        PARTITION BY city
        ORDER BY sale_date
        -- default: RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                  AS wrong_last_value,

    -- ✅ CORRECT: extend frame to end of partition
    LAST_VALUE(revenue) OVER (
        PARTITION BY city
        ORDER BY sale_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    )                                  AS correct_last_value,

    -- FIRST_VALUE: works fine with default frame (frame always starts at beginning)
    FIRST_VALUE(revenue) OVER (
        PARTITION BY city
        ORDER BY sale_date
    )                                  AS first_value
FROM daily_sales
ORDER BY sale_date;

-- wrong_last_value:   100, 200, 300, 400  ← mirrors itself (useless)
-- correct_last_value: 400, 400, 400, 400  ← last day's revenue on every row
-- first_value:        100, 100, 100, 100  ← first day's revenue on every row


-- ── Q13: Partition total vs running total ─────────────────

SELECT
    sale_date,
    revenue,
    -- No ORDER BY → sees all rows → same total on every row
    SUM(revenue) OVER (
        PARTITION BY city
    )                                  AS partition_total,

    -- With ORDER BY (default frame) → grows each row → running total
    SUM(revenue) OVER (
        PARTITION BY city
        ORDER BY sale_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                  AS running_total
FROM daily_sales
ORDER BY sale_date;

-- partition_total: 1000, 1000, 1000, 1000  ← same on every row
-- running_total:    100,  300,  600, 1000  ← grows each row


-- ============================================================
-- SECTION 6: SESSIONISATION
-- ============================================================
-- Interview context:
--   Group user events into sessions where a new session starts
--   after 30 minutes of inactivity. Classic analytics engineering
--   problem asked at data-heavy companies (Tempus, Amazon, Flatiron).
--
-- Pattern to memorise:
--   LAG → gap in minutes → CASE flag → running SUM = session_id
--
-- Why NULL is flagged as 1:
--   NULL means no previous event = first event per user = session 1 start.
--   Without NULL=1: session 1 never created, all IDs off by one.
-- ============================================================

CREATE TABLE user_events (
    user_id    VARCHAR(10),
    event_time TIMESTAMP
);

INSERT INTO user_events VALUES
('user_A', '2026-05-26 10:00:00'),
('user_A', '2026-05-26 10:05:00'),
('user_A', '2026-05-26 10:20:00'),
('user_A', '2026-05-26 10:51:00'),  -- 31 min gap → new session
('user_A', '2026-05-26 10:55:00'),
('user_A', '2026-05-26 11:40:00'),  -- 45 min gap → new session
('user_B', '2026-05-26 09:00:00'),
('user_B', '2026-05-26 09:15:00'),
('user_B', '2026-05-26 10:00:00'),  -- 45 min gap → new session
('user_B', '2026-05-26 10:10:00');


-- ── Q14: Assign session IDs using LAG + running SUM ───────
--
-- Note: EXTRACT(EPOCH FROM interval) is PostgreSQL syntax.
--       BigQuery:   TIMESTAMP_DIFF(event_time, prev_time, MINUTE)
--       Snowflake:  DATEDIFF('minute', prev_time, event_time)
--       ::NUMERIC   is PostgreSQL cast syntax for ROUND()

WITH event_gaps AS (
    -- Step 1: find previous event time and calculate gap in minutes
    SELECT
        user_id,
        event_time,
        LAG(event_time) OVER (
            PARTITION BY user_id
            ORDER BY event_time
        )                              AS prev_event_time,
        EXTRACT(EPOCH FROM (
            event_time - LAG(event_time) OVER (
                PARTITION BY user_id
                ORDER BY event_time
            )
        )) / 60.0                      AS minutes_since_last
    FROM user_events
),
session_flags AS (
    -- Step 2: flag every session boundary
    SELECT
        *,
        CASE
            WHEN minutes_since_last IS NULL  -- first event per user
              OR minutes_since_last > 30     -- inactivity > 30 min
            THEN 1
            ELSE 0
        END                            AS new_session_flag
    FROM event_gaps
)
-- Step 3: running SUM of flags = session_id
SELECT
    user_id,
    event_time,
    ROUND(minutes_since_last::NUMERIC, 1)  AS minutes_since_last,
    new_session_flag,
    SUM(new_session_flag) OVER (
        PARTITION BY user_id
        ORDER BY event_time
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        -- Using ROWS explicitly (not default RANGE)
    )                                      AS session_id
FROM session_flags
ORDER BY user_id, event_time;

-- Expected output:
-- user_id  event_time  minutes  flag  session_id
-- user_A   10:00       NULL     1     1   ← session 1 starts
-- user_A   10:05       5.0      0     1
-- user_A   10:20       15.0     0     1
-- user_A   10:51       31.0     1     2   ← session 2 starts (31 > 30)
-- user_A   10:55       4.0      0     2
-- user_A   11:40       45.0     1     3   ← session 3 starts
-- user_B   09:00       NULL     1     1   ← session 1 starts
-- user_B   09:15       15.0     0     1
-- user_B   10:00       45.0     1     2   ← session 2 starts
-- user_B   10:10       10.0     0     2


-- ── Q15: Business value — sessions per user and avg length ─

WITH event_gaps AS (
    SELECT
        user_id,
        event_time,
        EXTRACT(EPOCH FROM (
            event_time - LAG(event_time) OVER (
                PARTITION BY user_id ORDER BY event_time
            )
        )) / 60.0                      AS minutes_since_last
    FROM user_events
),
session_flags AS (
    SELECT
        *,
        CASE
            WHEN minutes_since_last IS NULL OR minutes_since_last > 30
            THEN 1 ELSE 0
        END                            AS new_session_flag
    FROM event_gaps
),
sessions AS (
    SELECT
        user_id,
        event_time,
        SUM(new_session_flag) OVER (
            PARTITION BY user_id
            ORDER BY event_time
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        )                              AS session_id
    FROM session_flags
)
SELECT
    user_id,
    session_id,
    MIN(event_time)                    AS session_start,
    MAX(event_time)                    AS session_end,
    COUNT(*)                           AS events_in_session,
    ROUND(
        EXTRACT(EPOCH FROM (
            MAX(event_time) - MIN(event_time)
        )) / 60.0::NUMERIC,
        1
    )                                  AS session_duration_minutes
FROM sessions
GROUP BY user_id, session_id
ORDER BY user_id, session_id;

-- Real business questions this answers:
--   How many sessions per user per day?
--   What is the average session length?
--   Which sessions end in a purchase? (join to orders table)
--   Where do users drop off within a session?


-- ============================================================
-- QUICK REFERENCE — ALL CONCEPTS
-- ============================================================

-- ISOLATION LEVELS (weakest → strongest):
--   Read Uncommitted → prevents nothing     (avoid in production)
--   Read Committed   → prevents dirty reads  (PostgreSQL default)
--   Repeatable Read  → + non-repeatable     (MySQL default)
--   Serializable     → prevents all three   (financial systems)

-- JOIN TYPES:
--   INNER JOIN → only matching rows on both sides (drops unmatched)
--   LEFT JOIN  → all left rows + NULLs for unmatched right
--   RIGHT JOIN → all right rows + NULLs for unmatched left
--                (rarely written — rewrite as LEFT JOIN instead)
--   Silent bug: INNER JOIN drops rows with no delivery record
--               → revenue understated → no error, no warning

-- LAG vs calendar join:
--   LAG(col, 7)                      → 7 rows back → wrong on gaps
--   JOIN ON date - INTERVAL '7 days' → exact calendar → NULL on missing

-- ROWS vs RANGE:
--   ROWS  → physical row position → safe with duplicates
--   RANGE → grouped by value → pulls in duplicate-date rows silently
--   SQL default = RANGE (not ROWS) → always write frame explicitly

-- LAST_VALUE fix:
--   Always add: ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
--   FIRST_VALUE works fine without it

-- SUM behaviour:
--   No ORDER BY              → partition total (same on every row)
--   With ORDER BY            → running/cumulative total
--   With UNBOUNDED FOLLOWING → partition total (override default)

-- Sessionisation pattern:
--   LAG → gap in minutes → CASE (NULL=1, >30=1, else=0) → running SUM
--   NULL must be 1: no previous event = start of session 1
