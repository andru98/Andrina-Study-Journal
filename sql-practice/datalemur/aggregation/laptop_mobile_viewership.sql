-- Problem: Laptop vs Mobile Viewership
-- Source: DataLemur
-- Link: https://datalemur.com/questions/laptop-mobile-viewership

-- Topic: CASE WHEN & Conditional Aggregation
-- Difficulty: Easy

-- Approach:
-- 1. Use CASE WHEN inside SUM() to conditionally count rows.
-- 2. Laptop views — count rows where device_type = 'laptop'.
-- 3. Mobile views — count rows where device_type IN ('tablet', 'phone').
-- 4. Both columns returned in a single query — no GROUP BY needed.

SELECT
    SUM(CASE WHEN device_type = 'laptop'
        THEN 1 ELSE 0 END) AS laptop_views,
    SUM(CASE WHEN device_type IN ('tablet', 'phone')
        THEN 1 ELSE 0 END) AS mobile_views
FROM viewership;

--GROUP BY  → when each category needs its OWN row "show me views per device type"

--CASE WHEN   → when you need categories as COLUMNS in one row
              --"show me laptop vs mobile side by side"
             -- especially when combining multiple values (tablet + phone)
              --into one bucket

 --The rule : If you need to pivot categories into columns → CASE WHEN ,If you need categories as rows → GROUP BY

