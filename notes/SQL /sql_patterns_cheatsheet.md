# SQL Patterns Cheat Sheet
# Based on LeetCode SQL50 practice
# Last updated: 2026-09-02

## ============================================================
## WINDOW FUNCTIONS
## ============================================================

### ROW_NUMBER vs RANK vs DENSE_RANK
```sql
-- Salaries: 300, 200, 200, 100
ROW_NUMBER()  → 1, 2, 3, 4  -- unique, no ties
RANK()        → 1, 2, 2, 4  -- ties share rank, gap after
DENSE_RANK()  → 1, 2, 2, 3  -- ties share rank, NO gap ✅

-- Use DENSE_RANK for "top N unique values" ✅
-- Use ROW_NUMBER for pagination ✅
-- Use RANK when gaps after ties acceptable ✅
```

### Top N per group (lc185 - Hard):
```sql
WITH ranked AS (
    SELECT col,
           DENSE_RANK() OVER (
               PARTITION BY group_col
               ORDER BY metric DESC
           ) AS rnk
    FROM table
    JOIN ...
)
SELECT col FROM ranked WHERE rnk <= N;
```

### Moving Average (lc1321):
```sql
WITH daily AS (
    SELECT date_col, SUM(val) AS daily_total
    FROM table GROUP BY date_col
)
SELECT date_col,
    SUM(daily_total) OVER (
        ORDER BY date_col
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS rolling_sum,
    ROUND(AVG(daily_total) OVER (
        ORDER BY date_col
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2) AS rolling_avg
FROM daily
OFFSET 6;  -- skip incomplete windows ✅
-- Note: WHERE filters BEFORE window → use OFFSET or subquery ✅
```

### Running Total with OFFSET filter (lc1204):
```sql
-- OFFSET skips first N rows AFTER window calculation ✅
-- WHERE filters BEFORE window → wrong values ❌
-- Wrap in subquery to filter after window ✅
```

### LAG/LEAD (lc180 Consecutive Numbers):
```sql
SELECT DISTINCT num AS ConsecutiveNums
FROM (
    SELECT num,
           LAG(num) OVER (ORDER BY id) AS prev_num,
           LEAD(num) OVER (ORDER BY id) AS next_num
    FROM Logs
) t
WHERE num = prev_num AND num = next_num;
```

### Market Share with SUM OVER (lc1729):
```sql
SELECT artist_name,
    ROUND(track_count * 100.0 / SUM(track_count) OVER (), 2) AS market_share
FROM top_artists
ORDER BY track_count DESC;
```

### ROW_NUMBER for latest record per partition (lc1164):
```sql
WITH ranked AS (
    SELECT product_id, new_price,
           ROW_NUMBER() OVER (
               PARTITION BY product_id
               ORDER BY change_date DESC  -- latest first
           ) AS rn
    FROM Products
    WHERE change_date <= '2019-08-16'
)
SELECT p.product_id,
       COALESCE(r.new_price, 10) AS price
FROM (SELECT DISTINCT product_id FROM Products) p
LEFT JOIN ranked r ON p.product_id = r.product_id AND r.rn = 1;
```

---

## ============================================================
## NULL HANDLING
## ============================================================

### Second highest / Nth value with NULL (lc176):
```sql
-- Option 1: MAX() returns NULL on empty set ✅
WITH ranked AS (
    SELECT salary, DENSE_RANK() OVER (ORDER BY salary DESC) AS rnk
    FROM Employee
)
SELECT MAX(salary) AS SecondHighestSalary
FROM ranked WHERE rnk = 2;

-- Option 2: Scalar subquery returns NULL if empty ✅
SELECT (
    SELECT DISTINCT salary
    FROM Employee
    ORDER BY salary DESC
    LIMIT 1 OFFSET 1
) AS SecondHighestSalary;
```

### COALESCE / IFNULL:
```sql
COALESCE(val, default)  -- first non-NULL ✅
IFNULL(val, default)    -- MySQL only ✅
-- Example: COALESCE(price, 10) → 10 if price is NULL
```

### NULL in NOT IN (lc1978):
```sql
-- Always add IS NOT NULL when using NOT IN:
WHERE manager_id IS NOT NULL
AND manager_id NOT IN (SELECT employee_id FROM Employees)
-- NULL NOT IN (...) = UNKNOWN not FALSE ❌
```

