# Decorators for Data Engineers — Interview Notes

Covers: What decorators are, functools.wraps, @log\_execution, @timer, @retry, stacking decorators Last updated: 2026-06-23

---

## Table of Contents

1. [What is a Decorator](#1-what-is-a-decorator)  
2. [functools.wraps — Never Skip This](#2-functoolswraps--never-skip-this)  
3. [The Three DE Decorators](#3-the-three-de-decorators)  
4. [Stacking Decorators](#4-stacking-decorators)  
5. [When NOT to Use Decorators](#5-when-not-to-use-decorators)  
6. [Top Interview Questions and Answers](#6-top-interview-questions-and-answers)

---

## 1\. What is a Decorator

A decorator is a function that takes a function and returns a new function — adding behavior before and after without touching the original function body.

def my\_decorator(func):

    def wrapper(\*args, \*\*kwargs):

        \# runs BEFORE original function

        result \= func(\*args, \*\*kwargs)   \# calls original

        \# runs AFTER original function

        return result

    return wrapper

@my\_decorator

def extract\_orders(date):

    return fetch\_from\_db(date)

\# @ syntax is identical to:

\# extract\_orders \= my\_decorator(extract\_orders)

**After decoration:**

extract\_orders (the name) → points to wrapper

func (inside decorator)   → points to original extract\_orders

When you call `extract_orders("2026-06-22")` you actually call `wrapper("2026-06-22")`, which calls the original `extract_orders` internally via `func`.

### Why `*args, **kwargs` in wrapper

Wrapper doesn't know what arguments the original function takes — it could be zero, one, or many. `*args` captures positional arguments, `**kwargs` captures keyword arguments, and both are passed through to the original function unchanged.

\# Without \*args, \*\*kwargs — wrapper breaks

def my\_decorator(func):

    def wrapper():              \# accepts nothing

        return func()

    return wrapper

@my\_decorator

def extract\_orders(date):       \# needs one argument

    ...

extract\_orders("2026-06-22")   \# ❌ TypeError

\# With \*args, \*\*kwargs — works for any function

def my\_decorator(func):

    def wrapper(\*args, \*\*kwargs):      \# accepts anything

        return func(\*args, \*\*kwargs)   \# passes everything through

    return wrapper

### The core purpose

Decorators separate infrastructure concerns from business logic:

\# Without decorators — 300-line functions, 200 lines are boilerplate

def extract\_orders(date):

    logger.info("Starting extract\_orders")

    try:

        result \= fetch\_from\_db(date)

        logger.info("Completed extract\_orders")

        return result

    except Exception as e:

        logger.error(f"Failed: {e}")

        raise

\# With decorators — function contains only business logic

@log\_execution

def extract\_orders(date):

    return fetch\_from\_db(date)

One decorator written once applies to every pipeline function with a single line. No copy-paste. No risk of forgetting a finally block.

---

## 2\. functools.wraps — Never Skip This

Without `@wraps(func)`, your decorated function loses its name and docstring:

\# Without @wraps

def my\_decorator(func):

    def wrapper(\*args, \*\*kwargs):

        return func(\*args, \*\*kwargs)

    return wrapper

@my\_decorator

def extract\_orders(date):

    """Extract orders for a given date."""

    pass

print(extract\_orders.\_\_name\_\_)  \# "wrapper" ❌ not "extract\_orders"

print(extract\_orders.\_\_doc\_\_)   \# None ❌ docstring lost

**Real production problems this causes:**

Airflow task naming → shows "wrapper" for every task

Error logs → every error looks like it came from same function

Sentry/Datadog → can't trace which pipeline step actually failed

Debugging → impossible

**Fix — always add `@wraps(func)`:**

from functools import wraps

def my\_decorator(func):

    @wraps(func)               \# copies \_\_name\_\_, \_\_doc\_\_ from func

    def wrapper(\*args, \*\*kwargs):

        return func(\*args, \*\*kwargs)

    return wrapper

print(extract\_orders.\_\_name\_\_)  \# "extract\_orders" ✅

print(extract\_orders.\_\_doc\_\_)   \# "Extract orders for a given date." ✅

**Rule: Every decorator you write must have `@wraps(func)` — no exceptions.**

---

## 3\. The Three DE Decorators

### @log\_execution — Know What Ran and What Failed

from functools import wraps

import logging

logger \= logging.getLogger(\_\_name\_\_)

def log\_execution(func):

    @wraps(func)

    def wrapper(\*args, \*\*kwargs):

        logger.info(f"Starting {func.\_\_name\_\_}")

        try:

            result \= func(\*args, \*\*kwargs)

            logger.info(f"Completed {func.\_\_name\_\_} | success=True")

            return result

        except Exception as e:

            logger.error(f"Failed {func.\_\_name\_\_} | error={type(e).\_\_name\_\_}: {e}")

            raise   \# re-raise — never swallow the exception

    return wrapper

@log\_execution

def extract\_orders(date: str):

    return fetch\_from\_db(date)

**Why `raise` at the end:** Logs the error but still lets it bubble up. Without `raise` — error swallowed silently, pipeline thinks everything succeeded.

**Why `func.__name__` not hardcoded string:** Dynamic — one decorator correctly logs the name of every function it wraps. Hardcoding would only work for one specific function.

**Output:**

INFO  Starting extract\_orders

INFO  Completed extract\_orders | success=True

\# On failure:

INFO  Starting extract\_orders

ERROR Failed extract\_orders | error=ConnectionError: timeout after 30s

---

### @timer — Know How Long Everything Takes

import time

from functools import wraps

def timer(func):

    @wraps(func)

    def wrapper(\*args, \*\*kwargs):

        start \= time.perf\_counter()    \# start clock

        try:

            result \= func(\*args, \*\*kwargs)

            return result

        finally:                        \# runs whether success OR failure

            elapsed \= time.perf\_counter() \- start

            logger.info(f"{func.\_\_name\_\_} took {elapsed:.2f}s")

    return wrapper

@timer

def transform\_events(df):

    return apply\_transformations(df)

**Why `finally` not `except`:**

try → function runs

    success → finally runs → logs timing ✅

    exception → finally runs → logs timing ✅

except → only runs on failure

    success → except skipped → timing never logged ❌

Knowing a function ran 45 minutes before crashing is critical debugging information. `finally` guarantees timing is always logged.

**Why `time.perf_counter()` not `time.time()`:**

time.time()         → wall clock, affected by system clock changes

time.perf\_counter() → high precision, unaffected by clock changes

                      always use for measuring elapsed time

**In production — push to metrics not just logs:**

\# Push to Datadog/CloudWatch for dashboards and alerts

metrics.gauge("pipeline.duration", elapsed, tags={"function": func.\_\_name\_\_})

---

### @retry — Survive Transient Failures

Retry requires decorator arguments → needs three levels of nesting:

import time

from functools import wraps

def retry(max\_attempts=3, delay=1.0, backoff=2.0,

          exceptions=(Exception,)):

    def decorator(func):           \# level 2 — takes function

        @wraps(func)

        def wrapper(\*args, \*\*kwargs):   \# level 3 — does work

            current\_delay \= delay

            for attempt in range(1, max\_attempts \+ 1):

                try:

                    return func(\*args, \*\*kwargs)   \# success → return immediately

                except exceptions as e:

                    if attempt \== max\_attempts:

                        logger.error(f"{func.\_\_name\_\_} failed after {max\_attempts} attempts: {e}")

                        raise                      \# last attempt → give up

                    logger.warning(

                        f"{func.\_\_name\_\_} attempt {attempt}/{max\_attempts} failed. "

                        f"Retrying in {current\_delay:.1f}s..."

                    )

                    time.sleep(current\_delay)

                    current\_delay \*= backoff       \# double the wait each time

        return wrapper

    return decorator               \# level 1 returns decorator

@retry(max\_attempts=3, delay=2.0, backoff=2.0,

       exceptions=(ConnectionError, TimeoutError))

def call\_spotify\_api(endpoint):

    response \= requests.get(endpoint, timeout=30)

    response.raise\_for\_status()

    return response.json()

**Why three levels — not two:**

@timer has no arguments → two levels:

  timer(func) → wrapper

@retry has arguments → three levels:

  retry(max\_attempts=3) → returns decorator

  decorator(func) → returns wrapper

  wrapper(\*args) → does actual work

**Exponential backoff — `current_delay *= backoff`:**

delay=2.0, backoff=2.0

attempt 1 fails → sleep 2s → current\_delay \= 2 × 2 \= 4

attempt 2 fails → sleep 4s → current\_delay \= 4 × 2 \= 8

attempt 3 fails → raise (no sleep)

**Critical — always specify exception types:**

\# BAD — retries permanent errors too

@retry(exceptions=(Exception,))

def transform(record):

    salary \= record\["salary"\]   \# KeyError — field missing

    \# Retries 3 times — KeyError never fixes itself → waste of time

\# GOOD — only retry transient errors

@retry(exceptions=(ConnectionError, TimeoutError))

def call\_api(endpoint):

    ...

\# ConnectionError → might fix → retry ✅

\# KeyError → permanent → bubbles up immediately ✅

---

## 4\. Stacking Decorators

Decorators stack bottom-up — closest to function runs first:

@log\_execution    \# outermost — runs last (wraps everything)

@timer            \# middle

@retry(max\_attempts=3, exceptions=(ConnectionError,))  \# innermost — runs first

def extract\_from\_api(endpoint: str):

    response \= requests.get(endpoint, timeout=30)

    response.raise\_for\_status()

    return response.json()

**Execution order:**

1\. log\_execution starts → logs "Starting extract\_from\_api"

2\. timer starts → clock starts

3\. retry handles failures → retries on ConnectionError

4\. actual function runs

5\. retry returns result up

6\. timer stops → logs duration

7\. log\_execution → logs "Completed extract\_from\_api"

**Three decorators is the practical maximum** — deeper stacks make tracebacks confusing and debugging harder.

---

## 5\. When NOT to Use Decorators

Behavior is unique to one function → just put logic inline

                                     decorator for single use \= over-engineering

Need access to internal state → decorators only see inputs and outputs

                                 use a different pattern

Deeply nested stacks → tracebacks become unreadable

                        three decorators maximum

---

## 6\. Top Interview Questions and Answers

**Q: What is a decorator and why do you use them in pipelines?** A: A decorator is a function that takes a function and returns a new function, adding behavior before and after without touching the original function body. In pipelines I use them to separate infrastructure concerns like logging, timing, and retry logic from business logic. Without decorators, every pipeline function gets 200 lines of boilerplate for try/except, logging, and timing — all copy-pasted. With decorators I write that infrastructure once and apply it with a single line. The function body stays clean and focused on what it actually does.

**Q: Why do you need functools.wraps in every decorator?** A: Without `@wraps(func)`, the decorated function loses its name and docstring — `__name__` returns "wrapper" for every function. This breaks Airflow task naming, makes every error in logs look like it came from the same function called "wrapper", and breaks monitoring tools like Sentry and Datadog that rely on function names for alerting. I've seen production incidents caused by missing functools.wraps where nobody could tell which pipeline step failed.

**Q: Why does @retry need three levels of nesting but @timer only needs two?** A: `@timer` takes no arguments so it directly takes the function — two levels. `@retry` takes configuration arguments like `max_attempts` and `delay`, so the outer function captures that configuration and returns a decorator, which then takes the function. Three levels: outer captures config, middle captures function, inner does the actual work.

**Q: Why use `finally` in the timer decorator instead of putting timing after the function call?** A: `finally` runs whether the function succeeds or raises an exception. If you put timing after the function call, it only logs on success — when the function crashes you lose the timing information entirely. Knowing a function ran for 45 minutes before crashing is critical debugging data. `finally` guarantees timing is always captured.

**Q: Why should you always specify exception types in @retry instead of catching bare Exception?** A: Different exceptions need different responses. ConnectionError and TimeoutError are transient — they might fix themselves on retry. ValueError and KeyError are permanent data issues — retrying won't help, it just wastes time and hides the real problem. Catching bare Exception retries permanent errors that can never recover. Always specify the exact exception types you expect and want to retry.

**Q: What is the execution order when you stack three decorators?** A: Decorators stack bottom-up — the decorator closest to the function applies first. So `@retry` wraps the function first, `@timer` wraps retry, and `@log_execution` wraps timer. When called, log\_execution triggers first, then timer starts, then retry handles failures, then the actual function runs. Results propagate back up the same chain.

---

*Push to: `notes/decorators_for_data_engineers.md`*  
