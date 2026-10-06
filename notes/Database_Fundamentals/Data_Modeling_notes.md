# Data Warehousing & Data Modeling
Study notes from Ansh Lamba's Data Warehousing series — applied to real-world Data Engineering projects.

---

## Table of Contents
1. Layers of Data Modeling
2. OLTP vs OLAP
3. Keys
4. Relationships & Cardinality
5. Normalization
6. Data Warehouse Architecture
7. Dimensional Modeling
8. Fact Tables
9. Dimension Tables
10. Slowly Changing Dimensions
11. Incremental Loading

---

## 1. Layers of Data Modeling

```
Conceptual Layer
→ Talk to stakeholders
→ Gather requirements, KPIs, goals
→ No technical detail yet

        ↓

Logical Layer
→ Entity Relationship Diagram (ERD)
→ Entities, attributes, relationships
→ Database agnostic

        ↓

Physical Layer
→ Actual SQL scripts
→ Data types, indexes, constraints
→ Database specific
```

---

## 2. OLTP vs OLAP

| Property | OLTP | OLAP |
|----------|------|------|
| Full name | Online Transactional Processing | Online Analytical Processing |
| Purpose | Day-to-day operations | Analytics & reporting |
| Users | Customers, front-end apps | Analysts, business users |
| Operations | INSERT, UPDATE, DELETE | SELECT, aggregations |
| Data size | Small per transaction | Huge (millions of rows) |
| Speed | Fast (milliseconds) | Slower but acceptable |
| Design | Normalized (3NF) | Denormalized (star schema) |
| Example | Booking a flight | Monthly revenue report |

```
OLTP Database → ETL Process → Data Warehouse (OLAP)
     ↓                              ↓
 Operations                     Analytics
 (source)                       (reporting)
```

---

## 3. Keys

### Primary Key
```
→ Uniquely identifies each row
→ Cannot be NULL
→ Only ONE primary key per table
```

### Key Types Hierarchy
```
Super Key
→ ALL possible combinations that uniquely identify a row

    ↓ subset of

Candidate Key
→ Minimal combination to uniquely identify a row
→ Any column that COULD be primary key

    ↓ chosen one becomes

Primary Key          Alternate Key
→ Selected candidate → Remaining candidates
→ THE identifier     → Not chosen but still unique
```

### Foreign Key
```
fact_bookings                    dim_customer
+------------+                   +-------------+
| booking_sk |                   | customer_sk |←── PK
| customer_sk|────────────────→  | name        |
| revenue    |     FK references | city        |
+------------+                   +-------------+
```

### Surrogate vs Natural Key

Natural Key comes from the source system — for example `customer_id = "CUST-001"` from a CRM. The problem is it can change anytime, uses strings (slow joins), and breaks with SCD Type 2.

Surrogate Key is an artificial integer YOU create — `customer_sk = 1, 2, 3...`. You control it, it never changes, uses integers (fast joins), works perfectly with SCD Type 2, and stays independent of source system changes.

**Rule: Always use surrogate keys in dimensional modeling.**

### Composite Key
When a single column is not enough to uniquely identify a row, combine columns. For example `(customer_id + product_id)` uniquely identifies an order line.

---

## 4. Relationships & Cardinality

### Cardinality Types

**One-to-One (1:1)**
```
Person ──── Passport
Each person has exactly one passport
```

**One-to-Many (1:N)**
```
Department ──<── Employee
One department has many employees
```

**Many-to-Many (M:N)**
```
Student >──< Course
Students enroll in many courses
Courses have many students
→ Requires a BRIDGE TABLE
```

### Many-to-Many Bridge Table
```
Student          Enrollment (Bridge)    Course
+----------+     +------------+         +----------+
|student_id|───→ |student_id  | ←──────|course_id |
|name      |     |course_id   |         |name      |
+----------+     |enroll_date |         +----------+
                 +------------+
```

### Crow's Foot Notation
```
──|     Exactly one
──<     Many
──○     Zero or one
──|<    One or many
──○<    Zero or many
```

---

## 5. Normalization

Goal: Reduce data redundancy and improve data integrity.

### 1NF — First Normal Form
Rules: each column has atomic (single) values, no repeating groups, has a primary key.

```
Violation:                       Fixed (1NF):
+----+------------------+        +----+---------+----------+
| id | subjects         |        | id | student | subject  |
+----+------------------+        +----+---------+----------+
| 1  | Math, Science    |  →     | 1  | Anna    | Math     |
| 2  | English          |        | 1  | Anna    | Science  |
+----+------------------+        | 2  | Bob     | English  |
                                  +----+---------+----------+
```

### 2NF — Second Normal Form
Must be 1NF with no partial dependency — non-key columns must depend on the WHOLE primary key, not just part of it.

```
Violation: Orders table has (order_id + product_id) as PK
product_name depends only on product_id → partial dependency ❌

Fixed:
Orders:   order_id, product_id, quantity
Products: product_id, product_name
```

### 3NF — Third Normal Form
Must be 2NF with no transitive dependency — non-key columns must not depend on other non-key columns.