---

## ============================================================
## JOINS
## ============================================================

### LEFT JOIN + NULL = "not exists" pattern (lc1978):
```sql
-- Find employees whose manager left:
SELECT e.employee_id
FROM Employees e
LEFT JOIN Employees m ON e.manager_id = m.employee_id
WHERE e.salary < 30000
  AND e.manager_id IS NOT NULL
  AND m.employee_id IS NULL  -- manager not found = left ✅
ORDER BY e.employee_id;
```

### INNER vs LEFT JOIN decision:
```sql
-- INNER: only matching rows (albums WITH tracks) ✅
-- LEFT: all left rows, NULL where no match ✅
-- Use LEFT when: want to preserve all records
-- Use INNER when: only want complete matches
```

### Self JOIN for bidirectional count (lc602):
```sql
-- Count friends from both sides:
SELECT id, COUNT(*) AS num
FROM (
    SELECT requester_id AS id FROM RequestAccepted
    UNION ALL
    SELECT accepter_id AS id FROM RequestAccepted
) all_friends
GROUP BY id
ORDER BY num DESC LIMIT 1;
```

---

## ============================================================
## UNION ALL
## ============================================================

### UNION vs UNION ALL:
```sql
UNION     -- removes duplicates (slower) ❌ for counting
UNION ALL -- keeps all rows (faster) ✅ for counting

-- Use UNION ALL for:
-- → bidirectional relationships (friends) ✅
-- → combining two separate results (lc1341) ✅
-- → counting occurrences ✅
```

### Two separate questions in one result (lc1341):
```sql
SELECT name AS results FROM (
    SELECT name, COUNT(*) AS cnt
    FROM table1 JOIN ...
    GROUP BY name
    ORDER BY cnt DESC, name
    LIMIT 1
) t1
UNION ALL
SELECT title AS results FROM (
    SELECT title, AVG(rating) AS avg_r
    FROM table2 JOIN ...
    WHERE date_filter
    GROUP BY title
    ORDER BY avg_r DESC, title
    LIMIT 1
) t2;
```

---

## ============================================================
## SUBQUERIES
## ============================================================

### IN vs NOT IN:
```sql
-- IN: rows where value EXISTS in list ✅
-- NOT IN: rows where value MISSING from list ✅
-- Always add IS NOT NULL with NOT IN ✅
```

### Tuple IN subquery (lc585):
```sql
-- Filter by two conditions independently:
WHERE tiv_2015 IN (
    SELECT tiv_2015 FROM Insurance
    GROUP BY tiv_2015 HAVING COUNT(*) > 1
)
AND (lat, lon) IN (
    SELECT lat, lon FROM Insurance
    GROUP BY lat, lon HAVING COUNT(*) = 1
)
```

### Scalar subquery:
```sql
-- Returns one value, NULL if empty ✅
SELECT (SELECT MAX(val) FROM table WHERE condition) AS result;
```

---

## ============================================================
## GROUP BY + HAVING
## ============================================================

### HAVING vs WHERE:
```sql
WHERE  -- filters BEFORE GROUP BY (can't use aggregates) ❌
HAVING -- filters AFTER GROUP BY (can use aggregates) ✅

-- Use HAVING for: COUNT(*) > 1, SUM() > 100 etc
```

### English → SQL translation:
```
"same as others"        → HAVING COUNT(*) > 1
"unique/only one"       → HAVING COUNT(*) = 1
"at least one other"    → HAVING COUNT(*) >= 2
"appears exactly N"     → HAVING COUNT(*) = N
"most/highest"          → ORDER BY DESC LIMIT 1
"both conditions"       → WHERE cond1 AND cond2
"either condition"      → WHERE cond1 OR cond2
```

### Salary categories with UNION ALL reference table (lc1907):
```sql
-- When category might have 0 rows, use UNION ALL:
SELECT 'Low Salary' AS category,
       COUNT(*) FILTER (WHERE income < 20000) AS accounts_count
UNION ALL
SELECT 'Average Salary',
       COUNT(*) FILTER (WHERE income BETWEEN 20000 AND 50000)
UNION ALL
SELECT 'High Salary',
       COUNT(*) FILTER (WHERE income > 50000);
```

---

## ============================================================
## DATE FUNCTIONS
## ============================================================

