-- ============================================================
-- Advanced SQL: Partial Periods, MoM Growth, Daily Rate
-- Topic   : Time Series Analysis / Partial Period Handling
-- Level   : Mid-Senior
-- Date    : 2026-09-17
-- ============================================================

-- ============================================================
-- THE CORE PROBLEM
-- ============================================================
-- Running report on Sep 17 (mid-month):
-- August  = 31 complete days → $90,000
-- September = 17 days only  → $48,000
--
-- Raw MoM: (48,000 - 90,000) / 90,000 = -47% ❌ WRONG!
-- September is NOT declining — it's incomplete!
--
-- Two solutions:
-- 1. Daily Rate: normalize revenue by days elapsed ✅
-- 2. MTD Cutoff: compare same days across months ✅
-- ============================================================

-- ============================================================
-- SOLUTION 1: Daily Rate Normalization
-- Concept: revenue / days_elapsed = fair daily rate
-- Compare rates not totals ✅
--
-- days_elapsed logic:
-- → current month: EXTRACT(DAY FROM CURRENT_DATE)
--   "how many days have passed this month?"
-- → past months: last day of that month
--   "how many days does that month have?"
-- ============================================================

WITH monthly AS (
    SELECT
        DATE_TRUNC('month', order_date)     AS month,
        SUM(revenue)                         AS total_revenue,

        -- days elapsed: current month vs past months
        CASE
            WHEN DATE_TRUNC('month', CURRENT_DATE)
               = DATE_TRUNC('month', order_date)
            -- current month → days so far:
            THEN EXTRACT(DAY FROM CURRENT_DATE)
            -- past months → full month length:
            ELSE EXTRACT(DAY FROM
                DATE_TRUNC('month', order_date)
                + INTERVAL '1 month'        -- first day of next month
                - INTERVAL '1 day'          -- step back = last day of THIS month
            )
        END                                  AS days_elapsed,

        -- label for display:
        CASE
            WHEN DATE_TRUNC('month', CURRENT_DATE)
               = DATE_TRUNC('month', order_date)
            THEN 'partial'
            ELSE 'complete'
        END                                  AS period_status
    FROM orders
    GROUP BY 1
),
daily_rate AS (
    SELECT
        month,
        total_revenue,
        days_elapsed,
        period_status,
        -- daily rate = revenue / days:
        ROUND(total_revenue / days_elapsed, 2) AS daily_rate
    FROM monthly
)
SELECT
    month,
    total_revenue,
    days_elapsed,
    period_status,
    daily_rate,
    -- previous month daily rate:
    LAG(daily_rate) OVER (ORDER BY month)      AS prev_daily_rate,
    -- growth based on RATE not raw revenue:
    ROUND(
        (daily_rate - LAG(daily_rate) OVER (ORDER BY month)) * 100.0
        / NULLIF(LAG(daily_rate) OVER (ORDER BY month), 0)
    , 2)                                        AS mom_growth_pct
FROM daily_rate
ORDER BY month;

-- ============================================================
-- HOW days_elapsed WORKS:
--
-- Today = Sep 17, 2026
--
-- July (past month):
-- DATE_TRUNC(July) = 2026-07-01
-- + 1 month        = 2026-08-01
-- - 1 day          = 2026-07-31  ← last day of July
-- EXTRACT(DAY)     = 31 ✅
--
-- August (past month):
-- DATE_TRUNC(Aug) = 2026-08-01
-- + 1 month       = 2026-09-01
-- - 1 day         = 2026-08-31  ← last day of August
-- EXTRACT(DAY)    = 31 ✅
--
-- September (current month):
-- DATE_TRUNC(Sep) = 2026-09-01
-- matches CURRENT → THEN branch
-- EXTRACT(DAY FROM CURRENT_DATE) = 17 ✅
-- ============================================================

-- ============================================================
-- EXAMPLE OUTPUT (Today = Sep 17):
--
-- month      | revenue | days | status   | rate   | prev   | growth
-- 2026-07-01 | 4500    | 31   | complete | 145.16 | NULL   | NULL
-- 2026-08-01 | 3000    | 31   | complete | 96.77  | 145.16 | -33.34%
-- 2026-09-01 | 2800    | 17   | partial  | 164.71 | 96.77  | +70.23%
--
-- WHY DAILY RATE MATTERS:
-- Raw MoM:      Aug $3,000 vs Sep $2,800 = -6.7% ❌ looks bad
-- Daily rate:   Aug $96.77 vs Sep $164.71 = +70% ✅ actually great!
-- September only 17 days but earning MORE per day ✅
-- ============================================================