```
Violation:
employee_id → department_id → department_name
department_name depends on department_id, not directly on employee_id ❌

Fixed:
Employees:   employee_id, department_id
Departments: department_id, department_name
```

### BCNF — Boyce-Codd Normal Form
Stricter version of 3NF. For every dependency X → Y, X must be a super key.

---

## 6. Data Warehouse Architecture

```
Source Systems (OLTP)
         │
         ▼
  ETL / ELT Pipeline
  Extract → Transform → Load
         │
         ▼
┌────────────────────────────────┐
│         Data Warehouse         │
│                                │
│  Staging Layer  →  Core Layer  │
│  (raw, truncated)  (transformed│
│                    facts+dims) │
└────────────────────────────────┘
         │
         ▼
  Data Marts (business-specific subsets)
         │
         ▼
  BI Tools / Reports / Dashboards
```

**Staging Layer:** Receives raw data from source. Usually truncated before each load (transient). 95% of the time, always truncate staging.

**Core Layer:** Transformed, clean data exposed to downstream consumers — analysts, BI tools, data marts.

**Data Mart:** A subset of the data warehouse focused on a specific business domain (e.g. finance, marketing, operations).

### Medallion Architecture (Modern Data Lakehouse)
```
Bronze (Raw)  →  Silver (Cleaned)  →  Gold (Aggregated)
   JSON/CSV      One Big Table         Fact + Dim tables
                 (denormalized)        Star/Snowflake schema
```

---

## 7. Dimensional Modeling

### Star Schema
```
                   dim_date
                  +----------+
                  | date_sk  |
                  | date     |
                  | month    |
                  | year     |
                  +----------+
                       |
dim_customer      fact_bookings       dim_route
+------------+   +--------------+   +----------+
|customer_sk |←──| booking_sk   |──→| route_sk |
|name        |   | customer_sk  |   | origin   |
|city        |   | route_sk     |   | dest     |
|segment     |   | date_sk      |   | distance |
+------------+   | revenue      |   +----------+
                 | seats_sold   |
                 +--------------+
                       |
                  dim_fare_class
                  +------------+
                  |fare_cls_sk |
                  |class_code  |
                  |cabin_type  |
                  +------------+
```

### Snowflake Schema
Dimensions are further normalized — for example `dim_customer → dim_city → dim_country`. Less redundancy but more joins and slower queries.

### Star vs Snowflake

| Property | Star Schema | Snowflake Schema |
|----------|-------------|-----------------|
| Normalization | Denormalized | Normalized |
| Query speed | Faster | Slower |
| Storage | More space | Less space |
| Complexity | Simple | Complex |
| Use case | Most analytics | Large dimensions |

---

## 8. Fact Tables

The most granular layer — contains measures (numbers) plus foreign keys to dimensions.

### Transaction Fact Table (most common)
One row equals one transaction.

```
+------------+-------------+----------+---------+
| booking_sk | customer_sk | route_sk | revenue |
+------------+-------------+----------+---------+
| 1          | 101         | 5        | 350.00  |  ← one booking
| 2          | 102         | 5        | 275.00  |  ← one booking
+------------+-------------+----------+---------+
```

### Periodic Snapshot Fact Table
One row equals one time period (daily, monthly, yearly). Not one row per transaction — one row per chosen time period.

```
+----------+----------+------------------+
| date_sk  | route_sk | monthly_revenue  |
+----------+----------+------------------+
| 20240801 | 5        | 125,000.00       |  ← August total
| 20240901 | 5        |  98,000.00       |  ← September total
+----------+----------+------------------+
```

Use case: Balance sheets, inventory levels, account balances.

### Accumulating Snapshot Fact Table
One row describes the entire journey or process. Has multiple date columns for each stage. Row gets UPDATED as the process progresses.

```
+------------+---------------+----------------+--------------+
| booking_sk | booking_date  | check_in_date  | flight_date  |
+------------+---------------+----------------+--------------+
| 1          | 2024-01-10    | 2024-03-14     | 2024-03-15   |
+------------+---------------+----------------+--------------+
```

Use case: Order fulfillment, insurance claims, loan processing.

---

## 9. Dimension Tables

Context tables containing descriptive attributes — WHO, WHAT, WHERE, WHEN. No measures here.

### Conformed Dimension
Shared by more than one fact table. `dim_date` used by `fact_bookings`, `fact_ancillary`, and `fact_refunds` — one version of truth across the warehouse.

### Role-Playing Dimension
Same dimension table plays multiple roles in the same fact table.

```
fact_flight:
+------------+------------------+-------------------+
| flight_sk  | booking_date_sk  | departure_date_sk |
+------------+------------------+-------------------+
Both reference the same dim_date table with different meanings.
```

### Junk Dimension
When you have flags or indicators with very few distinct values, group them into one dimension instead of keeping them in the fact table.

```
dim_flight_flags:
+----------+------------+------------+----------------+
| flag_sk  | is_weekend | is_holiday | is_peak_season |
+----------+------------+------------+----------------+
| 1        | Y          | N          | Y              |
| 2        | N          | Y          | Y              |
+----------+------------+------------+----------------+
```

