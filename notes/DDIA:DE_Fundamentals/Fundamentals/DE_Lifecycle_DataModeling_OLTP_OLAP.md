# Data Engineering Fundamentals
## Study Notes — Interview Preparation
**Author: Anna Shrestha | DE Career Transition | Healthcare & Tech Focus**
**Topics: DE Lifecycle · Data Modeling · OLTP vs OLAP · Relational Design**

---

## 1. The Data Engineering Lifecycle

> A data engineer's job is to move data reliably from where it is born (source systems) to where it creates value (dashboards, ML models, applications).

### The Five Stages

```
Source (OLTP) → Ingestion → Storage → Transformation → Serving (OLAP)
        ↑                                                        ↑
        └──────── Orchestration manages all stages ──────────────┘
        └──────── Observability watches all stages ──────────────┘
```

### Stage 1 — Source (Generation)

Data originates in production systems owned by other teams.

```
Example — Spotify play event:
  App writes to Postgres: user_id=42, song_id=1180, played_at=21:02
```

**The most important DE mindset:**
> "You don't own this data. Another team owns that database and they will change its schema on a Tuesday without telling you."

**What good DEs do about this:**
- Validate schema at ingestion — detect column changes immediately
- Data contracts with the app team — written agreement: "14 days notice before renaming columns"
- Bronze layer absorbs schema changes — raw data lands as received, fix mapping in Silver
- Monitor schema drift — alert when today's schema differs from yesterday's

### Stage 2 — Ingestion

Moving data from source into your platform.

| Method | How | Latency | Use when |
|---|---|---|---|
| Batch | Pull on schedule (hourly/daily) via SQL | Minutes to hours | Latency of hours is acceptable |
| Streaming | Kafka — capture events as they happen | Milliseconds | Real-time required |
| CDC | Debezium reads DB transaction log | Milliseconds | Real-time DB replication, zero source load |

**Three ways ingestion breaks — and the fixes:**

```
1. Source is down:
   Fix: retry 3 times (10 min apart) → dead letter → alert fires

2. API rate limits you:
   Fix: exponential backoff, read Retry-After header, batch requests

3. Schema changed overnight:
   Fix: schema validation at ingestion → mismatch → dead letter → alert
        Bronze still stores whatever arrived → reprocess after fix
```

### Stage 3 — Storage

```
Data Lake (S3/GCS):       Raw data, any format, cheap, schema on read
                          Bronze layer — kept forever for replay
                          Format: Parquet (columnar, compressed, fast)

Data Warehouse            Structured, clean, queryable, schema on write
(Snowflake/BigQuery):     Gold layer — trusted by business
                          Column-oriented — fast aggregations

Lakehouse (Delta Lake):   Best of both — ACID + time travel + schema enforcement
                          Silver and Gold layers in Medallion architecture
```

**Why Parquet over CSV:**

| | CSV | Parquet |
|---|---|---|
| Storage | Row-oriented | Column-oriented |
| Compression | Poor | 5-10× smaller |
| Analytics | Reads all columns even for one | Reads only needed columns |
| Schema | Inferred at read time | Embedded in file |
| Speed | Slow for analytics | Fast for analytics |

### Stage 4 — Transformation

Where most DE code lives. Raw events become business answers.

```
Raw Bronze:    user_id=42, song_id=1180, played_at=21:02
After Silver:  user_id=42, artist_id=A001, artist="Taylor Swift", is_complete=true
After Gold:    user_id=42, artist="Taylor Swift", play_count=47, rank=1
```

**Four problems transformation fixes:**
1. **Standardise values:** "CONFIRMED", "confirmed", "cnfrmd" → "confirmed"
2. **Remove duplicates:** double-click creates two rows → deduplicate to one
3. **Fix types:** price stored as VARCHAR "₹4,500" → DECIMAL 4500.00
4. **Fix dates:** "01/06/2026", "June 1, 2026" → "2026-06-01T00:00:00Z"

