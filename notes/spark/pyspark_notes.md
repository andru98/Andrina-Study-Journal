# PySpark Interview Prep Notes

Comprehensive PySpark notes built for Data Engineering interview prep and as a GitHub portfolio reference. Covers everything from the DataFrame API fundamentals through architecture, performance tuning, and the concepts interviewers actually probe on.

Every code snippet in this file (and in [`notebooks/pyspark_practice.ipynb`](http://notebooks/pyspark_practice.ipynb)) has been run against a live PySpark session — nothing here is untested pseudocode.

## How this repo is organized

- **`README.md`** — this file. Concept notes, analogies, gotchas, and interview Q\&A.  
- **`notebooks/pyspark_practice.ipynb`** — runnable, hands-on code practice for every concept below, in the same order. Every cell has already been executed against a real local Spark session, so outputs are visible without needing to run anything.  
- **`data/`** — small sample CSV files the notebook reads from.  
- **`build_notebook.py`** — regenerates the notebook from source (kept for reproducibility/version control friendliness — notebook diffs are painful, this script isn't).  
- **`requirements.txt`** — `pip install -r requirements.txt` to run it yourself (needs Java 11/17/21 installed for Spark).

## Table of Contents

**Part 1 — PySpark DataFrame Fundamentals**

1. [What is Spark / PySpark, and why](#1-what-is-spark--pyspark-and-why)  
2. [SparkSession and reading data](#2-sparksession-and-reading-data)  
3. [Schema: printSchema, inferSchema vs StructType (DDL schema)](#3-schema-printschema-inferschema-vs-structtype-ddl-schema)  
4. [SELECT](#4-select)  
5. [ALIAS](#5-alias)  
6. [FILTER / WHERE](#6-filter--where)  
7. [withColumnRenamed](#7-withcolumnrenamed)  
8. [withColumn](#8-withcolumn)  
9. [Type Casting](#9-type-casting)  
10. [SORT / ORDER BY](#10-sort--order-by)  
11. [LIMIT](#11-limit)  
12. [DROP](#12-drop)  
13. [DROP\_DUPLICATES](#13-drop_duplicates)  
14. [UNION and UNION BY NAME](#14-union-and-union-by-name)  
15. [String Functions](#15-string-functions)  
16. [DATEDIFF and DATE\_FORMAT](#16-datediff-and-date_format)  
17. [Handling Nulls](#17-handling-nulls)  
18. [Split, Indexing, and Explode](#18-split-indexing-and-explode)  
19. [ARRAY\_CONTAINS](#19-array_contains)  
20. [GROUP BY and COLLECT\_LIST](#20-group-by-and-collect_list)  
21. [PIVOT](#21-pivot)  
22. [WHEN — OTHERWISE](#22-when--otherwise)  
23. [JOINS](#23-joins)  
24. [WINDOW FUNCTIONS](#24-window-functions)  
25. [User Defined Functions (UDFs)](#25-user-defined-functions-udfs)  
26. [Data Writing and Write Modes](#26-data-writing-and-write-modes)  
27. [Parquet File Format](#27-parquet-file-format)  
28. [Managed vs External Tables](#28-managed-vs-external-tables)  
29. [Spark SQL (createTempView / spark.sql)](#29-spark-sql-createtempview--sparksql)

**Part 2 — Architecture & Interview-Level Depth** 30\. [Spark Architecture](#30-spark-architecture) 31\. [RDD vs DataFrame vs Dataset](#31-rdd-vs-dataframe-vs-dataset) 32\. [Transformations vs Actions, Lazy Evaluation](#32-transformations-vs-actions-lazy-evaluation) 33\. [Partitioning and Shuffling](#33-partitioning-and-shuffling) 34\. [Cache vs Persist](#34-cache-vs-persist) 35\. [Joins Under the Hood: Broadcast vs Shuffle Joins](#35-joins-under-the-hood-broadcast-vs-shuffle-joins) 36\. [Catalyst Optimizer, Tungsten, and AQE](#36-catalyst-optimizer-tungsten-and-aqe) 37\. [Delta Lake Essentials](#37-delta-lake-essentials) 38\. [Structured Streaming Basics](#38-structured-streaming-basics)

**Reference**

- [Common Interview Q\&A — Rapid Fire](#common-interview-qa--rapid-fire)  
- [Cheat Sheet](#cheat-sheet)  
- [Resources](#resources)

---

## Part 1 — PySpark DataFrame Fundamentals

### 1\. What is Spark / PySpark, and why

**Analogy:** A single computer processing 10 TB of data is like one cashier trying to check out an entire stadium of shoppers alone. Spark is like opening hundreds of checkout lanes at once and having a manager (the driver) coordinate them — the same work gets split across many machines and finishes in parallel.

**Definition:** Apache Spark is a distributed, in-memory computing engine for processing large datasets across a cluster of machines. PySpark is the Python API for Spark — it lets you write Spark jobs in Python while the actual execution happens on the JVM via Py4J.

Spark reads data through a **higher-level API — the DataFrame** — instead of forcing you to write low-level RDD transformations by hand. A DataFrame is a distributed table with named columns and a schema, conceptually similar to a pandas DataFrame or a SQL table, but partitioned across the cluster.

Why Spark over plain Python/pandas for big data:

- pandas runs on a single machine, in a single process — it's bound by that machine's RAM.  
- Spark distributes both the data (partitions) and the computation (tasks) across a cluster, and processes in memory instead of writing to disk between steps (unlike classic Hadoop MapReduce).

**Interview angle:** "Why Spark instead of MapReduce?" → Spark keeps intermediate results in memory (RDD lineage graph) instead of writing to disk after every step, and offers a much richer, higher-level API (DataFrame/SQL) with the Catalyst optimizer choosing an efficient physical plan for you.

---

### 2\. SparkSession and reading data

`SparkSession` is the single entry point to all Spark functionality (replaced the old `SparkContext` \+ `SQLContext` \+ `HiveContext` split from Spark 1.x).

from pyspark.sql import SparkSession

spark \= (

    SparkSession.builder

    .appName("PySparkInterviewPrep")

    .master("local\[\*\]")   \# run locally using all cores; omit/replace on a real cluster

    .getOrCreate()

)

df \= spark.read.format("csv") \\

    .option("header", True) \\

    .option("inferSchema", True) \\

    .load("data/employees.csv")

df.show(5)

`spark.read` is the **DataFrameReader** — it supports `csv`, `json`, `parquet`, `orc`, `avro`, `jdbc`, `delta`, and more, all through the same `.format(...).option(...).load(...)` pattern.

---

### 3\. Schema: printSchema, inferSchema vs StructType (DDL schema)

df.printSchema()

\# root

\#  |-- emp\_id: integer (nullable \= true)

\#  |-- name: string (nullable \= true)

\#  |-- salary: double (nullable \= true)

**`option("inferSchema", True)`** makes Spark do an extra pass over the data to guess column types. It's convenient for exploration but:

- It's slower (extra read pass over the whole file).  
- It can guess wrong (e.g., a numeric-looking ID column with leading zeros gets read as an integer and loses the zeros).

**In production, define the schema explicitly** — this skips the inference pass entirely and guarantees you get the types you expect.

Two ways to define a schema:

from pyspark.sql.types import StructType, StructField, IntegerType, StringType, DoubleType

\# 1\. Programmatic StructType schema

my\_struct\_schema \= StructType(\[

    StructField("emp\_id", IntegerType(), True),

    StructField("name", StringType(), True),

    StructField("salary", DoubleType(), True),

\])

df \= spark.read.format("csv") \\

    .option("header", True) \\

    .schema(my\_struct\_schema) \\

    .load("data/employees.csv")

\# 2\. DDL-string schema — quicker to write, same result

my\_ddl\_schema \= "emp\_id INT, name STRING, salary DOUBLE"

df \= spark.read.format("csv") \\

    .option("header", True) \\

    .schema(my\_ddl\_schema) \\

    .load("data/employees.csv")

**Interview angle:** "Why avoid `inferSchema` in production pipelines?" → Extra full-data-scan cost, and it's a correctness risk — wrong types silently corrupt downstream logic. Explicit schemas are also how you catch bad/malformed source data early (schema mismatch fails fast instead of producing nulls).

---

### 4\. SELECT

from pyspark.sql.functions import col

\# By column name(s) — cleanest for simple selection

df.select("name", "salary").show()

\# Using the col() object — needed when you want to chain

\# transformations (alias, cast, arithmetic) on the column itself

df.select(col("name"), col("salary") \* 1.1).show()

`col("colname")` returns a **Column object** you can further transform (`.alias()`, `.cast()`, arithmetic, conditionals). Passing a plain string only works for straight selection.

---

### 5\. ALIAS

df.select(col("salary").alias("monthly\_salary")).show()

df.select((col("salary") \* 12).alias("annual\_salary")).show()

`alias()` renames the output column of an *expression* — used constantly with computed columns, joins (to disambiguate same-named columns from two tables), and aggregations.

---

### 6\. FILTER / WHERE

`filter()` and `where()` are exact aliases of each other in PySpark — use whichever reads better.

df.filter(col("salary") \> 50000).show()

df.where(col("dept") \== "Engineering").show()

\# Multiple conditions — use & / | / \~, NOT and / or / not

df.filter((col("salary") \> 50000\) & (col("dept") \== "Engineering")).show()

df.filter((col("dept") \== "Sales") | (col("dept") \== "HR")).show()

df.filter(\~(col("dept") \== "HR")).show()

**Important gotcha (and one Anna's original notes specifically flagged):** use a **single** `&` / `|` / `~`, not Python's `and` / `or` / `not` and not double `&&` / `||`. PySpark overloads the single bitwise operators on `Column` objects for boolean logic — Python's `and`/`or` don't work element-wise on a distributed column, and `&&`/`||` are SQL/Java syntax, not valid Python. Also always wrap each condition in parentheses because `&`/`|` have higher operator precedence than `==`/`>` in Python.

\# Equivalent SQL-string filter, if you prefer

df.filter("salary \> 50000 AND dept \= 'Engineering'").show()

---

### 7\. withColumnRenamed

df \= df.withColumnRenamed("emp\_id", "employee\_id")

Renames one existing column. For renaming many columns at once, chain it or use a loop/`reduce`; there's no native "rename multiple" method.

---

### 8\. withColumn

from pyspark.sql.functions import lit

\# Add a new column

df \= df.withColumn("bonus", col("salary") \* 0.10)

\# Overwrite an existing column (same name \= replace, not add)

df \= df.withColumn("salary", col("salary") \+ col("bonus"))

\# Add a constant/literal column

df \= df.withColumn("currency", lit("USD"))

`withColumn(name, expr)` adds a new column, or **replaces** the column in place if `name` already exists. `lit()` wraps a Python literal into a Spark `Column` so it can be used in column expressions.

---

### 9\. Type Casting

from pyspark.sql.types import IntegerType, StringType

df \= df.withColumn("salary", col("salary").cast(IntegerType()))

df \= df.withColumn("emp\_id", col("emp\_id").cast("string"))   \# string type-name shortcut also works

Cast explicitly rather than relying on inference, especially before joins (mismatched types on join keys silently produce zero matches) and before writing to a strongly-typed sink.

---

### 10\. SORT / ORDER BY

Exact aliases, same as filter/where.

df.sort(col("salary").desc()).show()

df.orderBy("dept", col("salary").desc()).show()   \# multi-column: dept asc, salary desc

---

### 11\. LIMIT

df.limit(10).show()

`limit(n)` returns only the first `n` rows **as a DataFrame** (so it can be chained further) — different from `.show(n)`, which just prints `n` rows without truncating the underlying DataFrame or returning anything usable.

---

### 12\. DROP

df \= df.drop("currency")

df \= df.drop("currency", "bonus")   \# multiple columns at once

---

### 13\. DROP\_DUPLICATES

df.dropDuplicates().show()                      \# exact duplicate rows across all columns

df.dropDuplicates(\["emp\_id"\]).show()             \# duplicates based on a subset of columns

df.distinct().show()                             \# alias-like behavior, all columns, no subset option

`dropDuplicates(subset)` keeps the first-seen row per subset-key (note: "first" isn't deterministic across partitions unless you sort first) — for deterministic "keep highest salary per emp\_id" logic, use a window function instead (see [§24](#24-window-functions)).

---

### 14\. UNION and UNION BY NAME

df1.union(df2).show()            \# stacks rows — matches by COLUMN POSITION, not name

df1.unionByName(df2).show()      \# matches by COLUMN NAME — safer when column order differs

df1.unionByName(df2, allowMissingColumns=True).show()  \# fills missing cols with null

**Interview trap:** `union()` is purely positional. If `df1` is `(id, name)` and `df2` is `(name, id)`, `union()` silently mixes id values into the name column. Always prefer `unionByName()` unless you're certain column order is identical.

---

### 15\. String Functions

from pyspark.sql.functions import initcap, upper, lower, trim, concat, concat\_ws, length, substring

df.select(initcap("name")).show()          \# "john doe" \-\> "John Doe"

df.select(upper("name"), lower("dept")).show()

df.select(trim("name")).show()

df.select(concat\_ws(" ", "first\_name", "last\_name").alias("full\_name")).show()

df.select(substring("name", 1, 3)).show()   \# 1-indexed, not 0-indexed

---

### 16\. DATEDIFF and DATE\_FORMAT

from pyspark.sql.functions import datediff, current\_date, date\_format, to\_date

df.select(datediff(current\_date(), col("join\_date")).alias("days\_employed")).show()

df.select(date\_format(col("join\_date"), "yyyy-MM-dd").alias("formatted\_date")).show()

**Gotcha Anna's original notes flagged (and got right):** Spark's `date_format` pattern is **`yyyy`, lowercase**, not `YYYY`. This is Java's `SimpleDateFormat`/`DateTimeFormatter` pattern syntax, not Python's `strftime`:

- `yyyy` \= calendar year (what you want almost always)  
- `YYYY` \= "week year" (ISO week-based year — can differ from the calendar year on dates near Jan 1 / Dec 31, a classic silent-bug source)  
- Similarly: `MM` \= month, `mm` \= minutes; `dd` \= day of month, `DD` \= day of year. Mixing these up is a very common real-world bug.

---

### 17\. Handling Nulls

\# Dropping nulls

df.dropna(how="any").show()     \# drop a row if ANY column in it is null

df.dropna(how="all").show()     \# drop a row only if ALL columns in it are null

df.dropna(subset=\["salary"\]).show()   \# only consider nulls in specific column(s)

\# Filling nulls

df.fillna(0).show()                          \# fill all numeric nulls with 0

df.fillna("Unknown", subset=\["dept"\]).show() \# fill nulls in one column

df.fillna({"salary": 0, "dept": "Unknown"}).show()  \# different fill value per column

\# Equivalent SQL-style: df.na.drop(...), df.na.fill(...)

`how="any"` vs `how="all"` is the detail worth memorizing cold: **"any"** \= at least one null triggers the drop (stricter, drops more rows); **"all"** \= every column must be null (looser, drops fewer rows — only fully-empty rows).

---

### 18\. Split, Indexing, and Explode

from pyspark.sql.functions import split, explode

\# "John,Doe,Engineering" \-\> array\["John","Doe","Engineering"\]

df \= df.withColumn("parts", split(col("full\_info"), ","))

\# Indexing into the array (0-indexed, unlike substring\!)

df \= df.withColumn("first\_name", col("parts")\[0\])

df \= df.withColumn("last\_name", col("parts")\[1\])

\# explode: turn \["python","sql","spark"\] into 3 separate ROWS,

\# duplicating every other column's value on each new row

df.withColumn("skill", explode(col("skills"))).show()

**Interview angle:** `explode` is the go-to when a source system nests multiple values per record (e.g., a JSON array of tags/skills/line-items) and you need one analytical row per value — very common in JSON/semi-structured ingestion.

---

### 19\. ARRAY\_CONTAINS

from pyspark.sql.functions import array\_contains

df.filter(array\_contains(col("skills"), "Python")).show()

Filters rows where the array column contains a given value — avoids having to `explode` \+ filter \+ re-aggregate when you just need a row-level boolean check.

---

### 20\. GROUP BY and COLLECT\_LIST

from pyspark.sql.functions import sum as \_sum, avg, count, collect\_list, collect\_set

df.groupBy("dept").agg(

    \_sum("salary").alias("total\_salary"),

    avg("salary").alias("avg\_salary"),

    count("\*").alias("headcount"),

).show()

\# collect\_list: aggregate values back into an array (keeps duplicates)

\# collect\_set:  same idea, but de-duplicated

df.groupBy("dept").agg(collect\_list("name").alias("employees")).show()

Note: import Spark's `sum`/`avg`/`count`/`min`/`max` from `pyspark.sql.functions` — they shadow Python's built-in `sum()`, hence the common `as _sum` or `import pyspark.sql.functions as F` convention.

`collect_list` is essentially the inverse of `explode` — useful for "un-flattening" data, e.g. rebuilding one row per customer with an array of all their order IDs.

---

### 21\. PIVOT

\# Rows \-\> columns: one row per employee, one column per year, values \= salary

df.groupBy("emp\_id").pivot("year").agg(\_sum("salary")).show()

\# Constrain to specific pivot values for a performance win —

\# Spark otherwise has to compute distinct values of the pivot column first

df.groupBy("emp\_id").pivot("year", \["2023", "2024", "2025"\]).agg(\_sum("salary")).show()

`pivot()` must be called on a `GroupedData` object (i.e., right after `groupBy`, before `agg`). Passing the explicit list of pivot values avoids an extra distinct-value scan and is the recommended production pattern.

---

### 22\. WHEN — OTHERWISE

from pyspark.sql.functions import when

df \= df.withColumn(

    "salary\_band",

    when(col("salary") \< 50000, "Low")

    .when((col("salary") \>= 50000\) & (col("salary") \< 100000), "Mid")

    .otherwise("High")

)

PySpark's equivalent of `CASE WHEN ... THEN ... ELSE ... END` in SQL. Conditions are evaluated top-to-bottom, first match wins — same short-circuit behavior as SQL `CASE`. Omitting `.otherwise()` leaves non-matching rows as `null`.

---

### 23\. JOINS

emp.join(dept, emp.dept\_id \== dept.dept\_id, "inner").show()

emp.join(dept, emp.dept\_id \== dept.dept\_id, "left").show()    \# a.k.a. "left\_outer"

emp.join(dept, emp.dept\_id \== dept.dept\_id, "right").show()   \# a.k.a. "right\_outer"

emp.join(dept, emp.dept\_id \== dept.dept\_id, "full").show()    \# a.k.a. "outer" / "full\_outer"

emp.join(dept, emp.dept\_id \== dept.dept\_id, "left\_anti").show()   \# rows in emp with NO match in dept

emp.join(dept, emp.dept\_id \== dept.dept\_id, "left\_semi").show()   \# rows in emp WITH a match, dept columns dropped

| Join type | Returns |
| :---- | :---- |
| `inner` | Only rows with matching keys in both sides |
| `left` | All left rows \+ matched right columns (nulls where no match) |
| `right` | All right rows \+ matched left columns (nulls where no match) |
| `full` / `outer` | Union of left and right, nulls on the non-matching side |
| `left_anti` | Left rows with **no** match in right — like a "NOT IN" / "NOT EXISTS" |
| `left_semi` | Left rows **with** a match in right, but only left's columns (existence check, not a real join) |

**Interview angle:** `left_anti` and `left_semi` come up constantly in "find customers who never ordered" / "find records that exist in source but not target" (CDC / reconciliation) style questions — know them cold, they trip people up because they don't exist as join types in plain ANSI SQL under those exact names (SQL expresses the same logic with `NOT EXISTS` / `EXISTS`).

---

### 24\. WINDOW FUNCTIONS

**Analogy:** `GROUP BY` collapses a neighborhood of houses into a single summary block. A window function is a sliding scanner that looks at each house's neighbors (its "window") but keeps every house — every row — visible in the output.

from pyspark.sql.window import Window

from pyspark.sql.functions import row\_number, rank, dense\_rank, sum as \_sum

window\_spec \= Window.partitionBy("dept").orderBy(col("salary").desc())

df \= df.withColumn("row\_num", row\_number().over(window\_spec))

df \= df.withColumn("rank", rank().over(window\_spec))

df \= df.withColumn("dense\_rank", dense\_rank().over(window\_spec))

- **`row_number()`** — unique, sequential, no ties (1, 2, 3, 4 …) even for equal values.  
- **`rank()`** — ties share a rank, next rank **skips** (100, 100, 90 → 1, 1, 3).  
- **`dense_rank()`** — ties share a rank, next rank does **not** skip (100, 100, 90 → 1, 1, 2).

**Cumulative sum \+ the frame clause** — this is the part almost everyone gets wrong first, because Spark's *default* frame for an `ORDER BY`'d window is `(unbounded preceding, current row)`, so a plain running sum "just works"... until you add a *second* window function that needs the *whole* partition instead, and it silently breaks unless you override the frame:

from pyspark.sql.functions import sum as \_sum

running\_total\_spec \= Window.partitionBy("dept").orderBy("join\_date")

df \= df.withColumn("running\_total", \_sum("salary").over(running\_total\_spec))

\# Frame clause: explicitly control which rows are "in the window"

\# relative to the current row. This is what you change inside .over(window\_spec).

dept\_total\_spec \= (

    Window.partitionBy("dept")

    .orderBy("join\_date")

    .rowsBetween(Window.unboundedPreceding, Window.unboundedFollowing)  \# whole partition

)

df \= df.withColumn("dept\_total\_salary", \_sum("salary").over(dept\_total\_spec))

\# Other common frames

last\_3\_rows\_spec \= Window.partitionBy("dept").orderBy("join\_date").rowsBetween(-2, 0\)   \# current \+ 2 preceding

range\_spec \= Window.partitionBy("dept").orderBy("salary").rangeBetween(-1000, 1000\)     \# value-based, not position-based

| Frame boundary | Meaning |
| :---- | :---- |
| `Window.unboundedPreceding` | from the very first row of the partition |
| `Window.unboundedFollowing` | to the very last row of the partition |
| `Window.currentRow` | the current row |
| `rowsBetween(a, b)` | physical row offsets (e.g., \-2 to 0 \= "last 3 rows") |
| `rangeBetween(a, b)` | value-based offsets on the `orderBy` column, not row position |

**Interview angle:** "Write a query to get each department's second-highest-paid employee." → `rank()` (not `row_number()`, since ties should share rank 2\) `over(Window.partitionBy("dept").orderBy(desc("salary")))`, then filter `rank == 2`.

---

### 25\. User Defined Functions (UDFs)

from pyspark.sql.functions import udf

from pyspark.sql.types import StringType

def categorize\_salary(salary):

    if salary is None:

        return "Unknown"

    return "High" if salary \> 80000 else "Low"

categorize\_udf \= udf(categorize\_salary, StringType())

df \= df.withColumn("salary\_category", categorize\_udf(col("salary")))

\# Cleaner in modern PySpark: register as a decorator

@udf(returnType=StringType())

def categorize\_salary\_v2(salary):

    return "Unknown" if salary is None else ("High" if salary \> 80000 else "Low")

**Interview angle — always know this tradeoff:** UDFs are a last resort, not a first choice. A Python UDF forces Spark to serialize each row out of the JVM, run it through a Python process, and serialize the result back — that round-trip kills the performance benefit of Catalyst's optimizations and vectorized execution. Always check whether a built-in `pyspark.sql.functions` function (or a SQL expression via `expr()`) can do the job first. When you truly need custom Python logic, prefer a **pandas UDF** (`@pandas_udf`) over a plain row-at-a-time UDF — pandas UDFs operate on Arrow-backed batches instead of row-by-row, which is dramatically faster.

from pyspark.sql.functions import pandas\_udf

import pandas as pd

@pandas\_udf(StringType())

def categorize\_salary\_pandas(salary: pd.Series) \-\> pd.Series:

    return salary.apply(lambda s: "Unknown" if pd.isna(s) else ("High" if s \> 80000 else "Low"))

---

### 26\. Data Writing and Write Modes

df.write.format("parquet") \\

    .mode("overwrite") \\

    .partitionBy("dept") \\

    .save("output/employees\_parquet")

| Mode | Behavior |
| :---- | :---- |
| `append` | Adds new files alongside whatever's already at the destination |
| `overwrite` | **Deletes** the existing data at the destination and replaces it — use cautiously, it's destructive |
| `error` / `errorifexists` (default) | Throws an error if the destination already has data |
| `ignore` | Silently does nothing if the destination already exists — no error, no write |

---

### 27\. Parquet File Format

**Analogy:** A CSV is like a spreadsheet you have to read left-to-right, row by row, even if you only want one column. Parquet is like a filing cabinet organized by *column* — if you only need "salary," you open only the "salary" drawer instead of flipping through every row.

Parquet is a **columnar**, compressed, binary storage format and is Spark's default and preferred format for a reason:

- **Columnar storage** → queries that touch only a few columns read only those columns off disk (column pruning), not the whole row.  
- **Predicate pushdown** → filters can be applied while reading, skipping whole row-groups that can't match.  
- **Schema embedded in the file** → no `inferSchema` pass needed on read, and types are preserved exactly.  
- **Compression-friendly** → similar values stored together compress far better than row-oriented CSV.

df.write.format("parquet").mode("overwrite").save("output/employees\_parquet")

df2 \= spark.read.format("parquet").load("output/employees\_parquet")  \# no schema/inferSchema needed

---

### 28\. Managed vs External Tables

**Analogy:** A managed table is like a hotel room — the hotel (Spark/the metastore) owns and controls both the room (data) and the booking record (metadata). Check out (drop the table) and the hotel clears the room out entirely. An external table is like your own apartment that you've simply told the front desk about — the front desk (metastore) keeps a note of the address (metadata), but the apartment (data) is yours; if you cancel the note, your apartment is untouched.

|  | Managed Table | External Table |
| :---- | :---- | :---- |
| Data location | Controlled by Spark/the metastore (default warehouse path) | Wherever you point it (`LOCATION` clause), e.g. your own S3/ADLS path |
| Who owns the underlying files | Spark/Databricks | You |
| `DROP TABLE` behavior | Deletes **both** the metadata (schema) **and** the underlying data files | Deletes **only** the metadata/schema — the actual data files are left untouched |

\-- Managed: no LOCATION specified, Spark owns the files

CREATE TABLE managed\_employees (emp\_id INT, name STRING, salary DOUBLE);

\-- External: LOCATION points to a path you control

CREATE TABLE external\_employees (emp\_id INT, name STRING, salary DOUBLE)

USING PARQUET

LOCATION '/mnt/data/employees/';

**Interview angle:** "When would you use an external table over a managed one?" → When the data needs to persist independently of the table definition, be shared across multiple systems/tools beyond Spark, or already lives in a specific location you don't want Spark to move/own (e.g., a raw landing zone that other pipelines also read from).

---

### 29\. Spark SQL (createTempView / spark.sql)

You can freely mix the DataFrame API and raw SQL — register a DataFrame as a temporary view, then query it with `spark.sql()`, which itself returns a DataFrame you can keep chaining.

df.createOrReplaceTempView("employees")   \# createTempView() errors if the view already exists;

                                            \# createOrReplaceTempView() is the safer default to re-run

result\_df \= spark.sql("""

    SELECT dept, AVG(salary) AS avg\_salary

    FROM employees

    GROUP BY dept

    ORDER BY avg\_salary DESC

""")

result\_df.show()

`createOrReplaceTempView` scopes the view to the current `SparkSession`. For a view visible across sessions/notebooks in the same cluster, use `createOrReplaceGlobalTempView` (queried as `global_temp.employees`).

**Interview angle:** Interviewers like asking "solve this with the DataFrame API, now solve it with SQL" — both compile down to the exact same Catalyst logical plan, so performance is identical. Know both fluently; a lot of teams have a house style preference.

---

## Part 2 — Architecture & Interview-Level Depth

### 30\. Spark Architecture

**Analogy:** The **Driver** is the site foreman with the blueprint (your code) — it plans the work and hands out assignments. The **Cluster Manager** is HR, deciding which workers (executors) are available and assigning them to the job. Each **Executor** is a work crew that actually lays the bricks (runs tasks) and reports progress back to the foreman.

Your Python code

      │

      ▼

   Driver ── talks to ──▶ Cluster Manager (YARN / Kubernetes / Standalone / Databricks)

      │                          │

      │                requests resources

      ▼                          ▼

  builds a DAG            Executors (JVM processes on worker nodes)

  of stages/tasks           \- each runs 1+ tasks in parallel (per core)

      │                     \- holds cached/partitioned data in memory

      ▼

  sends tasks to executors, collects results

- **Driver** — runs your `main()`, builds the logical → physical execution plan (DAG), schedules tasks, and collects final results (e.g. for `.collect()`/`.show()`).  
- **Cluster Manager** — allocates cluster resources to your application (YARN, Kubernetes, Spark Standalone, or the Databricks-managed one).  
- **Executors** — JVM processes on worker nodes that actually execute tasks and store data partitions in memory/disk for caching.  
- **Job → Stage → Task** — an action (e.g., `.count()`) triggers a **Job**; the job is split into **Stages** at shuffle boundaries; each stage is split into **Tasks**, one task per partition, run in parallel across executor cores.

**Interview angle:** "What happens when you call `.collect()` on a 500 GB DataFrame?" → Every partition gets pulled back to the driver's single JVM heap — if it doesn't fit, the driver OOMs. This is the classic real-world Spark mistake; use `.take(n)`, `.show(n)`, or write to storage instead of collecting large results.

---

### 31\. RDD vs DataFrame vs Dataset

|  | RDD | DataFrame | Dataset |
| :---- | :---- | :---- | :---- |
| Level | Low-level, distributed collection of objects | High-level, distributed table with schema | High-level, typed (JVM languages only) |
| Optimization | None — you control execution manually | Catalyst optimizer \+ Tungsten | Catalyst optimizer \+ Tungsten |
| Type safety | Compile-time (generic `RDD[T]`) | Runtime only | Compile-time (Scala/Java only) |
| Available in PySpark | Yes | Yes | **No** — Python is dynamically typed, so PySpark has no Dataset API |
| When to use | Rarely — unstructured data, fine-grained control, legacy code | Default choice for almost everything in PySpark | N/A in Python |

**Interview angle:** "Why don't Datasets exist in PySpark?" is a favorite trick question — the honest answer is Python has no compile-time type system for Spark to hook into, so the typed-Dataset API is Scala/Java only; PySpark DataFrames are the untyped equivalent.

---

### 32\. Transformations vs Actions, Lazy Evaluation

**Analogy:** Writing transformations is like drafting a recipe — nothing gets cooked yet. Calling an action is like actually turning on the stove: only then does Spark look at the whole recipe end-to-end and figure out the most efficient way to cook it (e.g., "these three ingredients can be prepped at once").

- **Transformations** (`select`, `filter`, `withColumn`, `join`, `groupBy`...) are **lazy** — they just build up a logical plan (a DAG), nothing executes.  
- **Actions** (`.show()`, `.count()`, `.collect()`, `.write()`, `.take()`) **trigger execution** of the whole accumulated plan.

Why this matters: laziness lets Catalyst see the *entire* chain of transformations before running anything, so it can reorder, combine, and prune steps (e.g., push a filter down before a join, skip reading unused columns) — impossible if each line executed eagerly in isolation.

\# Nothing has run yet after these three lines — just building a plan

step1 \= df.filter(col("salary") \> 50000\)

step2 \= step1.select("name", "dept")

step3 \= step2.withColumn("dept\_upper", upper("dept"))

step3.show()   \# \<- THIS triggers actual execution of the whole chain

**Narrow vs wide transformations:**

- **Narrow** (`filter`, `select`, `withColumn`) — each output partition depends on only one input partition; no data movement across the network.  
- **Wide** (`groupBy`, `join`, `distinct`, `orderBy`) — output partitions depend on *multiple* input partitions, requiring a **shuffle** (data movement across the network) and creating a new stage.

---

### 33\. Partitioning and Shuffling

**Analogy:** Partitioning is how you split a deck of cards among players before a game. A shuffle is what happens when the rules suddenly require everyone to regroup their cards by suit — everyone has to pass cards to everyone else. That mass exchange is expensive; the fewer times you force a regroup, the faster the game goes.

df.rdd.getNumPartitions()

df2 \= df.repartition(8)                 \# full shuffle, can increase or decrease partitions, evens out sizes

df3 \= df.repartition(8, "dept")         \# hash-partition by column — same dept lands in same partition

df4 \= df.coalesce(2)                    \# no full shuffle — merges existing partitions, can only DECREASE count

spark.conf.set("spark.sql.shuffle.partitions", "200")   \# default \# of partitions after a shuffle (join/groupBy)

- **`repartition(n)`** — triggers a full shuffle; use to *increase* partitions or to rebalance skewed partition sizes.  
- **`coalesce(n)`** — avoids a full shuffle by merging adjacent partitions; only works to *decrease* partition count; much cheaper, but can leave you with uneven partition sizes.  
- **`spark.sql.shuffle.partitions`** (default 200\) — controls how many partitions a shuffle (join/groupBy/distinct) produces. Too high → many tiny tasks, scheduling overhead. Too low → few huge partitions, memory pressure/spill. This is one of the most common real tuning knobs interviewers ask about.

**Interview angle:** "Your Spark job has 1 partition with 90% of the data and everything else nearly empty — what's happening and how do you fix it?" → **Data skew**. Fixes: salting the skewed key before a join/groupBy, `repartition()` on a better key, enabling **Adaptive Query Execution** (which can auto-split skewed partitions in modern Spark), or broadcasting the small side of a skewed join.

---

### 34\. Cache vs Persist

df.cache()      \# shorthand for persist(StorageLevel.MEMORY\_AND\_DISK) — default storage level

df.persist()    \# same default as cache()

from pyspark import StorageLevel

df.persist(StorageLevel.MEMORY\_ONLY)          \# faster, but data is lost (recomputed) if it doesn't fit

df.persist(StorageLevel.DISK\_ONLY)            \# spills fully to disk, slower but safe for huge data

df.persist(StorageLevel.MEMORY\_AND\_DISK\_SER)  \# serialized — less memory, more CPU to deserialize

df.unpersist()   \# always release when no longer needed

`cache()` is just `persist()` with a fixed default storage level — `persist()` lets you choose the level explicitly. Both are **lazy** too — nothing is actually cached until the next action runs.

**When to cache:** a DataFrame that gets **reused multiple times** downstream (e.g., referenced in three different aggregations) — without caching, Spark recomputes the *entire* upstream lineage from scratch every single time it's referenced, because of lazy evaluation.

**Interview angle:** "You call `df.cache()` — has it cached anything yet?" → No. Caching is registered lazily; the DataFrame is only materialized into cache on the *next* action that touches it.

---

### 35\. Joins Under the Hood: Broadcast vs Shuffle Joins

**Analogy:** If one team is tiny, it's cheaper to photocopy their whole roster and hand a copy to every other team (**broadcast join**) than to make every team member physically travel to compare notes with everyone else (**shuffle join**).

from pyspark.sql.functions import broadcast

\# Force a broadcast join when Spark's cost-based optimizer doesn't pick one automatically

large\_df.join(broadcast(small\_df), "customer\_id")

spark.conf.set("spark.sql.autoBroadcastJoinThreshold", 10 \* 1024 \* 1024\)  \# default 10MB; \-1 disables auto-broadcast

- **Broadcast (map-side) join** — the smaller DataFrame is copied in full to *every* executor; no shuffle needed for the large side. Fast, but only works when the small side fits comfortably in each executor's memory (default auto-threshold: 10MB, configurable).  
- **Shuffle (sort-merge) join** — both sides are shuffled/repartitioned by the join key so matching keys land on the same executor, then joined. Necessary when both sides are large; the expensive default.

**Interview angle:** "You're joining a 500GB fact table to a 2MB dimension table and it's slow — what do you check first?" → Whether Spark actually picked a broadcast join (check the physical plan via `.explain()`); if not, wrap the small side in `broadcast()` explicitly.

---

### 36\. Catalyst Optimizer, Tungsten, and AQE

- **Catalyst Optimizer** — Spark SQL's query optimizer. Turns your DataFrame/SQL code into a logical plan, applies rule-based optimizations (predicate pushdown, column pruning, constant folding), then picks a physical plan.  
- **Tungsten** — the execution engine that manages memory and generates optimized JVM bytecode directly (whole-stage code generation) instead of interpreting the plan row by row — this is what makes DataFrame/SQL code run close to hand-written Scala speed even though you wrote it in Python.  
- **AQE (Adaptive Query Execution)** — re-optimizes the query plan *during* execution using real runtime statistics instead of only static, pre-run estimates: it can dynamically switch a shuffle join to a broadcast join once it sees the actual data size, coalesce shuffle partitions that turned out too small, and split skewed partitions automatically. Enabled by default since Spark 3.x (`spark.sql.adaptive.enabled`).

df.filter(col("salary") \> 50000).select("name").explain(True)   \# inspect the logical \+ physical plan

spark.conf.set("spark.sql.adaptive.enabled", True)               \# default True in modern Spark

**Interview angle:** "Why is a PySpark DataFrame job often as fast as a Scala one, when Python UDFs are so much slower?" → Because DataFrame/SQL operations never actually run in the Python interpreter — Python is just the API you use to *build* the plan; Catalyst \+ Tungsten execute it on the JVM. It's only custom Python UDFs that pay the cross-language serialization cost.

---

### 37\. Delta Lake Essentials

**Analogy:** A plain Parquet folder is like a shared document with no version history — if two people edit at once, or someone needs yesterday's version, you're out of luck. Delta Lake adds a transaction log on top, like Google Docs' version history — every change is recorded, so you can see who changed what, roll back, and be sure a write either fully completed or didn't happen at all.

Delta Lake adds **ACID transactions**, **schema enforcement**, and **time travel** on top of Parquet files via a transaction log (`_delta_log`).

df.write.format("delta").mode("overwrite").save("/delta/employees")

from delta.tables import DeltaTable

delta\_tbl \= DeltaTable.forPath(spark, "/delta/employees")

\# MERGE (upsert) — the flagship Delta feature over plain Parquet

delta\_tbl.alias("target").merge(

    updates\_df.alias("source"),

    "target.emp\_id \= source.emp\_id"

).whenMatchedUpdateAll() \\

 .whenNotMatchedInsertAll() \\

 .execute()

\# Time travel — query a previous version or timestamp

spark.read.format("delta").option("versionAsOf", 3).load("/delta/employees")

spark.read.format("delta").option("timestampAsOf", "2026-08-01").load("/delta/employees")

**Interview angle:** "How do you implement SCD Type 2 in Delta Lake?" → `MERGE` with `whenMatchedUpdate` (to expire the old row: set `end_date`, `is_current = false`) combined with `whenNotMatchedInsert` (for genuinely new records), typically run as two passes or one `MERGE` plus a follow-up insert for the new current row — this is the modern, Delta-native version of the classic SCD2 pattern from the SQL notes above.

---

### 38\. Structured Streaming Basics

**Analogy:** Batch processing is reading a book chapter by chapter after it's fully printed. Structured Streaming is like reading a live news feed — new "micro-chapters" of data keep arriving, and you re-run your same logic on each new arrival almost instantly, without re-reading everything from the start.

streaming\_df \= (

    spark.readStream.format("delta")

    .load("/delta/raw\_orders")

)

agg\_df \= streaming\_df.groupBy("dept").count()

query \= (

    agg\_df.writeStream

    .format("delta")

    .outputMode("complete")          \# "append", "complete", or "update"

    .option("checkpointLocation", "/checkpoints/orders\_agg")

    .trigger(processingTime="1 minute")

    .start("/delta/orders\_agg")

)

Structured Streaming treats a stream as an **unbounded table** that keeps growing — you write the exact same DataFrame/SQL logic you'd write for batch, and Spark handles re-running it incrementally on each new micro-batch. The **checkpoint location** is what makes it fault-tolerant: it tracks exactly which offsets have already been processed so a restart doesn't reprocess or skip data.

**Interview angle:** "Batch vs streaming — when do you pick which?" → Batch for non-time-sensitive, large-scale periodic aggregation (cheaper, simpler); streaming for low-latency use cases like fraud detection or live dashboards, at the cost of more operational complexity (checkpointing, watermarking for late data, exactly-once semantics).

---

## Common Interview Q\&A — Rapid Fire

**Q: Difference between `repartition()` and `coalesce()`?** A: `repartition()` does a full shuffle and can increase or decrease partitions while rebalancing sizes evenly; `coalesce()` avoids a shuffle by merging existing partitions and can only decrease the count, which can leave sizes uneven.

**Q: Difference between `cache()` and `persist()`?** A: `cache()` is `persist()` with the default storage level (`MEMORY_AND_DISK`); `persist()` lets you pick the storage level explicitly (memory-only, disk-only, serialized, etc.).

**Q: `rank()` vs `dense_rank()` vs `row_number()`?** A: For scores 100, 100, 90 → `row_number()` gives 1, 2, 3 (always unique); `rank()` gives 1, 1, 3 (ties share, next rank skips); `dense_rank()` gives 1, 1, 2 (ties share, no skip).

**Q: What triggers a shuffle?** A: Wide transformations — `groupBy`, `join` (non-broadcast), `distinct`, `orderBy`/`sort`, `repartition`. Narrow transformations (`filter`, `select`, `withColumn`, `map`) never shuffle.

**Q: Why are Python UDFs slow in PySpark?** A: Every row has to be serialized out of the JVM, sent to a Python process, computed, and serialized back — this per-row cross-process hop bypasses Catalyst/Tungsten's optimizations entirely. Prefer built-in functions or, if custom logic is required, pandas UDFs (vectorized, Arrow-based batches).

**Q: `union()` vs `unionByName()`?** A: `union()` stacks by column *position* — dangerous if schemas differ in order. `unionByName()` matches by column *name*, which is almost always what you actually want.

**Q: How does Spark achieve fault tolerance without replicating data like Hadoop?** A: RDD **lineage** — Spark remembers the sequence of transformations that produced each partition. If a partition is lost (executor failure), Spark just recomputes it from the lineage graph instead of needing a physical replica.

**Q: What's data skew and how do you fix it?** A: An uneven distribution of a key (e.g., one customer ID with 40% of all rows) causes one partition/task to be far larger than the rest, becoming the bottleneck for the whole stage. Fixes: salting the key, repartitioning on a more even key, broadcasting the small side of a skewed join, or letting AQE's skew-join optimization handle it automatically.

**Q: managed vs external table — what does `DROP TABLE` do differently?** A: Managed table: drops both the metadata *and* deletes the underlying data files. External table: drops only the metadata/catalog entry; the data files are untouched.

**Q: Why does PySpark have no Dataset API?** A: Datasets require compile-time type checking, which needs a static type system (Scala/Java). Python is dynamically typed, so PySpark only exposes the untyped DataFrame API.

**Q: Explain the Spark execution hierarchy: Job → Stage → Task.** A: One action call \= one **Job**. A job is split into **Stages** at every shuffle boundary. Each stage is split into **Tasks**, one per partition, and tasks within a stage run in parallel across executor cores.

---

## Cheat Sheet

\# Session

spark \= SparkSession.builder.appName("app").getOrCreate()

\# Read / Write

df \= spark.read.format("csv").option("header", True).schema(ddl).load(path)

df.write.format("parquet").mode("overwrite").partitionBy("col").save(path)

\# Explore

df.printSchema(); df.show(5); df.columns; df.dtypes; df.describe().show()

\# Transform

df.select(...); df.filter(cond); df.withColumn(name, expr)

df.withColumnRenamed(old, new); df.drop(cols); df.dropDuplicates(\[cols\])

df.sort(col.desc()); df.limit(n)

\# Aggregate

df.groupBy(cols).agg(F.sum(...), F.avg(...), F.count("\*"))

df.groupBy(cols).pivot("col", \[vals\]).agg(...)

\# Nulls

df.dropna(how="any"/"all", subset=\[...\]); df.fillna(value\_or\_dict)

\# Joins

left.join(right, on\_cond, "inner"/"left"/"right"/"full"/"left\_anti"/"left\_semi")

\# Window

w \= Window.partitionBy(...).orderBy(...).rowsBetween(a, b)

F.row\_number().over(w); F.rank().over(w); F.sum(col).over(w)

\# Perf

df.cache(); df.persist(StorageLevel.X); df.unpersist()

df.repartition(n, col); df.coalesce(n)

F.broadcast(small\_df)

df.explain(True)

\# SQL

df.createOrReplaceTempView("t"); spark.sql("SELECT ...")

## Resources

- [PySpark official docs](https://spark.apache.org/docs/latest/api/python/) — free, authoritative  
- [Databricks Academy](https://academy.databricks.com/) — free Spark/Databricks courses  
- [Delta Lake documentation](https://docs.delta.io/) — free  
- DataLemur.com — for the SQL side of DE interviews (window functions overlap heavily with this notebook)

