# DDIA — Designing Data-Intensive Applications
## Chapter 1: Reliable, Scalable, and Maintainable Applications
**Covered: May 2026 | Author: Anna's Study Notes**

---

## Section 1 — Figure 1-1: What a Modern Data System Looks Like

### The core idea
No single tool handles everything. Application code stitches multiple specialised tools together. A data engineer's job is to make sure data flows correctly between all of them.

### The components (Mario's Pizza example)

| Component | What it does | Real example |
|---|---|---|
| API | Front door — receives user requests | User searches "pizza near me" |
| Application code | Brain — decides what to do with each request | Checks cache, queries DB, triggers tasks |
| Cache (in-memory) | Fast notepad of recent answers | Redis — stores last 1000 searches |
| Primary database | Main source of truth | PostgreSQL — all restaurant data |
| Search index | Full-text search engine | Elasticsearch — "pizza near me" query |
| Message queue | Holds background tasks without blocking the user | Send email, notify driver |
| Worker (background app code) | Picks up tasks from the queue and executes them | Sends the actual confirmation email |
| Outside world | External systems that receive the final output | Gmail, SMS, driver app |

### Cache miss behaviour
1. User searches "pizza near me"
2. App checks cache — not there (cache miss)
3. App queries primary database
4. Result saved to cache for next time
5. Result returned to user

### Message queue flow
- Queue holds tasks — it does NOT execute them
- Worker application code picks up tasks one by one and does the work
- Analogy: queue = ticket dispenser at deli, worker = deli staff

### Why this matters for DE
You are responsible for: keeping cache in sync with the database, ensuring the message queue doesn't lose events, handling what happens when any one box fails.

**1-sentence takeaway:** No single tool handles everything — a DE's job is making sure data flows correctly between all of them.

---

## Section 2 — Describing Load: Load Parameters

### What is a load parameter?
A number that describes how much work your system is currently doing — so you can reason about what happens when load grows.

The right parameter depends on your system's bottleneck:

| System | Load parameter |
|---|---|
| Web server | Requests per second |
| Database | Read/write ratio |
| Cache | Hit rate |
| Chat app | Simultaneous active users |
| Twitter | Fan-out per tweet (followers per user) |

**Key rule:** Always think average AND peak. Never just average.

---

## Section 3 — The Twitter Fan-Out Problem

### The numbers
- **4,600 tweets/sec** (average) — people posting tweets
- **12,000 tweets/sec** (peak) — people posting tweets at peak
- **300,000 reads/sec** — people loading their home timeline
- **345,000 writes/sec** — fan-out cache writes (avg: 4,600 × 75 followers)
- **900,000 writes/sec** — fan-out cache writes (peak: 12,000 × 75 followers)

### What fan-out means
One tweet → written to every follower's personal mailbox.
4,600 tweets × 75 avg followers = 345,000 mailbox writes every second.
One celebrity tweet × 30,000,000 followers = 30 million writes instantly.

### Approach 1 — Do the work at READ time

**Write:** One tweet → one INSERT into global tweets table. Cheap. 4,600 writes/sec.

**Read:** Every person opening Twitter triggers a full JOIN:
```sql
SELECT tweets.*, users.*
FROM tweets
JOIN users ON tweets.sender_id = users.id
JOIN follows ON follows.followee_id = users.id
WHERE follows.follower_id = current_user
```
300,000 expensive JOINs per second. Does not scale.

| | Cost |
|---|---|
| Write | Cheap — 1 INSERT |
| Read | Very expensive — full JOIN every time |

### Approach 2 — Do the work at WRITE time

**Write:** One tweet → push to every follower's personal mailbox immediately.
4,600 × 75 = 345,000 simple cache writes/sec. Each write is trivially cheap.

**Read:** Just read your pre-filled mailbox. No JOIN. Instant.
300,000 cheap reads/sec. Easily handled.

| | Cost |
|---|---|
| Write | Slightly more — fan-out to mailboxes |
| Read | Trivially cheap — just read cache |

**Why 345k cheap writes beats 300k expensive reads:** Cost per operation matters more than count. One cache write = "drop tweet in mailbox." One JOIN = "find 500 people, fetch all their tweets, sort, merge." Cheap × more = still better than expensive × less.

### The Hybrid Model (real Twitter)

Celebrities (30M+ followers) cannot be fanned out — 30 million writes per tweet would spike the system.

```
Your timeline =
  Cache (pre-filled from everyone you follow who isn't a celebrity)
  + Live fetch (celebrity tweets fetched separately at read time)
  + Merge + sort by timestamp
  = Your feed
```

| User type | Approach used |
|---|---|
| Regular users | Approach 2 — pre-fan-out to caches |
| Celebrities | Approach 1 — fetch live at read time |

