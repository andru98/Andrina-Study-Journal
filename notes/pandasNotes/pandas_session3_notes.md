# Pandas Session 3 — String Operations, Categorical Data & Dates

> Date: 28 Feb 2026 | Dataset: Titanic + custom | Topics: .str methods · Regex · Categorical dtype · Date handling

---

## Table of Contents
1. [String Operations with .str](#1-string-operations-with-str)
2. [Regex in Pandas](#2-regex-in-pandas)
3. [Categorical Data](#3-categorical-data)
4. [Encoding Categorical Columns](#4-encoding-categorical-columns)
5. [Date Handling in Pandas](#5-date-handling-in-pandas)
6. [Date Arithmetic](#6-date-arithmetic)
7. [Full Interview Q&A Bank](#7-full-interview-qa-bank)
8. [Quick Reference Card](#8-quick-reference-card)

---

## 1. String Operations with .str

The `.str` accessor lets you apply string methods to an entire column without looping. Every operation returns a new Series — it never modifies the original in place.

### Core methods

```python
df['Name'].str.len()                        # length of each string
df['Name'].str.lower()                      # all lowercase
df['Name'].str.upper()                      # all uppercase
df['Name'].str.capitalize()                 # first letter of whole string only
df['Name'].str.title()                      # first letter of every word
df['Name'].str.strip()                      # remove leading/trailing whitespace
df['Name'].str.lstrip()                     # remove left whitespace only
df['Name'].str.rstrip()                     # remove right whitespace only
df['Name'].str.replace("Mr.", "Sir", regex=False)  # simple replace
df['Name'].str.find("Mr")                   # position of substring, -1 if missing
df['Name'].str.contains("Miss")             # True/False per row
df['Name'].str.split(",")                   # split into list
df['Name'].str.split(",").str[0]            # split then grab first element
df['Name'].str.pad(width=20, side='left', fillchar='-')  # pad to fixed width
```

### Real example from Titanic

```python
# count how many passengers have "Miss" in their name
count = df['Name'].str.contains("Miss").sum()
# → 182

# split name and grab surname (everything before the comma)
df['Surname'] = df['Name'].str.split(",").str[0]
# 'Braund, Mr. Owen Harris' → 'Braund'
```

### The NaN rule — important for interviews

`.str` methods never crash on NaN — they silently return NaN for that row. But if you use `.apply(lambda x: x.lower())` instead, it crashes with `AttributeError` because `None` has no `.lower()`. Always prefer `.str` over lambda for string operations.

```python
# safe — NaN rows return NaN silently
df['Name'].str.lower()

# crashes if Name has NaN
df['Name'].apply(lambda x: x.lower())   # AttributeError on NaN rows
```

### str.replace with regex=False — why it matters

```python
df['Name'].str.replace("Mr.", "Sir", regex=False)
```

The `regex=False` flag tells pandas to treat `"Mr."` as a plain string, not a regex pattern. Without it, the dot `.` in regex means "match any character" — so `"Mr."` would match `"Mrs"`, `"Mra"`, `"Mrx"` etc. Always pass `regex=False` for literal replacements.

---

## 2. Regex in Pandas

Regex (regular expressions) are patterns used to match, extract, or replace text. Pandas supports regex directly in `.str.replace()` and `.str.contains()`.

### Regex pattern breakdown

```python
df['Name'].str.replace(r"\(.*\)", "", regex=True)
```

| Part | What it means |
|------|---------------|
| `r"..."` | Raw string — Python won't interpret `\` as escape |
| `\(` | Matches a literal `(` — escaped because `(` is special in regex |
| `.*` | `.` = any character, `*` = zero or more of them |
| `\)` | Matches a literal `)` |

So `r"\(.*\)"` matches everything inside parentheses including the parentheses themselves.

```python
# before: 'Cumings, Mrs. John Bradley (Florence Briggs Thayer)'
# after:  'Cumings, Mrs. John Bradley '
```

### Email validator using regex

```python
import re

def is_valid_email(email):
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return bool(re.fullmatch(pattern, email))

# test it
emails = ["user@example.com", "invalid-email", "hello@ghail@abc.com"]
for e in emails:
    print(f"{e}: {'Valid' if is_valid_email(e) else 'Invalid'}")

# user@example.com: Valid
# invalid-email: Invalid
# hello@ghail@abc.com: Invalid  ← two @ signs, caught correctly
```

Pattern breakdown:
- `^` → start of string
- `[a-zA-Z0-9._%+-]+` → one or more valid username characters
- `@` → literal @ sign
- `[a-zA-Z0-9.-]+` → domain name
- `\.[a-zA-Z]{2,}$` → dot followed by 2+ letter extension at end

### apply() vs regex — when to use which

```python
# apply with custom function — good for complex multi-step logic
def remove_parentheses(name):
    start = name.find("(")
    end = name.find(")")
    if start == -1:
        return name           # no parentheses, return as-is
    return name[0:start].strip()

df["Name_clean"] = df["Name"].apply(remove_parentheses)

# regex — cleaner for pattern-based replacements
df["Name_clean"] = df['Name'].str.replace(r"\(.*\)", "", regex=True).str.strip()
```

The regex approach is one line and handles all rows consistently. The `apply` approach is more readable for complex logic with multiple conditions.

---

## 3. Categorical Data

Categorical dtype is for columns with a fixed set of repeated values — like gender, grade, port of embarkation. It saves memory and, when `ordered=True`, enables comparison operators like `>` and `<`.

### Why categorical?

```python
# object dtype — stores full string for every row
df['Embarked'].dtype   # object → stores 'S', 'C', 'Q' repeated 891 times

# category dtype — stores each unique value once, then codes per row
df['Embarked_cat'] = df['Embarked'].astype('category')
# internally: {'C':0, 'N':1, 'Q':2, 'S':3} + array of codes
# much more memory efficient for repeated values
```

### Auto categorical vs custom ordered

```python
# auto — pandas picks alphabetical order
df['Embarked_auto'] = df['Embarked'].astype('category')
df['Embarked_auto'].cat.categories
# Index(['C', 'N', 'Q', 'S'])  ← alphabetical, no order logic

# custom ordered — you define the order
df['Embarked_ordered'] = pd.Categorical(
    df['Embarked'],
    categories=['N', 'S', 'C', 'Q'],   # ascending: N is lowest, Q is highest
    ordered=True
)

# now comparison operators work!
df['Embarked_ordered'] > 'S'
# True for rows where port is C or Q (higher than S in our ranking)
```

### Real world use case — student grades

```python
class_df['Grade_cat'] = pd.Categorical(
    class_df['Grade'],
    categories=['F', 'D', 'C', 'B', 'A'],   # F=lowest, A=highest
    ordered=True
)

# filter students with grade above C
class_df[class_df['Grade_cat'] > 'C']   # returns B and A students
```

### Accessing category metadata

```python
df['Embarked_ordered'].cat.categories   # see all categories in order
df['Embarked_ordered'].cat.codes        # see numeric code per row (0,1,2,3)
```

---

## 4. Encoding Categorical Columns

When building ML models, you need numbers not strings. Three ways to encode:

```python
# option 1 — astype category then get codes (auto-assigned)
df['Sex_encoded'] = df['Sex'].astype('category').cat.codes
# female=0, male=1 (alphabetical)

# option 2 — replace with explicit mapping (most readable)
df['Sex_encoded'] = df['Sex'].replace(['female', 'male'], [0, 1])

# option 3 — apply with lambda
df['Sex_encoded'] = df['Sex'].apply(lambda x: 1 if x == 'male' else 0)
```

Which to use in interviews:
- `replace()` is clearest for binary encoding — explicit mapping
- `cat.codes` is compact but order depends on alphabetical unless you use `pd.Categorical` with custom order
- `apply` with lambda is most flexible for complex mappings

---

## 5. Date Handling in Pandas

Dates stored as strings are useless for filtering and arithmetic. `pd.to_datetime()` converts them to proper `datetime64` dtype, unlocking the `.dt` accessor.

### Converting strings to datetime

```python
df = pd.DataFrame({
    'event': ['Concert', 'Conference', 'Wedding'],
    'date':  ['2025-01-01', '2025-03-15', '2025-07-20']
})

# date column is str right now — can't filter or do math
df.info()   # date: str

# convert to datetime
df['date'] = pd.to_datetime(df['date'])
df.info()   # date: datetime64[us]   ← now proper datetime
```

### Extracting date components with .dt

```python
df['date'].dt.year        # 2025, 2025, 2025
df['date'].dt.month       # 1, 3, 7
df['date'].dt.day         # 1, 15, 20
df['date'].dt.weekday     # 0=Monday ... 6=Sunday
df['date'].dt.day_name()  # 'Wednesday', 'Saturday', 'Sunday'
```

### Filtering by date

```python
# filter events after April 2025
df[df['date'] > '2025-04-01']
# only Wedding (2025-07-20) survives

# filter events within a date range
df[df['date'].between('2025-01-01', '2025-06-01')]
# Concert and Conference survive, Wedding is after June 1
```

Note: pandas is smart enough to compare datetime column with a string like `'2025-04-01'` — it auto-converts the string for the comparison.

### Creating date ranges

```python
# daily range
pd.date_range(start='2026-02-01', end='2026-02-10', freq='D')
# 10 dates: 2026-02-01 through 2026-02-10

# month end
pd.date_range(start='2024-01-01', end='2024-03-10', freq='ME')
# 2024-01-31, 2024-02-29  ← jumps to last day of each month

# month start
pd.date_range(start='2024-01-01', end='2024-03-10', freq='MS')
# 2024-01-01, 2024-02-01, 2024-03-01
```

Frequency codes to know cold:
| Code | Meaning |
|------|---------|
| `D` | Daily |
| `ME` | Month end |
| `MS` | Month start |
| `W` | Weekly |
| `H` | Hourly |
| `T` | Minute |
| `S` | Second |

---

## 6. Date Arithmetic

Once dates are `datetime64`, you can do math on them.

```python
# add 7 days to every date
df['next_week'] = df['date'] + pd.Timedelta(days=7)
# Concert: 2025-01-01 → 2025-01-08

# days until/since today
df['days_to_event'] = df['date'] - pd.Timestamp.today()
# Concert: -424 days (already happened)

# useful for trading journal — days held
df['days_held'] = df['exit_date'] - df['entry_date']
# gives a Timedelta column — extract the number with .dt.days
df['days_held_int'] = df['days_held'].dt.days
```

### Timestamp vs Timedelta vs DatetimeIndex

```python
pd.Timestamp.today()              # single point in time — "right now"
pd.Timedelta(days=7)              # duration — "7 days"
pd.date_range(...)                # sequence of timestamps — DatetimeIndex
```

---

## 7. Full Interview Q&A Bank

**Q: What does the .str accessor do and when would you use it?**

The `.str` accessor exposes Python string methods to work on an entire pandas column without needing a loop or apply. Internally it's still iterating but it handles NaN rows gracefully — they return NaN instead of crashing. I use it for cleaning text columns: stripping whitespace, extracting substrings, replacing patterns. For anything pattern-based I'll use `.str.replace(..., regex=True)` instead of apply.

---

**Q: What is the difference between str.replace with regex=True vs regex=False?**

With `regex=False`, the first argument is treated as a literal string. With `regex=True`, it's treated as a regex pattern where characters like `.`, `(`, `*` have special meanings. So `str.replace("Mr.", "Sir", regex=False)` replaces exactly `"Mr."` — but with `regex=True` the dot would match any character. Always pass `regex=False` for literal replacements to avoid unexpected matches.

---

**Q: What is categorical dtype and why use it?**

Categorical dtype is for columns with a fixed, repeated set of values — gender, grades, ports, status codes. Compared to object dtype, it stores each unique value once and uses integer codes per row, which is more memory efficient. When `ordered=True`, it also enables comparison operators like `>` and `<` which don't work on plain strings in a meaningful way. The tradeoff is that adding new values not in the original category list requires updating the categories first.

---

**Q: What is the difference between auto categorical and ordered categorical?**

Auto categorical — `df['col'].astype('category')` — assigns categories alphabetically with no ordering. You can't do `df['col'] > 'some_value'` meaningfully. Ordered categorical — `pd.Categorical(..., categories=[...], ordered=True)` — lets you define a custom order, after which comparison operators work exactly as you'd expect. Use ordered when the categories have a natural rank like grades or priority levels.

---

**Q: Why convert date strings to datetime and what does pd.to_datetime() do?**

String dates look like dates but pandas treats them as plain text — you can't filter by range, extract month/year, or do arithmetic. `pd.to_datetime()` converts to `datetime64` dtype which unlocks the `.dt` accessor for component extraction and makes comparison operators and arithmetic work correctly. The format parameter is optional — pandas is smart enough to infer common formats like `YYYY-MM-DD` automatically.

---

**Q: What is the difference between pd.Timestamp, pd.Timedelta, and pd.date_range?**

`pd.Timestamp` represents a single point in time — think of it as a single datetime value. `pd.Timedelta` represents a duration — the difference between two points in time. `pd.date_range` generates a sequence of timestamps with a given frequency — useful for creating calendar axes or filling in missing dates in time series data.

---

**Q: How would you find the number of days between two date columns?**

Subtract one datetime column from the other — pandas returns a Timedelta column. Then use `.dt.days` to extract the integer number of days.

```python
df['duration'] = df['end_date'] - df['start_date']
df['duration_days'] = df['duration'].dt.days
```

---

**Q: Three ways to encode a binary categorical column like Sex — which do you prefer?**

All three work: `cat.codes`, `.replace()`, and `apply()` with a lambda. I prefer `.replace({'female': 0, 'male': 1})` — it's explicit, readable, and the mapping is obvious to anyone reviewing the code. `cat.codes` is compact but the codes depend on alphabetical order of categories which can be confusing. `apply` with lambda is fine for more complex mappings but overkill for binary.

---

## 8. Quick Reference Card

| Task | Code |
|------|------|
| String length per row | `df['col'].str.len()` |
| Lowercase | `df['col'].str.lower()` |
| Uppercase | `df['col'].str.upper()` |
| Capitalize first word | `df['col'].str.capitalize()` |
| Capitalize every word | `df['col'].str.title()` |
| Strip whitespace | `df['col'].str.strip()` |
| Contains substring | `df['col'].str.contains("word")` |
| Find position | `df['col'].str.find("word")` |
| Replace literal | `df['col'].str.replace("old", "new", regex=False)` |
| Replace pattern | `df['col'].str.replace(r"\(.*\)", "", regex=True)` |
| Split and get element | `df['col'].str.split(",").str[0]` |
| Auto categorical | `df['col'].astype('category')` |
| Ordered categorical | `pd.Categorical(df['col'], categories=[...], ordered=True)` |
| View categories | `df['col'].cat.categories` |
| Get numeric codes | `df['col'].cat.codes` |
| Convert to datetime | `pd.to_datetime(df['col'])` |
| Extract year | `df['col'].dt.year` |
| Extract month | `df['col'].dt.month` |
| Extract weekday name | `df['col'].dt.day_name()` |
| Filter by date | `df[df['col'] > '2025-01-01']` |
| Filter date range | `df[df['col'].between('2025-01-01', '2025-06-01')]` |
| Add days | `df['col'] + pd.Timedelta(days=7)` |
| Days between dates | `(df['end'] - df['start']).dt.days` |
| Today's timestamp | `pd.Timestamp.today()` |
| Date range daily | `pd.date_range(start='...', end='...', freq='D')` |
| Date range monthly | `pd.date_range(start='...', end='...', freq='MS')` |

---

*Next session: groupby, aggregation, merge, pivot tables*