-- ============================================================
-- SOLUTION 2: MTD Cutoff (same days comparison)
-- Concept: cut all months at same day number
-- Aug 1-17 vs Sep 1-17 → apples to apples ✅
--
-- LEAST handles February edge case:
-- Today = March 30, February only has 28 days
-- LEAST(30, 28) = 28 → cut both at day 28 ✅
--
-- LEAST logic:
-- Value 1: today's day number
-- Value 2: days in previous month
-- Picks smaller → never exceed shorter month ✅
-- ============================================================

WITH mtd AS (
    SELECT
        DATE_TRUNC('month', order_date)     AS month,
        SUM(revenue)                         AS total_revenue
    FROM orders
    WHERE EXTRACT(DAY FROM order_date) <=
        LEAST(
            -- today's day number:
            EXTRACT(DAY FROM CURRENT_DATE),
            -- days in previous month:
            -- first day of current month - 1 day = last day of prev month
            EXTRACT(DAY FROM
                DATE_TRUNC('month', CURRENT_DATE)
                - INTERVAL '1 day'
            )
        )
    GROUP BY 1
)
SELECT
    month,
    total_revenue,
    LAG(total_revenue) OVER (ORDER BY month)    AS prev_mtd_revenue,
    ROUND(
        (total_revenue - LAG(total_revenue) OVER (ORDER BY month)) * 100.0
        / NULLIF(LAG(total_revenue) OVER (ORDER BY month), 0)
    , 2)                                         AS mtd_growth_pct
FROM mtd
ORDER BY month;

-- ============================================================
-- HOW LEAST WORKS:
--
-- Normal case (Today = Sep 17):
-- LEAST(17, 31) = 17  ← today's day wins
-- August cut at day 17 ✅
-- September cut at day 17 ✅
-- Fair comparison ✅
--
-- February edge case (Today = March 30):
-- LEAST(30, 28) = 28  ← February's length wins
-- March cut at day 28 ✅
-- February all 28 days ✅
-- Fair comparison ✅
--
-- HOW - INTERVAL '1 day' gives Feb 28:
-- DATE_TRUNC('month', Mar 30) = Mar 01
-- Mar 01 - 1 day              = Feb 28  ← last day of Feb
-- EXTRACT(DAY FROM Feb 28)    = 28 ✅
-- Handles leap years automatically ✅
-- ============================================================

-- ============================================================
-- WHEN TO USE WHICH:
--
-- Daily Rate:
-- ✅ business operates every day (retail, SaaS)
-- ✅ want to normalize for month length differences
-- ✅ "revenue per day" is meaningful metric
-- ✅ comparing months of different lengths
--
-- MTD Cutoff:
-- ✅ want exact same calendar days compared
-- ✅ simpler to explain to business stakeholders
-- ✅ "Aug 1-17 vs Sep 1-17" intuitive
-- ✅ most common approach in practice
-- ============================================================

-- ============================================================
-- COMMON MISTAKES:
--
-- 1. Using raw totals for partial months:
--    Sep $48,000 vs Aug $90,000 = -47% ❌ misleading
--    Normalize by days or use MTD ✅
--
-- 2. Using COUNT(DISTINCT order_date) for days:
--    Counts only days WITH orders → inflated rate ❌
--    Use actual calendar days elapsed ✅
--
-- 3. Ignoring February edge case:
--    March 30 vs February → unfair without LEAST ❌
--    LEAST(current_day, prev_month_days) ✅
--
-- 4. LAG on raw revenue for partial month:
--    Growth distorted by incomplete data ❌
--    LAG on daily_rate instead ✅
--
-- 5. Division by zero:
--    NULLIF(denominator, 0) always ✅
-- ============================================================

-- ============================================================
-- INTERVIEW TALKING POINTS:
--
-- Q: "How do you handle partial month in MoM growth?"
--
-- A: "Raw MoM comparison is misleading for incomplete months
--    because September with 17 days looks worse than August
--    with 31 days even if September is performing better.
--
--    Two approaches:
--    1. Daily rate normalization — divide revenue by days
--       elapsed, compare rates not totals. Shows true pace.
--
--    2. MTD cutoff — compare same days across months.
--       Aug 1-17 vs Sep 1-17 = apples to apples.
--       Use LEAST to handle February's shorter length.
--
--    I prefer daily rate for operational dashboards and
--    MTD cutoff for stakeholder-facing reports because
--    'same 17 days' is easier to explain." ✅
-- ============================================================

-- ============================================================
-- REAL DE USE CASES:
-- → Airline: RASK daily rate by route (partial month) ✅
-- → Ancillary revenue pace tracking mid-month ✅
-- → Sabre: booking conversion rate MTD vs prior month ✅
-- → Healthcare: patient volume daily rate by department ✅
-- → Caterpillar: equipment utilization rate partial period ✅
-- → SaaS: MRR growth rate normalized for month length ✅
-- ============================================================
