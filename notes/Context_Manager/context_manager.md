# Context Managers for Data Engineers — Interview Notes

Covers: What context managers are, class-based vs generator-based, production patterns, interview Q\&A Last updated: 2026-06-25

---

## Table of Contents

1. [What is a Context Manager](#1-what-is-a-context-manager)  
2. [Class-Based Context Managers](#2-class-based-context-managers)  
3. [Generator-Based Context Managers](#3-generator-based-context-managers)  
4. [Four Production Patterns](#4-four-production-patterns)  
5. [Nesting Context Managers](#5-nesting-context-managers)  
6. [Context Manager vs Decorator](#6-context-manager-vs-decorator)  
7. [Production File Structure](#7-production-file-structure)  
8. [Top Interview Questions and Answers](#8-top-interview-questions-and-answers)

---

## 1\. What is a Context Manager

A context manager guarantees setup and cleanup around a block of code — even when exceptions occur. The `with` statement is Python's way of expressing this pattern.

with open("file.csv", "r") as f:

    data \= f.read()

\# file closed automatically here — even if read() raises an exception

**Why it matters in DE pipelines:**

Without context manager:

conn \= psycopg2.connect(dsn)

try:

    cursor.execute(query)

    conn.commit()

except Exception:

    conn.rollback()

    raise

finally:

    conn.close()   \# must remember every time — easy to forget

With context manager:

with DatabaseConnection(dsn) as conn:

    cursor.execute(query)

\# commit, rollback, close — all automatic, impossible to forget

**Two methods Python calls automatically:**

\_\_enter\_\_() → runs when entering the with block

              return value bound to the as variable

\_\_exit\_\_(exc\_type, exc\_val, exc\_tb) → runs when leaving the with block

              exc\_type \= type of exception (None if no exception)

              exc\_val  \= error message

              exc\_tb   \= traceback showing where error occurred

              return False → exception propagates (always use this)

              return True  → exception suppressed (almost never correct)

---

## 2\. Class-Based Context Managers

Use when: complex logic, state management, need full exception handling control.

import psycopg2

import logging

logger \= logging.getLogger(\_\_name\_\_)

class DatabaseConnection:

    """Context manager for PostgreSQL connection with automatic cleanup."""

    def \_\_init\_\_(self, dsn: str, autocommit: bool \= False):

        self.dsn \= dsn

        self.autocommit \= autocommit

        self.conn \= None

    def \_\_enter\_\_(self):

        self.conn \= psycopg2.connect(self.dsn)

        self.conn.autocommit \= self.autocommit

        logger.info(f"Opened connection to {self.dsn.split('@')\[-1\]}")

        return self.conn    \# ← this becomes the as variable

    def \_\_exit\_\_(self, exc\_type, exc\_val, exc\_tb):

        if self.conn is not None:

            if exc\_type is not None:          \# exception occurred

                self.conn.rollback()           \# undo all changes

                logger.warning(f"Rolled back due to {exc\_type.\_\_name\_\_}")

            else:                              \# success

                self.conn.commit()             \# save all changes

            self.conn.close()                  \# always close

            logger.info("Connection closed")

        return False    \# never suppress exceptions

\# Usage

with DatabaseConnection("postgresql://user:pass@host:5432/warehouse") as conn:

    cursor \= conn.cursor()

    cursor.execute("INSERT INTO staging.orders SELECT \* FROM raw.orders")

    \# commits on success, rolls back on failure, closes either way

**Why `return False` is critical:**

return False  \# exception propagates → Airflow marks task FAILED → alert fires ✅

return True   \# exception swallowed → Airflow marks task SUCCESS → silent data loss ❌

              \# pipeline appears healthy while failing for weeks

**What rollback does:**

INSERT order 1 → staged in memory

INSERT order 2 → staged in memory

INSERT order 3 → CRASHES

Without rollback: orders 1 and 2 written, order 3 missing → partial data ❌

With rollback:    all three undone → database unchanged → rerun cleanly ✅

---

## 3\. Generator-Based Context Managers

Use when: simple setup/cleanup, fewer lines of code needed.

from contextlib import contextmanager

import tempfile

import shutil

import logging

logger \= logging.getLogger(\_\_name\_\_)

@contextmanager

def temp\_staging\_directory(prefix: str \= "pipeline\_"):

    """Create a temp directory that is automatically cleaned up."""

    \# ZONE 1 — SETUP (equivalent to \_\_enter\_\_)

    tmp\_dir \= tempfile.mkdtemp(prefix=prefix)

    logger.info(f"Created temp directory: {tmp\_dir}")

    try:

        yield tmp\_dir    \# ← handover point — tmp\_dir becomes the as variable

                         \# your with block runs here

    finally:

        \# ZONE 2 — CLEANUP (equivalent to \_\_exit\_\_)

        shutil.rmtree(tmp\_dir, ignore\_errors=True)

        logger.info(f"Cleaned up: {tmp\_dir}")

\# Usage

with temp\_staging\_directory(prefix="orders\_extract\_") as staging\_dir:

    output\_path \= os.path.join(staging\_dir, "orders.parquet")

    extract\_to\_parquet(source\_query, output\_path)

    upload\_to\_s3(output\_path, "s3://data-lake/staging/orders/")

\# directory deleted automatically even if upload\_to\_s3 fails

**How yield splits the function:**

Everything BEFORE yield \= \_\_enter\_\_ (setup)

yield value              \= return value bound to as variable

Everything AFTER yield   \= \_\_exit\_\_ (cleanup)

try/finally around yield guarantees cleanup even on exception

**Why local variables survive across yield:**

Generator function pauses at yield — not finished

Local variables (tmp\_dir) stay in memory until generator exhausts

That is why finally block can still access tmp\_dir after yield

---

## 4\. Four Production Patterns

### Pattern 1 — Pipeline Timer

@contextmanager

def pipeline\_timer(step\_name: str):

    """Time a pipeline step and log duration."""

    start \= time.perf\_counter()

    logger.info(f"\[{step\_name}\] Starting")

    try:

        yield

    except Exception:

        logger.error(f"\[{step\_name}\] Failed after {time.perf\_counter() \- start:.2f}s")

        raise

    else:

        elapsed \= time.perf\_counter() \- start

        logger.info(f"\[{step\_name}\] Completed in {elapsed:.2f}s")

\# Usage

with pipeline\_timer("extract\_orders"):

    orders\_df \= extract\_orders(target\_date)

Use this when you want to time a BLOCK of code, not an entire function. Different from `@timer` decorator which wraps the whole function.

---

### Pattern 2 — S3 File Handler

@contextmanager

def s3\_temp\_download(bucket: str, key: str, local\_dir: str \= "/tmp"):

    """Download S3 file to temp location, clean up when done."""

    s3 \= boto3.client("s3")

    local\_path \= os.path.join(local\_dir, os.path.basename(key))

    try:

        s3.download\_file(bucket, key, local\_path)

        yield local\_path

    finally:

        if os.path.exists(local\_path):

            os.remove(local\_path)

\# Usage

with s3\_temp\_download("data-lake", "raw/events/2024-01-15.parquet") as local\_file:

    df \= pd.read\_parquet(local\_file)

\# 5GB file deleted from disk automatically — no orphaned files

S3 files can not be read directly by pandas — must download first. Context manager handles download and cleanup so disk never fills with orphaned files.

---

### Pattern 3 — Database Transaction Scope

@contextmanager

def transaction(conn):

    """Atomic transaction — commits on success, rolls back on failure."""

    cursor \= conn.cursor()

    try:

        yield cursor

        conn.commit()

        logger.info("Transaction committed")

    except Exception:

        conn.rollback()

        logger.warning("Transaction rolled back")

        raise

    finally:

        cursor.close()

\# Usage — atomic write: either both succeed or neither does

with DatabaseConnection(DSN) as conn:

    with transaction(conn) as cursor:

        cursor.execute("DELETE FROM dim\_customers WHERE updated\_at \< %s", (cutoff,))

        cursor.execute("INSERT INTO dim\_customers SELECT \* FROM staging\_customers")

Both DELETE and INSERT must succeed together or both roll back — atomicity guaranteed.

---

### Pattern 4 — Spark Session Manager

@contextmanager

def spark\_session(app\_name: str, configs: dict \= None):

    """Create Spark session and stop it on exit."""

    from pyspark.sql import SparkSession

    builder \= SparkSession.builder.appName(app\_name)

    for key, value in (configs or {}).items():

        builder \= builder.config(key, value)

    spark \= builder.getOrCreate()

    try:

        yield spark

    finally:

        spark.stop()   \# always release cluster resources

\# Usage

with spark\_session("daily\_orders\_etl", {"spark.sql.shuffle.partitions": "200"}) as spark:

    df \= spark.read.parquet("s3://data-lake/raw/orders/")

    result \= transform(df)

    result.write.mode("overwrite").parquet("s3://data-lake/curated/orders/")

\# spark.stop() called automatically — cluster resources released

Spark sessions consume cluster resources. Without context manager, a crash leaves the cluster running indefinitely — costs money.

---

## 5\. Nesting Context Managers

\# Setup runs outside-in (top to bottom)

\# Cleanup runs inside-out (bottom to top)

with DatabaseConnection(DSN) as conn:      \# 1st setup, last cleanup

    with transaction(conn) as cursor:      \# 2nd setup, 2nd cleanup

        with pipeline\_timer("load"):       \# 3rd setup, 1st cleanup

            cursor.execute(query)

**Order:**

Setup:

1\. DatabaseConnection opens connection

2\. transaction creates cursor

3\. pipeline\_timer starts clock

Cleanup (reverse):

3\. pipeline\_timer logs duration

2\. transaction commits or rolls back

1\. DatabaseConnection closes connection

Think of it like Russian dolls — open outer first, close inner first.

**Why order matters:**

timer must stop BEFORE transaction commits

transaction must commit BEFORE connection closes

connection must close LAST

Reversed order causes errors

**Python 3.10+ — cleaner syntax for multiple managers:**

with (

    DatabaseConnection(DSN) as conn,

    pipeline\_timer("full\_pipeline"),

):

    with transaction(conn) as cursor:

        cursor.execute(query)

---

## 6\. Context Manager vs Decorator

| Aspect | Decorator | Context Manager |
| :---- | :---- | :---- |
| Wraps | Entire function | Block of code inside function |
| Applied | Once per function definition | Per resource per usage |
| Best for | Cross-cutting concerns | Resource lifecycle |
| Examples | logging, retry, timing | connections, files, sessions |
| Syntax | `@decorator` above function | `with ... as` inside function |

**Cross-cutting** \= behavior that applies across many functions regardless of what they do. Logging, retry, timing — not specific to one function's business logic.

**Use both together:**

@log\_execution          \# decorator — wraps entire function

@retry(max\_attempts=3)  \# decorator — wraps entire function

def run\_pipeline():

    with DatabaseConnection(DSN) as conn:   \# context manager — resource

        with transaction(conn) as cursor:   \# context manager — resource

            with pipeline\_timer("load"):    \# context manager — timing block

                cursor.execute(query)

---

## 7\. Production File Structure

Write once, apply everywhere:

pipeline/

├── utils/

│   ├── decorators.py        ← log\_execution, retry, timer written here

│   └── context\_managers.py  ← database\_connection, spark\_session, temp\_dir written here

├── extract.py               ← just import and apply

├── transform.py             ← just import and apply

└── load.py                  ← just import and apply

\# extract.py — clean, just business logic

from utils.decorators import log\_execution, retry

from utils.context\_managers import database\_connection

@log\_execution

@retry(max\_attempts=3, exceptions=(ConnectionError,))

def extract\_orders(date):

    with database\_connection(DSN) as conn:

        cursor \= conn.cursor()

        cursor.execute("SELECT \* FROM orders WHERE date \= %s", (date,))

        return cursor.fetchall()

Infrastructure code lives in utils. Business logic lives in pipeline files. No copy-paste. No boilerplate.

---

## 8\. Top Interview Questions and Answers

**Q: What is a context manager and why do you use it in pipelines?** A: A context manager guarantees setup and cleanup around a block of code — even when exceptions occur. In pipelines it makes resource leaking impossible. Database connections always close, Spark clusters always stop, temp files always get deleted. Without context managers a pipeline crash leaves connections open, clusters running, and disk filling with orphaned files. The `with` statement calls `__enter__` for setup and `__exit__` for cleanup — cleanup is guaranteed regardless of what happens inside the block.

**Q: What is the difference between class-based and generator-based context managers?** A: Class-based uses `__enter__` for setup and `__exit__` for cleanup — `__enter__` returns the resource bound to the `as` variable, `__exit__` receives exc\_type, exc\_val, exc\_tb for full exception handling control. Generator-based uses `@contextmanager` with a function — everything before `yield` is setup, the yielded value becomes the `as` variable, everything after `yield` in the `finally` block is cleanup. Generator-based is less verbose and preferred for simple cases like temp directories. Class-based is preferred when you need to inspect the exception type to decide behavior — like committing or rolling back a database transaction.

**Q: What does `return False` in `__exit__` do and why does it matter?** A: `return False` means do not suppress the exception — let it propagate up the call stack so the orchestrator knows the task failed. `return True` swallows the exception — the pipeline appears successful while actually failing. I have seen pipelines that returned True to avoid crashes — the result was weeks of silent data loss because Airflow marked every task as success. Always return False so failures are visible and alerts fire immediately.

**Q: What is the difference between a decorator and a context manager?** A: A decorator wraps an entire function and applies to every call — used for cross-cutting concerns like logging, retry, and timing that apply regardless of what the function does. A context manager wraps a block of code inside a function — used for resource lifecycle management like database connections, file handles, and Spark sessions. In practice both work together — decorators handle infrastructure at the function level, context managers handle resources at the block level.

**Q: You need to download a file from S3, process it, and upload results. How do you use a context manager?** A: I would use a generator-based context manager that creates a temp directory on entry, yields the path so the pipeline can download the S3 file and process it there, then deletes the entire directory in the finally block. The finally block guarantees cleanup even if processing or upload crashes — without it a 5GB file could be left on disk indefinitely, filling storage across pipeline runs.

**Q: What order do nested context managers run in?** A: Setup runs outside-in — the outermost manager sets up first, innermost last. Cleanup runs inside-out — innermost cleans up first, outermost last. Like Russian dolls — you open the outer layer first and close the inner layer first. This order matters because each inner resource depends on the outer one — the transaction cursor depends on the connection, so the connection must close last after the transaction commits.

**Q: What does `return True` in `__exit__` cause in a production pipeline?** A: It suppresses the exception — the with block acts like a bare `except: pass`. The pipeline continues as if nothing went wrong, Airflow marks the task as successful, no alert fires. In practice this causes silent data loss — records fail processing, dashboards show wrong numbers, and nobody knows until an analyst notices inconsistencies days or weeks later. Always return False so exceptions propagate and orchestrators can trigger alerts and retries.

---

*Push to: `notes/context_managers_for_data_engineers.md`*  
