# SQL Pattern: Active Subscriptions & MRR (Date-Range Overlap)

SaaS companies (Salesforce, HubSpot, Stripe, etc.) frame growth metrics around **MRR (Monthly Recurring Revenue)**. Unlike a transactions table where you just `SUM(amount)`, a subscriptions table has a `start_date` and (often nullable) `end_date` per row — so "how much revenue was active in March?" requires checking **date-range overlap**, not a simple filter or sum.

## The core idea: subscriptions are date ranges, not events

Think of each subscription as a bar on a timeline (like a hotel reservation), not a single point-in-time transaction:

```
Subscription bar:        [=====================]
                       start_date          end_date
```

A subscription is "active in month M" if its bar **touches** month M anywhere — even for a single day. That's an interval-overlap check, and the standard condition for it is:

```sql
start_date <= month_end
AND (end_date IS NULL OR end_date >= month_start)
```

Both halves must be true:
- the subscription **started on or before** the month ends
- the subscription **either never ended, or ended on or after** the month begins

If either half is false, the two ranges can't possibly touch.

## Sample data

```
subscriptions
--------------
subscription_id | customer_id | plan_amount | start_date | end_date

1   | 101 | 50  | 2026-01-15 | 2026-04-10
2   | 102 | 100 | 2026-02-01 | NULL          -- still active
3   | 103 | 75  | 2026-03-05 | 2026-03-20
4   | 101 | 60  | 2026-04-11 | NULL          -- plan upgrade, same customer as #1
5   | 104 | 50  | 2026-01-01 | 2026-01-31
```

Note subscriptions #1 and #4 share a customer but are **separate rows** (an upgrade) — a common trap. Counting by `subscription_id` and counting by `customer_id` give different answers here.

## Step 1 — generate the list of months to check

There's no built-in "months" table, so you build one:

```sql
WITH months AS (
    SELECT
        month_start,
        (month_start + interval '1 month' - interval '1 day')::date AS month_end
    FROM (
        SELECT generate_series(
            '2026-01-01'::date,
            '2026-12-01'::date,     -- extend as far as needed (or tie to CURRENT_DATE)
            interval '1 month'
        )::date AS month_start
    ) m
)
```

This produces one row per month, with both the first and last day computed:

| month_start | month_end |
|---|---|
| 2026-01-01 | 2026-01-31 |
| 2026-02-01 | 2026-02-28 |
| 2026-03-01 | 2026-03-31 |
| 2026-04-01 | 2026-04-30 |

## Step 2 — join months to subscriptions on the overlap condition

```sql
SELECT
    m.month_start,
    s.subscription_id,
    s.plan_amount
FROM months m
JOIN subscriptions s
    ON s.start_date <= m.month_end
   AND (s.end_date IS NULL OR s.end_date >= m.month_start)
```

Mentally this is a nested loop: *for each subscription, for each month, keep the pair only if the subscription overlaps that month.* Out of every possible (month × subscription) pairing, only the true overlaps survive.

Visual walkthrough for subscription #1 (Jan 15 → Apr 10):

```
Subscription #1:              [Jan15============Apr10]

Jan:      [Jan1------Jan31]        → overlaps → KEPT
Feb:                [Feb1------Feb28]  → fully inside → KEPT
Mar:                          [Mar1------Mar31]  → fully inside → KEPT
Apr:                                    [Apr1--Apr10--------Apr30]  → overlaps 10 days → KEPT
May:                                                  [May1------May31]  → no touch → DROPPED
                                            (end Apr10 >= May1 is FALSE)
```

Intermediate result (before aggregation) for Jan–Apr against all 5 subscriptions:

| month_start | subscription_id | plan_amount |
|---|---|---|
| 2026-01-01 | 1 | 50 |
| 2026-01-01 | 5 | 50 |
| 2026-02-01 | 1 | 50 |
| 2026-02-01 | 2 | 100 |
| 2026-03-01 | 1 | 50 |
| 2026-03-01 | 2 | 100 |
| 2026-03-01 | 3 | 75 |
| 2026-04-01 | 1 | 50 |
| 2026-04-01 | 2 | 100 |
| 2026-04-01 | 4 | 60 |

## Step 3 — aggregate per month

```sql
SELECT
    m.month_start,
    COUNT(s.subscription_id) AS active_subscriptions,
    SUM(s.plan_amount) AS mrr
FROM months m
JOIN subscriptions s
    ON s.start_date <= m.month_end
   AND (s.end_date IS NULL OR s.end_date >= m.month_start)
GROUP BY m.month_start
ORDER BY m.month_start;
```

`GROUP BY` folds the intermediate table's rows together per month:

| month_start | active_subscriptions | mrr |
|---|---|---|
| 2026-01-01 | 2 | 100 |
| 2026-02-01 | 2 | 150 |
| 2026-03-01 | 3 | 225 |
| 2026-04-01 | 3 | 210 |

## Two equivalent ways to write the same join

**A. `JOIN ... ON <condition>`** — filtering happens as part of the join itself. This is what you'd normally write in production.

**B. `CROSS JOIN ... WHERE <condition>`** — builds *every* combination first (all months × all subscriptions, no filter), then filters afterward with `WHERE`.

```sql
-- Equivalent to the JOIN...ON version above
SELECT
    m.month_start,
    s.subscription_id,
    s.plan_amount
FROM months m
CROSS JOIN subscriptions s
WHERE s.start_date <= m.month_end
  AND (s.end_date IS NULL OR s.end_date >= m.month_start)
```

Both produce identical results. `CROSS JOIN` is a useful debugging trick: temporarily drop the `WHERE` clause to literally see the full "every pair" table, confirm its shape, then add the filter back one condition at a time to watch rows disappear — a good technique to mention in an interview, since it shows you understand joins operationally, not just as syntax.

## Why not `FIRST_VALUE`/`LAST_VALUE` or a simple `SUM`?

A plain `SUM(plan_amount)` across all rows is meaningless here — it doesn't account for *when* each subscription was active, so it would double-count revenue that only existed for one month as if it applied to every month. Window functions like `FIRST_VALUE`/`LAST_VALUE` solve a different problem (picking a value within an existing group) — they don't generate the "which months exist" dimension or check date-range overlap on their own. The `generate_series` + range-overlap join is the standard pattern specifically because there's no natural row to group by until you manufacture the month list yourself.

## Common variations to know

- **Distinct customers vs. distinct subscriptions**: `COUNT(DISTINCT s.customer_id)` vs `COUNT(s.subscription_id)` give different numbers when a customer has multiple/overlapping subscriptions (see #1/#4 above).
- **Point-in-time snapshot** instead of month range: some companies define "active" as "active on the last day of the month" rather than "active any day during the month" — swap the join condition to check a single date (`s.start_date <= month_end AND (s.end_date IS NULL OR s.end_date >= month_end)`) instead of a range.
- **Net new / churned MRR**: once you have `mrr` per month, `LAG(mrr) OVER (ORDER BY month_start)` gets you month-over-month MRR growth, same pattern as the BOP/EOP balance write-up.
