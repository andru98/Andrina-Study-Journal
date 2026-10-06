# Sessionization: Follow-Up Questions I Should Be Ready For

My revision notes for the questions that usually come *after* the main sessionization problem. This is a companion to `sessionization-gaps-islands-pattern.md`, which covers the core pattern (30-minute idle gap, then a 4-hour cap).

Everything below was run on test data and the outputs shown are the real results. Queries are written for Postgres. Where another engine differs, I say so.

---

## Test data

Twelve events, four users. U4 has two events at the exact same second on purpose (used in section 6).

| event_id | user_id | session_id | event_time | page |
|---|---|---|---|---|
| 1 | U1 | 1 | 09:00:00 | Home |
| 2 | U1 | 1 | 09:05:00 | Product |
| 3 | U1 | 1 | 09:10:00 | Cart |
| 4 | U1 | 1 | 09:15:00 | Checkout |
| 5 | U1 | 2 | 11:00:00 | Search |
| 6 | U1 | 2 | 11:10:00 | Blog |
| 7 | U2 | 1 | 10:00:00 | Home |
| 8 | U2 | 1 | 10:20:00 | Pricing |
| 9 | U3 | 1 | 14:00:00 | Home |
| 10 | U4 | 1 | 15:00:00 | Blog |
| 11 | U4 | 1 | 15:00:00 | Home |
| 12 | U4 | 1 | 15:10:00 | Cart |

```sql
CREATE TABLE events (
    event_id   INT,
    user_id    TEXT,
    session_id INT,
    event_time TIMESTAMP,
    page       TEXT
);

INSERT INTO events VALUES
    (1,  'U1', 1, '2026-01-01 09:00:00', 'Home'),
    (2,  'U1', 1, '2026-01-01 09:05:00', 'Product'),
    (3,  'U1', 1, '2026-01-01 09:10:00', 'Cart'),
    (4,  'U1', 1, '2026-01-01 09:15:00', 'Checkout'),
    (5,  'U1', 2, '2026-01-01 11:00:00', 'Search'),
    (6,  'U1', 2, '2026-01-01 11:10:00', 'Blog'),
    (7,  'U2', 1, '2026-01-01 10:00:00', 'Home'),
    (8,  'U2', 1, '2026-01-01 10:20:00', 'Pricing'),
    (9,  'U3', 1, '2026-01-01 14:00:00', 'Home'),
    (10, 'U4', 1, '2026-01-01 15:00:00', 'Blog'),
    (11, 'U4', 1, '2026-01-01 15:00:00', 'Home'),
    (12, 'U4', 1, '2026-01-01 15:10:00', 'Cart');
```

---

## 1. Is `event_time` a DATE or a TIMESTAMP?

Worth asking before writing any SQL, because the 30-minute rule only works on a timestamp.

| Column type | `a - b` returns (Postgres) | Works with `> INTERVAL '30 minutes'`? |
|---|---|---|
| `TIMESTAMP` | an interval, like `00:25:00` | Yes |
| `DATE` | an integer number of days | No, type error |

A DATE has no time of day, so a 30-minute gap can't even be expressed. I'd ask for the real event timestamp.

Other engines don't use the `-` with interval syntax. A portable way is to compare in **seconds**:

| Engine | Gap greater than 30 minutes |
|---|---|
| Postgres | `EXTRACT(EPOCH FROM (event_time - prev)) > 1800` |
| MySQL | `TIMESTAMPDIFF(SECOND, prev, event_time) > 1800` |
| SQL Server | `DATEDIFF(SECOND, prev, event_time) > 1800` |
| Snowflake | `DATEDIFF('second', prev, event_time) > 1800` |
| BigQuery | `TIMESTAMP_DIFF(event_time, prev, SECOND) > 1800` |

Use seconds, not minutes. In several engines, minute-level `DATEDIFF` counts clock boundaries crossed instead of real elapsed time, which causes off-by-one errors.

---

## 2. The 4-hour cap: what happens at exactly 4h00m?

Two formulas, two different answers right at the boundary.

| Elapsed since session start | `FLOOR(x / 4h)` | `GREATEST(CEIL(x / 4h) - 1, 0)` |
|---|---|---|
| 3h59m | 0 | 0 |
| **4h00m** | **1** | **0** |
| 4h00m01s | 1 | 1 |
| **8h00m** | **2** | **1** |
| 8h00m01s | 2 | 2 |

- `FLOOR` treats each chunk as `[0, 4h)`, so exactly 4h already starts a new session.
- `CEIL - 1` treats each chunk as `(0, 4h]`, so exactly 4h is still inside the session.