### Degenerate Dimension
A dimension key stored directly in the fact table with no separate dimension table. For example `booking_reference` or `invoice_number` — has no attributes worth storing separately.

### Slowly Changing Dimension
See next section.

---

## 10. Slowly Changing Dimensions

How to handle changes to dimension attributes over time.

### SCD Type 0 — Retain Original
No changes allowed. Original value preserved forever. Use case: date of birth, original contract terms.

### SCD Type 1 — Overwrite
Simply update the record. No history kept.

```
dim_customer BEFORE:          dim_customer AFTER:
customer_sk | city            customer_sk | city
1           | Peoria    →     1           | Chicago
                              (Peoria gone forever)
```

SQL pattern:
```sql
MERGE INTO dim_customer AS target
USING source ON target.customer_id = source.customer_id
WHEN MATCHED THEN UPDATE SET city = source.city
WHEN NOT MATCHED THEN INSERT VALUES (...)
```

### SCD Type 2 — Full History (Recommended)
Add a new row for each change. Track with `start_date`, `end_date`, and `is_active`.

```
dim_customer:
sk | customer_id | city     | start_date | end_date   | is_active
1  | CUST-001    | Peoria   | 2020-01-01 | 2023-06-30 | N  ← old
2  | CUST-001    | New York | 2023-07-01 | NULL       | Y  ← current

fact_bookings references correctly:
booking in 2022 → sk=1 → Peoria ✅
booking in 2024 → sk=2 → New York ✅
```

Surrogate key is essential here — same natural key (`CUST-001`) maps to two different surrogate keys, and the fact table points to the exact version at the time of the transaction.

### SCD Type 3 — Partial History
Add a column for the previous value. Only one level of history tracked.

```
dim_customer:
sk | customer_id | current_city | previous_city
1  | CUST-001    | New York     | Peoria
```

Pros: simple. Cons: only tracks one change.

### SCD Comparison

| Type | History | Storage | Complexity | Use Case |
|------|---------|---------|------------|----------|
| Type 0 | None | Minimal | Simple | Static data |
| Type 1 | None | Minimal | Simple | Corrections |
| Type 2 | Full | More | Medium | Most cases |
| Type 3 | Partial | Medium | Medium | Simple tracking |

---

## 11. Incremental Loading

Only process new or changed data — not a full reload every time.

### Change Data Capture (CDC)

**Option 1: Store MAX date**
Select the MAX `updated_at` from staging, save it to a config table. Next run only processes records where `updated_at > last_run_date`.

**Option 2: Database CDC**
Read the transaction log using tools like Debezium or AWS DMS. Captures INSERT, UPDATE, DELETE events in real time.

**Option 3: Delta Lake MERGE**
```sql
MERGE INTO gold_table USING new_data
WHEN MATCHED THEN UPDATE SET ...
WHEN NOT MATCHED THEN INSERT ...
```

### Staging Layer Types

**Transient Staging** (most common — 95% of cases): Truncate before each load. Only holds the current batch. No history in staging.

**Persistent Staging**: Keep all historical raw data. Equivalent to the Bronze layer in medallion architecture. Useful if you need to reprocess from scratch.

### ETL Flow with Incremental Loading
```
Source DB        Staging           Core (DW)
    │               │                  │
    │── new rows ──→│── transform ────→│
    │               │   + validate      │
    │           store MAX date          │
    │           for next run            │
```

---

## Key Concepts Summary

| Concept | Short Answer |
|---------|-------------|
| OLTP | Normalized, fast writes, operational |
| OLAP | Denormalized, fast reads, analytical |
| Surrogate Key | Artificial integer YOU control, SCD-safe |
| Natural Key | From source, can change, avoid in joins |
| Star Schema | Denormalized dims, fast queries |
| Snowflake Schema | Normalized dims, more joins |
| Fact Table | Measures + FK references |
| Dim Table | Context and attributes |
| SCD Type 1 | Overwrite, no history |
| SCD Type 2 | New row, full history (recommended) |
| SCD Type 3 | New column, partial history |
| Incremental | Process only new/changed data |
| Full Load | Process everything (slow, expensive) |

---

## Applied to Airline Ancillary Revenue Platform

**fact_ancillary_bookings** is a Transaction Fact Table — one row per seat purchase, with measures like `price_paid`, `is_sold`, `revenue`, and foreign keys to flight, seat type, passenger, and date dimensions.

**dim_passenger** uses SCD Type 2 — when a passenger changes their frequent flyer status, a new row is added. Historical bookings correctly reflect the old status through the surrogate key.

**dim_seat_type** is a Conformed Dimension — shared by both `fact_ancillary_bookings` and `fact_bookings`. Contains seat categories ST, PZ, ELR from Sabre Ancillary IQ work.

**dim_date** is a Role-Playing Dimension — used as both `booking_date_sk` and `departure_date_sk` in the same fact table.

---

*Notes by Anna Shrestha | MS Data Science | Data Engineering Portfolio*
*GitHub: [Andrina-Study-Journal](https://github.com/andru98/Andrina-Study-Journal)*