### Date filtering:
```sql
-- February 2020 (works in all databases):
WHERE date_col >= '2020-02-01' AND date_col < '2020-03-01'

-- MySQL alternative:
WHERE YEAR(date_col) = 2020 AND MONTH(date_col) = 2

-- PostgreSQL:
WHERE DATE_TRUNC('month', date_col) = '2020-02-01'
```

### Date arithmetic:
```sql
-- PostgreSQL:
MIN(date) + INTERVAL '6 days'

-- MySQL:
DATE_ADD(MIN(date), INTERVAL 6 DAY)
```

### Decade from year:
```sql
FLOOR(release_year / 10) * 10 AS decade
-- 2020 → 202 * 10 = 2020 ✅
-- 2015 → 201 * 10 = 2010 ✅
```

---

## ============================================================
## STRING FUNCTIONS
## ============================================================

### Proper case (lc1667):
```sql
CONCAT(UPPER(LEFT(name, 1)), LOWER(SUBSTRING(name, 2)))
-- "aLice" → "Alice" ✅
-- PostgreSQL shortcut: INITCAP(LOWER(name))
```

### SUBSTRING reference:
```sql
SUBSTRING(str, start)      -- from position to end
SUBSTRING(str, start, len) -- from position, n chars
LEFT(str, n)               -- first n chars
RIGHT(str, n)              -- last n chars
LENGTH(str)                -- string length
```

### LIKE word boundary (lc1527):
```sql
-- Find word starting with PREFIX in space-separated string:
WHERE col LIKE 'PREFIX%'      -- at start ✅
   OR col LIKE '% PREFIX%'   -- after space ✅
-- '%PREFIX%' too broad → matches 'XPREFIX' ❌
```

### GROUP_CONCAT / STRING_AGG (lc1484):
```sql
-- MySQL:
GROUP_CONCAT(DISTINCT product ORDER BY product SEPARATOR ',')

-- PostgreSQL:
STRING_AGG(DISTINCT product, ',' ORDER BY product)

-- Both: aggregate strings within a group ✅
-- DISTINCT needed even with GROUP BY ✅
```

---

## ============================================================
## DELETE / UPDATE
## ============================================================

### Delete duplicates keeping min id (lc196):
```sql
-- PostgreSQL:
DELETE FROM Person
WHERE id NOT IN (
    SELECT MIN(id) FROM Person GROUP BY email
);

-- MySQL (wrapped):
DELETE FROM Person
WHERE id NOT IN (
    SELECT min_id FROM (
        SELECT MIN(id) AS min_id FROM Person GROUP BY email
    ) t
);

-- Self JOIN (universal):
DELETE p1 FROM Person p1
JOIN Person p2 ON p1.email = p2.email AND p1.id > p2.id;
```

---

## ============================================================
## CASE WHEN
## ============================================================

### Conditional transformation (lc626):
```sql
-- Specific before general ✅
CASE
    WHEN specific_condition THEN special_value  -- check first!
    WHEN general_condition  THEN general_value
    ELSE default_value
END
```

### Seat swapping pattern:
```sql
CASE
    WHEN id % 2 = 1 AND id = (SELECT MAX(id) FROM Seat)
        THEN id          -- last odd → stay
    WHEN id % 2 = 1 THEN id + 1   -- odd → swap up
    ELSE id - 1                     -- even → swap down
END AS id
```

### Modulo (odd/even):
```sql
id % 2 = 0  -- even
id % 2 = 1  -- odd
MOD(id, 2)  -- MySQL alternative
```

---

## ============================================================
## CASTING / TYPE CONVERSION
## ============================================================

### PostgreSQL ROUND with float:
```sql
-- Error: ROUND(double precision, int) not supported ❌
ROUND(SUM(tiv_2016)::numeric, 2)  -- cast to numeric first ✅
```

### PostgreSQL cast syntax:
```sql
value::numeric    -- cast to numeric ✅
value::int        -- cast to integer ✅
value::varchar    -- cast to string ✅
CAST(value AS numeric)  -- ANSI standard ✅
```

---

## ============================================================
## OFFSET vs LIMIT
## ============================================================