**Medallion Architecture:**
```
Bronze (raw, schema on read)  →  Silver (clean, schema on write)  →  Gold (business-ready)
S3 Parquet                        Delta Lake                           Snowflake
Append-only, kept forever         IDs extracted, types fixed           Aggregated, analyst-ready
```

### Stage 5 — Serving

```
Analytics dashboards:  Analysts query Gold tables in Snowflake via SQL
ML models:             Feature store → real-time predictions
Reverse ETL:           Clean data pushed back to operational systems (Salesforce CRM)
App APIs:              Redis cache serves pre-computed results instantly
```

### Orchestration and Observability (Undercurrents)

**Orchestration (Airflow):** schedule every job, manage dependencies, retry on failure, alert when retries exhausted.

**Three minimum pipeline monitoring checks — run after every load:**

| Check | Threshold | What it catches |
|---|---|---|
| Row count | ±25% of 7-day average | Missing rows — timezone bugs, bad filters |
| Freshness | MAX(event_timestamp) lag < 2 hours | Stale data — wrong Kafka offset |
| Revenue sanity | ±30% vs same weekday last week | Silent JOIN failures |

> Silence = OK. A result row = alert fires. Job status alone is never enough.

---

## 2. Data Modeling

> A data model is the blueprint for how data is laid out — which tables exist, what columns they hold, and how they connect through keys.

### What is a Data Model?

Design the data model BEFORE writing any application code. It defines:
- Which tables exist
- What columns and data types each table holds
- How tables connect through primary and foreign keys

### Primary Key vs Foreign Key

```
users table:              orders table:
user_id  PK ←─────────── user_id  FK
name                      order_id PK
city                      amount
                          order_date

Arrow direction: FROM orders (FK) → TO users (PK)
```

**Primary Key rules:**
- Uniquely identifies one row in its own table
- Never NULL, never duplicate, never changes
- Every table has exactly one PK

**Foreign Key rules:**
- The same ID stored in another table to link them
- Always lives on the MANY side of a relationship
- CAN be NULL (order with no payment yet)
- CAN repeat (same user_id on many orders)

**The rule — FK always lives on the MANY side:**
```
One user  → many orders    → user_id FK lives in orders table
One trip  → many stops     → trip_id FK lives in stops table
One order → many items     → order_id FK lives in order_items table
One artist → many songs    → artist_id FK lives in songs table
```

### Normalisation — Why Split Data?

**Problem — one big denormalised table:**
```
order | customer | city     | product  | amount
5001  | Adam     | New York | Mouse    | 1499
5002  | Adam     | New York | Keyboard | 2999
5003  | Adam     | New York | Cable    | 299
```
"Adam | New York" copied on every row. Adam moves to Chicago → must update thousands of rows → miss one → data is wrong.

**Solution — normalised tables:**
```
users table:              orders table:
user_id | name | city     order_id | user_id | product  | amount
U001    | Adam | New York 5001     | U001    | Mouse    | 1499
                          5002     | U001    | Keyboard | 2999
```
Adam's city stored ONCE. Update one row → all orders automatically correct via JOIN.

**Three problems normalisation solves:**
1. **Storage waste** — no repeated data
2. **Update anomaly** — change in one place, reflects everywhere
3. **Inconsistency** — one value, one place, always consistent

### Cardinality — Relationship Types

```
One-to-many (most common):
  One user → many orders
  One driver → many trips
  FK lives on the MANY side (orders, trips)

Many-to-many:
  One order → many products
  One product → many orders
  Solution: junction table (order_items) with FKs to both sides

One-to-one:
  One order → one invoice
  FK can live on either side
```

### Schema Design Interview Process

> Never start writing SQL in an interview. Follow this process:

1. **List the entities** (nouns) → these become your tables
2. **Give each a primary key**
3. **Connect with foreign keys** — FK on the MANY side
4. **Talk through cardinality out loud** — "one user can take MANY trips"
5. **Ask about edge cases** — "can a driver have multiple vehicles?"

