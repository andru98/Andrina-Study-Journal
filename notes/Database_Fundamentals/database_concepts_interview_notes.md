# Database Concepts — Interview Notes

Covers: DB Fundamentals, SQL, Keys, Joins, Aggregations, Python \+ SQLite, Python \+ PostgreSQL (Supabase), MongoDB, Streamlit Last updated: 2026-06-09

---

## Table of Contents

1. [Why Databases Exist](#1-why-databases-exist)  
2. [Relational vs Non-Relational — Quick Reference Table](#2-relational-vs-non-relational)  
3. [Core Structure of a Relational Database](#3-core-structure-of-a-relational-database)  
4. [Keys — Complete Reference Table](#4-keys)  
5. [SQL Expressions — Complete Reference Table](#5-sql-expressions)  
6. [Query Execution Order](#6-query-execution-order)  
7. [JOINs — Reference Table](#7-joins)  
8. [Python \+ SQLite](#8-python--sqlite)  
9. [Python \+ PostgreSQL via Supabase](#9-python--postgresql-via-supabase)  
10. [MongoDB](#10-mongodb)  
11. [Streamlit](#11-streamlit)  
12. [System Design: Scaling](#12-system-design-scaling)  
13. [Top Interview Questions and Answers](#13-top-interview-questions-and-answers)

---

## 1\. Why Databases Exist

Before databases, data was stored in flat files (.txt, .csv). This caused four core problems:

| Problem | Description | Example |
| :---- | :---- | :---- |
| Slow searching | Scanning 5,00,000 rows line by line | Finding employee\_id \= 3 takes forever |
| Race condition | Two programs writing same file simultaneously | HR and Manager portal both updating attendance at 10:00 AM — conflict |
| Data corruption | Program crashes mid-write, file left in broken state | CSV partially written, rest is garbage |
| No relationships | No way to link data across files cleanly | Employees and Departments stored separately with no enforced link |

**Solution → DBMS (Database Management System)** Software that manages data storage, retrieval, relationships, and concurrency safely.

Examples: PostgreSQL (relational), MongoDB (non-relational), MySQL, SQLite

---

## 2\. Relational vs Non-Relational

| Feature | Relational (SQL) | Non-Relational (NoSQL) |
| :---- | :---- | :---- |
| Storage format | Tables (rows and columns) | Flexible: documents (JSON), key-value, graph |
| Schema | Fixed — defined upfront | Dynamic — schema can change per document |
| Query language | SQL | MongoDB Query, Redis commands, etc. |
| Relationships | Enforced via foreign keys | Handled in application code or embedded documents |
| Scaling | Vertical scaling (bigger machine) | Horizontal scaling (more machines) |
| Best for | Structured, relational data | Unstructured, flexible, rapidly changing data |
| Examples | PostgreSQL, MySQL, SQLite | MongoDB, Redis, Cassandra, DynamoDB |
| Consistency | Strong (ACID) | Eventual consistency (BASE) in many systems |
| Real use case | Bank transactions, HR systems, ERP | Social media posts, logs, product catalogs, real-time feeds |
| Python library | psycopg2 (PostgreSQL), sqlite3 | pymongo (MongoDB) |
| Cloud option | Supabase → PostgreSQL via cloud | MongoDB Atlas → MongoDB via cloud |

**When to choose relational:** data has clear relationships, transactions matter, consistency is critical.

**When to choose non-relational:** schema changes frequently, need to store nested/complex data, need to scale horizontally across many machines.

---

## 3\. Core Structure of a Relational Database

Database

  └── Schema (blueprint)

        └── Table (structured collection of data)

              ├── Columns (name, data type, constraints)

              └── Rows (individual records)

### Data Types

| SQLite | PostgreSQL |
| :---- | :---- |
| NULL | CHAR, VARCHAR, TEXT |
| INT | DATE, TIME, TIMESTAMP |
| REAL | BOOLEAN |
| TEXT | NUMERIC, INTEGER |
| BLOB | SERIAL (auto-increment) |

### Common Constraints

| Constraint | Meaning | Example |
| :---- | :---- | :---- |
| PRIMARY KEY | Unique identifier for each row, cannot be NULL | `id INT PRIMARY KEY` |
| NOT NULL | Column cannot be empty | `name TEXT NOT NULL` |
| UNIQUE | No duplicate values in the column | `email TEXT UNIQUE` |
| CHECK | Validates a condition before insert | `CHECK (length(name) > 3)` |
| FOREIGN KEY | Links to primary key of another table | `FOREIGN KEY (dept_id) REFERENCES departments(dept_id)` |

---

## 4\. Keys

| Key Type | Definition | Example |
| :---- | :---- | :---- |
| Super Key | Any combination of columns that uniquely identifies a row. May contain unnecessary columns. | (student\_id), (student\_id, name), (student\_id, email), (email, phone) |
| Candidate Key | Minimal super key — no extra columns. Every candidate key can uniquely identify a row on its own. | (student\_id), (email), (gov\_id) |
| Primary Key | The ONE candidate key chosen as the official row identifier. Cannot be NULL. | student\_id |
| Alternate Key | Every candidate key that was NOT chosen as the primary key. | email, gov\_id (if student\_id is PK) |
| Foreign Key | A column in one table that refers to the primary key of another table. Enforces referential integrity. | dept\_id in students table → dept\_id in departments table |
| Surrogate Key | An artificial key with no real-world meaning, created just to be the primary key. | row\_id (auto-generated integer) |
| Composite Key | A primary key made of two or more columns combined. | (emp\_id, project\_id) in employee\_projects table |

**Key hierarchy to memorize:**

All possible unique combos → Super Keys (50+)

Remove unnecessary columns → Candidate Keys (25)

Pick one official → Primary Key (1)

Remaining candidates → Alternate Keys (24)

---

## 5\. SQL Expressions

### SELECT and Filtering

| Expression | Syntax | Use Case |
| :---- | :---- | :---- |
| SELECT all | `SELECT * FROM employees;` | Get all rows and columns |
| SELECT columns | `SELECT name, salary FROM employees;` | Get specific columns |
| Column alias | `SELECT salary*12 AS yearly_salary FROM employees;` | Rename column in output |
| WHERE | `SELECT * FROM employees WHERE department = 'IT';` | Filter rows by condition |
| AND | `WHERE department = 'IT' AND salary > 75000` | Both conditions must be true |
| OR | `WHERE department = 'IT' OR salary > 75000` | Either condition true |
| BETWEEN | `WHERE salary BETWEEN 65000 AND 80000` | Inclusive range filter |
| IN | `WHERE city IN ('Delhi', 'Bangalore')` | Match any value in list |
| LIKE | `WHERE name LIKE 'R%'` | Pattern match — % \= any chars, \_ \= one char |
| IS NULL | `WHERE dept_id IS NULL` | Check for NULL values |
| IS NOT NULL | `WHERE dept_id IS NOT NULL` | Exclude NULL rows |
| NOT IN | `WHERE dept_id NOT IN (1, 2)` | Exclude specific values — beware NULL trap |

### Sorting and Limiting

| Expression | Syntax | Use Case |
| :---- | :---- | :---- |
| ORDER BY ASC | `ORDER BY salary` | Sort ascending (default) |
| ORDER BY DESC | `ORDER BY salary DESC` | Sort descending |
| Multiple sort | `ORDER BY department, salary DESC` | Sort by dept first, then salary |
| LIMIT | `LIMIT 3` | Return top N rows |
| Top N pattern | `ORDER BY salary DESC LIMIT 1` | Highest salary |

### Aggregations

| Function | Syntax | Use Case |
| :---- | :---- | :---- |
| COUNT | `SELECT COUNT(*) FROM employees` | Count all rows |
| COUNT filtered | `SELECT COUNT(*) FROM employees WHERE department='IT'` | Count rows matching condition |
| SUM | `SELECT SUM(salary) FROM employees` | Total of a column |
| AVG | `SELECT AVG(salary) FROM employees` | Average of a column |
| MIN | `SELECT MIN(salary) FROM employees` | Lowest value |
| MAX | `SELECT MAX(salary) FROM employees` | Highest value |

### GROUP BY and HAVING

| Expression | Syntax | Use Case |
| :---- | :---- | :---- |
| GROUP BY | `SELECT department, AVG(salary) FROM employees GROUP BY department` | Aggregate per group |
| HAVING | `HAVING AVG(salary) > 70000` | Filter groups after aggregation |
| WHERE vs HAVING | WHERE filters rows (before GROUP BY). HAVING filters groups (after GROUP BY). WHERE cannot use aggregate functions. | — |

### DDL and DML

| Operation | Syntax | Notes |
| :---- | :---- | :---- |
| CREATE TABLE | `CREATE TABLE employees (id INT PRIMARY KEY, name TEXT NOT NULL, salary INT);` | Define schema |
| INSERT single | `INSERT INTO employees VALUES (1, 'Rahul', 'IT', 70000);` | Add one row |
| INSERT multiple | `INSERT INTO employees VALUES (1,...), (2,...), (3,...);` | Add multiple rows at once |
| UPDATE | `UPDATE employees SET salary = 80000 WHERE id = 1;` | Modify existing rows |
| DELETE | `DELETE FROM employees WHERE id = 1;` | Remove rows |
| ALTER TABLE | `ALTER TABLE employees ADD COLUMN city TEXT;` | Change schema after creation |
| DROP TABLE | `DROP TABLE employees;` | Delete entire table |

---

## 6\. Query Execution Order

SQL does NOT execute in the order you write it. This is one of the most common interview questions.

Written order:     SELECT → FROM → WHERE → GROUP BY → HAVING → ORDER BY → LIMIT

Execution order:   FROM → WHERE → GROUP BY → HAVING → SELECT → ORDER BY → LIMIT

**Plain English:**

1. FROM — get the table  
2. WHERE — filter individual rows  
3. GROUP BY — group the filtered rows  
4. HAVING — filter the groups  
5. SELECT — pick columns and compute aggregates  
6. ORDER BY — sort the result  
7. LIMIT — cut down to N rows

**Why this matters in interviews:**

- You cannot use a SELECT alias in a WHERE clause (WHERE runs before SELECT)  
- You cannot use aggregate functions in WHERE (use HAVING instead)  
- HAVING runs after GROUP BY so it can use aggregate results

---

## 7\. JOINs

JOINs combine rows from two or more tables based on a related column.

| JOIN Type | Returns | NULL behaviour | SQLite support |
| :---- | :---- | :---- | :---- |
| INNER JOIN | Only rows where match exists in BOTH tables | No NULLs — unmatched rows excluded | ✅ |
| LEFT JOIN | All rows from LEFT table \+ matching rows from RIGHT | NULL for right table columns when no match | ✅ |
| RIGHT JOIN | All rows from RIGHT table \+ matching from LEFT | NULL for left table columns when no match | ✅ (simulate via swapping tables) |
| FULL JOIN | All rows from BOTH tables | NULL where no match on either side | ❌ SQLite not supported — use UNION workaround |
| CROSS JOIN | Every row from left × every row from right | No join condition | ✅ |

### JOIN Syntax Pattern

\-- INNER JOIN

SELECT employees.name, departments.dept\_name

FROM employees

INNER JOIN departments ON employees.dept\_id \= departments.dept\_id;

\-- With aliases (cleaner for interviews)

SELECT emp.name, dept.dept\_name

FROM employees AS emp

INNER JOIN departments AS dept ON emp.dept\_id \= dept.dept\_id;

\-- LEFT JOIN

SELECT emp.name, dept.dept\_name

FROM employees AS emp

LEFT JOIN departments AS dept ON emp.dept\_id \= dept.dept\_id;

\-- FULL JOIN workaround in SQLite (UNION removes duplicates)

SELECT employees.name, departments.dept\_name

FROM employees

LEFT JOIN departments ON employees.dept\_id \= departments.dept\_id

UNION

SELECT employees.name, departments.dept\_name

FROM departments

LEFT JOIN employees ON employees.dept\_id \= departments.dept\_id;

### UNION

UNION combines results of two SELECT statements and removes duplicates automatically. UNION ALL keeps duplicates.

SELECT name FROM employees\_2024

UNION

SELECT name FROM employees\_2025;

\-- Duplicates removed automatically

---

## 8\. Python \+ SQLite

SQLite is a lightweight, file-based DBMS built into Python. No server needed. Ideal for local development and learning.

### Connection Workflow (5 steps — memorize this)

import sqlite3

\# Step 1 — Connect (creates .db file if not exists)

conn \= sqlite3.connect('student\_1.db')

\# Step 2 — Create cursor (executes SQL, fetches results)

cursor \= conn.cursor()

\# Step 3 — Enable foreign keys (OFF by default in SQLite)

cursor.execute('PRAGMA foreign\_keys \= ON;')

\# Step 4 — Execute queries

cursor.execute('''

    CREATE TABLE IF NOT EXISTS employees (

        id INT PRIMARY KEY,

        name TEXT NOT NULL,

        dept\_id INT,

        FOREIGN KEY (dept\_id) REFERENCES departments(dept\_id)

    )

''')

\# Insert using parameterised queries (prevents SQL injection)

student\_vals \= \[(1, 'Anna', 2), (2, 'Bob', 2)\]

for val in student\_vals:

    cursor.execute('''

        INSERT INTO employees (id, name, dept\_id) VALUES (?,?,?)

    ''', val)

\# Step 5 — Commit (save changes to disk) and close

conn.commit()

conn.close()

### Fetching Data

conn \= sqlite3.connect('student\_1.db')

cursor \= conn.cursor()

cursor.execute("SELECT \* FROM employees")

\# fetchone() — one row at a time, returns None when exhausted

row \= cursor.fetchone()   \# (1, 'Anna', 2\)

row \= cursor.fetchone()   \# (2, 'Bob', 2\)

row \= cursor.fetchone()   \# None — no more rows

\# fetchall() — all rows at once as a list of tuples

cursor.execute("SELECT \* FROM employees")

rows \= cursor.fetchall()  \# \[(1,'Anna',2), (2,'Bob',2)\]

\# Iterate cleanly

for row in rows:

    print(row)

conn.close()

### Introspection Queries

\-- List all tables

SELECT name FROM sqlite\_schema WHERE type='table' AND name NOT LIKE 'sqlite\_%';

\-- View table schema

SELECT sql FROM sqlite\_schema WHERE name \= 'employees';

### Why SQLite over PostgreSQL for learning?

- No server to install or configure  
- Database is a single .db file  
- Built into Python standard library (no pip install)  
- Same SQL syntax as PostgreSQL for core operations  
- Not suitable for production — no concurrent writes at scale

---

## 9\. Python \+ PostgreSQL via Supabase

### What is Supabase?

Supabase is a cloud platform that provides a managed PostgreSQL database with a web UI, API, and authentication. You connect to it using psycopg2 exactly like any PostgreSQL database — Supabase just hosts it for you.

### Setup Steps

pip install python-dotenv psycopg2

### .env file (never commit this to GitHub)

user=postgres.yourprojectid

password=your\_password

host=aws-0-ap-south-1.pooler.supabase.com

port=6543

dbname=postgres

### Connection Code

import os

import psycopg2

from dotenv import load\_dotenv

\# Load secrets from .env file into OS environment variables

load\_dotenv()

USER     \= os.getenv("user")

PASSWORD \= os.getenv("password")

HOST     \= os.getenv("host")

PORT     \= os.getenv("port")

DBNAME   \= os.getenv("dbname")

try:

    connection \= psycopg2.connect(

        user=USER,

        password=PASSWORD,

        host=HOST,

        port=PORT,

        dbname=DBNAME

    )

    cursor \= connection.cursor()

    \# Execute query

    cursor.execute("SELECT \* FROM student;")

    results \= cursor.fetchall()

    for row in results:

        print(row)

    \# Insert with parameterised query (%s for PostgreSQL, ? for SQLite)

    student\_val \= ("Anna", 25, "Chicago", 9\)

    cursor.execute('''

        INSERT INTO student (name, age, city, class)

        VALUES (%s, %s, %s, %s)

    ''', student\_val)

    connection.commit()

except Exception as e:

    print(f"Connection failed: {e}")

finally:

    cursor.close()

    connection.close()

### SQLite vs PostgreSQL (Python) — Key Differences

|  | SQLite | PostgreSQL (psycopg2) |
| :---- | :---- | :---- |
| Placeholder | `?` | `%s` |
| Connect to | `.db` file | Server (local or cloud) |
| Library | `sqlite3` (built-in) | `psycopg2` (pip install) |
| Foreign keys | OFF by default, enable with PRAGMA | ON by default |
| Concurrent writes | Limited | Full support |
| Production use | No | Yes |

### Supabase Connection Types

| Type | Use When | Port |
| :---- | :---- | :---- |
| Direct Connection | Long-lived connections, VMs, containers | 5432 |
| Transaction Pooler | Serverless functions, brief connections | 6543 |
| Session Pooler | IPv4 network, alternative to direct | 5432 |

---

## 10\. MongoDB

### Relational vs MongoDB Terminology

| Relational | MongoDB |
| :---- | :---- |
| Database | Database |
| Table | Collection |
| Row | Document |
| Column | Field |
| Primary Key | \_id (auto-generated) |
| SQL | MongoDB Query Language |

### Document Format

MongoDB stores data as documents (dict/JSON format). Documents in the same collection can have different fields — no rigid schema required.

\# Relational row

(1, 'Anna', 25, 'Chicago')

\# MongoDB document (dict/JSON)

{

    "\_id": ObjectId("..."),

    "name": "Anna",

    "age": 25,

    "city": "Chicago",

    "courses": \["Python", "SQL"\]   \# nested data possible

}

### Key MongoDB Query Operators

| Operator | Meaning | SQL equivalent |
| :---- | :---- | :---- |
| `$set` | Update a field | SET |
| `$gt` | Greater than | \> |
| `$lt` | Less than | \< |
| `$regex` | Pattern match | LIKE |
| `$exists` | Field exists | IS NOT NULL |
| `$in` | Match any in list | IN |

### Key MongoDB Methods (pymongo)

| Method | Use |
| :---- | :---- |
| `.find()` | Get all documents matching filter |
| `.find_one()` | Get first matching document |
| `.insert_one()` | Insert one document |
| `.insert_many()` | Insert multiple documents |
| `.delete_one()` | Delete first matching document |
| `.delete_many()` | Delete all matching documents |
| `.update_one()` | Update first matching document |

### Setup: MongoDB Atlas (Cloud)

1. Create account at mongodb.com  
2. Create a free cluster (M0 — free tier)  
3. Create a database user (username \+ password)  
4. Add your IP address to the access list  
5. Get the connection string URI  
6. Connect via Python: `pip install pymongo`

---

## 11\. Streamlit

Streamlit is a Python library for building web UIs using only Python code. No HTML or JavaScript required.

import streamlit as st

\# Run: streamlit run app.py

\# Opens at http://localhost:8501

st.title("My Dashboard")

st.write("Hello world")

name \= st.text\_input("Enter your name")

dob  \= st.date\_input("Select Date of Birth")

if st.button("Submit", type="primary"):

    st.write(f"Hello {name}\!")

### Refresh vs Rerun

|  | Refresh (F5) | Rerun (widget interaction) |
| :---- | :---- | :---- |
| Triggered by | Browser reload | Any widget change |
| session\_state | Wiped | Preserved |
| Script execution | Restart from top | Restart from top |

### session\_state — persisting data across reruns

\# Without session\_state — value resets every rerun

count \= 0

if st.button("Add"):

    count \+= 1          \# always stays 0

\# With session\_state — value persists across reruns

if "count" not in st.session\_state:

    st.session\_state.count \= 0

if st.button("Add"):

    st.session\_state.count \+= 1

st.write(st.session\_state.count)  \# increments correctly

### Streamlit vs Traditional Web Stack

|  | Streamlit | Traditional |
| :---- | :---- | :---- |
| Language | Python only | HTML \+ CSS \+ JS \+ Python |
| Use case | DS/AI prototypes, internal dashboards | Production web apps |
| Speed to build | Very fast | Slower |
| Customisation | Limited | Full |
| Deployment | Streamlit Cloud, AWS, GCP | Any web server |

---

## 12\. System Design: Scaling

### Vertical Scaling

Upgrade the existing machine — more CPU, more RAM.

2018: i3 CPU, 4GB RAM, 256GB storage

2026: i3 CPU, 8GB RAM, 256GB storage  ← upgraded same machine

Limit: you can only upgrade one machine so far before hitting hardware limits.

### Horizontal Scaling

Add more machines and distribute the load.

System 1: i3, 12GB RAM, 256GB

System 2: i5, 20GB RAM         ← added new machine

Total capacity \= combined

**Relational databases** traditionally use vertical scaling. **Non-relational databases** (MongoDB, Cassandra) are designed for horizontal scaling — this is why they dominate large-scale internet applications.

---

## 13\. Top Interview Questions and Answers

**Q: What is a database and why do we need it instead of a flat file?** A: A database is an organised collection of data managed by a DBMS. Flat files fail at scale because searching is slow (full scan), multiple programs cause race conditions, crashes cause data corruption, and there is no way to enforce relationships between datasets. A DBMS solves all four problems.

**Q: What is the difference between a primary key and a foreign key?** A: A primary key uniquely identifies each row in a table and cannot be NULL. A foreign key is a column in one table that references the primary key of another table, enforcing the relationship between them. For example, dept\_id in the employees table is a foreign key pointing to dept\_id in the departments table.

**Q: What is the difference between WHERE and HAVING?** A: WHERE filters individual rows before grouping. HAVING filters groups after GROUP BY. WHERE cannot use aggregate functions like COUNT or AVG. HAVING can. Example: `WHERE salary > 70000` filters rows; `HAVING AVG(salary) > 70000` filters groups.

**Q: What is the difference between INNER JOIN and LEFT JOIN?** A: INNER JOIN returns only rows where a match exists in both tables. LEFT JOIN returns all rows from the left table and the matching rows from the right table — if no match exists, NULL is returned for the right table columns. Use LEFT JOIN when you need to keep all records from the primary table regardless of whether a relationship exists.

**Q: What is the SQL query execution order?** A: FROM → WHERE → GROUP BY → HAVING → SELECT → ORDER BY → LIMIT. This matters because a SELECT alias cannot be used in WHERE (WHERE runs first), and aggregate functions cannot be used in WHERE (use HAVING instead).

**Q: What is a candidate key and how does it differ from a primary key?** A: A candidate key is the minimal super key — any column or combination that can uniquely identify a row with no unnecessary columns. There can be multiple candidate keys. A primary key is the one candidate key chosen as the official identifier. The remaining candidate keys become alternate keys.

**Q: What is a surrogate key and when do you use it?** A: A surrogate key is an artificially generated key with no real-world meaning, typically an auto-incrementing integer (row\_id). Used when no natural candidate key exists or when natural keys are too complex to use as a primary key. It makes joins simpler and avoids coupling your primary key to business data that might change.

**Q: Why does SQLite require PRAGMA foreign\_keys \= ON?** A: SQLite disables foreign key enforcement by default for backwards compatibility. Without enabling it, you can insert a dept\_id that does not exist in the departments table and SQLite will not raise an error. Always enable it at the start of every SQLite session in production code.

**Q: What is the difference between SQLite and PostgreSQL?** A: SQLite is a lightweight, file-based, serverless database built into Python — ideal for local development and learning. PostgreSQL is a full production-grade DBMS with a server, supports concurrent writes, enforces foreign keys by default, and scales to millions of rows. The SQL syntax is nearly identical; the main Python difference is the placeholder character (? vs %s).

**Q: What is a race condition in databases?** A: When two programs read and write the same data simultaneously, they can overwrite each other's changes. Example: HR software marks attendance as absent and the manager portal marks it as present at the same time — one overwrites the other. Databases solve this with transactions and locking mechanisms (ACID properties).

**Q: What is the difference between relational and non-relational databases?** A: Relational databases store data in structured tables with fixed schemas, enforce relationships via foreign keys, use SQL, and scale vertically. Non-relational databases store data in flexible formats (documents, key-value, graph), have dynamic schemas, use their own query languages, and scale horizontally. Choose relational when consistency and relationships matter. Choose non-relational when flexibility, speed, and horizontal scale matter.

**Q: What is Supabase?** A: Supabase is a cloud platform that hosts a managed PostgreSQL database. It provides a web UI (Table Editor, SQL Editor), authentication, storage, and API out of the box. You connect to it from Python using psycopg2 exactly like any PostgreSQL database — Supabase just removes the need to manage your own server.

**Q: What is the difference between fetchone() and fetchall() in Python database connections?** A: fetchone() retrieves the next single row from the result set as a tuple, advancing an internal cursor. Returns None when no rows remain. fetchall() retrieves all remaining rows at once as a list of tuples. Use fetchone() when processing large results row by row to avoid loading everything into memory. Use fetchall() for small result sets where you need all rows immediately.

**Q: What is parameterised query and why is it important?** A: A parameterised query uses placeholders (? in SQLite, %s in PostgreSQL) instead of directly embedding user input into SQL strings. This prevents SQL injection attacks where malicious input could alter the query logic. Never use string formatting to build SQL queries with user input.

---

*Push to: `notes/database_concepts_interview_notes.md`*  