```sql
LIMIT n          -- return first n rows
OFFSET n         -- skip first n rows
LIMIT 3 OFFSET 6 -- skip 6, return next 3 (pagination)

-- SQL execution order:
-- 1. FROM/CTE → 2. WHERE → 3. GROUP BY →
-- 4. HAVING → 5. SELECT (window functions) →
-- 6. ORDER BY → 7. LIMIT/OFFSET

-- Window functions execute at step 5 ✅
-- WHERE at step 2 → filters before window ❌
-- OFFSET at step 7 → after window ✅
```

---

## ============================================================
## PATTERNS QUICK REFERENCE
## ============================================================

```
Top N unique per group:     DENSE_RANK + PARTITION BY + HAVING rnk <= N
Moving average N days:      SUM/AVG OVER (ROWS BETWEEN N-1 PRECEDING AND CURRENT ROW)
Nth highest with NULL:      MAX() or scalar subquery
Find missing/deleted rows:  LEFT JOIN + IS NULL
Bidirectional count:        UNION ALL both directions
Two results one column:     UNION ALL two subqueries
Word in space-separated:    LIKE 'WORD%' OR LIKE '% WORD%'
Delete duplicates:          DELETE WHERE id NOT IN (SELECT MIN(id) GROUP BY)
Aggregate strings:          GROUP_CONCAT / STRING_AGG
Proper case string:         CONCAT(UPPER(LEFT(1)), LOWER(SUBSTRING(2)))
Decade from year:           FLOOR(year/10)*10
Swap alternating rows:      CASE WHEN id%2=1 THEN id+1 ELSE id-1 END
```

---

## ============================================================
## PROBLEMS SOLVED INDEX
## ============================================================

```
lc176:  Second Highest Salary (NULL handling)
lc180:  Consecutive Numbers (LAG/LEAD)
lc185:  Department Top 3 Salaries (DENSE_RANK Hard)
lc196:  Delete Duplicate Emails (DELETE)
lc570:  Managers with 5+ Direct Reports
lc577:  Employee Bonus
lc584:  Find Customer Referee
lc585:  Investments 2016 (tuple IN)
lc595:  Big Countries
lc596:  Classes with 5+ Students
lc602:  Friend Requests Most Friends (UNION ALL)
lc610:  Triangle Judgement (CASE WHEN)
lc619:  Biggest Single Number
lc620:  Not Boring Movies
lc626:  Exchange Seats (CASE WHEN modulo)
lc1045: Customers who bought all products
lc1068: Product Sales Analysis
lc1070: Product Sales Analysis III
lc1075: Project Employees I
lc1141: User Activity for past 30 days
lc1148: Article Views I
lc1164: Product Price at Given Date (ROW_NUMBER)
lc1174: Immediate Food Delivery
lc1193: Monthly Transactions
lc1204: Last Person to Fit on Bus (running total OFFSET)
lc1211: Queries Quality and Percentage
lc1251: Average Selling Price
lc1280: Students and Examinations
lc1321: Restaurant Growth (moving average)
lc1327: List the Products Ordered in a Period
lc1341: Movie Rating (UNION ALL two questions)
lc1378: Replace Employee ID
lc1393: Capital Gain/Loss
lc1407: Top Travellers
lc1484: Group Sold Products (GROUP_CONCAT)
lc1527: Patients with Condition (LIKE word boundary)
lc1581: Customer Who Visited but No Transaction
lc1633: Percentage of Users Attended a Contest
lc1667: Fix Names (string functions)
lc1683: Invalid Tweets
lc1693: Daily Leads and Partners
lc1729: Find Followers Count
lc1731: Employees Managers with 5 Reports
lc1757: Recyclable and Low Fat Products
lc1789: Primary Department for Each Employee
lc1907: Count Salary Categories (UNION ALL reference)
lc1934: Confirmation Rate
lc1978: Employees Whose Manager Left (LEFT JOIN NULL)
lc2356: Number of Unique Subjects Taught by Each Teacher
```

---

## ============================================================
## WEEKLY REVISION PLAN
## ============================================================

```
Monday:    Window functions (ROW_NUMBER, RANK, DENSE_RANK, LAG/LEAD)
Tuesday:   JOINs + NULL handling
Wednesday: Subqueries + HAVING
Thursday:  String functions + Date functions
Friday:    2 new problems
Sunday:    Re-solve 2 random problems from memory
           Read this cheat sheet (15 mins)
```
