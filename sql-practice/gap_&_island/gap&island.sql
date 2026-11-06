show databases;

/*==============================================================
 Gap & Island Patterns
 Author: Andrina
 Notes:
   Pattern A -> Consecutive Values (ROW_NUMBER trick)
   Pattern B -> Sessionization (LAG + Running SUM)

 Common DE Interview Topics:
   - Consecutive logins
   - User sessions
   - Website activity streaks
   - Session duration
   - Gap detection

==============================================================*/

--------------------------------------------------------------
-- Pattern A: Consecutive Integers
--------------------------------------------------------------

/*
Input:

1
2
3
5
6
8
9
10

Output:

grp | start_id | end_id | length
----+----------+--------+--------
 0  |    1     |   3    |   3
 1  |    5     |   6    |   2
 2  |    8     |  10    |   3
*/

WITH cte AS (
    SELECT
        id,
        id - ROW_NUMBER() OVER (ORDER BY id) AS grp
    FROM numbers
)
SELECT
    grp,
    MIN(id) AS start_id,
    MAX(id) AS end_id,
    COUNT(*) AS length
FROM cte
GROUP BY grp
ORDER BY grp;


--------------------------------------------------------------
-- Pattern A: Consecutive Login Dates
--------------------------------------------------------------

/*
Find user login streaks.

Input:

user_id | login_date
--------+------------
1       | 2024-01-01
1       | 2024-01-02
1       | 2024-01-03
1       | 2024-01-05
1       | 2024-01-06

Output:

user_id | streak_start | streak_end | days
--------+-------------+------------+------
1       | 2024-01-01  | 2024-01-03 | 3
1       | 2024-01-05  | 2024-01-06 | 2
*/

WITH login_rn AS (
    SELECT
        user_id,
        login_date,
        ROW_NUMBER() OVER (
            PARTITION BY user_id
            ORDER BY login_date
        ) AS rn
    FROM logins
),
groups_cte AS (
    SELECT
        user_id,
        login_date,
        login_date - rn * INTERVAL '1 DAY' AS grp
    FROM login_rn
)
SELECT
    user_id,
    MIN(login_date) AS streak_start,
    MAX(login_date) AS streak_end,
    COUNT(*) AS streak_length
FROM groups_cte
GROUP BY user_id, grp
ORDER BY user_id, streak_start;


--------------------------------------------------------------
-- Pattern B: Sessionization (LAG + Running SUM)
--------------------------------------------------------------

/*
Business Rule:

Start a new session if gap > 5 minutes

Input:

10:00
10:02
10:04
10:30
10:31
11:00

Output:

session 0 -> 10:00 to 10:04
session 1 -> 10:30 to 10:31
session 2 -> 11:00
*/

WITH session_flags AS (
    SELECT
        *,
        CASE
            WHEN event_time
                - LAG(event_time) OVER (
                    PARTITION BY user_id
                    ORDER BY event_time
                )
                > INTERVAL '5 minutes'
            THEN 1
            ELSE 0
        END AS flag
    FROM events
),
sessions AS (
    SELECT
        *,
        SUM(flag) OVER (
            PARTITION BY user_id
            ORDER BY event_time
        ) AS session_id
    FROM session_flags
)
SELECT *
FROM sessions;


--------------------------------------------------------------
-- Session Summary
--------------------------------------------------------------

/*
Get:

- session start
- session end
- duration
- events count
*/

WITH session_flags AS (
    SELECT
        *,
        CASE
            WHEN event_time -
                 LAG(event_time) OVER (
                    PARTITION BY user_id
                    ORDER BY event_time
                 )
                 > INTERVAL '5 minutes'
            THEN 1
            ELSE 0
        END AS flag
    FROM events
),
sessions AS (
    SELECT
        *,
        SUM(flag) OVER (
            PARTITION BY user_id
            ORDER BY event_time
        ) AS session_id
    FROM session_flags
)
SELECT
    user_id,
    session_id,
    MIN(event_time) AS session_start,
    MAX(event_time) AS session_end,
    MAX(event_time) - MIN(event_time) AS session_duration,
    COUNT(*) AS event_count
FROM sessions
GROUP BY user_id, session_id
ORDER BY user_id, session_id;


--------------------------------------------------------------
-- Reusable Session Template
--------------------------------------------------------------

/*
Replace the break condition below.

Examples:

Gap > 5 minutes
Gap > 1 day
Status changed
Device changed
Country changed
Price changed
*/

WITH flagged AS (
    SELECT
        *,
        CASE
            WHEN <BREAK_CONDITION>
            THEN 1
            ELSE 0
        END AS flag
    FROM source_table
),
grouped AS (
    SELECT
        *,
        SUM(flag) OVER (
            PARTITION BY user_id
            ORDER BY event_time
        ) AS grp
    FROM flagged
)
SELECT *
FROM grouped;

--------------------------------------------------------------
-- Interview Cheat Sheet
--------------------------------------------------------------

/*
Pattern A
---------
value - ROW_NUMBER()

Use For:
- Consecutive IDs
- Consecutive Dates
- Login Streaks

Pattern B
---------
LAG() + Running SUM()

Use For:
- Sessionization
- Gap > X Minutes
- Gap > X Days
- Status Changes
- Any Business Break Rule

Golden Rule:
------------
Pattern A = Natural Consecutive Sequence

Pattern B = Custom Business Break Logic
*/