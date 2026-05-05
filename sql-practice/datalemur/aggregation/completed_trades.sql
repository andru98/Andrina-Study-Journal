
-- Problem: Completed Trades
-- Source: DataLemur
-- Link: https://datalemur.com/questions/completed-trades

-- Topic: Joins & Aggregation
-- Difficulty: Easy

-- Approach:
-- 1. Join trades with users to access city information.
-- 2. Filter only completed trades.
-- 3. Group by city to count total completed orders.
-- 4. Order by highest activity and return the top 3.

SELECT
    u.city,
    COUNT(*) AS total_orders
FROM trades t
JOIN users u
    ON t.user_id = u.user_id
WHERE t.status = 'Completed'
GROUP BY u.city
ORDER BY total_orders DESC
LIMIT 3;