**Example — ride-hailing app:**
```
Entities: Users, Drivers, Trips, Payments, Vehicles

trips table:
  trip_id     PK
  user_id     FK → users     (many trips, one user)
  driver_id   FK → drivers   (many trips, one driver)
  vehicle_id  FK → vehicles  (many trips, one vehicle)
  payment_id  FK → payments  (one trip, one payment)
  start_time, end_time, distance, fare
```

### When to Create a New Table

Create a separate table when something:
- Can have MULTIPLE occurrences per parent (one trip → many stops)
- Has its own attributes worth storing (vehicle has plate, model, year)
- Is SHARED between multiple parents (one vehicle used by multiple drivers)

---

## 3. OLTP vs OLAP — Deep Dive

> As a data engineer, you spend your career moving data between two systems. One runs the app. The other answers questions about the app. Your job lives in the gap between them.

### OLTP — Online Transaction Processing

**Purpose:** power the live application

**What is a transaction?**
Any single action that creates or changes a record:
```
User buys on Amazon     → INSERT orders + UPDATE inventory + INSERT payments
User returns a product  → UPDATE order status + INSERT refund
User changes address    → UPDATE one row in users
User logs in            → UPDATE last_login timestamp
```

**Reads in OLTP — always targeted:**
```
User opens order history:  SELECT * FROM orders WHERE user_id = 42
User checks order status:  SELECT status FROM orders WHERE order_id = 5001
User searches products:    SELECT * FROM products WHERE name LIKE '%iPhone%'

Pattern: always FEW rows, always for ONE specific user/record
         Index jumps directly to matching rows — milliseconds
```

**OLTP characteristics:**
```
Speed:          milliseconds
Pattern:        1-100 rows at a time
Users:          thousands of live users simultaneously
Schema:         normalised — many tables, FKs, no duplication
Optimised for:  fast single-row reads and writes
Databases:      PostgreSQL, MySQL, Oracle
Storage:        row-oriented
```

### OLAP — Online Analytical Processing

**Purpose:** answer business questions over historical data

```
"What was total revenue per city over the last five years?"
→ Scans millions of rows — not time-critical
→ Nobody waiting the way a user waits for a payment
```

**OLAP characteristics:**
```
Speed:          seconds to minutes (acceptable)
Pattern:        millions of rows, aggregations
Users:          few analysts, data scientists
Schema:         denormalised — star schema, fewer JOINs
Optimised for:  fast column scans and aggregations
Databases:      Snowflake, BigQuery, Redshift
Storage:        column-oriented
```

### The Real Difference — Row vs Column Storage

**This is the most important technical concept:**

**Row storage (OLTP) — entire row stored together on disk:**
```
[1 | Adam | 26 | 10]
[2 | Bola | 25 | 20]
[3 | Cara | 30 | 30]

SELECT SUM(payment):
  Read row 1 → grab payment=10, throw away id, name, age
  Read row 2 → grab payment=20, throw away id, name, age
  Read row 3 → grab payment=30, throw away id, name, age
  Read 12 values → used 3 → wasted 9 (75% waste)
```

**Column storage (OLAP) — entire column stored together on disk:**
```
id:      [1, 2, 3]
name:    [Adam, Bola, Cara]
age:     [26, 25, 30]
payment: [10, 20, 30]  ← only this is read

SELECT SUM(payment):
  Jump directly to payment column
  Read [10, 20, 30] → add up → done
  Never touched id, name, or age
  Read 3 values → used 3 → wasted 0 (0% waste)
```

> "Row storage is fast for 'give me this one record.' Column storage is fast for 'give me this one column across everything.' That single choice — how bytes are laid out on disk — is the whole OLTP vs OLAP story."

**Compression bonus for column storage:**
```
payment column: [10, 20, 30, 10, 10, 20, 10, 30...]
Similar values cluster together → compress 10:1
Even less data to read from disk → even faster

Row storage compresses poorly — values in a row are always varied
```

### Why Not Use One System for Both?

The two storage layouts pull in opposite directions:
- Fast single-row writes require row-oriented storage
- Fast column scans require column-oriented storage
- The indexing, file format, and disk layout are fundamentally different

