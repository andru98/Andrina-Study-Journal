-- ============================================================
-- CASE STATEMENTS — Interview Patterns
-- Author : Anna Shrestha
-- Topics : CASE in SELECT, WHERE, ORDER BY, JOIN
--          NULLIF vs COALESCE
-- ============================================================


-- ------------------------------------------------------------
-- 1. CASE in SELECT — basic categorisation
-- ------------------------------------------------------------
-- Pattern: label each row based on a column value
-- Real use: trade outcome buckets, customer segments, status labels

SELECT
    symbol,
    side,
    pnl,
    CASE
        WHEN pnl >  10 THEN 'Strong Win'
        WHEN pnl >   0 THEN 'Small Win'
        WHEN pnl =   0 THEN 'Breakeven'
        WHEN pnl > -10 THEN 'Small Loss'
        ELSE                'Big Loss'
    END AS trade_result
FROM trades;

-- Interview note:
-- CASE evaluates top-down and stops at the first match.
-- Always include ELSE to handle unexpected values — without it,
-- unmatched rows return NULL silently, which is a common bug.


-- ------------------------------------------------------------
-- 2. CASE in SELECT — searched vs simple form
-- ------------------------------------------------------------

-- Simple form (equality checks only)
SELECT
    order_id,
    CASE status
        WHEN 'pending'   THEN 'Awaiting payment'
        WHEN 'confirmed' THEN 'Processing'
        WHEN 'shipped'   THEN 'On the way'
        ELSE                  'Unknown'
    END AS status_label
FROM orders;

-- Searched form (supports any condition: ranges, IS NULL, etc.)
SELECT
    customer_id,
    total_spend,
    CASE
        WHEN total_spend >= 10000 THEN 'Platinum'
        WHEN total_spend >=  5000 THEN 'Gold'
        WHEN total_spend >=  1000 THEN 'Silver'
        ELSE                           'Bronze'
    END AS tier
FROM customers;

-- Interview note:
-- Simple form is cleaner for equality; searched form is more flexible.
-- Both are valid — choose based on the condition type.


-- ------------------------------------------------------------
-- 3. CASE in ORDER BY — custom sort
-- ------------------------------------------------------------
-- Pattern: sort by business priority, not alphabetically
-- Real use: show urgent statuses first, custom dashboard ordering

SELECT
    order_id,
    status,
    created_at
FROM orders
ORDER BY
    CASE status
        WHEN 'pending'    THEN 1   -- highest priority
        WHEN 'processing' THEN 2
        WHEN 'shipped'    THEN 3
        WHEN 'delivered'  THEN 4
        ELSE                   5   -- unknown statuses last
    END,
    created_at ASC;               -- secondary sort within each group

-- Interview note:
-- CASE in ORDER BY assigns a sort number per row — SQL sorts by
-- that number. This is the correct way to implement custom ordering
-- without procedural code.


-- ------------------------------------------------------------
-- 4. CASE in WHERE — conditional filtering
-- ------------------------------------------------------------
-- Pattern: apply different filter rules based on a condition
-- Real use: role-based access, day-of-week rules, feature flags

-- Trading journal example: Friday rules differ from other days


-- Interview note:
-- CASE in WHERE returns 1 (true) or 0 (false).
-- The = 1 at the end is required — it evaluates the CASE expression
-- as a boolean condition. This pattern replaces complex OR chains
-- when filter logic changes based on context.


-- ------------------------------------------------------------
-- 5. CASE in JOIN — route to different tables per row
-- ------------------------------------------------------------
-- Pattern: join to different tables depending on a flag column
-- Real use: digital vs physical orders, options vs shares

SELECT
    o.order_id,
    o.is_digital,
    CASE
        WHEN o.is_digital = 1 THEN dd.tracking_id
        ELSE                       pd.tracking_id
    END AS tracking_id
FROM orders o
LEFT JOIN digital_delivery  dd ON o.order_id = dd.order_id AND o.is_digital = 1
LEFT JOIN physical_delivery pd ON o.order_id = pd.order_id AND o.is_digital = 0;

-- Interview note:
-- Both JOINs run on every row but only one finds data per row —
-- the other returns NULL. CASE then picks whichever side is populated.
-- Alternative: UNION of two filtered queries — valid but less efficient
-- as it requires two passes over the table.


-- ------------------------------------------------------------
-- 6. NULLIF vs COALESCE
-- ------------------------------------------------------------

-- NULLIF(a, b): returns NULL when a = b, otherwise returns a
-- Primary use case: prevent division by zero

-- Without NULLIF — crashes when total_sessions = 0
SELECT conversions / total_sessions AS cvr
FROM campaign_stats;

-- With NULLIF — returns NULL safely instead of crashing
SELECT
    campaign_id,
    conversions / NULLIF(total_sessions, 0) AS cvr
FROM campaign_stats;

-- COALESCE(a, b, c, ...): returns the first non-NULL value
-- Primary use case: substitute a default when data is missing

SELECT
    user_id,
    COALESCE(preferred_name, first_name, 'Unknown') AS display_name
FROM users;

-- Production pattern — combine both:
-- NULLIF prevents crash, COALESCE replaces NULL with a safe default
SELECT
    campaign_id,
    COALESCE(
        conversions / NULLIF(total_sessions, 0),
        0
    ) AS cvr
FROM campaign_stats;

-- Interview note:
-- NULLIF   = protection (crash prevention)
-- COALESCE = substitution (default value)
-- They solve different problems. Combined they give you both.
-- COUNTIF does not exist in SQL — that is an Excel function.


-- ------------------------------------------------------------
-- 7. LeetCode practice — using CASE
-- ------------------------------------------------------------

-- LC 627: Swap Salary
-- Swap all 'm' to 'f' and 'f' to 'm' in a single UPDATE
UPDATE salary
SET sex = CASE sex
    WHEN 'm' THEN 'f'
    ELSE          'm'
END;

-- LC 1179: Reformat Department Table
-- Pivot monthly revenue into columns using CASE + MAX + GROUP BY
SELECT
    id,
    MAX(CASE WHEN month = 'Jan' THEN revenue END) AS Jan_revenue,
    MAX(CASE WHEN month = 'Feb' THEN revenue END) AS Feb_revenue,
    MAX(CASE WHEN month = 'Mar' THEN revenue END) AS Mar_revenue,
    MAX(CASE WHEN month = 'Apr' THEN revenue END) AS Apr_revenue,
    MAX(CASE WHEN month = 'May' THEN revenue END) AS May_revenue,
    MAX(CASE WHEN month = 'Jun' THEN revenue END) AS Jun_revenue,
    MAX(CASE WHEN month = 'Jul' THEN revenue END) AS Jul_revenue,
    MAX(CASE WHEN month = 'Aug' THEN revenue END) AS Aug_revenue,
    MAX(CASE WHEN month = 'Sep' THEN revenue END) AS Sep_revenue,
    MAX(CASE WHEN month = 'Oct' THEN revenue END) AS Oct_revenue,
    MAX(CASE WHEN month = 'Nov' THEN revenue END) AS Nov_revenue,
    MAX(CASE WHEN month = 'Dec' THEN revenue END) AS Dec_revenue
FROM Department
GROUP BY id
ORDER BY id;

-- Interview note:
-- This is the standard SQL PIVOT pattern — CASE inside an aggregate.
-- MAX() is used because each id+month combination has one row;
-- MAX collapses the NULLs from other months and keeps the one value.
-- This pattern appears in almost every intermediate SQL interview.
