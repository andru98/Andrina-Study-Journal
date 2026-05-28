# Subqueries — Types, Correlated, EXISTS vs IN
*Personal Study Notes — May 2026*

---

## Table of Contents
1. [Subquery in WHERE](#1-subquery-in-where)
2. [Subquery in FROM](#2-subquery-in-from)
3. [Subquery in SELECT](#3-subquery-in-select)
4. [Correlated Subqueries](#4-correlated-subqueries)
5. [Rewriting Correlated Subquery as CTE + JOIN](#5-rewriting-correlated-subquery-as-cte--join)
6. [EXISTS vs IN](#6-exists-vs-in)
7. [HAVING vs Subquery in FROM](#7-having-vs-subquery-in-from)

---

## 1. Subquery in WHERE

Used to filter rows based on a calculated value. The subquery returns a single value or a list — the outer query uses it as a filter condition.

```sql
-- Find employees earning above company average
SELECT name, salary
FROM employees
WHERE salary > (SELECT AVG(salary) FROM employees);
```

The inner query runs first and returns one number — say 75,000. Then the outer query filters using that number. This is a scalar subquery — it runs once and the result is cached for all rows.

**Common patterns:**
```sql
-- Compare against a single calculated value
WHERE salary > (SELECT AVG(salary) FROM employees)

-- Check membership in a list
WHERE customer_id IN (SELECT customer_id FROM orders)

-- Check against the maximum
WHERE salary = (SELECT MAX(salary) FROM employees)
```

**What it returns:** A single value or a list — used as a condition, not a table.

---

## 2. Subquery in FROM

Used when you need to aggregate or transform data first, then query or filter the result further. The subquery produces a temporary table — the outer query treats it like a normal table.

```sql
-- Find departments with above average headcount
SELECT dept, avg_sal
FROM (
    SELECT department AS dept, AVG(salary) AS avg_sal
    FROM employees
    GROUP BY department
) AS dept_summary
WHERE avg_sal > 80000;
```

The inner query runs first and produces a grouped result. The outer query then filters that grouped result. This is the same thing a CTE does — just written inline. CTE is usually cleaner for readability.

**What it returns:** A full table — multiple rows and columns — that can be queried further.

**Key rule:** The subquery in FROM must always have an alias (`AS dept_summary` above). Without the alias MySQL throws an error.

---

## 3. Subquery in SELECT

Used to add a calculated column alongside each row. The subquery runs once per row in the outer query.

```sql
-- Add company average to every employee row
SELECT
    name,
    salary,
    (SELECT AVG(salary) FROM employees) AS company_avg
FROM employees;
```

**Two types:**

**Scalar — runs once, fast:**
```sql
(SELECT AVG(salary) FROM employees)  -- no reference to outer query
-- runs once, result reused for every row
```

**Correlated — runs per row, slow:**
```sql
(SELECT COUNT(*) FROM orders WHERE orders.customer_id = customers.customer_id)
-- references outer query → reruns for every customer row
```

When you see a subquery in SELECT that references the outer table, that is the signal to consider rewriting as a JOIN.

---

## 4. Correlated Subqueries

A correlated subquery references a column from the outer query. This reference forces the inner query to rerun from scratch for every single row the outer query processes.

```sql
-- Find employees earning above their department average
SELECT name, salary, department
FROM employees e1
WHERE salary > (
    SELECT AVG(salary)
    FROM employees e2
    WHERE e2.department = e1.department  -- references outer query
);
```

`e1.department` is the reference — the inner query cannot run independently. It needs to know which department the outer query is currently on.

**What happens row by row:**
```
Outer picks Alice (Engineering) → inner calculates AVG for Engineering → 120,000 > 100,000 ✅
Outer picks Bob   (Engineering) → inner calculates AVG for Engineering AGAIN → 80,000 > 100,000 ❌
Outer picks Carol (HR)          → inner calculates AVG for HR → 90,000 > 75,000 ✅
Outer picks Diana (HR)          → inner calculates AVG for HR AGAIN → 60,000 > 75,000 ❌
```

Engineering average is calculated twice — once for each Engineering employee. With 1 million employees across 5 departments, the inner query runs 1 million times even though only 5 unique averages exist.

**How to spot a correlated subquery:** look for the outer table's column referenced inside the inner query — `e1.department` inside the subquery using `e1` alias from outside.

**Why databases prefer set-based over row-by-row:** SQL is designed to process collections of rows at once. Correlated subqueries force row-by-row loop behavior inside a set-based language — that mismatch is the root of the performance problem.

---

## 5. Rewriting Correlated Subquery as CTE + JOIN

The fix is always the same pattern: extract what the inner query calculates, compute it for ALL groups at once in a CTE, then JOIN the result.

**Original correlated subquery:**
```sql
SELECT name, salary, department
FROM employees e1
WHERE salary > (
    SELECT AVG(salary)
    FROM employees e2
    WHERE e2.department = e1.department
);
```

**Step 1 — what does the inner query calculate?**
AVG salary per department.

**Step 2 — extract it into a CTE for ALL departments at once:**
```sql
WITH dept_avg AS (
    SELECT department, AVG(salary) AS avg_salary
    FROM employees
    GROUP BY department
)
```

**Step 3 — JOIN the CTE to the main table:**
```sql
SELECT e.name, e.salary, e.department
FROM employees e
JOIN dept_avg d ON e.department = d.department
WHERE e.salary > d.avg_salary;
```

**Full rewritten query:**
```sql
WITH dept_avg AS (
    SELECT department, AVG(salary) AS avg_salary
    FROM employees
    GROUP BY department
)
SELECT e.name, e.salary, e.department
FROM employees e
JOIN dept_avg d ON e.department = d.department
WHERE e.salary > d.avg_salary;
```

**Performance comparison:**

| | Correlated Subquery | CTE + JOIN |
|--|--------------------|-----------| 
| AVG calculated | Once per employee row | Once per department |
| 1M employees, 5 depts | Runs 1M times | Runs 5 times |
| Approach | Row by row | Set-based one pass |

---

## 6. EXISTS vs IN

### IN — checks membership in a list

```sql
SELECT name
FROM customers
WHERE customer_id IN (SELECT customer_id FROM orders);
```

Inner query runs first and returns the full list of customer_ids. Outer query checks each customer against that list. All values are loaded into memory before comparison begins.

### EXISTS — checks if any matching row exists

```sql
SELECT name
FROM customers c
WHERE EXISTS (
    SELECT 1
    FROM orders o
    WHERE o.customer_id = c.customer_id
);
```

For each customer — checks if even one matching order exists. Returns TRUE immediately on the first match and stops. Never reads beyond the first match.

### How they execute differently

```
IN:     inner query runs → loads full list (1, 2, 4, 7...) into memory → outer checks each value
EXISTS: for each outer row → inner searches → stops at first match → returns TRUE or FALSE
```

EXISTS short-circuits — it never builds a full list. IN always builds the complete list first.

### When to use which

| Situation | Use |
|-----------|-----|
| Small fixed list of values | IN — clean and readable |
| Large subquery result | EXISTS — stops at first match |
| Only care if a match exists | EXISTS |
| Need to match against known values | IN |

### The NULL Trap — Critical

**NOT IN breaks silently with NULLs:**
```sql
WHERE customer_id NOT IN (SELECT customer_id FROM orders)
-- If ANY customer_id in orders is NULL:
-- customer_id = NULL evaluates to NULL (not FALSE)
-- The entire result returns empty — silently, no error
```

**NOT EXISTS is always safe:**
```sql
WHERE NOT EXISTS (SELECT 1 FROM orders WHERE orders.customer_id = c.customer_id)
-- Checks row existence, not value equality
-- NULL in the data does not affect behavior
```

In production — always prefer NOT EXISTS over NOT IN when the subquery could contain NULLs.

---

## 7. HAVING vs Subquery in FROM

A common confusion — when to use HAVING and when to use a subquery in FROM.

**HAVING** filters groups after aggregation. It collapses rows into one per group. You lose individual rows.

```sql
-- Departments where average salary is above 80,000
SELECT department, AVG(salary) AS avg_sal
FROM employees
GROUP BY department
HAVING AVG(salary) > 80000;
-- Result: one row per department — individual employees gone
```

**Subquery in FROM** keeps individual rows and lets you compare each row against its group's aggregate.

```sql
-- Individual employees earning above their department average
SELECT e.name, e.salary, e.department
FROM employees e
JOIN (
    SELECT department, AVG(salary) AS avg_sal
    FROM employees
    GROUP BY department
) d ON e.department = d.department
WHERE e.salary > d.avg_sal;
-- Result: individual employee rows
```

**Decision rule:**

```
Want department-level summary?              → HAVING
Want individual rows compared to their      → Subquery in FROM or CTE + JOIN
group's aggregate?
```

---

*Study notes compiled May 2026 — Anna's DE Prep Journey*
