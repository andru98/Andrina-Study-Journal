# Error Handling for Data Engineers — Interview Notes
> Covers: Fail-fast vs Fail-graceful vs Fail-silent, try/except best practices, Error Budget, Dead-Letter Queue, Circuit Breaker, Structured Logging
> Last updated: 2026-06-19

---

## Table of Contents
1. [The Error Handling Spectrum](#1-the-error-handling-spectrum)
2. [try/except Best Practices](#2-tryexcept-best-practices)
3. [Transient vs Permanent Errors](#3-transient-vs-permanent-errors)
4. [Error Budget](#4-error-budget)
5. [Dead-Letter Queue](#5-dead-letter-queue)
6. [Circuit Breaker Pattern](#6-circuit-breaker-pattern)
7. [Structured Logging](#7-structured-logging)
8. [Top Interview Questions and Answers](#8-top-interview-questions-and-answers)

---

## 1. The Error Handling Spectrum

Every error handling decision falls on a spectrum:

```
Fail-Fast ←————————————→ Fail-Silent
              ↑
        Fail-Graceful
        (production default)
```

### Fail-Fast — stop immediately

```python
def validate_schema(record: dict, required_fields: list[str]) -> dict:
    missing = [f for f in required_fields if f not in record]
    if missing:
        raise ValueError(
            f"Schema violation: missing fields {missing}. "
            f"This likely means the upstream source changed its schema."
        )
    return record
```

**When to use:**
- Schema validation at ingestion boundary
- Authentication failures
- Configuration errors
- Data contract violations — upstream changed format

**Why:** These errors mean something is **fundamentally broken upstream**. Processing more records makes things worse — 10M records processed = 10M bad records in DLQ = dashboard blank. Fail immediately, alert fires, engineer fixes upstream.

---

### Fail-Graceful — log, quarantine, continue (production default)

```python
processed = []
failed = []

for record in records:
    try:
        result = transform_record(record)
        processed.append(result)
    except Exception as e:
        failed.append({
            "original_record": record,
            "error_type": type(e).__name__,
            "error_message": str(e),
            "timestamp": datetime.utcnow().isoformat()
        })

return processed, failed
```

**When to use:**
- Individual record corruption
- Optional field missing
- One bad record in a million good ones

**Why:** One bad record shouldn't kill the entire pipeline. Quarantine it, process the rest, fix and reprocess later.

---

### Fail-Silent — never use

```python
try:
    result = transform(record)
except:
    pass  # ← ticking time bomb
```

**Why never:**
- Data loss — records silently dropped, nobody knows
- Schema change hidden — all values NULL in output, dashboard wrong for days
- Connection failure hidden — pipeline reports success, zero records written
- Code bugs hidden — never surfaces, never gets fixed

**Only exception:** Non-critical telemetry where dropping a metric is truly acceptable. Extremely rare in DE.

---

### The key rule:

```
Fail-fast at the boundary (ingestion layer)
Fail-graceful inside the pipeline (individual records)
Never fail-silent
```

---

## 2. try/except Best Practices

### Rule 1 — Catch specific exceptions

```python
# BAD — catches everything including KeyboardInterrupt, SystemExit, code bugs
try:
    result = transform(record)
except Exception:
    pass

# GOOD — catch what you expect, different response per error type
try:
    result = transform(record)
except (ValueError, KeyError) as e:
    # data issue → quarantine and continue
    logger.warning(f"Data error for record {record.get('id')}: {e}")
    dead_letter_queue.append(record)
except TypeError as e:
    # code bug not data issue → fail fast
    raise RuntimeError(f"Code bug in transform: {e}") from e
```

**Why specific exceptions matter:**

| Exception | Cause | Response |
|---|---|---|
| ValueError | Bad data value | Quarantine, continue |
| KeyError | Missing field | Quarantine, continue |
| TypeError | Code bug | Fail fast, fix code |
| ConnectionError | Network issue | Retry with backoff |
| KeyboardInterrupt | User pressed Ctrl+C | Never swallow — must stop |
| SystemExit | Airflow killing task | Never swallow — must stop |

---

### Rule 2 — Include context in error messages

```python
# BAD — useless at 3 AM
except Exception as e:
    logger.error(f"Error: {e}")

# GOOD — tells you exactly what failed
except Exception as e:
    logger.error(
        f"Failed to process record | "
        f"record_id={record.get('id')} | "
        f"error_type={type(e).__name__} | "
        f"error_message={str(e)} | "
        f"batch_id={batch_id}"
    )
```

Good log tells you: which record, what error type, what failed, which batch. Fix in 2 minutes not 2 hours.

---

### Exception bubbling up the call stack

```python
def inner():
    raise ValueError("bad data")  # raised here

def middle():
    inner()                        # no except → passes through

def outer():
    try:
        middle()
    except ValueError as e:
        print(f"caught here: {e}") # caught here
```

Exception travels UP the call stack until something catches it. If nothing catches it — program crashes with traceback.

**`raise` inside `except` re-throws:**

```python
except ConnectionError as e:
    if attempt == max_retries - 1:
        raise    # caught AND immediately re-thrown → bubbles up to caller
    time.sleep(2 ** attempt)
```

---

## 3. Transient vs Permanent Errors

| | Transient | Permanent |
|---|---|---|
| Definition | Temporary, fixes itself | Won't fix itself, needs intervention |
| Examples | Network timeout, API rate limit, brief DB unavailability | Bad data value, missing required field, code bug, schema mismatch |
| Response | Retry with exponential backoff | Quarantine to DLQ, count against error budget |
| Retry? | ✅ yes — up to max_retries | ❌ no — retrying won't help |

### Retry pattern for transient errors

```python
def process_with_retry(record, max_retries=3):
    for attempt in range(max_retries):
        try:
            result = transform(record)
            return result
        except ConnectionError as e:
            if attempt == max_retries - 1:
                raise              # last attempt → bubble up to error budget
            time.sleep(2 ** attempt)  # exponential backoff: 1s, 2s, 4s
        except (ValueError, KeyError) as e:
            raise                  # permanent — don't retry, fail immediately
```

**Key:** `process_with_retry` raises after all retries exhausted. Caller catches it and increments error_count. Two separate responsibilities — retry logic and budget tracking never mix.

### Which errors to retry

```python
# Retry — temporary
retryable = {ConnectionError, TimeoutError}

# Never retry — permanent
non_retryable = {ValueError, KeyError, TypeError}
```

---

## 4. Error Budget

### The problem without error budget

```
Pipeline processes 10M records with broken transform
9.5M → DLQ
500K → target table
Pipeline reports "success"
Dashboard shows wrong data
Nobody notices for 3 days
```

### Error budget = circuit breaker for data quality

```python
error_count = 0
total_count = 0

for record in records:
    total_count += 1
    try:
        process_with_retry(record, max_retries=3)
    except Exception as e:
        error_count += 1
        logger.warning(f"Record failed: {e}")

        # Check after minimum sample
        if total_count >= 1000:
            error_rate = error_count / total_count
            if error_rate > 0.05:  # 5% threshold
                raise RuntimeError(
                    f"Error budget exceeded: {error_rate:.1%} failure rate "
                    f"({error_count}/{total_count}) — aborting pipeline"
                )
```

**Three key numbers:**
```python
max_error_rate = 0.05           # 5% — industry standard
min_records_before_check = 1000 # don't check too early
max_retries = 3                 # retry transient before counting
```

**Why minimum sample (1000 records):**
```
Without minimum: record 1 fails → rate = 100% → abort immediately (too sensitive)
With minimum: check only after 1000 records → meaningful sample
```

### Sliding window — catches scattered failures

Basic error budget misses evenly spread failures — early good records dilute the rate.

```python
from collections import deque

recent_results = deque(maxlen=1000)  # keeps only last 1000

for record in records:
    try:
        transform(record)
        recent_results.append(0)  # success
    except Exception as e:
        recent_results.append(1)  # failure
        dlq.send(record, e)

    if len(recent_results) == 1000:
        recent_rate = sum(recent_results) / 1000
        if recent_rate > 0.05:
            raise RuntimeError("Recent error rate exceeded — aborting")
```

**Use both together:**
```
Cumulative check → catches clustered failures fast (schema change)
Sliding window   → catches scattered failures gradually (data quality drift)
```

---

## 5. Dead-Letter Queue

### What is a DLQ

A DLQ is where failed records go instead of being lost. Quarantined for inspection, repair, and reprocessing later.

```
Pipeline runs → failures → DLQ
                    ↓
Engineer inspects next morning
                    ↓
Identifies root cause
                    ↓
Fixes transform logic
                    ↓
Reprocesses DLQ records
                    ↓
No data lost ✅
```

### DLQ entry structure

```python
dlq_entry = {
    "pipeline": self.pipeline_name,        # which pipeline
    "timestamp": datetime.utcnow().isoformat(),  # when it failed
    "error_type": type(error).__name__,    # what type of error
    "error_message": str(error),           # what the error said
    "original_record": record,             # the failed record
    "context": context or {}              # where in pipeline it failed
}
self._file.write(json.dumps(dlq_entry, default=str) + "\n")
```

### Why JSONL not JSON array

| | JSONL | JSON array |
|---|---|---|
| Stream one at a time | ✅ RAM stays flat | ❌ load entire file |
| Append new failures | ✅ just append a line | ❌ rewrite entire file |
| Corrupt entry | ✅ only that line fails | ❌ entire file unreadable |
| Reprocess | ✅ one record at a time | ❌ all or nothing |

### DLQ file naming convention

```
dlq/spotify_daily_20260619.jsonl          # local
s3://data-lake/dlq/spotify/dt=2026-06-19/ # cloud
```

Date in filename → easy to find and reprocess failures from specific run.

### Context manager guarantees cleanup

```python
with DeadLetterQueue("dlq/spotify.jsonl", "spotify") as dlq:
    for record in records:
        try:
            transform(record)
        except (ValueError, KeyError) as e:
            dlq.send(record, e, context={"step": "transform"})
# __exit__ always runs → file closed → buffer flushed to disk ✅
# Even if exception occurs mid-pipeline
```

**Without context manager:**
```
Exception mid-pipeline → close() never called → buffer never flushed
→ DLQ file empty on disk → failed records lost → defeats entire purpose
```

### DLQ must be independent of failing dependency

```
Database down → DLQ to S3 ← different system ✅
S3 down       → DLQ to local file ← fallback
Both down     → abort pipeline, alert fires
```

Never put DLQ on the same system that's failing.

---

## 6. Circuit Breaker Pattern

### What it solves

```
Without circuit breaker:
Database down → each request waits 30 second timeout
1000 workers × 30 seconds = 30,000 seconds wasted
Database gets hammered → harder to recover

With circuit breaker:
Database down → circuit opens after 5 failures
Next requests → fail immediately (no timeout)
→ database gets breathing room to recover
→ recovery happens faster
```

### Three states

| State | Behaviour | Transitions to |
|---|---|---|
| CLOSED | Normal operation, requests pass through | OPEN after failure_threshold failures |
| OPEN | Fail immediately, no requests sent | HALF_OPEN after recovery_timeout seconds |
| HALF_OPEN | Test one request | CLOSED if success, OPEN if fails |

```python
db_breaker = CircuitBreaker(failure_threshold=5, recovery_timeout=120)

for record in records:
    try:
        db_breaker.call(write_to_database, record)
    except RuntimeError as e:
        # Circuit OPEN — fail immediately, send to DLQ
        dlq.send(record, e, context={"step": "database_write"})
```

### When to abort vs DLQ during OPEN state

| Pipeline type | Partial data ok? | Action during OPEN |
|---|---|---|
| Daily revenue calculation | ❌ | Abort → full rerun after fix |
| Event tracking / logs | ✅ | DLQ → reprocess after recovery |
| ML feature pipeline | ❌ | Abort → full rerun |
| Clickstream analytics | ✅ | DLQ → reprocess |

**Key question:** "Does my pipeline produce correct results with partial data?"
- Yes → DLQ, keep going
- No → abort, fix dependency, full rerun

---

## 7. Structured Logging

### Junior vs Mid vs Senior logging

```python
# Junior — print statements
print("Pipeline started")
print(f"Error: {error}")

# Mid — basic logging
logger.info("Pipeline started")
logger.error(f"Record failed: {error}")

# Senior — structured JSON logging
log.error(
    "Record transform failed",
    record_id="usr_12345",
    error_type="ValueError",
    pipeline="spotify_daily",
    run_id="run_20260619_001",
    step="transform"
)
# Output: {"level": "ERROR", "pipeline": "spotify_daily",
#           "run_id": "run_20260619_001", "record_id": "usr_12345", ...}
```

### Why structured logging matters

```
Plain text → unqueryable at scale
JSON structured → filter by pipeline, run_id, error_type in CloudWatch/Datadog
              → set automated alerts: error_count > 100 in 5 mins → PagerDuty
              → trace exactly what failed, when, in which batch
```

### Key fields in every log entry

```python
{
    "level": "ERROR",
    "pipeline": "spotify_daily",      # which pipeline
    "run_id": "run_20260619_001",     # which specific run
    "batch_id": "batch_001",          # which batch
    "message": "Record failed",
    "record_id": "usr_12345",         # which record
    "error_type": "ValueError",       # what failed
    "error_message": "...",           # why it failed
    "timestamp": "2026-06-19T10:23:45"
}
```

---

## 8. Top Interview Questions and Answers

**Q: What are the three error handling modes and when do you use each?**
A: Fail-fast stops immediately on fundamental errors like schema violations or auth failures — processing more records would make things worse. Fail-graceful is the production default — log the error, quarantine the bad record to a DLQ, and continue processing the rest. One bad record shouldn't kill a million good ones. Fail-silent swallows errors entirely — never use this in pipelines because it hides data loss, schema changes, and connection failures silently.

**Q: What is an error budget and why does it matter?**
A: An error budget sets a maximum acceptable failure rate — typically 5%. After a minimum sample of 1000 records, if the failure rate exceeds the threshold the pipeline aborts immediately. Without it, a pipeline with a broken transform processes all 10M records, sends 9.5M to the DLQ, writes 500K to the target, and nobody notices until the dashboard goes blank 3 days later. An error budget catches this in the first minute. I use both cumulative rate for clustered failures like schema changes, and a sliding window on the most recent 1000 records for scattered data quality degradation.

**Q: What is a dead-letter queue?**
A: A DLQ is where failed records go instead of being discarded. Each entry contains the original record, error type, error message, pipeline name, timestamp, and context about which step failed. I use JSONL format so records can be streamed one at a time, new failures appended without rewriting the file, and a corrupt entry only affects that one line. The DLQ must be on a different system than the failing dependency — if the database is down, the DLQ goes to S3. After fixing the root cause, I reprocess the DLQ records through the fixed pipeline.

**Q: What is the difference between a transient and permanent error?**
A: Transient errors are temporary and can resolve themselves — network timeouts, API rate limits, brief database unavailability. I retry these with exponential backoff up to 3 times. Permanent errors won't fix themselves — bad data values, missing required fields, schema mismatches, code bugs. Retrying is pointless. I catch these specifically, quarantine to DLQ immediately, and count against the error budget. If the error budget is exceeded, I abort — it signals a systemic issue needing human intervention.

**Q: What is a circuit breaker and why use it?**
A: A circuit breaker prevents a pipeline from hammering a failing dependency with requests that all timeout. It has three states — closed for normal operation, open after a failure threshold is reached where requests fail immediately without waiting for timeout, and half-open after the recovery timeout where one test request goes through. If it succeeds the circuit closes. If it fails it opens again. This gives the dependency breathing room to recover instead of being overwhelmed. During the open state, records go to DLQ or the pipeline aborts depending on whether partial data is acceptable.

**Q: Why use structured JSON logging over plain text?**
A: Plain text logs are unqueryable at scale. Structured JSON logs with consistent fields like pipeline name, run_id, and batch_id let you filter all logs from a specific pipeline run in CloudWatch or Datadog, set up automated alerts when error counts exceed thresholds, and trace exactly what failed and when. In healthcare or financial pipelines where auditability matters, structured logging is a compliance requirement not just a best practice.

**Q: Why should you never use `except: pass`?**
A: It silently swallows everything — data loss where records are dropped without any trace, schema changes where KeyErrors are hidden and all values become NULL in the target, connection failures where the pipeline reports success while writing zero records, and code bugs that never surface and never get fixed. At minimum always log the error. Ideally catch specific exceptions and handle each appropriately.

---

*Push to: `notes/error_handling_for_data_engineers.md`*