My 30-minute rule uses strict `>`, so a gap of exactly 30 minutes stays in the same session. For consistency, "capped at 4 hours" should also let exactly 4h stay in. That is the `CEIL - 1` version.

### What `GREATEST` is doing

`GREATEST(a, b)` returns the bigger of the two. In `GREATEST(CEIL(...) - 1, 0)` it only matters for the first row of a session, where elapsed time is 0:

| Row | elapsed / 4h | `CEIL(...) - 1` | after `GREATEST(..., 0)` |
|---|---|---|---|
| first row (0h) | 0.0 | **-1** | **0** |
| 1h | 0.25 | 0 | 0 |
| 4h | 1.0 | 0 | 0 |
| 4h00m01s | 1.00007 | 1 | 1 |

Without it, the first row would land in chunk -1.

### Full query, with a boundary test row

The test data has an event every 30 minutes from 08:00 to exactly 12:00:00, plus one row at 12:00:01. I'm checking that the 4h00m row stays in chunk 0 and the next second starts chunk 1.

```sql
WITH clickstream AS (   -- test data; replace with the real table
    SELECT 'U1' AS user_id, ts AS event_time
    FROM generate_series(
        TIMESTAMP '2026-01-01 08:00:00',
        TIMESTAMP '2026-01-01 12:00:00',
        INTERVAL '30 minutes'
    ) AS t(ts)
    UNION ALL
    SELECT 'U1', TIMESTAMP '2026-01-01 12:00:01'
),
time_gaps AS (
    SELECT
        user_id,
        event_time,
        CASE
            WHEN LAG(event_time) OVER (PARTITION BY user_id ORDER BY event_time) IS NULL
              OR event_time - LAG(event_time) OVER (PARTITION BY user_id ORDER BY event_time) > INTERVAL '30 minutes'
            THEN 1 ELSE 0
        END AS timeout_flag
    FROM clickstream
),
preliminary_sessions AS (
    SELECT
        user_id,
        event_time,
        SUM(timeout_flag) OVER (PARTITION BY user_id ORDER BY event_time) AS prelim_session_id
    FROM time_gaps
),
with_session_start AS (
    SELECT
        user_id,
        event_time,
        prelim_session_id,
        MIN(event_time) OVER (PARTITION BY user_id, prelim_session_id) AS session_start
    FROM preliminary_sessions
),
final_sessions AS (
    SELECT
        user_id,
        event_time,
        prelim_session_id,
        session_start,
        GREATEST(
            CEIL(EXTRACT(EPOCH FROM (event_time - session_start)) / (4 * 3600)) - 1,
            0
        ) AS duration_chunk_index
    FROM with_session_start
)
SELECT
    user_id,
    prelim_session_id,
    duration_chunk_index,
    MIN(event_time) AS session_start,
    MAX(event_time) AS session_end,
    COUNT(*)        AS event_count
FROM final_sessions
GROUP BY user_id, prelim_session_id, duration_chunk_index
ORDER BY user_id, prelim_session_id, duration_chunk_index;
```

Result:

| user_id | prelim_session_id | duration_chunk_index | session_start | session_end | event_count |
|---|---|---|---|---|---|
| U1 | 1 | 0 | 08:00:00 | 12:00:00 | 9 |
| U1 | 1 | 1 | 12:00:01 | 12:00:01 | 1 |

The first session ends at exactly 4h00m and keeps the 12:00:00 row. The row one second later starts the next session. The same test data also checks the 30-minute rule: the gap from 11:30 to 12:00:00 is exactly 30 minutes, and because the flag uses strict `>`, it stays one session.

**What I'd say out loud:** "Before I code the cap, I'd confirm whether exactly four hours is allowed. My 30-minute rule uses strict greater-than, so I'd stay consistent and use a ceiling-minus-one. If exactly four hours should start a new session, it's a plain floor. Either way I'd add a test row at exactly 4h00m."

---

## 3. Landing page and exit page

The landing page is the page at the user's **first** event in the session. The exit page is the page at the **last** event.

### Why `MIN(page)` is wrong

`MIN` on text returns the alphabetically smallest value, not the earliest one.

| event_time | page |
|---|---|
| 09:00 | Home |
| 09:05 | Product |
| 09:10 | Cart |
| 09:15 | Checkout |

| Expression | Returns | Correct? |
|---|---|---|
| `MIN(page)` | Cart | No, the real landing page is Home |
| `MAX(page)` | Product | No, the real exit page is Checkout |

`MIN(event_time)` is fine for `session_start`, because the value I want is the time itself. For the page at the earliest time, I need an ordered lookup.

### Option A: `MIN_BY` / `MAX_BY` (shortest, no sort needed)

