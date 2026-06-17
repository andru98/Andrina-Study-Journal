# APIs for Data Engineers — Interview Notes
> Covers: HTTP basics, authentication, pagination, rate limiting, retries, Session, production patterns
> Last updated: 2026-06-15

---

## Table of Contents
1. [What is an API](#1-what-is-an-api)
2. [HTTP Methods and Status Codes](#2-http-methods-and-status-codes)
3. [The requests Library — Production Baseline](#3-the-requests-library--production-baseline)
4. [Authentication Patterns](#4-authentication-patterns)
5. [Pagination](#5-pagination)
6. [Rate Limiting and Exponential Backoff](#6-rate-limiting-and-exponential-backoff)
7. [requests.Session()](#7-requestssession)
8. [APIExtractor Class Pattern](#8-apiextractor-class-pattern)
9. [Webhook vs Regular API](#9-webhook-vs-regular-api)
10. [Top Interview Questions and Answers](#10-top-interview-questions-and-answers)

---

## 1. What is an API

An API (Application Programming Interface) is a way for two systems or applications to communicate even if they are built in different languages or run on different servers.

```
Your Python pipeline          Spotify servers
(speaks Python)    →→→ API →→→ (speaks anything)

You ask: "give me all songs by Taylor Swift"
Spotify returns: JSON with song data
```

**REST API** — the most common type. Uses HTTP (same protocol browsers use). 95% of APIs you call as a DE are REST APIs.

**Webhook** — reverse of regular API. Instead of you asking, they push data to you when something happens. See section 9.

---

## 2. HTTP Methods and Status Codes

### HTTP Methods

| Method | What it does | DE use case |
|---|---|---|
| GET | Fetch data | Pull records from API — 90% of DE work |
| POST | Send/create data | Send events to webhook |
| PUT | Update existing | Update a record |
| DELETE | Delete | Remove a record |

### Status Codes — memorize these

| Code | Meaning | What to do |
|---|---|---|
| 200 | Success | Process the data |
| 400 | Bad request | Your request is wrong — fix params |
| 401 | Unauthorized | Wrong or missing API key |
| 403 | Forbidden | Correct key but no permission |
| 404 | Not found | Wrong URL |
| 429 | Too many requests | Rate limited — slow down, retry |
| 500 | Server error | Their fault — retry later |
| 502/503/504 | Server unavailable | Retry with backoff |

**Memory trick:**
```
2xx → success
4xx → your fault (client error)
5xx → their fault (server error)
429 → slow down
```

**401 vs 403 — important distinction:**
```
401 → not authenticated — server doesn't know WHO you are
      Fix: provide correct API key

403 → not authorized — server knows WHO you are
      but you don't have permission for this resource
      Fix: request access or upgrade plan
```

---

## 3. The requests Library — Production Baseline

### Four things always in a production API call:

```python
import requests
import os

response = requests.get(
    "https://api.spotify.com/v1/tracks",           # 1. URL
    headers={"Authorization": "Bearer TOKEN"},      # 2. Auth header
    params={"limit": 100, "offset": 0},            # 3. Query params
    timeout=30                                      # 4. Timeout — NEVER skip
)

response.raise_for_status()  # raises HTTPError for 4xx/5xx
data = response.json()       # JSON string → Python dict
```

### Why timeout=30 is non-negotiable:

```
Without timeout:
requests.get(url) → waits FOREVER if API doesn't respond
→ Airflow task status = "still running" not "failed"
→ no alert sent
→ blocks all downstream tasks
→ nobody knows pipeline is dead

With timeout=30:
→ raises exception after 30 seconds
→ Airflow marks task failed
→ alert sent
→ retry logic kicks in
```

### What raise_for_status() does:

```python
response.raise_for_status()
# 200 → does nothing, continues
# 4xx → raises HTTPError immediately
# 5xx → raises HTTPError immediately
# Without it — silent failure, might parse error page as JSON
```

### What response.json() returns:

```python
data = response.json()
type(data)  # <class 'dict'> — Python dict, NOT JSON string

# Same as:
import json
data = json.loads(response.text)
```

---

## 4. Authentication Patterns

| Auth Type | Header Format | Used by |
|---|---|---|
| Bearer Token | `Authorization: Bearer TOKEN` | Spotify, Stripe, Slack, GitHub |
| API Key header | `X-API-Key: KEY` | AWS API Gateway, internal APIs |
| API Key query param | `?api_key=KEY` | Google Maps, older APIs |
| Basic Auth | `Authorization: Basic base64(user:pass)` | Jira, legacy systems |

### Why query param is less secure than header:

```
Query param → key appears in full URL:
https://api.example.com/data?api_key=SECRET123&limit=100

URL gets logged in:
- Server logs (Apache/Nginx)
- Proxy logs (company middleman records all traffic)
- Browser history
- Monitoring tools

Header → key hidden from URL:
https://api.example.com/data?limit=100
Authorization: Bearer SECRET123
→ not captured in URL logs → safer
```

### Never hardcode secrets:

```python
# ❌ NEVER — commits key to GitHub, bots scan 24/7
headers={"Authorization": "Bearer abc123secretkey"}

# ✅ ALWAYS — key from environment variable
import os
headers={"Authorization": f"Bearer {os.environ['SPOTIFY_API_KEY']}"}
```

---

## 5. Pagination

APIs limit responses to a fixed page size. You fetch page by page until done.

### Pattern 1 — Offset Pagination

```python
def fetch_all_offset(url, headers, page_size=100):
    all_records = []
    offset = 0

    while True:
        response = requests.get(
            url,
            headers=headers,
            params={"limit": page_size, "offset": offset},
            timeout=30
        )
        response.raise_for_status()
        data = response.json()

        records = data.get("results", [])  # safe — returns [] if key missing
        if not records:                     # empty page = done
            break

        all_records.extend(records)
        offset += page_size                 # move to next page

    return all_records
```

**The sliding window problem:**
```
You start fetching at offset=0
While fetching page 3 → someone inserts new record at top
→ every record shifts down by 1
→ you skip one record or get duplicate
→ data unreliable for live datasets
```

### Pattern 2 — Cursor Pagination (better)

```python
def fetch_all_cursor(url, headers, page_size=100):
    all_records = []
    cursor = None          # no cursor on first request

    while True:
        params = {"limit": page_size}
        if cursor:
            params["cursor"] = cursor

        response = requests.get(url, headers=headers,
                                params=params, timeout=30)
        response.raise_for_status()
        data = response.json()

        records = data.get("results", [])
        all_records.extend(records)

        cursor = data.get("next_cursor")   # API gives next cursor
        if not cursor or not records:       # no cursor = done
            break

    return all_records
```

**Why cursor beats offset:**
- Cursor points to specific record not position number
- New inserts don't shift positions
- Stable under concurrent writes
- Used by Stripe, Slack, GitHub

**Cursor is opaque** — treat it as a black box. Don't decode or modify it. Just pass it back to the API as-is.

### Pattern 3 — Link Header Pagination (GitHub style)

```python
url = "https://api.github.com/user/repos"

while url:
    response = requests.get(url, headers=headers, timeout=30)
    response.raise_for_status()
    process(response.json())

    link = response.headers.get("Link", "")
    url = None
    for part in link.split(","):
        if 'rel="next"' in part:
            url = part.split(";")[0].strip().strip("<>")
            break
```

Next page URL comes in response **header** not body. You just follow it.

### Pagination Comparison

| | Offset | Cursor | Link Header |
|---|---|---|---|
| Next page info | You calculate | Token in body | URL in header |
| Stable under writes | ❌ | ✅ | ✅ |
| Simple to implement | ✅ | Medium | Complex |
| Used by | Shopify, older APIs | Stripe, Slack | GitHub, GitLab |

---

## 6. Rate Limiting and Exponential Backoff

### What is rate limiting:

APIs limit requests per time window:
```
Spotify: 100 requests/minute
Stripe:  100 requests/second
GitHub:  5000 requests/hour
```

When exceeded → 429 Too Many Requests.

### Exponential backoff with jitter:

```python
import time
import random

for attempt in range(5):
    response = requests.get(url, headers=headers, timeout=30)

    if response.status_code == 429:
        # Check if API tells you how long to wait
        retry_after = response.headers.get("Retry-After")
        if retry_after:
            wait = float(retry_after)
        else:
            wait = 2 ** attempt              # 2, 4, 8, 16, 32 seconds
        
        wait = random.uniform(0, wait)       # add jitter
        time.sleep(wait)
        continue

    response.raise_for_status()
    break
```

**Exponential backoff:**
```
attempt 1 → wait 2s
attempt 2 → wait 4s
attempt 3 → wait 8s
attempt 4 → wait 16s
attempt 5 → wait 32s
```

**Why jitter (randomness) is critical:**

```
Without jitter — thundering herd:
50 workers all hit rate limit at 10:00:00 AM
All wait exactly 4 seconds
All retry at 10:00:04 AM → overwhelm API again
→ never recovers

With jitter:
Worker 1 → waits 0.3s
Worker 2 → waits 2.1s
Worker 3 → waits 3.7s
→ spread across 4 seconds → API recovers ✅
```

### Which errors to retry vs not:

```python
# Retry — temporary problems
retryable = {429, 500, 502, 503, 504}

# Never retry — permanent problems
# 400 → your request is wrong — fix it
# 401 → wrong API key — fix it
# 403 → no permission — fix it
# 404 → wrong URL — fix it
```

---

## 7. requests.Session()

```python
# Without Session — new TCP connection every request (slow)
requests.get(url1, headers={"Authorization": "Bearer TOKEN"})
requests.get(url2, headers={"Authorization": "Bearer TOKEN"})
# 4000 pages = 4000 TCP connections opened and closed

# With Session — one connection reused (2-5x faster)
session = requests.Session()
session.headers.update({"Authorization": "Bearer TOKEN"})
session.timeout = 30

session.get(url1)   # connect once
session.get(url2)   # reuse connection
session.get(url3)   # reuse connection
# 4000 pages = 1 TCP connection reused 4000 times
```

**Two benefits:**
1. Reuses TCP connection → 2-5x faster for paginated calls
2. Headers set once → no repetition every request

---

## 8. APIExtractor Class Pattern

Wraps auth, pagination, retries into one reusable class:

```python
class APIExtractor:
    def __init__(self, base_url, api_key, page_size=100):
        # Fixed config — set once, never changes
        self.base_url = base_url
        self.page_size = page_size
        self.session = requests.Session()
        self.session.headers.update({
            "Authorization": f"Bearer {api_key}",
            "Accept": "application/json"
        })

    def _request(self, endpoint, params):
        # Generic HTTP + retry logic
        url = f"{self.base_url}/{endpoint}"
        for attempt in range(5):
            response = self.session.get(url, params=params, timeout=30)
            if response.status_code == 429:
                time.sleep(2 ** attempt + random.uniform(0, 1))
                continue
            response.raise_for_status()
            return response
        raise RuntimeError(f"Failed after 5 retries: {url}")

    def extract_all(self, endpoint, filters=None):
        # Pagination + yielding records
        params = filters or {}        # fresh dict every call
        params["limit"] = self.page_size
        cursor = None

        while True:
            if cursor:
                params["cursor"] = cursor
            data = self._request(endpoint, params).json()
            records = data.get("results", [])
            for record in records:
                yield record          # generator — RAM stays flat
            cursor = data.get("next_cursor")
            if not cursor or not records:
                break

# Usage
extractor = APIExtractor("https://api.spotify.com/v1",
                          os.environ["SPOTIFY_KEY"])
for record in extractor.extract_all("tracks", filters={"genre": "pop"}):
    write_to_jsonl(record)
```

**Why `filters=None` not `filters={}`:**
```python
# DANGEROUS — mutable default shared across all calls
def extract_all(self, endpoint, filters={}):
    filters["limit"] = 100   # modifies the default permanently
    # next call → filters already has {"limit": 100} from last call

# SAFE — None converted to fresh dict every call
def extract_all(self, endpoint, filters=None):
    params = filters or {}   # fresh {} every time
```

Same trap as dataclass `errors: list = []` — mutable defaults get shared.

**Why endpoint in method not `__init__`:**
```
base_url → never changes → __init__
endpoint → changes per call → method parameter

extractor.extract_all("tracks")    # different endpoint
extractor.extract_all("playlists") # same extractor, different endpoint
```

---

## 9. Webhook vs Regular API

| | Regular API | Webhook |
|---|---|---|
| Who initiates | You (pull) | They (push) |
| When you get data | When you ask | When event happens |
| Efficiency | Polling — wasteful | Event-driven — efficient |
| Your role | Client making requests | Server receiving requests |
| DE use case | Bulk extraction | Real-time event processing |

```
Regular API: You ask "did anyone pay?" every minute
Webhook: Stripe tells YOU the moment payment happens
         POST https://your-pipeline.com/webhook
         {"event": "payment.completed", "amount": 9900}
```

---

## 10. Top Interview Questions and Answers

**Q: What are the four things always in a production API call?**
A: URL, headers with authentication (Bearer token or API key), params for query parameters like limit and offset, and timeout. Timeout is critical — without it the request waits forever, hanging Airflow tasks indefinitely without triggering alerts.

**Q: What is the difference between 401 and 403?**
A: 401 is authentication failure — the server doesn't know who you are, usually because the API key is missing or wrong. 403 is authorization failure — the server knows who you are but you don't have permission for that resource. Fix 401 by providing the correct key. Fix 403 by requesting access or upgrading your plan.

**Q: What is the difference between offset and cursor pagination?**
A: Offset pagination skips N records by position number — you increment offset by page size each request. The problem is the sliding window — if new records are inserted while paginating, positions shift and you skip or duplicate records. Cursor pagination uses a token the API provides pointing to your exact position. New inserts don't affect it because it points to a specific record not a position. I prefer cursor for live data, offset for static datasets.

**Q: What is exponential backoff and why do you add jitter?**
A: Exponential backoff handles 429 rate limit errors by waiting progressively longer between retries — 2 seconds, then 4, 8, 16, up to a maximum. The formula is `2 ** attempt`. Jitter adds randomness to the wait time using `random.uniform(0, wait)`. Without jitter, if 50 pipeline workers all hit the rate limit simultaneously, they all retry at the same time — the thundering herd problem — overwhelming the API again. Jitter spreads retries over time so the API can recover.

**Q: Why use requests.Session() instead of bare requests.get()?**
A: Two reasons. Session reuses the TCP connection across requests — opening a new connection for every page of a 4000-page paginated response is 2-5x slower than reusing one connection. Session also lets you set headers once in the constructor instead of passing them on every request, which keeps the code clean and consistent.

**Q: Why should you never put API keys in query parameters?**
A: Query parameters appear in the full URL, which gets logged everywhere — server logs, proxy logs, browser history, monitoring tools. Anyone with access to any of those logs can see your key. Headers are transmitted separately from the URL and aren't captured in URL logs. Always use Bearer token in headers, never API key in query params.

**Q: What is a webhook and how is it different from a regular API call?**
A: A regular API call is pull-based — you ask the API for data when you need it. A webhook is push-based — you register a URL with the service and they send data to you automatically when something happens. Webhooks are more efficient for real-time event processing because you don't need to poll repeatedly. Stripe uses webhooks for payment events, GitHub for code pushes, and so on.

**Q: Why use `filters=None` instead of `filters={}` as a default parameter?**
A: Mutable default arguments in Python are shared across all calls. If you use `filters={}` and modify it inside the function, those modifications persist to the next call — the default dict accumulates changes. Using `filters=None` and converting it to a fresh dict inside the function with `filters or {}` guarantees a clean slate every call. Same trap as using `errors: list = []` in a dataclass instead of `field(default_factory=list)`.

---

*Push to: `notes/apis_for_data_engineers.md`*
