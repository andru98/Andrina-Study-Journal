# Pandas: groupby, agg(), and transform()

> A clear, interview-ready guide for real-world data manipulation.

---

## Table of Contents
1. [What groupby Does](#1-what-groupby-does)
2. [agg() — Aggregations](#2-agg----aggregations-one-row-per-group)
3. [transform() — Broadcast Back to Each Row](#3-transform----broadcast-back-to-each-row)
4. [Why Z-Score Cannot Be Done with agg()](#4-why-z-score-cannot-be-done-with-agg)
5. [Side-by-Side Comparison](#5-side-by-side-comparison)
6. [Real-World Patterns](#6-real-world-patterns)
7. [Interview Q&A Bank](#7-interview-qa-bank)

---

## 1. What groupby Does

`groupby` follows the classic **Split → Apply → Combine** pattern.

1. **Split** the DataFrame into groups
2. **Apply** an aggregation or transformation
3. **Combine** the results

Useful for:
- Aggregations (mean, max, count per group)
- Group-level statistics
- Feature engineering
- Normalization

```python
import pandas as pd

df = pd.DataFrame({
    'department': ['Engineering', 'Engineering', 'HR', 'HR', 'Finance'],
    'name':       ['Alice', 'Bob', 'Carol', 'Dave', 'Eve'],
    'salary':     [120000, 110000, 80000, 75000, 130000]
})

# groupby returns a GroupBy object — nothing computed yet
grouped = df.groupby('department')
# apply agg or transform to compute
```

---

## 2. agg() — Aggregations (One Row Per Group)

### What agg() returns

- One row per group
- One value per aggregation
- Output is **smaller** than the original DataFrame

### When to use it

Use `agg()` when you want summary statistics like mean, max, percentile, range, etc.

### Example

```python
dept_stats = df.groupby('department').agg(
    avg_salary   = ('salary', 'mean'),
    max_salary   = ('salary', 'max'),
    p90_salary   = ('salary', lambda x: x.quantile(0.9)),
    salary_range = ('salary', lambda x: x.max() - x.min())
)

print(dept_stats)
```

```
             avg_salary  max_salary  p90_salary  salary_range
department
Engineering      115000      120000    119000.0         10000
Finance          130000      130000    130000.0             0
HR                77500       80000     79500.0          5000
```

### Output shape

If you have 3 departments → output has **3 rows** — one per group.

### Interview takeaway

> `agg()` reduces each group to one row. Perfect for summary tables.

---

## 3. transform() — Broadcast Back to Each Row

### What transform() returns

- Same number of rows as the original DataFrame
- Values are **aligned row-by-row** back to the original
- Output can be added directly as a new column

### When to use it

Use `transform()` when you want:
- Group-level stats per row (e.g. each employee sees their department average)
- Feature engineering
- Normalization (z-scores, min-max scaling)
- Anything that must keep the original DataFrame shape

### Example — z-score within each department

```python
df['salary_zscore'] = (
    df.groupby('department')['salary']
      .transform(lambda x: (x - x.mean()) / x.std())
)

print(df[['name', 'department', 'salary', 'salary_zscore']])
```

```
    name  department  salary  salary_zscore
0  Alice  Engineering  120000       0.707107
1    Bob  Engineering  110000      -0.707107
2  Carol           HR   80000       0.707107
3   Dave           HR   75000      -0.707107
4    Eve      Finance  130000            NaN
```

Note: Eve's z-score is NaN because Finance has only one employee — std of one value is undefined.

### Output shape

If the original DataFrame has 10,000 rows → result also has **10,000 rows**.

### Interview takeaway

> `transform()` keeps the original shape. Perfect for adding new columns.

---

## 4. Why Z-Score Cannot Be Done with agg()

Z-score produces one value **per row**, not one per group.

```
agg()       expects one value per group  → compress  ❌ wrong tool for z-score
transform() expects one value per row   → expand    ✅ correct tool for z-score
```

```python
# this would fail or give wrong result:
df.groupby('department')['salary'].agg(
    lambda x: (x - x.mean()) / x.std()  # ❌ returns a Series per group, not one value
)

# this works correctly:
df.groupby('department')['salary'].transform(
    lambda x: (x - x.mean()) / x.std()  # ✅ broadcasts back to every row
)
```

### Mental model

```
agg()       → compress  → fewer rows   → summaries
transform() → expand    → same rows    → new columns
```

---

## 5. Side-by-Side Comparison

| Concept | groupby | agg() | transform() |
|---|---|---|---|
| Output shape | Depends | One row per group | Same as original |
| Use case | Split data into groups | Summaries | Feature engineering |
| Example | `groupby('dept')` | `mean`, `max`, `p90` | z-score, normalization |
| Returns | GroupBy object | Aggregated DataFrame | Series aligned to original |
| Adds new column directly? | No | No (need merge) | Yes |

---

## 6. Real-World Patterns

### Pattern 1 — groupby + agg (summary tables)

```python
dept_stats = df.groupby('department').agg(
    avg_salary = ('salary', 'mean'),
    max_salary = ('salary', 'max'),
    headcount  = ('name',   'count')
).reset_index()
# always reset_index() after groupby — brings department back as a column
```

### Pattern 2 — groupby + transform (feature engineering)

```python
# salary as a percentage of department total
df['salary_pct_of_dept'] = (
    df['salary'] / df.groupby('department')['salary'].transform('sum')
)

# department average added as a new column per row
df['dept_avg_salary'] = df.groupby('department')['salary'].transform('mean')
```

### Pattern 3 — agg + merge back (alternative to transform)

```python
# compute summary
dept_avg = df.groupby('department')['salary'].mean().reset_index()
dept_avg.columns = ['department', 'dept_avg_salary']

# merge back to original
df = df.merge(dept_avg, on='department', how='left')
```

This gives the same result as `transform('mean')` — but uses merge instead. `transform` is cleaner and faster for this pattern.

### Pattern 4 — multiple aggregations in one call

```python
result = df.groupby('department').agg(
    avg_salary   = ('salary', 'mean'),
    p90_salary   = ('salary', lambda x: x.quantile(0.9)),
    salary_range = ('salary', lambda x: x.max() - x.min()),
    headcount    = ('name', 'count')
).reset_index()
```

---

## 7. Interview Q&A Bank

**Q: What is the difference between agg() and transform() in pandas?**

> `agg()` reduces each group down to one row — it collapses the DataFrame into a summary. `transform()` computes a group-level value but broadcasts it back to every original row, so the output has the same shape as the input. Use `agg()` for summary tables, `transform()` for adding new columns. A good example: `agg('mean')` gives one average per department; `transform('mean')` gives each employee the average of their department on their own row.

---

**Q: When would you use transform() over agg()?**

> Whenever you need the result as a new column in the original DataFrame. Classic use cases: z-score normalization within groups, computing what percentage of a group total each row represents, flagging rows where a value exceeds the group average. All of these require one value per row — so transform() is the right tool.

---

**Q: Can you do z-score normalization with agg()? Why or why not?**

> No. Z-score produces one value per row — you need to know each individual's distance from the group mean. `agg()` expects each group to reduce to a single scalar, not a Series of per-row values. `transform()` is the correct tool because it accepts a function that returns a value aligned to each row in the group.

---

**Q: Why do you almost always call reset_index() after groupby + agg()?**

> When you group by a column, pandas promotes that column to the index of the result. So after `df.groupby('department').agg(...)`, the department column becomes the row label — it is no longer a regular column you can filter or join on. `reset_index()` brings it back as a regular column and resets the row numbers to 0, 1, 2... making the result easy to work with downstream.

---

**Q: What is the Split → Apply → Combine pattern?**

> It is the mental model behind every groupby operation. Split: pandas divides the DataFrame into sub-groups based on the groupby key. Apply: a function runs on each group independently — could be an aggregation, transformation, or filter. Combine: the results are assembled back into a single DataFrame. The power is that the apply step is completely flexible — any function that takes a group and returns a scalar (for agg) or aligned Series (for transform) works.

---

**Q: What is the difference between groupby + transform and groupby + agg + merge?**

> Both can produce the same result — each row gets the group-level statistic as a new column. `transform` is cleaner and faster: one line, no merge needed, pandas handles the alignment automatically. `agg + merge` is more explicit and easier to debug if something goes wrong, and it works well when you want to inspect the summary table before merging. In production code, `transform` is preferred for simplicity.

---

*Next: merge() join types, pivot_table, melt/reshape*