**The critical warning:**
> Never run heavy analytics on your production OLTP database.

```
Analyst runs revenue query on production Postgres:
  Scans 50 million rows × multiple table JOINs
  Takes 45 minutes
  During those 45 minutes: real users experience slow checkout
  In the worst case: database crashes, app goes down
  
Keep the two jobs on two systems. Always.
```

### Where the DE Fits — ETL/ELT

```
App database  →  Extract · Transform · Load  →  Data warehouse  →  Dashboards
(OLTP)            ↑ the data engineer's job      (OLAP)              ML/AI
row storage                                       column storage
```

**ETL (Extract, Transform, Load):**
- **Extract:** pull from OLTP source (Fivetran, Debezium, custom scripts)
- **Transform:** clean, deduplicate, fix types, standardise formats
- **Load:** write into OLAP warehouse

**ELT (Extract, Load, Transform):**
- Load raw data first, transform inside warehouse using dbt
- Default for modern cloud stacks (Snowflake, BigQuery)
- Re-transformable — update dbt model, reprocess all history without re-extracting

**ETL vs ELT — when to use which:**
```
Use ETL when:
  Healthcare/payments — HIPAA/PCI-DSS compliance
  Raw PII (patient names, card numbers) must never touch warehouse
  Mask before landing anywhere

Use ELT when:
  Modern cloud stack (Snowflake, BigQuery, Databricks)
  No compliance restrictions on raw data
  Business definitions may change — want to re-transform history
  Default choice for new projects
```

---

## 4. Complete OLTP vs OLAP Reference

| | OLTP | OLAP |
|---|---|---|
| Full name | Online Transaction Processing | Online Analytical Processing |
| Purpose | Run the live application | Answer analytical questions |
| Users | Thousands of live app users | Few analysts, data scientists |
| Operations | INSERT, UPDATE, DELETE, targeted SELECT | Aggregating SELECT across millions of rows |
| Row access | Few rows per query | Millions of rows per query |
| Storage | Row-oriented | Column-oriented |
| Schema | Normalised (many tables, FKs) | Denormalised (star schema) |
| Query speed | Milliseconds | Seconds to minutes |
| Time sensitivity | Real-time critical | Not time-critical |
| Databases | PostgreSQL, MySQL, Oracle | Snowflake, BigQuery, Redshift |
| Data scope | Current operational data | Years of historical data |
| Reads | Targeted — one user, one record | Wide — all users, all records |

---

## 5. Interview Quick-Fire Answers

**"Walk me through the DE lifecycle with an example"**
> "I'll use my Spotify pipeline project. When user 42 plays a song, the event is written to Spotify's API — a source I don't own and which can change without warning. Ingestion uses Python with the requests library, with retry logic and error handling for rate limits and schema changes. Raw events land in Bronze on AWS S3 — schema on read, kept forever for replay. Transformation is where most code lives — using pandas I join plays to a songs table to get the artist, deduplicate double-taps, filter incomplete plays under 30 seconds, and aggregate to find each user's top artist. This flows through Bronze, Silver, and Gold layers following the Medallion architecture. Airflow orchestrates every stage as a DAG — each layer is an explicit task with dependencies and retries. pytest covers each transformation function so bugs are caught before they reach the Gold layer. After every load, row count and freshness checks validate data quality."

**"What is normalisation and why do it?"**
> "Normalisation means storing each piece of information in exactly one place and linking other tables via foreign keys. Without it, a customer's name and city are duplicated on every one of their orders. If they move cities you must update thousands of rows — miss one and your data is inconsistent with no error thrown. With normalisation, their city lives in one row in the users table. Update once and every order reflects it automatically via JOIN."

