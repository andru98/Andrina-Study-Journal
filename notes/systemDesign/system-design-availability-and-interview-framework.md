# System Design Notes: Availability, Reliability and the Interview Framework

Notes from my system design prep for data engineering roles. The first half covers availability and reliability. The second half covers the step-by-step structure I use in a system design interview, with a worked data engineering example.

Last updated: 29 October 2026

---

## Part 1: Availability and reliability

### Key terms

| Term | In one line |
|---|---|
| Availability | Percentage of time a system is up and serving requests |
| Reliability | Whether it keeps doing the right thing over time: correct, complete data and few repeated failures |
| Single point of failure (SPOF) | One component whose failure takes the whole system down |
| Redundancy | Extra copies, so one failure does not matter |
| RPO (recovery point objective) | How much data, measured in time, I can afford to lose |
| RTO (recovery time objective) | How long the system can be down before it is back |

Availability and reliability are not the same thing. A warehouse can be reachable (available) while a pipeline loads wrong or missing data (not reliable).

### The nines

| Availability | Downtime per year | Downtime per month |
|---|---|---|
| 99.9% (three nines) | about 8h 46m | about 44 min |
| 99.99% (four nines) | about 52 min | about 4 min |

### Components in sequence vs in parallel

This is the calculation interviewers like to test.

| Setup | Rule | Meaning |
|---|---|---|
| In sequence | Multiply availabilities: A x B | Every part must work, so the total is lower |
| In parallel | 1 - (1 - A)(1 - B) | One part is enough, so the total is higher |

Simple numbers (each part 90% available):

| Parts | In sequence | In parallel |
|---|---|---|
| 1 | 90% | 90% |
| 2 | 0.9 x 0.9 = 81% | 1 - 0.1 x 0.1 = 99% |
| 3 | 0.9^3 = 72.9% | 1 - 0.1^3 = 99.9% |

Realistic numbers (each part 99.9%):

| Parts | In sequence | Downtime per year |
|---|---|---|
| 1 | 99.9% | about 8.8 hours |
| 2 | 99.8% | about 17.5 hours |
| 3 | 99.7% | about 26 hours |
| 4 | 99.6% | about 35 hours |

Two copies in parallel, each at 99.9%, give 99.9999%, which is about 32 seconds of downtime a year.

Caveat: the parallel formula assumes the copies fail independently. If both sit in the same data centre or share a power supply, one event can take both down and the real number is lower.

**Data engineering example.** A pipeline of API, Kafka, Spark and a warehouse, each at 99.9%, in a row gives about 99.6%. That is around 35 hours of downtime a year, even though every part looks good on its own. Replicating Kafka lifts the total only to about 99.7%, because the other three parts are still single points of failure.

### Single points of failure

Test: pick a component and imagine it dies right now. If everything stops, it is a SPOF.

| Component | Why it is a SPOF | Fix |
|---|---|---|
| One Airflow scheduler | No DAGs run if it dies | Run more than one scheduler |
| One Kafka broker | Topics and consumers depend on it | Several brokers with replication (replication factor 3 is common) |
| Single-AZ database | A zone outage stops it | Multi-AZ deployment with fail-over |
| Single region | A regional outage stops everything | Multi-region replication, if the cost is justified |
| One expiring credential | Every job fails when it expires | Secret manager, rotation, alerts before expiry |
| One person who knows the pipeline | Knowledge is a SPOF too | Runbooks and shared ownership |

How to answer "where is your single point of failure?": name the component, say what breaks, then give the fix and its trade-off.

### Fail-over

Fail-over means automatically switching to a standby when the primary fails.

1. Detect: heartbeats stop.
2. Switch: the standby is promoted to primary.
3. Redirect: traffic goes to the new primary (DNS, load balancer or application logic).

| | Active-passive | Active-active |
|---|---|---|
| Normal operation | One server serves, the other waits | Both serve traffic |
| Downtime on failure | Short gap while switching | Almost none |
| Cost | A standby that sits idle | Both must be able to carry the full load |

A hot standby is already running and up to date, so it takes over fast. A cold standby has to be started first, so it takes longer.

Drawbacks: extra hardware and complexity, possible data loss if recent writes were not replicated, and the risk of split brain (two servers both believing they are primary).

Redundancy, replication and fail-over work together. Redundancy is the spare, replication keeps the spare's data current, and fail-over is the switch that moves traffic to it.

### Replication: why fail-over can lose data

With asynchronous replication, the primary confirms a write first and copies it to the replica afterwards. If the primary crashes in that window, the last few writes exist only on the dead machine.

| | Asynchronous | Synchronous |
|---|---|---|
| Write speed | Fast | Slower |
| Data loss when the primary crashes | Possible (last few writes) | None for confirmed writes |
| Risk | Replication lag | Writes can block if the replica is down |

Zero data loss (RPO of 0) needs synchronous replication. A page-view counter can tolerate an RPO of a few seconds, so asynchronous is fine there. A bank cannot.

### Reliability in data engineering work

| Concern | Practice |
|---|---|
| Jobs get re-run after failures | Make them idempotent (running twice gives the same result) |
| Transient errors | Retries with backoff |
| Long-running jobs | Checkpoints so a failure does not restart from zero |
| Missed or wrong data | Ability to backfill |
| Silent failures | Monitoring and alerts on freshness, row counts and failures |
| Data correctness | Validation and reconciliation against the source |

