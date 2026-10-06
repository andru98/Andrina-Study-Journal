# SQL Pattern: First/Last Value Per Group (BOP/EOP Balances)

A common analytics need: for each account and month, get the **beginning-of-period (BOP)** and **end-of-period (EOP)** balance — without collapsing all the daily rows into a meaningless `SUM(balance)`.

## The core trick: `ROW_NUMBER()` + conditional `SUM(CASE ...)`

Two window functions rank each row within a group, once ascending and once descending:

```sql
ROW_NUMBER() OVER (PARTITION BY account_id, month ORDER BY balance_date ASC)  AS rn_asc,
ROW_NUMBER() OVER (PARTITION BY account_id, month ORDER BY balance_date DESC) AS rn_desc
```

- `rn_asc = 1` → the **earliest** row in the group (BOP)
- `rn_desc = 1` → the **latest** row in the group (EOP)

Then a conditional `SUM` pivots those single flagged rows into one row per group:

```sql
SUM(CASE WHEN rn_asc  = 1 THEN balance END) AS bop_balance,
SUM(CASE WHEN rn_desc = 1 THEN balance END) AS eop_balance
```

`CASE` returns `NULL` for every row except the one that matches, and `SUM()` ignores `NULL`s — so this "picks" a single value per group without needing `DISTINCT` or a self-join. This is the standard workaround for engines where `FIRST_VALUE()`/`LAST_VALUE()` don't collapse rows on their own.

### Worked example

Raw data, one account:

| account_id | balance_date | balance |
|---|---|---|
| A1 | 2026-01-01 | 500 |
| A1 | 2026-01-05 | 800 |
| A1 | 2026-01-12 | 650 |
| A1 | 2026-01-20 | 900 |
| A1 | 2026-01-28 | 1200 |

After ranking:

| balance_date | balance | rn_asc | rn_desc |
|---|---|---|---|
| 2026-01-01 | 500 | **1** | 5 |
| 2026-01-05 | 800 | 2 | 4 |
| 2026-01-12 | 650 | 3 | 3 |
| 2026-01-20 | 900 | 4 | 2 |
| 2026-01-28 | 1200 | 5 | **1** |

Result after the conditional `SUM`, grouped:

| account_id | bop_balance | eop_balance |
|---|---|---|
| A1 | 500 | 1200 |

## Full query — per-account monthly BOP/EOP + growth

```sql
WITH daily_balances AS (
    SELECT
        account_id,
        balance_date,
        balance,
        DATE_TRUNC('month', balance_date) AS month,
        ROW_NUMBER() OVER (
            PARTITION BY account_id, DATE_TRUNC('month', balance_date)
            ORDER BY balance_date ASC
        ) AS rn_asc,   -- for BOP
        ROW_NUMBER() OVER (
            PARTITION BY account_id, DATE_TRUNC('month', balance_date)
            ORDER BY balance_date DESC
        ) AS rn_desc   -- for EOP
    FROM account_balances
),
snapshots AS (
    SELECT
        account_id,
        month,
        SUM(CASE WHEN rn_asc  = 1 THEN balance END) AS bop_balance,
        SUM(CASE WHEN rn_desc = 1 THEN balance END) AS eop_balance
    FROM daily_balances
    GROUP BY account_id, month
)
SELECT
    account_id,
    month,
    bop_balance,
    eop_balance,
    -- growth within the month (BOP -> EOP)
    ROUND(
        (eop_balance - bop_balance) * 100.0 / NULLIF(bop_balance, 0)
    , 2) AS within_month_growth_pct,
    -- month-over-month EOP growth, per account
    LAG(eop_balance) OVER (PARTITION BY account_id ORDER BY month) AS prev_eop,
    ROUND(
        (eop_balance - LAG(eop_balance) OVER (PARTITION BY account_id ORDER BY month)) * 100.0
        / NULLIF(LAG(eop_balance) OVER (PARTITION BY account_id ORDER BY month), 0)
    , 2) AS mom_eop_growth_pct
FROM snapshots
ORDER BY account_id, month;
```

### Key design decision: `GROUP BY account_id, month` vs `GROUP BY month` only

- **`GROUP BY account_id, month`** (above) → one row per account per month. Lets you compare each account's own trend, and `LAG() OVER (PARTITION BY account_id ...)` correctly compares an account against *its own* prior month.
- **`GROUP BY month` only** → collapses every account into a single portfolio-level total per month. Useful for an aggregate view, but you lose per-account detail, and a plain `LAG() OVER (ORDER BY month)` (no `PARTITION BY`) would be comparing across the wrong grain if account-level rows ever leaked in.

Pick the grain based on what the question is: "how did account X do this month?" → per-account. "How did the whole book do this month?" → aggregate.

## Why not just `FIRST_VALUE()` / `LAST_VALUE()`?

They compute a value per row (not per group), so you'd still end up needing `DISTINCT` or an extra `GROUP BY` pass to collapse duplicates — at which point the `ROW_NUMBER()` + conditional `SUM` approach ends up being both more explicit and easier to extend (e.g., adding more picked columns, or combining with other aggregates like `SUM(deposits)`, `COUNT(txns)` in the same result row).