**"Design the schema for a ride-hailing app"**
> "I start by listing the entities — Users, Drivers, Trips, Payments, Vehicles. Each becomes a table with its own primary key. Trips is the central fact table with foreign keys to Users, Drivers, Vehicles, and Payments. The FK always lives on the MANY side — one driver has many trips, so driver_id FK lives in trips not in drivers. I would then ask about edge cases: can a driver use multiple vehicles? If yes, vehicles gets its own table with vehicle_id FK in trips. Does a trip have multiple stops? If yes, stops gets its own table with trip_id FK referencing trips."

**"What is the difference between OLTP and OLAP?"**
> "OLTP is the relational database powering the live application — Postgres, MySQL — optimised for fast reads and writes of individual rows. Thousands of users simultaneously, each touching a few rows in milliseconds. OLAP is the data warehouse — Snowflake, BigQuery — optimised for scanning millions of rows to answer business questions. The fundamental technical difference is physical storage: OLTP stores data row by row so retrieving one record is instant. OLAP stores data column by column so aggregations only read the needed column, skipping everything else. The same SELECT SUM(revenue) query reads 75% wasted data in OLTP but zero wasted data in OLAP."

**"Why never run analytics on the production database?"**
> "OLTP and OLAP have opposite storage requirements. A heavy analytics query scanning 50 million rows competes directly with live users for database CPU and memory. During that 45-minute scan, real users experience slow checkouts and timeouts. In the worst case the database crashes and the app goes down for everyone. That is why we keep the two jobs on separate systems — OLTP for the live app, OLAP for analytics — and the DE builds the ETL pipeline between them."

**"ETL vs ELT — when would you choose each?"**
> "ELT is the default for modern cloud stacks — extract raw data, load it immediately, transform inside the warehouse using dbt. The key advantage is re-transformability: if business definitions change, update a dbt model and reprocess all historical raw data without re-extracting from source. ETL is the right choice when compliance requires it — HIPAA for healthcare, PCI-DSS for payments. Raw patient identifiers or card numbers must be masked before landing anywhere. Since my target companies include Tempus and Flatiron Health, ETL is non-negotiable for patient data even when the rest of the stack uses ELT."

**"What is Parquet and why use it over CSV?"**
> "Parquet is a columnar file format — same storage principle as OLAP warehouses. Analytics queries read only the columns they need, skipping everything else. Combined with compression — similar values in a column compress 5-10x better than row data — Parquet files are much smaller and faster to scan than CSV. CSV is row-oriented, reads every column even for a single-column aggregation, and has no embedded schema. Parquet is the standard for data lake Bronze layers because it delivers near-warehouse analytical performance while keeping storage costs low."

---

## 6. Applied to My Projects

### Spotify Data Pipeline (June 2026)
```
Source:         Spotify API — external, schema can change without notice
Ingestion:      Python (requests library) with retry and error handling
Storage:        AWS S3 — Bronze / Silver / Gold layers
Transformation: pandas — Bronze (raw JSON) → Silver (clean) → Gold (aggregated)
Orchestration:  Apache Airflow — scheduled DAGs, dependency management, retries
Testing:        pytest — unit tests per transformation function
Key DE work:    Medallion architecture in Python/pandas
                Row count and freshness validation after each layer
                Dead letter handling for malformed API responses
```

**What I learned building it:**
- Calling an API you do not control means defensive coding at every step — null checks, schema validation, retry logic
- pandas is right for this scale — straightforward, readable, testable
- Airflow enforces discipline: each stage is an explicit task with clear dependencies
- pytest on transformation functions catches bugs before they reach the Gold layer

### Airline Revenue Intelligence Platform (October 2026).
```
Source:         Booking system Postgres (OLTP — normalised, row storage)
Ingestion:      Debezium CDC → Kafka (real-time booking velocity)
Storage:        Delta Lake Bronze/Silver/Gold (Medallion)
Transformation: Spark (Bronze→Silver) + dbt (Silver→Gold)
Serving:        Snowflake → revenue dashboard + XGBoost demand model
Key DE work:    Normalise raw "Mumbai"/"mumbai"/"BOM" → airport_id = 'BOM'
                ETL for any PII (passenger names masked before warehouse)
Monitoring:     Revenue sanity check ±30% vs same weekday
```