### Interview answers I want to be able to give

| Question | Short answer |
|---|---|
| What does 99.99% availability mean? | About 52 minutes of downtime a year |
| Why does a longer chain have lower availability? | Availabilities multiply, so the total is below the weakest part |
| How do you improve availability? | Remove single points of failure with redundancy, replication and fail-over |
| Sync vs async replication? | Safety versus speed. Async can lose recent writes on fail-over |
| RPO vs RTO? | Acceptable data loss versus acceptable downtime |

Source for the nines and the fail-over/replication patterns: [System Design Primer, availability patterns](https://ido777.github.io/system-design-primer-update/en/sd_availability_patterns.html) (a mirror of the donnemartin primer).

Still to study: CAP theorem and consistency patterns (weak, eventual, strong).

---

## Part 2: The system design interview framework

A structure for the 35 to 45 minutes of a system design interview.

| Step | Time | What I do |
|---|---|---|
| 1. Requirements | about 5 min | Agree on what the system must do and how well |
| 2. Core entities | about 2 min | List the main nouns in the system |
| 3. API / interface | about 5 min | Define how data and users get in and out |
| 4. Data flow (optional) | about 5 min | Write the path data takes, step by step |
| 5. High-level design | 10 to 15 min | Boxes and arrows that satisfy the requirements |
| 6. Deep dives | about 10 min | Scale it, handle failures and edge cases |

### Step notes

**Requirements.** Split into two kinds.
- Functional: "users should be able to...". Keep it to the top three.
- Non-functional: "the system should be...". Put numbers on them. "Fresh within 5 minutes" says more than "low latency". Things to consider: consistency vs availability, scale, latency, durability, security, fault tolerance, compliance.

**Capacity estimation.** Skip long up-front arithmetic. Calculate only when the answer changes the design, for example deciding how many Kafka partitions are needed.

**Core entities.** A short first draft is enough. Fields get added once the design reaches the database.

**API.** Default to REST unless there is a reason not to. Use plural nouns for resources (`/v1/tweets`, not `/v1/tweet`). Take the current user from the authentication token, never from the request body.

**High-level design.** Satisfy the API with the simplest design first. Note where a cache or queue might go, then move on. Adding complexity too early is a common reason candidates never finish.

**Deep dives.** Test the design against the non-functional requirements. At mid-level I should handle the interviewer's probes well. At senior level I would find the weak spots and lead the discussion.

Mistakes to avoid: too many requirements, early complexity, writing every column of every table, long arithmetic that does not change the design, and talking over the interviewer.

---

## Part 3: Worked example

Prompt: *Design a pipeline that loads daily sales data from stores into a warehouse for reporting.*

### Questions to ask first, and the assumptions I used

| Question | Assumed answer |
|---|---|
| How many stores and how much data? | About 1,000 stores, 2,000 sales each per day, so 2 million rows a day |
| How does data reach us? | Each store sends a file once a day |
| Who uses the output? | Analysts and managers, through dashboards and reports |
| How fresh? | Yesterday's data ready by 6 AM |
| History? | At least 3 years |

Size check: 2 million rows at about 200 bytes each is roughly 400 MB per day, or about 146 GB a year. That fits a standard warehouse.

### Step 1: Requirements

Functional:
1. Ingest each store's daily sales files.
2. Validate, clean and load the data into the warehouse.
3. Analysts can query sales by store, product and date, and a past day can be re-run.

Non-functional:
1. Fresh: yesterday's data is ready by 6 AM every day.
2. Correct: no lost or double-counted sales, and row counts reconcile with the source.
3. Reliable: failed runs retry automatically, re-running a day gives the same result, and someone is alerted if the load is late.

### Step 2: Core entities

| Entity | Role |
|---|---|
| Sale (transaction) | The fact: one sale with amount, time, store and product |
| Store | A dimension: describes where the sale happened |
| Product | A dimension: describes what was sold |
| DailySalesSummary (optional) | Totals per store per day for fast reports |

### Step 3: Interface

How data enters depends on the requirement:

| Option | Best when |
|---|---|
| Stores drop files into cloud storage | Daily batch is enough |
| Stores call an HTTP endpoint | Stores can send events as they happen |
| Pull from each store's database | We control the store systems |
| Events through Kafka | Near real-time, high volume |

Choice for this scenario: **files in cloud storage.** The requirement is "ready by 6 AM", not real time, so batch is enough. It is the simplest to operate, and keeping the raw files means any past day can be replayed. Analysts read through SQL on the warehouse plus a dashboard. I would not build an API because nobody asked for one.

If the requirement changed to "visible within one minute", I would switch to an HTTP endpoint or Kafka for ingestion, and the freshness and exactly-once questions would become the main deep dive.

### Likely deep dives for this design

| Topic | Question |
|---|---|
| Duplicates and retries | How do we avoid counting a sale twice? (idempotent loads) |
| Late or missing files | What if a store's file arrives late or not at all? |
| Failures | What if the load job or warehouse fails? Retries, alerts, no single point of failure |
| Schema changes | What if a store changes its file format? |
| Data quality | How do we detect wrong or missing data? Validation and reconciliation |
| Backfills | How do we re-run history? |
| Growth | What changes at 10x the volume? |
