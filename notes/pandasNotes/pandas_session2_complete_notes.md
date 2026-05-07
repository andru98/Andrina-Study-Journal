# Pandas Session 2 — Interview-Ready Notes

> **Date:** 25 February 2026 | **Dataset:** Titanic | **Level:** FAANG-ready  
> **Topics:** Views vs Copies · set_index vs reindex · Iteration (iterrows/itertuples) · apply() · Sorting · String Operations · inplace · astype with NaN

---

## Table of Contents
1. [Are Subsets Views or Copies?](#1-are-subsets-views-or-copies)
2. [set_index by Name — Real Example](#2-set_index-by-name--real-example)
3. [set_index vs reindex — The Difference](#3-set_index-vs-reindex--the-difference)
4. [reindex in Action — Store Sales Example](#4-reindex-in-action--store-sales-example)
5. [Iteration in Pandas](#5-iteration-in-pandas)
6. [apply() — The Better Way](#6-apply--the-better-way)
7. [inplace — What it Really Means](#7-inplace--what-it-really-means)
8. [Sorting in Pandas](#8-sorting-in-pandas)
9. [astype and the NaN Problem](#9-astype-and-the-nan-problem)
10. [String Operations with .str accessor](#10-string-operations-with-str-accessor)
11. [Full Interview Q&A Bank](#11-full-interview-qa-bank)
12. [Quick Reference Card](#12-quick-reference-card)

---

## 1. Are Subsets Views or Copies?

This one trips up even experienced pandas developers. And interviewers love asking it.

When you slice or filter a DataFrame, pandas might give you a **view** (a window into the original data) or a **copy** (a completely separate object). The problem is — you can't always tell which one you got just by looking.

**Why does this matter?** Because if you get a view and modify it, you might accidentally modify the original DataFrame. Or you might think you modified the original but didn't.

### The short version

```python
# This might be a view — modifying subset might affect df
subset = df[df['Sex'] == 'male']
subset['Age'] = subset['Age'] + 1  # SettingWithCopyWarning!

# This is always a safe, independent copy
subset = df[df['Sex'] == 'male'].copy()
subset['Age'] += 1  # ✅ Safe — df is untouched
```

### The full picture

| How you sliced | View or Copy? | Should you .copy()? |
|---|---|---|
| `.iloc[]` slicing | Mostly Copy | Optional |
| `.loc[]` slicing | May be View | Recommended |
| Boolean filter `df[condition]` | May be View | Recommended |
| **You plan to modify the subset** | Use `.copy()` | **YES, always** |

### What SettingWithCopyWarning looks like

In your notebook you saw this exact pattern:

```python
# This raises SettingWithCopyWarning
subset = df[df['Sex'] == 'male']
subset['Age'] = subset['Age'] + 1
# SettingWithCopyWarning: A value is trying to be set on a copy of a slice

# Fix — always use .copy() when you plan to modify
subset = df[df['Sex'] == 'male'].copy()
subset['Age'] += 1  # No warning. Clean.
```

After running the fixed version, you could see in the output that the male subset had ages incremented (Braund went from 22 → 23, Allen went from 35 → 36) but the original `df.head()` showed the original ages unchanged. That's the proof `.copy()` worked.

### The rule to remember

> If you're going to modify a subset, always add `.copy()` at the end of your filter. It costs almost nothing in time and saves you from silent data corruption bugs.

---

> **Q: What is the difference between a view and a copy in pandas?**

A view is a reference to the original DataFrame's memory — modifying the view may modify the original. A copy is an independent object — modifying it never affects the original. Whether you get a view or a copy depends on the operation: `.iloc[]` tends to return copies, while `.loc[]` and boolean filtering may return views. The safe rule: always call `.copy()` on any filtered subset you intend to modify.

> **Q: What is SettingWithCopyWarning and how do you fix it?**

It happens when you try to assign values through chained indexing on what might be a view of another DataFrame. For example: `df[df['Sex']=='male']['Age'] = 0`. Pandas can't guarantee whether this modifies the original or a copy, so it warns you. The fix is either: 1) Use `.loc` directly on the original: `df.loc[df['Sex']=='male', 'Age'] = 0`, or 2) Call `.copy()` first if you want an independent subset to modify.

---

## 2. set_index by Name — Real Example

In session 1 you learned `set_index` conceptually. Today you used it in two real ways.

```python
# Set PassengerId as index
df_by_passenger_id = df.set_index('PassengerId')
df_by_passenger_id.head()
# Now PassengerId is the row label — not a column
# Access passenger 1: df_by_passenger_id.loc[1]

# Set Name as index — useful for name-based lookup
df_by_name = df.set_index('Name')
print(df_by_name.loc['Allen, Miss. Elisabeth Walton'])
```

Output from your notebook:
```
PassengerId         731
Survived              1
Pclass                1
Sex              female
Age                29.0
Fare           211.3375
Cabin                B5
...
Name: Allen, Miss. Elisabeth Walton, dtype: object
```

Notice: `Name` disappeared from the columns. It became the index. That's what `set_index` does — it **moves** a column into the index position.

Then you did `reset_index()` to bring it back:

```python
df_by_name = df_by_name.reset_index()
# Name is back as a regular column
# Index is back to 0, 1, 2...
# But notice: Name is now the FIRST column (before PassengerId)
```

---

## 3. set_index vs reindex — The Difference

This is asked in interviews a lot because the names sound similar but they do very different things.

| | `set_index()` | `reindex()` |
|---|---|---|
| What it does | Moves a column to become the row labels | Changes which row/column labels exist |
| Changes columns? | Yes — column disappears | No — columns stay the same |
| Adds NaNs? | No | Yes — for labels that didn't exist |
| Main use | Look up rows by a meaningful key | Align two DataFrames to the same structure |

**Simple way to remember it:**
- `set_index` = "use THIS column as my row labels"
- `reindex` = "I want these labels to exist, fill with NaN if they don't"

---

## 4. reindex in Action — Store Sales Example

This is the clearest example from your notebook. Read this carefully — it shows exactly when reindex is needed and why.

### The problem

```python
# January sales — 3 stores
sales_jan = pd.DataFrame({
    'Sales': [250, 400, 300]
}, index=['Store_A', 'Store_B', 'Store_C'])

# February sales — only 2 stores (Store_B closed)
sales_feb = pd.DataFrame({
    'Sales': [260, 310]
}, index=['Store_A', 'Store_C'])
```

If you try to subtract them directly:
```python
sales_feb['Sales'] - sales_jan['Sales']
# Store_A     10.0
# Store_B      NaN   ← pandas doesn't know what to put here
# Store_C     10.0
```

Pandas aligns on the index. Store_B exists in Jan but not in Feb, so the result is NaN.

### Solution — use reindex to align first

```python
# Make Feb match Jan's structure
common_index = sales_jan.index  # ['Store_A', 'Store_B', 'Store_C']
sales_feb_aligned = sales_feb.reindex(common_index)

#          Sales
# Store_A  260.0
# Store_B    NaN   ← Store_B added with NaN (didn't exist in Feb)
# Store_C  310.0

# Now subtract — NaN stays NaN (Store_B had no Feb data)
diff = sales_feb_aligned['Sales'] - sales_jan['Sales']
# Store_A    10.0
# Store_B     NaN
# Store_C    10.0
```

### If you want to fill missing values instead of NaN

```python
sales_feb_aligned = sales_feb.reindex(common_index, fill_value=0)
# Store_B gets 0 instead of NaN

diff = sales_feb_aligned['Sales'] - sales_jan['Sales']
# Store_A     10
# Store_B   -400   ← Feb was 0, Jan was 400, so 0-400 = -400
# Store_C     10
```

> Choose `fill_value=0` carefully — it implies "Store_B had zero sales in Feb" which might not be the same as "Store_B didn't report". Always know what your NaN means before filling it.

### reindex on columns — aligning column structure

```python
# source_a has columns: Product, Price, Stock
# source_b has columns: Price, Product (different order, missing Stock)

aligned_b = source_b.reindex(columns=source_a.columns, fill_value=0)
# Now source_b has the same column order as source_a
# Stock column added with fill_value=0
```

This is extremely useful in ETL pipelines when you're combining data from multiple sources that might have different column orders or missing columns.

---

> **Q: What is the difference between set_index and reindex?**

`set_index` promotes an existing column to become the DataFrame's row labels — the column moves to the index and disappears from df.columns. `reindex` doesn't touch columns — it changes what row or column labels exist by aligning to a new label list, inserting NaN for any label that wasn't in the original. Use `set_index` when you want to look up rows by a meaningful key. Use `reindex` when you need two DataFrames to share the same index structure so you can safely compare or combine them.

> **Q: When would you use reindex with fill_value?**

When you're aligning multiple DataFrames for operations like subtraction or comparison, and you want missing entries to be treated as zero (or some other default) rather than NaN. Common example: monthly sales reports where some stores didn't report — reindex with fill_value=0 treats them as having zero sales rather than unknown sales. Be careful though — zero and "no data" are semantically different. Always know what you're filling and why.

---

## 5. Iteration in Pandas

Iteration means looping through rows or columns of a DataFrame. You have three main ways to do it — but one of them is almost always the right answer.

### Setup for all examples

```python
df = pd.DataFrame({
    'Name': ['Alice', 'Bob', 'Charlie'],
    'Age': [25, 30, 35],
    'City': ['Delhi', 'Mumbai', 'Chennai']
})
```

### Method 1: iterrows() — loop by row, get a Series

```python
for index, row in df.iterrows():
    print(f"{index}: {row['Name']} lives in {row['City']} and is {row['Age']} years old.")
```

Output from your notebook:
```
0: Alice lives in Delhi and is 25 years old.
1: Bob lives in Mumbai and is 30 years old.
2: Charlie lives in Chennai and is 35 years old.
```

- `index` = the row label (0, 1, 2 here)
- `row` = a Series with all column values for that row
- Access values like a dict: `row['Name']`, `row['Age']`

### Method 2: itertuples() — loop by row, get a namedtuple (faster)

```python
for row in df.itertuples():
    print(row)           # Pandas(Index=0, Name='Alice', Age=25, City='Delhi')
    print(row.Index)     # 0
    print(f"{row.Name} lives in {row.City}, and is {row.Age} years old.")
```

- Access values with dot notation: `row.Name`, `row.Age`
- **Faster than iterrows** because it returns a namedtuple, not a Series
- Column names become attributes — no string lookup needed

### Method 3: Iterating over columns

```python
for col in df.columns:
    print(f"Column: {col}")
    print(df[col].values)  # prints the NumPy array of values
```

Output:
```
Column: Name
['Alice', 'Bob', 'Charlie']
Column: Age
[25 30 35]
Column: City
['Delhi', 'Mumbai', 'Chennai']
```

You can also do `list(df.columns)` to get column names as a plain Python list.

### When to use each

| Method | Speed | Use when |
|---|---|---|
| `iterrows()` | Slow | You need a full Series per row, or debugging |
| `itertuples()` | Faster | You just need row values, not to modify anything |
| Vectorized / `apply()` | Fastest | **Production code — always prefer this** |

> Loops in pandas are slow because pandas is designed for vectorized operations. For 891 rows (Titanic) you won't notice. For 10 million rows, a loop can take minutes while vectorized code takes seconds.

---

> **Q: What is the difference between iterrows() and itertuples()?**

Both iterate row by row, but `iterrows()` returns each row as a pandas Series (with overhead from creating a Series object each iteration), while `itertuples()` returns each row as a Python namedtuple. `itertuples()` is significantly faster — sometimes 5-10x — because namedtuples are lightweight and values are accessed via attribute lookup (`row.Name`) rather than dict-style lookup (`row['Name']`). In production code, neither should be your first choice — prefer vectorized operations or `apply()`.

> **Q: Why is iterating over pandas DataFrames generally considered bad practice?**

Because pandas is built on NumPy, which is designed for vectorized operations — applying a function to all rows at once using C-level loops, not Python loops. When you write `for row in df.iterrows()`, you're running a Python for loop over potentially millions of rows. Python loops are slow — each iteration has overhead. The same operation with `df['col'].apply(func)` or `df['col'] > threshold` runs the operation on all rows simultaneously in optimized C code, which can be 100x faster.

---

## 6. apply() — The Better Way

`apply()` runs a function on every element in a column (or every row in a DataFrame) without an explicit for loop. It's the recommended alternative to iteration for creating new columns.

### Adding a column with conditional logic — 3 ways

You wanted to classify passengers as 'young' (< 40) or 'senior' (>= 40) based on Age.

#### Way 1: iterrows loop — works but slow

```python
categories = []

for idx, row in df.iterrows():
    if row['Age'] < 40:
        categories.append('young')
    else:
        categories.append('senior')

df['Category'] = categories
```

This works. For 891 rows it's fine. For 10 million rows — don't do this.

#### Way 2: apply() with lambda — clean and fast

```python
df['Category'] = df['Age'].apply(lambda age: 'young' if age < 40 else 'senior')
```

One line. Same result. Much faster.

#### Way 3: apply() with named function — readable and reusable

```python
def categorize_age(age):
    return 'young' if age < 40 else 'senior'

df['Category'] = df['Age'].apply(categorize_age)
```

Best for complex logic — easier to test, easier to read, reusable elsewhere.

### apply() across multiple columns (axis=1)

When your function needs to look at more than one column, use `axis=1`:

```python
def check_if_delhi_and_young(row):
    city = row['City']
    age = row['Age']
    if city == 'Delhi' and age < 40:
        return True
    return False

df['Is_young_delhi'] = df.apply(check_if_delhi_and_young, axis=1)
```

Output from your notebook:
```
      Name  Age     City  Is_young_delhi
0    Alice   25    Delhi            True   ← Delhi and young
1      Bob   30   Mumbai           False   ← not Delhi
2  Charlie   35  Chennai           False   ← not Delhi
```

### axis=0 vs axis=1 — what it means

```python
# axis=0 — keep column constant, loop through rows
# (apply the function to each column as a whole)
df.apply(func, axis=0)

# axis=1 — keep row constant, loop through columns
# (apply the function to each row as a whole — what you did above)
df.apply(func, axis=1)
```

---

> **Q: What is the difference between apply() with axis=0 and axis=1?**

`axis=0` (the default) applies the function to each **column** as a Series — the function receives all the values in a column. `axis=1` applies the function to each **row** as a Series — the function receives all the column values for a single row. You use `axis=1` when your function needs to look at multiple columns of the same row at once, like combining City and Age to make a decision.

> **Q: When should you use apply() vs a vectorized operation?**

Prefer vectorized operations whenever possible: `df['col'] > 40` is faster than `df['col'].apply(lambda x: x > 40)`. Use `apply()` when your logic is complex (multiple conditions, string manipulation, custom business rules) and can't easily be expressed as a vectorized pandas expression. Never use `apply()` for simple math or comparisons — those are always faster with built-in pandas/NumPy operations.

---

## 7. inplace — What it Really Means

Your instructor used a really good analogy in the notebook with a `Cal` class. Here's the concept clearly.

### The analogy from your notebook

```python
class Cal:
    def __init__(self, a):
        self.a = a

    def add(self, b):           # returns result, doesn't change self.a
        return self.a + b

    def inplace_add(self, b):   # changes self.a directly
        self.a = self.a + b
        return self.a
```

```python
c = Cal(10)

c.add(10)      # returns 20 — but c.a is still 10
c.a            # 10 — unchanged

c.inplace_add(10)  # returns 20 AND c.a becomes 20
c.a                # 20 — modified
```

### How this maps to pandas

```python
# inplace=False (default) — returns a new DataFrame, original unchanged
sorted_df = df.sort_values(by='Age')          # df is still original order
df = df.sort_values(by='Age')                 # df is now sorted (you reassigned)

# inplace=True — modifies the original directly, returns None
df.sort_values(by='Age', inplace=True)        # df is now sorted, returns None
result = df.sort_values(by='Age', inplace=True)
print(result)  # None — inplace returns nothing!
```

### Why inplace=True is being phased out

In modern pandas (2.x and 3.x), the pandas team recommends **avoiding inplace=True** because:
1. It's confusing — returns None, which leads to bugs like `df = df.sort_values(inplace=True)` setting df to None
2. It doesn't actually save memory in most cases (pandas copies internally anyway)
3. Method chaining is cleaner: `df = df.sort_values('Age').reset_index(drop=True)`

**The modern way:**
```python
# Instead of inplace=True
df.sort_values(by='Age', inplace=True)  # old style

# Do this instead
df = df.sort_values(by='Age')           # cleaner, safer
```

---

> **Q: What does inplace=True do in pandas and why is it being deprecated?**

`inplace=True` modifies the DataFrame directly instead of returning a new one. However, it's being phased out in modern pandas because: 1) It returns `None`, causing hard-to-catch bugs when developers write `df = df.method(inplace=True)` — df becomes None. 2) Despite the name, it doesn't actually save memory because pandas still makes internal copies during most operations. 3) It prevents method chaining. The modern recommendation is to always reassign: `df = df.sort_values('Age')`.

---

## 8. Sorting in Pandas

You have two sorting tools — one for data values, one for index labels.

### sort_values() — sort by data

```python
# Syntax
df.sort_values(by, axis=0, ascending=True, inplace=False, na_position='last')
```

| Parameter | What it does |
|---|---|
| `by` | Column name(s) to sort by |
| `ascending` | True = low to high (default), False = high to low |
| `na_position` | Where NaN goes: `'last'` (default) or `'first'` |
| `inplace` | Modify in place (avoid — reassign instead) |

#### Sort by single column

```python
sorted_df = df.sort_values(by='Age')
print(sorted_df[['Name', 'Age']].head(10))
```

Output from your notebook (youngest first):
```
                               Name   Age
Thomas, Master. Assad Alexander   0.42
Hamalainen, Master. Viljo         0.67
Baclini, Miss. Eugenie            0.75
...
```

And NaNs go to the bottom by default:
```
tail shows NaN ages at the end:
Johnston, Miss. Catherine Helen   NaN
Marechal, Mr. Pierre              NaN
```

#### Sort by multiple columns — with different directions

```python
# Sort by Pclass ascending, then Fare descending within each class
df_sorted = df.sort_values(by=['Pclass', 'Fare'], ascending=[True, False])
df_sorted.head()
```

Output — Class 1 passengers with highest fares first:
```
     Pclass      Fare    Name
258       1  512.3292  Ward, Miss. Anna
679       1  512.3292  Cardeza, Mr. Thomas Drake Martinez
737       1  512.3292  Lesurer, Mr. Gustave J
```

This is how you'd answer "find the most expensive first class tickets" in an interview.

### sort_index() — sort by row or column labels

```python
# Sort rows by index
df_sort_2 = df.set_index('PassengerId')
df_sorted_by_index = df_sort_2.sort_index()
# Now rows are ordered by PassengerId: 1, 2, 3...

# Sort columns alphabetically
df_sorted = df[sorted(df.columns)]
# Columns now in alphabetical order: Age, Cabin, Embarked, Fare, Name...
```

The `sorted(df.columns)` trick is clean — `sorted()` returns a Python list, and `df[list]` selects columns in that order.

### na_position — controlling where NaN lands

```python
# Default: NaN at the end
df.sort_values('Age')                          # NaN passengers at bottom

# Put NaN at the top
df.sort_values('Age', na_position='first')    # NaN passengers at top
```

---

> **Q: How do you sort by multiple columns with different sort directions?**

`df.sort_values(by=['col1', 'col2'], ascending=[True, False])` — pass a list to `by` and a matching list to `ascending`. The first column is the primary sort key, the second is the tiebreaker. In the Titanic example: `df.sort_values(by=['Pclass', 'Fare'], ascending=[True, False])` sorts by class (cheapest first) then within each class by fare (most expensive first), giving you the highest-paying passengers per class.

> **Q: What is the difference between sort_values and sort_index?**

`sort_values(by='col')` reorders rows based on the actual data in a column. `sort_index()` reorders rows based on their index labels. You use `sort_index()` when you've done operations that scrambled the index — like after filtering or after `set_index()` with a non-sequential key — and you want to restore logical order. You can also use `sort_index(axis=1)` to sort columns alphabetically.

---

## 9. astype and the NaN Problem

This is a real error you hit in your notebook and it comes up constantly in practice.

### The error

```python
df['Age'].dtype   # float64 — because NaN exists in Age column

df['Age'] = df['Age'].astype('int64')
# IntCastingNaNError: Cannot convert non-finite values (NA or inf) to integer.
```

**Why does this happen?** NaN is a float concept in NumPy. You can't convert a float column that contains NaN to int64 because integers have no way to represent "missing." Pandas will refuse rather than silently converting NaN to 0 (that would be data corruption).

### The fix from your notebook

```python
# Fill NaN first, then convert
df['Age'] = df['Age'].fillna(0).astype('int64')

# Verification
print(df[['Name', 'Age']].tail(10))
# Johnston, Miss. Catherine Helen   0  ← was NaN, now 0
# Braund, Mr. Owen Harris          22  ← was 22.0, now 22
```

### The better approach in production

```python
# Option 1: Fill with median (more realistic than 0)
df['Age'] = df['Age'].fillna(df['Age'].median()).astype('int64')

# Option 2: Use nullable integer type (pandas 1.0+)
df['Age'] = df['Age'].astype('Int64')   # capital I — supports NaN natively
# Now Age can be int AND have NaN (shown as <NA>)
```

The `Int64` (capital I) type is pandas' nullable integer — it supports NaN without needing to be float64. This is the modern approach.

---

> **Q: Why does astype('int64') fail on the Age column of the Titanic dataset?**

Because Age is `float64` — it contains NaN values, and NaN is a float-type sentinel in NumPy. Standard `int64` has no way to represent "missing" — every cell must have a valid integer. Pandas raises `IntCastingNaNError` rather than silently converting NaN to 0 (which would be wrong). The fix is either: fill NaN first with `fillna()` then convert, or use `Int64` (capital I) — pandas' nullable integer type that supports NaN natively without float overhead.

---

## 10. String Operations with .str accessor

Pandas has a `.str` accessor that lets you apply Python string methods to an entire column at once — no loop needed.

```python
# From your notebook — operations on the Name column

df['Name'].str.lower()       # all lowercase
df['Name'].str.upper()       # ALL UPPERCASE
df['Name'].str.capitalize()  # First letter uppercase, rest lower
df['Name'].str.len()         # length of each name as an integer
```

Output from your notebook:
```python
# str.lower()
0    braund, mr. owen harris
1    cumings, mrs. john bradley...

# str.upper()
0    BRAUND, MR. OWEN HARRIS

# str.capitalize() — only first letter of entire string is capitalized
0    Braund, mr. owen harris   # note: 'mr.' is NOT capitalized

# str.len()
0    23   # "Braund, Mr. Owen Harris" has 23 characters
1    51
```

### More useful .str methods (for interviews)

```python
df['Name'].str.contains('Miss')           # True/False — does name contain 'Miss'?
df['Name'].str.startswith('B')            # True/False
df['Name'].str.split(', ')               # split by comma-space
df['Name'].str.strip()                    # remove leading/trailing whitespace
df['Name'].str.replace('Mr.', 'Mr')      # replace substring
df['Name'].str.extract(r'(\w+),')        # extract first word (surname) with regex
```

### Why .str matters in interviews

When you get messy real-world data, text columns are almost always dirty. Interviewers give you tasks like "extract the title from passenger names" or "standardize email addresses to lowercase" — all solvable with `.str` methods.

---

> **Q: How do you apply string operations to an entire column in pandas?**

Use the `.str` accessor. `df['col'].str.lower()` applies `.lower()` to every value in the column without a loop. It works for all common string methods: `.upper()`, `.contains()`, `.replace()`, `.split()`, `.strip()`, `.len()`, `.startswith()`, `.extract()` for regex. The `.str` accessor handles NaN gracefully — it returns NaN for any row where the value is already NaN, so you don't get errors on mixed-type columns.

> **Q: What does str.capitalize() do vs str.title()?**

`str.capitalize()` only capitalizes the very first character of the entire string and lowercases everything else. `str.title()` capitalizes the first character of each word. For "braund, mr. owen harris": `capitalize()` gives "Braund, mr. owen harris" — only the B is capital. `title()` gives "Braund, Mr. Owen Harris" — every word starts with a capital.

---

## 11. Full Interview Q&A Bank

> **Q: What is a view vs a copy in pandas, and when does it matter?**  
A view shares memory with the original DataFrame — changes to the view can affect the original. A copy is independent — changes never affect the original. It matters when you filter or slice and then try to modify the result. Always use `.copy()` when you intend to modify a subset to avoid `SettingWithCopyWarning` and silent bugs.

> **Q: How do you safely modify a filtered subset of a DataFrame?**  
Either: 1) Use `.copy()` on the filtered result: `subset = df[condition].copy()`, then modify `subset` freely. Or 2) Use `.loc` directly on the original: `df.loc[condition, 'col'] = value` — this always modifies the original correctly without warnings.

> **Q: What is the difference between set_index and reindex?**  
`set_index` promotes a column to become the row labels — the column disappears from `df.columns`. `reindex` changes which labels exist in the index by aligning to a new list — inserting NaN for any label that wasn't there before. `set_index` is for lookup; `reindex` is for alignment.

> **Q: When would you use reindex in a real pipeline?**  
When combining data from multiple sources that don't share the same index. Classic example: monthly sales reports where some stores didn't report in certain months. `reindex` to a common store list, then `fill_value=0` for missing months. Without reindex, operations between the two DataFrames would produce NaN-filled results that don't make sense.

> **Q: What is the difference between iterrows and itertuples?**  
Both loop row by row. `iterrows()` returns each row as a Series (slower). `itertuples()` returns each row as a namedtuple (faster — sometimes 5-10x). For values, `iterrows` uses `row['col']`, itertuples uses `row.col`. In production, avoid both and use `apply()` or vectorized operations instead.

> **Q: When should you use apply() vs a vectorized operation?**  
Vectorized operations first — they're fastest: `df['Age'] > 40`. Use `apply()` for complex custom logic that can't be expressed as a simple comparison or arithmetic operation — multi-column conditions, string parsing, external function calls. Never use `apply()` for simple math.

> **Q: What does inplace=True do and should you use it?**  
It modifies the DataFrame in place instead of returning a new one — returns None. Avoid it in modern code because: it returns None (causes bugs when you accidentally do `df = df.sort_values(inplace=True)`), doesn't actually save memory, and prevents method chaining. Just reassign: `df = df.sort_values('Age')`.

> **Q: How do you sort by multiple columns in different directions?**  
`df.sort_values(by=['col1','col2'], ascending=[True, False])` — first column ascending, second descending. The first column is the primary sort key; the second breaks ties.

> **Q: Why does astype('int64') raise IntCastingNaNError?**  
Because `int64` cannot represent NaN — integers require a concrete value in every cell. When Age has NaN values, pandas refuses to silently convert them to 0 (data corruption). Fix: `df['Age'].fillna(0).astype('int64')` or use nullable integer `df['Age'].astype('Int64')` (capital I).

> **Q: How do you sort columns alphabetically in pandas?**  
`df = df[sorted(df.columns)]` — `sorted()` returns a Python list of column names in alphabetical order, then `df[list]` selects columns in that order. You can also use `df.sort_index(axis=1)` which does the same thing.

> **Q: How does the .str accessor handle NaN values?**  
Gracefully — it returns NaN for any row where the value is already NaN, instead of raising an error. So `df['col'].str.lower()` on a column with some NaN values gives you lowercased strings where data exists and NaN where it doesn't. This is one of the advantages over writing your own loop with `.apply()`.

---

## 12. Quick Reference Card

```python
# Views vs Copies
subset = df[condition].copy()               # always safe to modify
df.loc[condition, 'col'] = value            # modify original directly

# set_index
df_by_name = df.set_index('Name')           # Name becomes row label
df_by_name.loc['Allen, Miss. Elisabeth Walton']  # lookup by name
df_by_name.reset_index()                    # Name back as column

# reindex
df_feb_aligned = df_feb.reindex(df_jan.index)              # align rows, NaN for missing
df_feb_aligned = df_feb.reindex(df_jan.index, fill_value=0) # fill missing with 0
df_b_aligned = df_b.reindex(columns=df_a.columns, fill_value=0) # align columns

# Iteration
for idx, row in df.iterrows(): ...          # row is a Series — row['col']
for row in df.itertuples(): ...             # row is namedtuple — row.col (faster)
for col in df.columns: ...                  # loop over column names

# apply()
df['col'] = df['Age'].apply(lambda x: 'young' if x < 40 else 'senior')
df['col'] = df['Age'].apply(my_function)
df['col'] = df.apply(multi_col_function, axis=1)  # axis=1 = row-wise

# Sorting
df.sort_values(by='Age')                           # ascending by default
df.sort_values(by='Age', ascending=False)          # descending
df.sort_values(by='Age', na_position='first')      # NaN at top
df.sort_values(by=['Pclass','Fare'], ascending=[True, False])  # multi-column
df.sort_index()                                    # sort by row labels
df.sort_index(axis=1)                              # sort columns alphabetically
df[sorted(df.columns)]                             # same — sort columns alphabetically

# astype with NaN
df['Age'].fillna(0).astype('int64')               # fill NaN then convert
df['Age'].astype('Int64')                          # nullable integer — supports NaN

# String operations
df['Name'].str.lower()
df['Name'].str.upper()
df['Name'].str.capitalize()                        # only first letter of whole string
df['Name'].str.title()                             # first letter of each word
df['Name'].str.len()                               # length of each string
df['Name'].str.contains('Miss')                   # True/False per row
df['Name'].str.startswith('B')
df['Name'].str.replace('Mr.', 'Mr')
df['Name'].str.strip()                             # remove whitespace
```

---

*Next session: groupby · agg · merge · concat*  
*Send the notebook after the next Krish Naik session and the next chapter gets added.*