```sql
SELECT
    user_id,
    session_id,
    MIN(event_time)          AS session_start,
    MAX(event_time)          AS session_end,
    MIN_BY(page, event_time) AS landing_page,
    MAX_BY(page, event_time) AS exit_page,
    COUNT(*)                 AS events
FROM events
GROUP BY user_id, session_id;
```

Works in Spark/Databricks (3.0+), Snowflake, DuckDB. Postgres doesn't have it. There I'd use `(ARRAY_AGG(page ORDER BY event_time ASC))[1]` for landing and `... DESC)[1]` for exit.

| user_id | session_id | session_start | session_end | landing_page | exit_page | events |
|---|---|---|---|---|---|---|
| U1 | 1 | 09:00 | 09:15 | Home | Checkout | 4 |
| U1 | 2 | 11:00 | 11:10 | Search | Blog | 2 |
| U2 | 1 | 10:00 | 10:20 | Home | Pricing | 2 |
| U3 | 1 | 14:00 | 14:00 | Home | Home | 1 |
| U4 | 1 | 15:00 | 15:10 | Blog | Cart | 3 |

(Row order can differ between runs unless there's an `ORDER BY`.)

### Option B: window functions

```sql
WITH windowed AS (
    SELECT
        user_id,
        session_id,
        event_time,
        FIRST_VALUE(page) OVER w_full AS landing_page,
        LAST_VALUE(page)  OVER w_full AS exit_page
    FROM events
    WINDOW w_full AS (
        PARTITION BY user_id, session_id
        ORDER BY event_time
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    )
)
SELECT
    user_id,
    session_id,
    MIN(event_time) AS session_start,
    MAX(event_time) AS session_end,
    landing_page,
    exit_page,
    COUNT(*) AS events
FROM windowed
GROUP BY user_id, session_id, landing_page, exit_page;
```

**The frame trap.** `LAST_VALUE` without the `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING` frame uses the default frame, which stops at the current row. So it just returns the current row's own page:

| event_time | page | `LAST_VALUE`, default frame | `LAST_VALUE`, full frame |
|---|---|---|---|
| 09:00 | Home | Home | Checkout |
| 09:05 | Product | Product | Checkout |
| 09:10 | Cart | Cart | Checkout |
| 09:15 | Checkout | Checkout | Checkout |

`FIRST_VALUE` doesn't need the frame, because the default frame starts at the first row.

**Why this version needs a collapsing step.** A window function adds a value to every row and keeps all the rows. So each session's landing page shows up once per event. The `GROUP BY` (or `DISTINCT`) at the end brings it back to one row per session. This works because `landing_page` and `exit_page` are the same on every row of a session. If I added `page` or `event_time` to the `SELECT`, those differ per row and `DISTINCT` would stop collapsing.

### Option C: `ROW_NUMBER`

```sql
WITH ranked AS (
    SELECT
        user_id,
        session_id,
        page,
        ROW_NUMBER() OVER (PARTITION BY user_id, session_id ORDER BY event_time, event_id)      AS rn_first,
        ROW_NUMBER() OVER (PARTITION BY user_id, session_id ORDER BY event_time DESC, event_id DESC) AS rn_last
    FROM events
)
SELECT
    user_id,
    session_id,
    MAX(CASE WHEN rn_first = 1 THEN page END) AS landing_page,
    MAX(CASE WHEN rn_last  = 1 THEN page END) AS exit_page
FROM ranked
GROUP BY user_id, session_id;
```

The same pattern as my BOP/EOP balance notes. It is the best choice when I also need other columns from the first or last event.

### Which one I'd pick

| Approach | Cost | Notes |
|---|---|---|
| `MIN_BY` / `MAX_BY` | Cheapest, one pass | Not available in Postgres |
| `FIRST_VALUE` / `LAST_VALUE` | One sort, but every row is carried along | Same window definition shares the sort. Don't forget the frame. |
| two `ROW_NUMBER`s | Two different sorts | Most flexible |

On large data, I'd confirm with `EXPLAIN`.

---

## 4. Session duration and event count

```sql
SELECT
    user_id,
    session_id,
    MIN(event_time) AS session_start,
    MAX(event_time) AS session_end,
    MAX(event_time) - MIN(event_time) AS session_duration,
    COUNT(*) AS event_count
FROM events
GROUP BY user_id, session_id
ORDER BY user_id, session_id;
```

| user | session | start | end | duration | events |
|---|---|---|---|---|---|
| U1 | 1 | 09:00 | 09:15 | 00:15:00 | 4 |
| U1 | 2 | 11:00 | 11:10 | 00:10:00 | 2 |
| U2 | 1 | 10:00 | 10:20 | 00:20:00 | 2 |
| U3 | 1 | 14:00 | 14:00 | 00:00:00 | 1 |
| U4 | 1 | 15:00 | 15:10 | 00:10:00 | 3 |

Things to mention:
- A one-event session (U3) has duration 0. Decide whether to keep or filter those, since they drag averages down.
- Duration is first event to last event. It leaves out time spent on the final page, which the data can't show.

---

## 5. Most common landing page

Two steps: one landing page per session, then count **sessions**.

```sql
WITH session_landing AS (
    SELECT
        user_id,
        session_id,
        page AS landing_page,
        ROW_NUMBER() OVER (
            PARTITION BY user_id, session_id
            ORDER BY event_time, event_id
        ) AS rn
    FROM events
),
counts AS (
    SELECT landing_page, COUNT(*) AS sessions
    FROM session_landing
    WHERE rn = 1
    GROUP BY landing_page
),
ranked AS (
    SELECT
        landing_page,
        sessions,
        RANK() OVER (ORDER BY sessions DESC) AS rnk
    FROM counts
)
SELECT landing_page, sessions
FROM ranked
WHERE rnk = 1;
```

| landing_page | sessions |
|---|---|
| Home | 3 |

Two mistakes to avoid:
- **Counting events instead of sessions.** Without the `rn = 1` filter, a 4-event session counts 4 times, and the answer measures long sessions, not popular entry pages.
- **Hiding a tie for first place.** `ORDER BY ... LIMIT 1` returns one row even if two pages tie. `RANK() ... WHERE rnk = 1` returns all tied pages. Postgres 13+ also has `FETCH FIRST 1 ROWS WITH TIES`.

The same result using `FIRST_VALUE`:

```sql
WITH session_landing AS (
    SELECT DISTINCT
        user_id,
        session_id,
        FIRST_VALUE(page) OVER (
            PARTITION BY user_id, session_id
            ORDER BY event_time, event_id
        ) AS landing_page
    FROM events
)
SELECT landing_page, COUNT(*) AS sessions
FROM session_landing
GROUP BY landing_page
ORDER BY sessions DESC;
```

---

## 6. Exact timestamp ties

U4 has Blog and Home at the same second. "First" is undefined if I order by time alone.

| event_id | event_time | page | `ORDER BY event_time` only | `ORDER BY event_time, event_id` |
|---|---|---|---|---|
| 10 | 15:00:00 | Blog | tied, either could be first | 1 |
| 11 | 15:00:00 | Home | tied, either could be first | 2 |
| 12 | 15:10:00 | Cart | 3 | 3 |

Without a tiebreaker, U4's landing page could be Blog or Home depending on the run or engine. That flips Home's session count between 3 and 4, so the "most common landing page" result isn't reproducible.

**Fix:** add a unique column to the end of the `ORDER BY`. `event_id` is unique per event, so no two rows can tie on both columns. The tiebreaker is only consulted when the times are equal.

Things to mention:
- It has to be unique. If two rows share both time and id, the tie is still there.
- A sequence-based id usually reflects the real event order. A random UUID gives a repeatable result, but the order is arbitrary.
- If there's no unique column at all, ask which event should win, or state that the result is arbitrary.
- **Session boundaries aren't affected.** A tie gives a gap of 0 seconds, which never exceeds the 30-minute timeout. Only answers that depend on order are affected.
- Exact duplicate rows (same event logged twice) are a separate problem: decide whether to dedupe before counting.

---

## Quick answers I want to remember

- **Why a running total, not just the flag?** The flag only has two values, so it can't separate more than one session. The running total turns scattered boundary markers into a strictly increasing session id that `GROUP BY` can use.
- **Why not another flag for the 4-hour cap?** The 30-minute check compares a row with its neighbour, so a flag resets naturally. The cap compares a row with a fixed start time, so a flag would stay at 1 forever. Floor-dividing elapsed time avoids that.
- **`MIN(page)` for the landing page?** No. `MIN` gives the alphabetical smallest. I need the page at the smallest time: `MIN_BY`, `FIRST_VALUE` or `ROW_NUMBER`.
- **Why does `LAST_VALUE` need a frame?** The default frame ends at the current row, so it returns the current row's own value.
- **Why does `FIRST_VALUE` need `DISTINCT`?** Window functions don't collapse rows. Each session's value is repeated on every one of its rows.
- **Ties?** Add a unique tiebreaker to the `ORDER BY`. Session boundaries stay the same.
- **Boundary at exactly 4h?** State the convention, keep it consistent with the 30-minute rule, and add a test row at exactly 4h00m.