### DE real-world equivalent
**Kafka fan-out:** One upstream event (order placed) fans out to multiple downstream consumers — inventory, notifications, analytics, fraud. Monitor each consumer independently, not just the producer.

**Gold table = pre-built cache:** Every time Airflow materialises a Gold table nightly, you are doing Approach 2. Analysts read the pre-built table instantly instead of running expensive aggregations on demand.

**Average hides distribution:** Average followers = 75. Max = 30 million. Design for peak and p99, not average. Your pipeline handles 10,000 orders/day average but 800,000 on Diwali. Designing for average means crashing on the most important day.

---

## Section 4 — Describing Performance

### Throughput vs Response time

| | Throughput | Response time |
|---|---|---|
| Definition | Records processed per second / total time to run a job | Time between client sending request and receiving response |
| Cares about | Batch total | Individual request |
| System type | Batch — Hadoop, Spark, Airflow pipelines | Online — APIs, dashboards, web apps |
| Example question | "Did my pipeline process 10M rows in under 2 hours?" | "Did this user get their result in under 200ms?" |

### Latency vs Response time — not the same thing

**Response time** = what the client experiences = processing + network + queue wait

**Latency** = specifically the time a request spends WAITING before processing starts

```
Response time breakdown example:
  Request travels over network:     20ms
  Sits in server queue (latency):   80ms  ← latency
  Server processes (service time):  50ms  ← service time
  Response travels back:            20ms
  Total response time:             170ms
```

**DE equivalent:** Airflow task scheduled 2:00 AM, starts 2:08 AM (worker busy) = 8 min latency. Runs 12 min = service time. Total = 20 min wall-clock. Monitoring only "task duration" misses the 8-minute queue wait.

---

## Section 5 — Percentiles and Figure 1-4

### Why average is wrong

If 99 requests take 50ms and 1 takes 5,000ms:
- **Mean:** ~100ms — looks fine, hides the problem
- **Median (p50):** 50ms — accurate, most users are fast
- **p99:** 5,000ms — reveals 1 in 100 users waited 5 seconds

Average is pulled up by outliers. **Always report percentiles, never just averages.**

### Percentile definitions

| Percentile | Meaning |
|---|---|
| p50 (median) | Half of requests faster, half slower. Best "typical" metric. |
| p95 | 95 out of 100 requests faster than this threshold. 5 in 100 are slower. |
| p99 | 99 out of 100 faster. 1 in 100 slower — worst 1% of users. |
| p99.9 | 999 out of 1000 faster. 1 in 1000 slower. |

### Why Amazon optimises for p99.9
The slowest users are often the most valuable customers — they have the most purchase history, most saved addresses, most wishlist items. More data = slower queries. Making p99.9 fast is a revenue decision, not just a technical one.

Amazon observed: 100ms increase in response time reduces sales by 1%. 1-second slowdown reduces customer satisfaction by 16%.

### Tail latencies — definition
High percentiles of response time (p95, p99, p999) are called **tail latencies**. They directly affect user experience and are the metric that SLAs are defined against.

### DE real-world equivalent
Your pipeline runs 20 days in 45 min, 4 days (month-end) in 4 hours.
- Mean = 87 min — alarming and misleading
- Median = 45 min — accurate for most days
- p80 = 4 hours — tells you month-end needs special handling

**Report all three. Never just the mean.**

---

## Section 6 — Head-of-Line Blocking

### What it is
One slow request at the front of the queue blocks every fast request behind it, even though those fast requests would take milliseconds.

**Supermarket analogy:** One person with 200 items and a coupon dispute at the front. 10 people with 3 items each are waiting 10 minutes for a 30-second checkout.

### Why client-side measurement matters
- **Server sees:** "I processed A in 500ms, B in 10ms, C in 8ms" — looks fine
- **Client sees:** "I waited 510ms for B" — because B queued while A ran

Always measure response time on the **client side**, not server side. Server-side metrics miss queue wait entirely.

### The load testing trap
If your load generator waits for each response before sending the next request, it artificially keeps queues short — testing a much lighter load than production. Always send requests independently of response time in load tests.

### DE real-world equivalent
Airflow has 4 worker slots. 3 long-running tasks occupy them. Your lightweight monitoring task queues and waits 2 hours — even though it would complete in 30 seconds. Alert fires 2 hours late.

**Solution:** Dedicated worker pools for critical/lightweight tasks. Never let short tasks compete for the same workers as heavy ones.

---

## Section 7 — Figure 1-5: Tail Latency Amplification

### What it is
When calling multiple services in parallel, your overall p99 is worse than any individual service's p99. One slow backend makes the entire user request slow.

