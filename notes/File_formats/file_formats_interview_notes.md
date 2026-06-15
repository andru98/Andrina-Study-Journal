# File Formats for Data Engineers — Interview Notes

Covers: CSV, JSON, JSONL, Parquet, Avro — Python file I/O, production patterns, tradeoffs Last updated: 2026-06-09

---

## Table of Contents

1. [Why File I/O Matters in DE](#1-why-file-io-matters-in-de)  
2. [Python File I/O Fundamentals](#2-python-file-io-fundamentals)  
3. [Generators and yield](#3-generators-and-yield)  
4. [CSV](#4-csv)  
5. [JSON and JSONL](#5-json-and-jsonl)  
6. [Parquet](#6-parquet)  
7. [Avro](#7-avro)  
8. [Format Comparison — Quick Reference](#8-format-comparison--quick-reference)  
9. [Top Interview Questions and Answers](#9-top-interview-questions-and-answers)

---

## 1\. Why File I/O Matters in DE

Every data pipeline starts and ends with files. As a DE you will deal with:

- 5GB CSV dumps from vendors with broken encodings  
- JSONL event streams with 200M lines  
- Parquet files with 400 columns where you only need 3  
- Avro files with schemas that evolved multiple times

**RAM vs Disk — the foundation:**

|  | RAM | Hard Drive (SSD/HDD) |
| :---- | :---- | :---- |
| Speed | \~50 GB/s | SSD \~500 MB/s, HDD \~100 MB/s |
| Persistence | Temporary — wiped on program exit | Permanent |
| Cost | Expensive | Cheap |
| Use | Active processing | Storage |

**The pattern in every pipeline:**

Read from file (disk → RAM) → process in RAM (fast) → write back to file (RAM → disk)

Minimize file reads/writes. Do as much work as possible in memory.

---

## 2\. Python File I/O Fundamentals

### open() and the with statement

\# NEVER do this — file stays locked if error occurs

f \= open("data.csv", "r")

data \= f.read()

f.close()   \# never runs if error above crashes program

\# ALWAYS do this — file closes automatically even on error

with open("data.csv", "r", encoding="utf-8") as f:

    data \= f.read()

`with` guarantees `close()` is called no matter what. Always use `with open()` in production.

### File modes

| Mode | Meaning | Use case |
| :---- | :---- | :---- |
| `"r"` | Read text | Read existing file |
| `"w"` | Write text | Create new or overwrite |
| `"a"` | Append text | Add to end of file |
| `"rb"` | Read binary | Parquet, Avro, images |
| `"wb"` | Write binary | Parquet, Avro, images |

### Reading methods

| Method | Returns | Use when |
| :---- | :---- | :---- |
| `f.read()` | Entire file as string | Small files only |
| `f.readlines()` | List of all lines | Small files |
| `for line in f` | One line at a time | Large files — production default |

**Never use `f.read()` on large files** — loads entire file into RAM, crashes on 5GB+ files.

### Encoding — the vendor trap

Encoding is the lookup table that converts characters ↔ bytes.

Writing: character → bytes  (encoding)

Reading: bytes → character  (decoding)

| Encoding | Used by | Characters covered |
| :---- | :---- | :---- |
| UTF-8 | Universal standard | Every language, 1M+ characters |
| latin-1 | Western European systems | 256 characters, never crashes |
| cp1252 | Windows / Excel exports | Western European |

**15-20% of vendor CSV files claim UTF-8 but aren't.** Always have a fallback:

try:

    open(file\_path, "r", encoding="utf-8")

except UnicodeDecodeError:

    open(file\_path, "r", encoding="latin-1")

    \# latin-1 accepts ANY byte — never raises UnicodeDecodeError

---

## 3\. Generators and yield

### return vs yield

\# return — builds everything in memory first, hands it all over

def get\_records\_return():

    rows \= \[\]

    for i in range(1\_000\_000):

        rows.append({"id": i})

    return rows   \# 1M dicts in RAM before you get anything

\# yield — hands one item at a time, pauses until next() is called

def get\_records\_yield():

    for i in range(1\_000\_000):

        yield {"id": i}  \# one dict, then pause

                         \# RAM stays flat no matter how many rows

### How generators work internally

A function with `yield` returns a **generator object** — an iterator.

gen \= get\_records\_yield()  \# generator created — function hasn't run yet

next(gen)  \# function runs until first yield → returns {"id": 0} → pauses

next(gen)  \# resumes → returns {"id": 1} → pauses

next(gen)  \# resumes → returns {"id": 2} → pauses

\# StopIteration raised when exhausted

`for` loop is syntactic sugar — calls `next()` automatically until `StopIteration`:

\# These are identical:

for record in get\_records\_yield():

    process(record)

gen \= get\_records\_yield()

while True:

    try:

        record \= next(gen)

        process(record)

    except StopIteration:

        break

### Why generators matter in DE

5GB CSV file with return → 5GB in RAM → crashes

5GB CSV file with yield → 1 row in RAM at a time → RAM stays flat

200M JSONL file with return → program dies

200M JSONL file with yield → processes fine on a laptop

**Rule:** Any file reading function in production should use `yield`, not `return`.

---

## 4\. CSV

### The reality of CSV in production

CSV has no schema, no types, no compression, no standard encoding. It's still the most common format from external vendors, SFTP drops, and legacy systems.

### csv.reader vs csv.DictReader

import csv

\# csv.reader — returns list per row — fragile

with open("employees.csv", "r") as f:

    reader \= csv.reader(f)

    for row in reader:

        salary \= row\[2\]   \# what if vendor adds a column? silent bug

\# csv.DictReader — returns dict per row — production default

with open("employees.csv", "r") as f:

    reader \= csv.DictReader(f)

    for row in reader:

        salary \= row\["salary"\]  \# safe regardless of column position

**Always use DictReader in production.** If vendor adds a column, your code still works.

### Production CSV reader with encoding fallback

import csv

from typing import Iterator

def read\_csv\_safely(file\_path: str) \-\> Iterator\[dict\]:

    try:

        with open(file\_path, "r", encoding="utf-8", newline="") as f:

            reader \= csv.DictReader(f)

            for row in reader:

                yield row

    except UnicodeDecodeError:

        with open(file\_path, "r", encoding="latin-1", newline="") as f:

            reader \= csv.DictReader(f)

            for row in reader:

                yield row

\# Usage — streams one row at a time, RAM stays flat

for row in read\_csv\_safely("vendor\_dump.csv"):

    process(row)

**Why `newline=""`?** The csv module handles its own line endings. Without it, on Windows you can get double newlines.

### Important — all CSV values are strings

row\["salary"\]      \# → "95000" — string, not integer

row\["is\_active"\]   \# → "true" — string, not boolean

\# Always convert explicitly

salary \= int(row\["salary"\])

is\_active \= row\["is\_active"\].lower() \== "true"

CSV has no type information — everything is text.

---

## 5\. JSON and JSONL

### dict vs JSON — the key difference

\# Python dict — lives in RAM, Python only

trade \= {"symbol": "TSLA", "pnl": 150}

\# JSON — plain text, any language, saveable, sendable

'{"symbol": "TSLA", "pnl": 150}'

|  | Python dict | JSON |
| :---- | :---- | :---- |
| Lives in | RAM | File / network |
| Language | Python only | Any language |
| Survives program exit | ❌ | ✅ |
| Human readable | ✅ | ✅ |

### Four JSON functions — memorize these

| Function | Direction | Works with | Memory trick |
| :---- | :---- | :---- | :---- |
| `json.dumps()` | dict → string | string | dump to **s**tring |
| `json.loads()` | string → dict | string | load from **s**tring |
| `json.dump()` | dict → file | file object | dump to file |
| `json.load()` | file → dict | file object | load from file |

**s \= string, no s \= file**

import json

\# dict ↔ string

json\_str \= json.dumps({"symbol": "TSLA"})   \# → '{"symbol": "TSLA"}'

trade    \= json.loads('{"symbol": "TSLA"}')  \# → {"symbol": "TSLA"}

\# dict ↔ file

with open("trade.json", "w") as f:

    json.dump({"symbol": "TSLA"}, f)

with open("trade.json", "r") as f:

    trade \= json.load(f)

### The problem with large JSON files

\# 2GB JSON array — DO NOT do this

with open("events.json", "r") as f:

    data \= json.load(f)   \# loads entire 2GB into RAM → crashes

### JSONL — the production default

One JSON object per line. No outer array. Each line independently parseable.

{"user\_id": "u1", "action": "play", "song": "Blinding Lights"}

{"user\_id": "u2", "action": "skip", "song": "Levitating"}

{"user\_id": "u3", "action": "play", "song": "Stay"}

**Why JSONL beats JSON arrays for pipelines:**

|  | JSON array | JSONL |
| :---- | :---- | :---- |
| Streaming | ❌ must load all | ✅ line by line |
| Corrupt record | ❌ breaks entire file | ✅ skip and continue |
| Appending | ❌ rewrite entire file | ✅ just append a line |
| Parallelism | ❌ can't split easily | ✅ split by line count |
| Kafka / event streams | ❌ | ✅ native support |

### Production JSONL reader

import json

from typing import Iterator

def read\_jsonl(file\_path: str) \-\> Iterator\[dict\]:

    with open(file\_path, "r", encoding="utf-8") as f:

        for line\_number, line in enumerate(f, start=1):

            line \= line.strip()

            if not line:               \# skip blank lines

                continue

            try:

                yield json.loads(line) \# string → dict, yield one at a time

            except json.JSONDecodeError as e:

                print(f"Skipping bad line {line\_number}: {e}")

                \# pipeline continues — one bad line doesn't kill everything

### JSONL writer

def write\_jsonl(records: Iterator\[dict\], file\_path: str) \-\> int:

    count \= 0

    with open(file\_path, "w", encoding="utf-8") as f:

        for record in records:

            f.write(json.dumps(record, default=str) \+ "\\n")

            count \+= 1

    return count

`default=str` handles non-serializable types like datetime — converts them to string automatically instead of crashing.

### Streaming large JSON files — ijson

When you receive a large JSON array you can't control:

import ijson

def stream\_large\_json(file\_path: str):

    with open(file\_path, "rb") as f:   \# rb \= raw bytes, ijson handles decoding

        for item in ijson.items(f, "item"):

            yield item

**Why `"rb"` not `"r"`?** ijson reads raw bytes and handles its own decoding internally — faster for large files.

**`"item"` prefix** — tells ijson where records live in the structure:

\[                     ← root array

    {"user\_id": "u1"} ← each element \= "item"

\]

For nested structures:

ijson.items(f, "response.events.item")  \# dot notation path

### When to use what

| Situation | Use |
| :---- | :---- |
| File \< 500MB | `json.load()` |
| File \> 500MB | `ijson.items()` |
| You control the format | JSONL — always |
| Kafka / event streams | JSONL — always |
| API response | `json.loads()` — always small |

**Rule: When YOU control the format → always JSONL.**

---

## 6\. Parquet

### What is columnar storage

**CSV — row based:**

\[row1: id, name, dept, salary\]

\[row2: id, name, dept, salary\]

\[row3: id, name, dept, salary\]

To get all salaries → must read every row and discard unused columns.

**Parquet — column based:**

\[all ids\]\[all names\]\[all depts\]\[all salaries\]

To get all salaries → read ONLY the salary column. Other columns never touched.

### Why DE teams use Parquet over CSV

**1\. Column pruning — only read what you need:**

\# On a 400-column file, reads only 3 columns

\# Other 397 columns never loaded into RAM

table \= pq.read\_table("events.parquet", columns=\["user\_id", "event\_type", "ts"\])

\# Up to 100x faster than CSV for analytical queries

**2\. Compression — 5-10x smaller than CSV:** Same-type data in a column compresses extremely well:

department column: IT, HR, IT, IT, IT, HR, IT

→ compressed: IT(5), HR(2) — tiny

| Compression | Speed | Size | Use when |
| :---- | :---- | :---- | :---- |
| snappy | Fastest | Medium | Default — balanced |
| gzip | Slower | Smallest | Storage cost priority |
| zstd | Fast | Small | Best of both worlds |

**3\. Schema embedded — no type guessing:**

CSV → everything is a string → must convert manually

Parquet → int stays int, date stays date, schema stored in file

→ no silent schema drift from source

**4\. Predicate pushdown — filter before reading:**

Parquet divides data into **row groups** (default 128K rows). Each row group stores min/max metadata per column.

Row group 1: salary min=30000, max=95000

Row group 2: salary min=45000, max=110000

Row group 3: salary min=90000, max=185000  ← only group with salary \> 180000

Filter: salary \> 180000

→ row groups 1 and 2 skipped entirely — never read from disk

→ only row group 3 read

**Why row group size matters:**

- Too large (1M rows) → wide min/max range → can't skip much → slow filtering  
- Too small (100 rows) → too many metadata entries to check → overhead → slow  
- 128K rows → sweet spot — narrow range \+ manageable metadata

### Basic Parquet code — know this pattern

import pyarrow.parquet as pq

import pyarrow as pa

\# Read — specify only needed columns

table \= pq.read\_table("events.parquet", columns=\["user\_id", "event\_type"\])

\# Write — snappy compression is the default

pq.write\_table(table, "output.parquet", compression="snappy")

---

## 7\. Avro

### What is Avro

Avro is a binary serialization format designed specifically for:

- Schema evolution — handling schema changes over time  
- Kafka and streaming pipelines — where schema changes are inevitable  
- Compact binary storage with schema embedded

### Avro vs Parquet — different problems

|  | Parquet | Avro |
| :---- | :---- | :---- |
| Optimized for | Read performance (analytics) | Schema evolution (streaming) |
| Storage | Columnar | Row-based |
| Schema | Embedded but fixed | Embedded \+ versioned evolution |
| Best for | Data lakes, warehouses | Kafka, event streams |
| Schema changes | Breaks pipelines | Handled gracefully |

### Schema evolution — what Avro handles

| Change | Avro handles? | Notes |
| :---- | :---- | :---- |
| Add optional field with default | ✅ | Old records use default value |
| Remove optional field | ✅ | Readers ignore missing field |
| Rename field | ✅ | Via aliases |
| Change field type | ❌ | Breaking change |
| Add required field with no default | ❌ | Breaking change |

### Why Kafka uses Avro \+ Schema Registry

Producer sends events → schema can change over time

Consumer reads events → might read old AND new schema messages

Without Avro:

→ schema changes break consumers silently

With Avro \+ Schema Registry:

→ every message carries its schema version ID

→ consumer fetches correct schema for each message

→ handles old and new messages seamlessly

→ breaking changes caught before deployment

### Avro schema example

{

    "type": "record",

    "name": "TradeEvent",

    "fields": \[

        {"name": "symbol",    "type": "string"},

        {"name": "pnl",       "type": "double"},

        {"name": "timestamp", "type": "string"},

        {"name": "strategy",  "type": \["null", "string"\], "default": null}

    \]

}

`["null", "string"]` \= optional field — can be null or a string. Safe to add to existing schema without breaking old consumers.

---

## 8\. Format Comparison — Quick Reference

| Feature | CSV | JSON | JSONL | Parquet | Avro |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Storage | Row | Document | Row per line | Columnar | Row |
| Human readable | ✅ | ✅ | ✅ | ❌ binary | ❌ binary |
| Schema | ❌ none | ❌ none | ❌ none | ✅ embedded | ✅ versioned |
| Compression | ❌ | ❌ | ❌ | ✅ built-in | ✅ built-in |
| Streaming | ❌ | ❌ | ✅ | Batches | ✅ |
| Column pruning | ❌ | ❌ | ❌ | ✅ killer feature | ❌ |
| Schema evolution | ❌ | ❌ | ❌ | ❌ limited | ✅ designed for it |
| Type safety | ❌ all strings | ✅ basic | ✅ basic | ✅ strong | ✅ strong |
| Best for | Vendor dumps | API / config | Event streams | Data lakes | Kafka / streaming |
| Python library | csv | json / ijson | json | pyarrow | fastavro |

---

## 9\. Top Interview Questions and Answers

**Q: Why would you use Parquet instead of CSV in a data pipeline?** A: Three main reasons. First, Parquet is columnar — if I only need 3 columns from a 400-column file, Parquet reads only those 3 columns and never touches the rest, which can be 100x faster than CSV which reads every column. Second, Parquet has built-in compression — same-type data in a column compresses extremely well, giving 5-10x smaller files than CSV which reduces storage cost and network transfer time. Third, Parquet embeds the schema — data types are preserved so integers stay integers and dates stay dates, unlike CSV where everything is a string and you have to convert manually.

**Q: What is the difference between JSON and JSONL? Which would you use in a pipeline?** A: JSON is one connected structure — a single array or object. JSONL is one JSON object per line with no outer wrapper. For pipelines I always choose JSONL when I control the format. JSONL can be streamed line by line keeping RAM flat, a corrupt line only skips that record instead of failing the entire file, and new records can be appended without rewriting the entire file. JSON arrays require loading the whole file before processing anything. Kafka and most modern data tools natively support JSONL.

**Q: How do you handle a 5GB CSV file in Python without running out of memory?** A: Use a generator with csv.DictReader. Open the file and yield one row at a time instead of loading everything into a list. The file object itself is an iterator that reads one line at a time from disk, and yielding means only one row exists in RAM at any point. RAM usage stays flat regardless of file size. Never use f.read() or append to a list when processing large files.

**Q: What is a generator and why does it matter for file processing?** A: A generator is a function that uses yield instead of return. It returns a generator object which is iterable — Python calls next() on it each iteration, running the function until the next yield then pausing. The key benefit is lazy execution — data is produced one item at a time only when asked, so RAM usage stays constant regardless of how much data exists. For file processing this means you can handle files larger than your available RAM.

**Q: Why do you always use csv.DictReader instead of csv.reader?** A: DictReader returns each row as a dictionary with column names as keys, while csv.reader returns a list where you access values by index position. Index-based access is fragile — if a vendor adds or reorders a column, row\[2\] silently returns the wrong value with no error. With DictReader, row\["salary"\] always returns the salary column regardless of its position. Production code should never rely on column position.

**Q: What is encoding and why do vendor CSV files cause UnicodeDecodeError?** A: Encoding is the lookup table that maps characters to bytes and back. UTF-8 is the universal standard covering every language. But about 15-20% of vendor CSV files from Windows systems or European vendors use cp1252 or latin-1 encoding despite claiming UTF-8 in their documentation. When Python tries to decode those bytes as UTF-8 it encounters byte sequences that don't exist in UTF-8 and raises UnicodeDecodeError. The fix is a try/except that falls back to latin-1, which accepts any byte value and never crashes.

**Q: What is predicate pushdown in Parquet?** A: Parquet divides data into row groups and stores min/max metadata for every column in every row group. When you apply a filter, Parquet checks the metadata first — if a row group's min/max range makes it impossible to contain matching rows, the entire group is skipped without reading from disk. This filtering happens before data is loaded into memory, which is why it's called pushdown — the filter is pushed down to the storage layer. This makes Parquet dramatically faster for analytical queries with WHERE conditions.

**Q: What is the difference between Parquet and Avro?** A: They solve different problems. Parquet is optimized for read performance — it's columnar, supports column pruning, and has predicate pushdown, making it ideal for data lakes and analytical workloads. Avro is optimized for schema evolution — it's row-based and designed for streaming pipelines like Kafka where the schema changes over time. Avro handles adding optional fields, removing fields, and renaming fields without breaking existing consumers. Parquet doesn't handle schema changes gracefully. Use Parquet for your data lake and Avro for your Kafka topics.

**Q: When would you use ijson over json.load()?** A: When the file is large — over 500MB — and I don't control the format so I can't convert it to JSONL. json.load() reads the entire file into memory before returning anything, which crashes on large files. ijson streams through the file chunk by chunk, yielding one complete object at a time so RAM stays flat. If I control the format I'd always choose JSONL over both — it streams natively without any special library.

**Q: Why does ijson use "rb" mode instead of "r"?** A: "r" mode decodes bytes to a Python string before your code sees them. "rb" passes raw bytes directly to ijson. ijson handles its own decoding internally in C, which is faster for large files because it combines the decode and parse steps into one operation instead of two. It also auto-detects encoding from the file itself so you don't need to specify it.

---

*Push to: `notes/file_formats_interview_notes.md`*  
