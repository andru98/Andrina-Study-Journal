# Pandas Session 1 — Interview-Ready Notes

> **Date:** 22 February 2026 | **Dataset:** Titanic | **Level:** FAANG-ready  
> **Topics:** What is Pandas · Series · DataFrame · loc · iloc · Boolean Filtering · set_index · reset_index · read_csv · EDA

---

## Table of Contents
1. [What is Pandas?](#1-what-is-pandas)
2. [Series — 1D Labeled Array](#2-series--1d-labeled-array)
3. [Series Indexing — iloc vs loc](#3-series-indexing--iloc-vs-loc)
4. [DataFrame — 2D Labeled Table](#4-dataframe--2d-labeled-table)
5. [Loading Data — pd.read_csv()](#5-loading-data--pdread_csv)
6. [EDA — Exploratory Data Analysis](#6-eda--exploratory-data-analysis)
7. [DataFrame Indexing — loc and iloc](#7-dataframe-indexing--loc-and-iloc)
8. [Boolean Filtering](#8-boolean-filtering)
9. [set_index and reset_index](#9-set_index-and-reset_index)
10. [Slicing Rows and Columns Together](#10-slicing-rows-and-columns-together)
11. [Connection to the Backtest](#11-connection-to-the-backtest)
12. [Full Interview Q&A Bank](#12-full-interview-qa-bank)
13. [Quick Reference Card](#13-quick-reference-card)

---

## 1. What is Pandas?

Pandas is an open-source Python library for **data manipulation and analysis**. It provides powerful, fast, flexible, and expressive data structures designed to work with structured (tabular) data.

- **Name origin:** Panel Data — an econometrics term for multidimensional structured data
- **Built on top of:** NumPy — all pandas operations are vectorized NumPy operations under the hood

> 💡 **Think of pandas as:** Excel + NumPy + SQL + ETL tools — all inside Python

---

### 1.1 Why Was Pandas Created?

| Before Pandas (the problem) | With Pandas (the solution) |
|---|---|
| Raw Python lists and dicts | Labeled, indexed Series and DataFrame |
| No concept of column names | Every column has a name — `df['Age']` |
| Manual CSV/JSON/Excel parsing | `pd.read_csv()`, `pd.read_json()` one-liners |
| No missing data handling | `fillna()`, `dropna()`, `isnull()` built in |
| No grouping or aggregation | `groupby()`, `agg()`, `pivot_table()` |
| No join / merge logic | `merge()` replicates SQL JOIN exactly |
| No time series support | `DatetimeIndex`, `resample()`, `rolling()` |
| Real-world data is tabular | DataFrame matches that structure natively |

---

### 1.2 Where Is Pandas Used?

| Field | How Pandas Helps | Example |
|---|---|---|
| Data Science | Load, clean, explore, transform | EDA on Titanic survival data |
| Machine Learning | Feature engineering, preprocessing | Create lag features for LSTM |
| Finance / Trading | Time series, OHLCV, indicators | VWAP, EMA on TSLA 15m bars |
| Web / Analytics | ETL pipelines, product stats | Daily active users aggregation |
| Healthcare | Patient records, statistics | Survival analysis by age group |
| Data Engineering | Transform raw data, write to Parquet | `groupby + agg` then `to_parquet()` |

---

### 1.3 Core Pandas Objects

| Object | Dimensions | Analogy | Status |
|---|---|---|---|
| `Series` | 1D | One column of an Excel sheet | ✅ Current |
| `DataFrame` | 2D | Full Excel sheet / SQL table | ✅ Current |
| `Panel` | 3D | Stack of DataFrames | ❌ Deprecated since pandas 1.0 |

> 📌 **NOTE:** Panel was replaced by MultiIndex DataFrame. If asked about 3D data in pandas — answer is MultiIndex DataFrame or xarray.

---

### Interview Questions

> **Q: What is pandas and why use it instead of plain Python lists?**

Pandas provides labeled, indexed 2D data structures (DataFrame) and 1D (Series) with built-in support for grouping, merging, missing data, time series, and file I/O. Plain lists have none of this. Pandas is also backed by NumPy so operations are vectorized — orders of magnitude faster than Python loops.

> **Q: What does the pandas name stand for?**

Panel Data — a term from econometrics referring to multidimensional structured data observed over time. The library was originally designed for financial time series analysis.

---

## 2. Series — 1D Labeled Array

A Series is a one-dimensional labeled array that can hold any data type. Think of it as a **single column from an Excel spreadsheet** — values + index (row labels).

---

### 2.1 Full pd.Series() Signature

```python
pd.Series(data=None, index=None, dtype=None, name=None, copy=False)
```

| Parameter | What it does | Default |
|---|---|---|
| `data` | Values: list, dict, scalar, NumPy array | None |
| `index` | Row labels — must match data length | Auto 0,1,2... |
| `dtype` | Force a type: `'float32'`, `'int64'`, `'str'` | Inferred |
| `name` | Label for the Series — becomes column name in df | None |
| `copy` | Copy data instead of referencing it | False |

---

### 2.2 Four Ways to Create a Series

#### 1. From a list — auto index 0,1,2...
```python
data = [1, 2, 3, 4, 5, 6]
s1 = pd.Series(data)
```
```
0    1
1    2
2    3
dtype: int64
```

#### 2. From a list with custom index and name
```python
s2 = pd.Series(data, index=['a','b','c','d','e','f'], name='Numbers')
```
```
a    1
b    2
c    3
Name: Numbers, dtype: int64
```

#### 3. From a dictionary — keys become the index
```python
data = {'a': 10, 'b': 20, 'c': 30}
s3 = pd.Series(data)
```
```
a    10
b    20
c    30
dtype: int64
```

> 💡 **TIP:** Most natural when you already have a dict. Keys become index labels automatically.

#### 4. From a NumPy array
```python
import numpy as np
arr = np.array([5, 10, 15])
s4 = pd.Series(arr, index=['x', 'y', 'z'])
```

---

### 2.3 Series Attributes

```python
s2 = pd.Series([10, 20, 30, 40], index=['a','b','c','d'], name='Scores')

s2.index     # Index(['a','b','c','d'], dtype='str')
s2.values    # array([10, 20, 30, 40])  ← NumPy array
s2.dtype     # int64
s2.name      # 'Scores'
s2.shape     # (4,)  ← tuple, even for 1D
```

---

### Interview Questions

> **Q: What is the difference between s.values and s.index?**

`s.values` returns a NumPy array of the actual data — the numbers or strings stored. `s.index` returns the Index object — the labels used to look up rows. values = the "what", index = the "where".

> **Q: Why is s2.shape a tuple like (4,) instead of just 4?**

Because shape follows NumPy convention — always returns a tuple of dimensions. For 1D Series it's `(4,)`. For a 2D DataFrame it's `(891, 12)`. This consistency means you can always do `df.shape[0]` for rows and `df.shape[1]` for columns.

---

## 3. Series Indexing — iloc vs loc

> 🔑 **KEY:** The single most common pandas indexing interview question. Understand not just the definition but the slicing difference and the pandas 3.0 behavior change.

---

### 3.1 Three Ways to Access a Series Value

```python
s2 = pd.Series([10, 20, 30, 40], index=['a','b','c','d'], name='Scores')

s2.values[0]   # 10 — bypasses pandas, raw NumPy
s2.iloc[0]     # 10 — always by position
s2.loc['a']    # 10 — always by label
```

> 💡 **TIP:** Always use `.iloc` or `.loc` explicitly. Never use `s[0]` directly — it is ambiguous across pandas versions.

---

### 3.2 iloc — Integer Location (Position-Based)

```python
s2.iloc[0]        # 10  ← first element
s2.iloc[-1]       # 40  ← last element
s2.iloc[1:3]      # b:20, c:30  (index 3 = 'd' is NOT included — exclusive)
s2.iloc[[0, 2]]   # a:10, c:30
```

---

### 3.3 loc — Label Based

```python
s2.loc['a']          # 10
s2.loc['b':'d']      # b:20, c:30, d:40  (d IS included — inclusive)
s2.loc[['b', 'd']]   # b:20, d:40
s2.loc[s2 > 15]      # b:20, c:30, d:40  ← boolean with loc
```

---

### 3.4 The Slicing Difference — Critical

| | `iloc[1:3]` | `loc['b':'d']` |
|---|---|---|
| Basis | Position numbers | Index labels |
| End included? | ❌ No — exclusive (like Python lists) | ✅ Yes — inclusive |
| Result | positions 1, 2 | labels b, c, d |
| Values returned | 20, 30 | 20, 30, 40 |

---

### 3.5 The pandas 3.0 Behavior Change — From Your Notebook

In your notebook you tried `s2[0]` where s2 had string index `['a','b','c','d']`. It raised a `KeyError`. Here is exactly why:

```python
s2 = pd.Series([10,20,30,40], index=['a','b','c','d'])

# Pandas 2.x behavior:
# s2[0] → tried label 0 → not found → fell back to position → returned 10

# Pandas 3.0 behavior (what you are using):
s2[0]    # KeyError: 0 — no fallback. 0 is NOT a label.

# The fix — always be explicit:
s2.iloc[0]   # 10 ← by position
s2.loc['a']  # 10 ← by label
```

> ⚠️ **PITFALL:** `s2[0]` on a string-indexed Series raises KeyError in pandas 3.0. This is a breaking change from pandas 2.x. In interviews always say: *"I use .iloc or .loc explicitly to avoid ambiguity."*

---

### Interview Questions

> **Q: What is the difference between iloc and loc?**

`iloc` selects by integer position — `iloc[0]` is always the first row regardless of index labels. `loc` selects by label — `loc['a']` finds the row whose index IS `'a'`. Critical slicing difference: `iloc[1:3]` excludes position 3 (Python list convention), while `loc['b':'d']` includes `'d'` (both ends inclusive).

> **Q: When would iloc and loc give the same result?**

When the index is the default RangeIndex (0, 1, 2, 3...). In that case both `iloc[0]` and `loc[0]` return the first row because the label 0 IS at position 0. The moment you use a custom index — strings, dates, PassengerId — they diverge.

---

## 4. DataFrame — 2D Labeled Table

A DataFrame is a two-dimensional labeled data structure where each column can hold a different data type. Internally it is a **dictionary of Series objects** all sharing the same index.

> 📌 **NOTE:** Key insight: A DataFrame IS a dict of Series. `df['Age']` gives you the Age Series. `df.columns` gives the dict keys. This mental model explains every operation.

---

### 4.1 Three Ways to Create a DataFrame

#### 1. From a dict of lists — most common
```python
data = {
    'Name' : ['Hemanth', 'Aditya', 'Rajbeer'],
    'Age'  : [30, 31, 32],
    'City' : ['Delhi', 'Mumbai', 'Bangalore']
}
df = pd.DataFrame(data)
```
```
      Name  Age       City
0  Hemanth   30      Delhi
1   Aditya   31     Mumbai
2  Rajbeer   32  Bangalore
```

#### 2. From a list of dicts — each dict is one row
```python
records = [
    {'Name': 'Hemanth', 'Age': 30, 'City': 'Delhi'},
    {'Name': 'Aditya',  'Age': 31, 'City': 'Mumbai'},
    {'Name': 'Rajbeer', 'Age': 32, 'City': 'Bangalore'}
]
df = pd.DataFrame(records)   # same output as above
```

> 💡 **TIP:** This is the pattern used in the backtest — `signals.append({...})` inside a loop, then `pd.DataFrame(signals)` at the end. `list.append()` is O(1) — much faster than adding rows to a DataFrame directly.

#### 3. From a NumPy 2D array
```python
arr = np.array([[1, 2], [3, 4], [5, 6]])
df = pd.DataFrame(arr, columns=['A', 'B'])
```

> 📌 **NOTE:** All columns share the same dtype when created from NumPy (homogeneous). Use dict of lists when columns have different types.

---

### Interview Questions

> **Q: What are the three main ways to create a DataFrame?**

1. Dict of lists — `pd.DataFrame({'col1':[1,2], 'col2':[3,4]})` — most common for creating from scratch
2. List of dicts — `pd.DataFrame([{'a':1,'b':2}, {'a':3,'b':4}])` — natural when building records one at a time
3. NumPy 2D array — `pd.DataFrame(arr, columns=['A','B'])` — when data is already matrix form

> **Q: Why is list-of-dicts preferred when building a DataFrame in a loop?**

Because `list.append()` is O(1) — constant time. Appending rows to a DataFrame directly copies the entire DataFrame each iteration — O(n²). The correct pattern: build a Python list of dicts inside the loop, then call `pd.DataFrame(list)` once at the end.

---

## 5. Loading Data — pd.read_csv()

### 5.1 From a URL
```python
url = 'https://raw.githubusercontent.com/datasciencedojo/datasets/refs/heads/master/titanic.csv'
df = pd.read_csv(url)
```

### 5.2 From a Local File
```python
df = pd.read_csv('titanic.csv')               # file in same folder
df = pd.read_csv('/full/path/to/titanic.csv') # absolute path
```

### 5.3 Key Parameters

| Parameter | What it does | Example |
|---|---|---|
| `filepath` | Path or URL to CSV | `pd.read_csv('data.csv')` |
| `usecols` | Load only specific columns — saves memory | `usecols=['Name','Age','Survived']` |
| `nrows` | Load only first N rows | `nrows=100` |
| `skiprows` | Skip N rows at top | `skiprows=2` |
| `index_col` | Set column as index on load | `index_col='PassengerId'` |
| `parse_dates` | Parse column as datetime | `parse_dates=['Date']` |
| `dtype` | Force column types | `dtype={'Age': float}` |
| `na_values` | Extra strings to treat as NaN | `na_values=['NA','--','?']` |
| `chunksize` | Read in chunks for large files | `chunksize=10000` |

> 💡 **TIP:** Mentioning `usecols` and `chunksize` in interviews signals you think about memory — a senior-level concern.

### 5.4 display() vs print()

```python
print(df.head(3))    # plain text — works everywhere
display(df.head(3))  # HTML table — Jupyter only, richer output
```

> 📌 **NOTE:** `display()` is a Jupyter/IPython function. In a `.py` script or production code, use `print()`. In notebooks, `display()` renders a proper HTML table.

---

### Interview Questions

> **Q: How would you load only Name, Age, Survived from a 10GB CSV?**

`pd.read_csv('file.csv', usecols=['Name','Age','Survived'])`. The `usecols` parameter skips all other columns during parsing — never loads them into memory. For a 10GB file also add `chunksize=100000` to process in chunks: `for chunk in pd.read_csv('file.csv', chunksize=100000): process(chunk)`.

---

## 6. EDA — Exploratory Data Analysis

> 🔑 **KEY:** EDA is the first thing you do with any new dataset. Every FAANG data interview will ask "walk me through your first steps on this data." This section is your answer.

---

### 6.1 The EDA Protocol — 6 Steps

```python
df = pd.read_csv('titanic.csv')

df.shape            # (891, 12) — rows, columns
df.columns          # Index(['PassengerId','Survived','Pclass',...])
df.info()           # dtypes + non-null counts + memory
df.isnull().sum()   # Age:177  Cabin:687  Embarked:2
df.describe()       # count, mean, std, min, 25%, 50%, 75%, max
df.head(5)          # first 5 rows
df.tail(5)          # last 5 rows — check data ends cleanly
```

---

### 6.2 Reading df.info() Output

From your notebook — `info()` on passengers older than 70:

```
<class 'pandas.DataFrame'>
Index: 5 entries, 96 to 851
Data columns (total 12 columns):
 #   Column       Non-Null Count  Dtype
---  ------       --------------  -----
 0   PassengerId  5 non-null      int64
 1   Survived     5 non-null      int64
 5   Age          5 non-null      float64   ← float because NaN exists in full df
10   Cabin        2 non-null      str       ← 3 MISSING!
dtypes: float64(2), int64(5), str(5)
memory usage: 520.0 bytes
```

| Part of info() output | What it means | Action |
|---|---|---|
| `Index: 5 entries, 96 to 851` | Filtered df — original row numbers kept | Index is NOT 0-4 |
| `2 non-null` on Cabin | 3 rows are missing Cabin | Investigate before using |
| Age is `float64` not `int64` | Column has NaN — NaN can't exist in int | Fill NaN then downcast |
| `memory usage: 520.0 bytes` | Small df — but check on million-row data | Use float32 to halve memory |

---

### 6.3 Reading df.describe() Output

From your notebook — `describe()` on passengers older than 70:

```
       PassengerId  Survived  Pclass    Age   Fare
count     5.000000  5.000000    5.00   5.00   5.00
mean    438.200000  0.200000    1.80  73.30  25.94
std     328.292096  0.447214    1.10   3.99  18.09
min      97.000000  0.000000    1.00  70.50   7.75
25%     117.000000  0.000000    1.00  71.00   7.78
50%     494.000000  0.000000    1.00  71.00  30.00
75%     631.000000  0.000000    3.00  74.00  34.65
max     852.000000  1.000000    3.00  80.00  49.50
```

| Statistic | What to look for | Titanic insight |
|---|---|---|
| `count` | Are all rows present? | 5 — matches our filter |
| `mean` | Average value | Survived=0.2 — only 20% survived |
| `std` | Spread — high = wide distribution | Age std=3.99 — tightly clustered |
| `min/max` | Outliers? Range sensible? | Age 70.5 to 80 — matches filter |
| `50%` | Median — compare with mean for skew | Age median=71, mean=73.3 |
| `25%/75%` | Where 50% of data sits (IQR) | Age IQR: 71 to 74 |

---

### Interview Questions

> **Q: Walk me through your first 5 steps on a new dataset.**

1. `df.shape` — how big is it?
2. `df.dtypes` or `df.info()` — are columns the right type?
3. `df.isnull().sum()` — which columns have missing data?
4. `df.describe()` — are numeric ranges sensible? Any outliers?
5. `df.head()` and `df.tail()` — visual sanity check.

This is called **EDA — Exploratory Data Analysis**. Always name it explicitly in interviews.

> **Q: What does it mean when Age is float64 instead of int64?**

It means the column has at least one NaN value. NaN is a float-type sentinel in NumPy and cannot exist in an integer array. Pandas automatically upcasts integer columns to float64 when any value is missing. Fix: `df['Age'].fillna(df['Age'].median()).astype('int64')`.

---

## 7. DataFrame Indexing — loc and iloc

### 7.1 Selecting Columns

```python
df['Name']              # Single column → Series
df[['Name', 'Age']]     # Multiple columns → DataFrame (double brackets!)
df.columns              # All column names
```

> ⚠️ **PITFALL:** `df['Name','Age']` raises KeyError. Multi-column selection requires **double brackets**: `df[['Name','Age']]`. Outer `[]` = DataFrame indexer, inner `[]` = Python list.

---

### 7.2 iloc on a DataFrame

```python
df.iloc[0]           # First row → Series
df.iloc[-1]          # Last row → Series
df.iloc[:5]          # First 5 rows → DataFrame
df.iloc[0, 3]        # Row 0, Column index 3 → single value
df.iloc[0:3, 0:2]    # Rows 0-2, Columns 0-1 → DataFrame
df.iloc[0:5, 3]      # Rows 0-4, Column 3 → Series
df.iloc[0:3, [3, 1]] # Rows 0-2, Columns 3 and 1 — out of order!
```

### 7.3 loc on a DataFrame

```python
df.loc[0]                     # Row label 0 → Series
df.loc[0, 'Name']             # Row 0, column 'Name' → single value
df.loc[0:4, ['Name', 'Age']]  # Rows 0-4 INCLUSIVE, 2 columns → DataFrame
df.loc[0]['Name']             # Same — but avoid (chained indexing)
```

### 7.4 Titanic Examples from Your Notebook

```python
# First passenger full record
df.loc[0]              # Series: PassengerId=1, Survived=0, Name=Braund...

# Just the name
df.loc[0, 'Name']      # 'Braund, Mr. Owen Harris'
df.iloc[0, 3]          # same — column 3 is Name

# First 3 rows, first 2 columns
df.iloc[0:3, 0:2]      # PassengerId + Survived for rows 0,1,2

# Rows 0-4, Name + Age
df.loc[:4, ['Name', 'Age']]   # 5 rows (0,1,2,3,4), 2 columns

# First 3 rows, columns Name(3) and Survived(1)
df.iloc[0:3, [3, 1]]          # Name first, then Survived
```

---

### Interview Questions

> **Q: What is chained indexing and why avoid it?**

Chained indexing is `df[condition]['column']` — two indexing operations in sequence. Problems: 1) Slower — creates an intermediate DataFrame. 2) Assignment through chained indexing may silently fail — `df[condition]['col'] = value` might not modify the original df (SettingWithCopyWarning). Always use `df.loc[condition, 'col'] = value` — single operation, no ambiguity.

> **Q: Difference between df['Name'] and df[['Name']]?**

`df['Name']` returns a **Series** — 1D. `df[['Name']]` returns a single-column **DataFrame** — 2D. The outer brackets are the indexer, the inner brackets create a Python list. This matters when a function expects `df.columns` to exist.

---

## 8. Boolean Filtering

Boolean filtering checks a condition against an entire column at once — no Python loop needed. Pandas evaluates all rows simultaneously and returns only where the condition is True.

---

### 8.1 How It Works — Step by Step

```python
# Step 1: Create a boolean mask
mask = df['Age'] > 70
# Returns True/False for every row in the DataFrame

# Step 2: Use the mask to filter
df[df['Age'] > 70]    # returns only rows where Age > 70
```

> 📌 **NOTE:** Identical to SQL `WHERE age > 70`. Evaluated vectorized — no for loop.

---

### 8.2 Combining Conditions

```python
# & = AND  (both must be True)
df[(df['Age'] > 70) & (df['Survived'] == 1)]

# | = OR  (at least one must be True)
df[(df['Pclass'] == 1) | (df['Pclass'] == 2)]

# ~ = NOT  (invert)
df[~(df['Sex'] == 'male')]    # same as df[df['Sex']=='female']

# Three conditions
df[(df['Sex']=='female') & (df['Survived']==1) & (df['Pclass']==1)]
```

> ⚠️ **PITFALL:** Never use Python's `and`, `or`, `not` with pandas. `df[df['A']>1 and df['B']>2]` raises `ValueError: The truth value of a Series is ambiguous`. Must use `&` `|` `~` with each condition in its own parentheses. Parentheses are required because `&` has higher precedence than `>`.

---

### 8.3 Filter + Column Selection — From Your Notebook

```python
# Female survivors — all columns
df[(df['Sex'] == 'female') & (df['Survived'] == 1)]

# Female survivors — only Name and Age
# Method 1: two-step (works but slower)
df[(df['Sex']=='female') & (df['Survived']==1)][['Name','Age']]

# Method 2: loc — one step (preferred in interviews)
df.loc[(df['Sex']=='female') & (df['Survived']==1), ['Name','Age']]
```

> 💡 **TIP:** Always use Method 2 in interviews. Say: *"I prefer df.loc[condition, columns] — it's a single indexing operation and avoids SettingWithCopyWarning."*

---

### Interview Questions

> **Q: Explain what df[df['Age'] > 70] does internally.**

Two operations. First: `df['Age'] > 70` creates a boolean Series — True where Age > 70, False otherwise — evaluated vectorized using NumPy. Second: `df[boolean_series]` returns only rows where the mask is True, preserving original row labels (96, 116, 493, 630, 851 in the Titanic case).

> **Q: Why do you need parentheses around each condition with & and |?**

Operator precedence. `&` has higher precedence than `>` and `==`. So `df['Age'] > 70 & df['Pclass'] == 1` is evaluated as `df['Age'] > (70 & df['Pclass']) == 1` — completely wrong. Parentheses force each comparison first: `(df['Age'] > 70) & (df['Pclass'] == 1)`.

---

## 9. set_index and reset_index

The index is what pandas uses to look up rows. Default is 0, 1, 2... (RangeIndex). You can promote any column to become the index.

---

### 9.1 set_index

```python
df_by_pid = df.set_index('PassengerId')
# PassengerId is now the INDEX — not a column anymore

df_by_pid.loc[1]    # Passenger with PassengerId=1 (label lookup)
df_by_pid.iloc[0]   # First row by position
```

> 📌 **NOTE:** `set_index` returns a NEW DataFrame. To modify in place: `df.set_index('col', inplace=True)`. But `inplace` is being phased out — prefer `df = df.set_index('col')`.

---

### 9.2 reset_index

```python
df_restored = df_by_pid.reset_index()
# PassengerId goes back to being a regular column
# Index resets to 0, 1, 2...

df_clean = df_by_pid.reset_index(drop=True)
# drop=True: PassengerId is GONE — index becomes 0,1,2
```

> 💡 **TIP:** The most common use of `reset_index()` is after `groupby()`. You will write this hundreds of times: `df.groupby('column').agg(...).reset_index()`

---

### Interview Questions

> **Q: Why would you use set_index?**

Three reasons: 1) Faster lookups — `df.loc[user_id]` is O(1) hash lookup instead of O(n) column scan. 2) Time series — `DatetimeIndex` enables `df.between_time()`, `resample()`, and date-based loc. 3) Automatic alignment — when merging/joining DataFrames, pandas aligns on the index automatically.

> **Q: Difference between set_index and reset_index?**

`set_index` promotes a column to become row labels — column disappears from `df.columns`. `reset_index` does the reverse — moves index back into a column and resets to 0,1,2. Most common workflow: `df.groupby('date').agg({...}).reset_index()` — groupby creates a date index, reset_index flattens it back to a regular column.

---

## 10. Slicing Rows and Columns Together

```python
df.loc[:4, ['Name','Age']]             # Rows 0-4 (inclusive), 2 columns
df.iloc[0:3, 0:2]                      # Rows 0-2, Columns 0-1 (exclusive)
df.loc[0:3, ['Name','Survived']]       # 4 rows (0,1,2,3), 2 named columns
df.iloc[0:3, [3, 1]]                   # out-of-order columns OK
df.loc[(condition), ['Name','Age']]    # filter + column select
df.iloc[0:5, 3]                        # returns a Series
df.iloc[0, 3]                          # single value
df.loc[0, 'Name']                      # single value by label
```

> 🔑 **CRITICAL:** `df.loc[0:4]` gives rows 0,1,2,3,4 — **FIVE rows** (inclusive). `df.iloc[0:4]` gives rows 0,1,2,3 — **FOUR rows** (exclusive). Most common off-by-one error in pandas.

---

## 11. Connection to the Backtest

Every concept from today's session appears directly in the multi-ticker backtest:

| Concept learned today | Backtest function | Exact line |
|---|---|---|
| Series creation | `add_indicators()` | `df['ema9'] = ema(df['Close'], 9)` |
| DataFrame from list of dicts | `find_vwap_signals()` | `signals.append({...}) → pd.DataFrame(signals)` |
| iloc by position | `find_breakout_signals()` | `row=df.iloc[i]; prev=df.iloc[i-1]` |
| Boolean filter + & | `find_breakout_signals()` | `long_break = (cond1) & (cond2) & (cond3)` |
| Filter wins/losses | `strategy_stats()` | `wins = trades[trades['outcome']=='WIN']` |
| DatetimeIndex (set_index) | `download_data()` | `df.index = pd.to_datetime(df.index)` |
| reset_index | `save_master_csv()` | `pd.concat([...]).reset_index(drop=True)` |
| df.shape / df.info() | `download_data()` | `print(f'{len(df)} bars loaded')` |

---

## 12. Full Interview Q&A Bank

> **Q: What is pandas built on top of and why does that matter?**  
NumPy. All pandas operations on columns/rows are vectorized NumPy operations — they run in C, not Python. `df['Age'].mean()` calls a NumPy reduction — no Python for-loop anywhere. This makes pandas orders of magnitude faster than equivalent Python loops.

> **Q: What are the three core pandas objects?**  
Series (1D), DataFrame (2D), Panel (3D — deprecated since pandas 1.0, replaced by MultiIndex DataFrame).

> **Q: What is the full pd.Series() signature?**  
`pd.Series(data, index, dtype, name, copy)`. data=values, index=row labels, dtype=force a type, name=label (becomes column name in DataFrame), copy=reference vs copy.

> **Q: Why does s2[0] raise KeyError on a string-indexed Series in pandas 3.0?**  
In pandas 3.0, integer keys on `s[]` are always treated as labels. Since 0 is not a label in `['a','b','c','d']` it raises KeyError. In pandas 2.x it fell back to position — that behavior was removed. Fix: always use `s.iloc[0]` for position, `s.loc['a']` for label.

> **Q: What does df.info() tell you that df.describe() doesn't?**  
`df.info()` shows column names, non-null counts per column, dtypes, and memory usage — structural information. `df.describe()` shows statistical summaries (mean, std, percentiles) for numeric columns only. info() is for structure; describe() is for distribution.

> **Q: What does it mean when a column shows float64 instead of int64?**  
The column has at least one NaN. NaN is a float-type sentinel in NumPy and cannot exist in an integer array. Pandas upcasts to float64 automatically. Fix: fill NaN then `.astype('int64')`.

> **Q: Why prefer df.loc[condition, columns] over df[condition][columns]?**  
Two reasons: 1) Performance — loc is a single operation; chained indexing creates an intermediate DataFrame. 2) Safety — assignment through chained indexing `df[cond]['col'] = value` may silently not modify the original df (SettingWithCopyWarning). `df.loc[cond, 'col'] = value` always works correctly.

> **Q: What is the difference between df.isnull() and df.isnull().sum()?**  
`df.isnull()` returns a boolean DataFrame — True where NaN. `df.isnull().sum()` collapses it to a count per column. Use `.mean() * 100` for percentage missing.

> **Q: What does reset_index(drop=True) do vs reset_index()?**  
`reset_index()` moves the current index into a column and resets to 0,1,2. `reset_index(drop=True)` discards the old index entirely — just resets to 0,1,2 without adding it as a column. Use `drop=True` after filtering or groupby when you don't need the old index values.

---

## 13. Quick Reference Card

| Task | Code |
|---|---|
| Import | `import pandas as pd` |
| Series from list | `pd.Series([1,2,3])` |
| Series from dict | `pd.Series({'a':10, 'b':20})` |
| Series custom index + name | `pd.Series(data, index=['a','b'], name='Scores')` |
| DataFrame from dict of lists | `pd.DataFrame({'Name':['A','B'], 'Age':[30,31]})` |
| DataFrame from list of dicts | `pd.DataFrame([{'a':1,'b':2}, {'a':3,'b':4}])` |
| Load CSV | `pd.read_csv('file.csv')` or `pd.read_csv(url)` |
| Load specific columns only | `pd.read_csv('f.csv', usecols=['A','B'])` |
| EDA — size | `df.shape` |
| EDA — types + nulls | `df.info()` |
| EDA — statistics | `df.describe()` |
| EDA — missing count | `df.isnull().sum()` |
| First N rows | `df.head(N)` |
| Last N rows | `df.tail(N)` |
| Single column → Series | `df['Name']` |
| Multiple columns → DataFrame | `df[['Name', 'Age']]` |
| Row by position | `df.iloc[0]` |
| Row by label | `df.loc[0]` |
| Row + col by position | `df.iloc[0, 3]` or `df.iloc[0:3, 0:2]` |
| Row + col by label | `df.loc[0, 'Name']` or `df.loc[0:4, ['A','B']]` |
| Filter one condition | `df[df['Age'] > 30]` |
| Filter AND | `df[(df['Age']>30) & (df['Sex']=='female')]` |
| Filter OR | `df[(df['Pclass']==1) \| (df['Pclass']==2)]` |
| Filter NOT | `df[~(df['Sex']=='male')]` |
| Filter + columns (preferred) | `df.loc[condition, ['Name','Age']]` |
| Set column as index | `df.set_index('PassengerId')` |
| Reset index to 0,1,2 | `df.reset_index()` |
| Reset + discard old index | `df.reset_index(drop=True)` |

---

*Next session: groupby() · rolling() · ewm() · cumsum() · how indicators are built*  
*Come back after the next Krish Naik session and the next chapter gets added here.*