### Figure 1-5 numbers
7 backend services called in parallel: 92, 76, 103, 143, 86, **487**, 133ms.
User waits for: **487ms** — the slowest one.
Without Backend 6: user would wait 143ms.
One slow backend = 3.4× worse experience.

### The math
```
Each backend slow 1% of the time (p99 = slow)
Probability ALL 7 are fast = 0.99^7 = 93.2%
Probability at least ONE is slow = 6.8%

→ Individual services are 99% fast
→ User-facing request is slow 6.8% of the time — nearly 7× worse
```

With 20 backend calls: 1-(0.99^20) = 18% chance of a slow user request.

### DE real-world equivalent
Your pipeline calls 5 APIs in parallel to enrich order data. Each takes ~100ms normally. Fraud API occasionally takes 8 seconds. Entire enrichment step is now 8 seconds for those orders.

**Solution:** Set aggressive per-API timeouts. Use default/fallback value if one API is slow. Never let one slow dependency block all others.

---

## Section 8 — SLO and SLA

### Definitions

| Term | Meaning | Consequences |
|---|---|---|
| SLO (Service Level Objective) | Internal performance target your team sets for itself | No penalty — just a target you hold yourself to |
| SLA (Service Level Agreement) | Legal contract with a customer defining expected performance | Real financial consequences if missed |

### How they relate — the buffer principle
```
SLA (external promise): Gold table ready by 7 AM
SLO (internal target):  Pipeline completes by 5 AM
Buffer:                 2 hours to absorb failures and retries
```

**SLO is your warning system. SLA is the cliff.**

### What an SLA looks like in practice
"Service is up if: median response time < 200ms AND p99 < 1s. Must be up 99.9% of the time. If not met, customers may request a refund."

Note: Uptime alone is not a good SLA metric. A server responding in 5 seconds is technically "up" but violates the SLA.

### Data product SLA — what senior DEs own
A table is a **data product** (not just a file) when it has:
1. **An owner** — someone responsible when it breaks
2. **Schema under change control** — process when columns change so downstream doesn't silently break
3. **Monitoring that meets its SLA** — row count check, freshness check, business sanity check running automatically

---

## Key Terms Glossary

| Term | Definition |
|---|---|
| Load parameter | A number describing how much work your system is doing |
| Fan-out | One event triggering many downstream writes (1 tweet → N mailbox writes) |
| Cache | Pre-stored results for fast retrieval — avoids recomputation |
| Cache miss | Requested data not in cache — must fetch from primary database |
| Throughput | Records processed per second / batch job total time |
| Response time | Total time from client sending request to receiving response |
| Latency | Specifically the queue wait time before processing starts |
| p50/median | Half of requests faster, half slower |
| p95/p99/p999 | Tail latency percentiles — used in SLAs |
| Tail latency | High-percentile response times (p95+) |
| Tail latency amplification | Parallel calls make p99 worse — one slow service ruins the whole request |
| Head-of-line blocking | One slow request at front of queue blocks all fast requests behind it |
| SLO | Internal performance target |
| SLA | External contractual performance promise with financial consequences |
| Data product | A table with an owner, schema change control, and active monitoring |
| Approach 1 | Compute timeline at read time — cheap writes, expensive reads |
| Approach 2 | Fan-out at write time — more writes but all operations cheap |
| Hybrid model | Approach 2 for regular users, Approach 1 for celebrities |

---

## Interview Quick-Fire Answers

**Q: What is a load parameter?**
A number describing current system load so you can reason about growth. Right parameter depends on your bottleneck — for Twitter it was fan-out, not tweet volume.

**Q: What is fan-out and why does it matter?**
One event triggers many downstream writes. 4,600 tweets × 75 followers = 345,000 writes. One celebrity tweet × 30M followers = 30 million writes instantly. Fan-out is where your load actually multiplies.

**Q: Why percentiles over averages?**
Averages hide outliers. 99 requests at 50ms + 1 at 5s = mean of ~100ms — looks healthy. p99 = 5s — reveals the real problem. SLAs are always defined in percentiles.

**Q: Latency vs response time?**
Response time = total end-to-end (processing + network + queue wait). Latency = specifically the queue wait before processing starts.

**Q: What is tail latency amplification?**
Calling N services in parallel makes p99 worse than any individual service. Each slow 1% of the time → with 7 services, 6.8% chance at least one is slow → user feels slow 7× more often than any single service.

**Q: SLO vs SLA?**
SLO = internal target (5 AM pipeline completion). SLA = external contract (7 AM promise to business). SLO is always tighter — it's your buffer before the cliff.

**Q: What is a data product?**
A table with an owner, schema under change control, and monitoring that guarantees it meets its SLA. Not just a file that exists — something the business can actually rely on.
