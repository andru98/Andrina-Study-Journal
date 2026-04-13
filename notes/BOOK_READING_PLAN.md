# Book Reading Plan — Integrated with 8-Month Study Schedule
### Anna Shrestha | May 1 — December 31, 2026

## The 3 Books
1. Fundamentals of Data Engineering (FDE) — Joe Reis — ~400 pages
2. Designing Data-Intensive Applications (DDIA) — Martin Kleppmann — ~550 pages
3. System Design Interview Vol 1 — Alex Xu — ~300 pages

## Reading Philosophy
Read the chapter SAME WEEK you study that topic.
Never read ahead — always read in sync with your hands-on work.
After every chapter write 3 bullet points of what you learned.
Push those notes to GitHub in your notes/ folder.

## Time allocation
30 minutes integrated into your morning review block (8:00-8:30)
Read while having coffee before deep study starts.
That is 3.5 hours per week = enough to finish all 3 books by December.

---

## MONTH 1 — May 2026
### Main study: SQL + Python + Git

**FDE — Read these chapters:**
- Chapter 1: Data Engineering Described (Week 1)
  Why DE exists, what DEs actually do day to day
  After reading: write down how your future job connects to this

- Chapter 2: The Data Engineering Lifecycle (Week 2)
  Generation → Storage → Ingestion → Transformation → Serving
  After reading: draw the lifecycle on paper from memory

- Chapter 3: Designing Good Data Architecture (Week 3)
  Principles of good architecture, trade-offs
  After reading: describe one trade-off in your own words

**DDIA — Read these chapters:**
- Chapter 1: Reliable, Scalable, and Maintainable Applications (Week 4)
  The three properties every data system needs
  After reading: explain reliability vs scalability to yourself out loud

**System Design — Read:**
- Chapter 1: Scale From Zero to Millions of Users (Week 4)
  How systems grow from 1 user to millions
  After reading: draw the scaling diagram from memory

**May reading total: 5 chapters across 3 books**

---

## MONTH 2 — June 2026
### Main study: Pandas + NumPy + Statistics + LeetCode

**FDE — Read these chapters:**
- Chapter 4: Choosing Technologies Across the Data Engineering Lifecycle (Week 1)
  How to pick the right tool — build vs buy, monolith vs modular
  After reading: explain why you would use Spark vs Pandas for large data

- Chapter 5: Data Generation in Source Systems (Week 2)
  Databases, APIs, message queues as data sources
  After reading: list 3 source systems you will use in your pipeline project

**DDIA — Read these chapters:**
- Chapter 2: Data Models and Query Languages (Week 2)
  Relational vs document vs graph models, SQL vs NoSQL
  After reading: explain when you would NOT use a relational database

- Chapter 3: Storage and Retrieval (Week 3)
  How databases store data on disk, indexes, LSM trees, B-trees
  After reading: explain why an index speeds up reads but slows writes

**System Design — Read:**
- Chapter 2: Back-of-the-Envelope Estimation (Week 3)
  How to estimate scale — QPS, storage, bandwidth
  After reading: estimate how much storage your trading journal needs at 10x scale

- Chapter 3: A Framework for System Design Interviews (Week 4)
  The 4-step framework for answering any design question
  After reading: practice the framework out loud on a fake question

**June reading total: 6 chapters**

---

## MONTH 3 — July 2026
### Main study: Pipeline design + Airflow + dbt + Data quality

**FDE — Read these chapters:**
- Chapter 8: Queries, Modeling, and Transformation (Week 1)
  SQL in the modern data stack, dbt, transformations
  After reading: directly apply concepts to your dbt project this week

- Chapter 9: Serving Data for Analytics, ML, and Reverse ETL (Week 2)
  How data flows from pipelines to end users
  After reading: sketch how your pipeline project serves data to analysts

**DDIA — Read these chapters:**
- Chapter 4: Encoding and Evolution (Week 2)
  JSON, Parquet, Avro, schema evolution, backward compatibility
  After reading: explain why Parquet is better than CSV for pipelines

- Chapter 5: Replication (Week 3)
  Leader-follower replication, consistency, lag
  After reading: explain how this relates to database reliability

- Chapter 7: Transactions (Week 4)
  ACID properties, isolation levels, dirty reads
  After reading: connect ACID to Delta Lake's ACID guarantees

**System Design — Read:**
- Chapter 4: Design a Rate Limiter (Week 3)
  Not directly DE but teaches system thinking under constraints
  After reading: identify one constraint in your Airflow pipeline

- Chapter 5: Design Consistent Hashing (Week 4)
  How data is distributed across nodes — Kafka and Spark use this
  After reading: explain how Kafka uses partitions to distribute load

**July reading total: 7 chapters**

---

## MONTH 4 — August 2026
### Main study: Apache Spark + Databricks + Delta Lake

**FDE — Read these chapters:**
- Chapter 6: Storage (Week 1)
  Data lakes, data warehouses, lakehouses, object storage
  After reading: explain difference between data lake and lakehouse

- Chapter 7: Ingestion (Week 2)
  Batch ingestion, streaming ingestion, push vs pull
  After reading: design the ingestion layer for your portfolio project

**DDIA — Read these chapters:**
- Chapter 6: Partitioning (Week 1)
  How data is split across nodes, partition strategies, skew
  After reading: directly apply to Spark partitioning concepts this week

- Chapter 10: Batch Processing (Week 2)
  MapReduce, dataflow engines — this IS Spark under the hood
  After reading: explain how Spark DAG relates to MapReduce

- Chapter 11: Stream Processing (Week 3)
  Event streams, stream-batch joins, exactly-once semantics
  After reading: connect to Spark Structured Streaming you build this week

**System Design — Read:**
- Chapter 6: Design a Key-Value Store (Week 3)
  Distributed storage fundamentals, replication, consistency
  After reading: explain how Delta Lake provides consistency guarantees

- Chapter 8: Design a URL Shortener (Week 4)
  Classic system design — teaches estimation and API design
  After reading: practice explaining this design out loud in 15 minutes

**August reading total: 7 chapters**

---

## MONTH 5 — September 2026
### Main study: AWS + GCP + Azure + AZ-900 certification

**FDE — Read these chapters:**
- Chapter 10: Security and Privacy (Week 1)
  Data security, encryption, access control, compliance
  After reading: list 3 security practices you will apply in Azure pipelines

**DDIA — Read these chapters:**
- Chapter 8: The Trouble with Distributed Systems (Week 2)
  Partial failures, network unreliability, clocks — why distributed is hard
  After reading: explain one failure mode in your AWS pipeline project

- Chapter 9: Consistency and Consensus (Week 3)
  CAP theorem, linearizability, distributed transactions
  After reading: explain CAP theorem in plain English — FAANG loves this question

**System Design — Read:**
- Chapter 9: Design a Web Crawler (Week 1)
  Teaches distributed work queues — relevant to data ingestion
  After reading: connect crawling architecture to your data ingestion design

- Chapter 10: Design a Notification System (Week 2)
  Event-driven architecture, message queues, fan-out
  After reading: explain how this connects to Kafka topics and consumers

- Chapter 11: Design a News Feed System (Week 3)
  High read volume, caching, ranking — Meta interview favorite
  After reading: practice explaining this design in 15 minutes out loud

- Chapter 12: Design a Chat System (Week 4)
  WebSockets, message storage, presence — real-time data patterns
  After reading: identify one pattern that applies to streaming pipelines

**September reading total: 7 chapters**

---

## MONTH 6 — October 2026
### Main study: Kafka + Streaming + Portfolio Project 1

**DDIA — Read these chapters:**
- Chapter 11 revisit: Stream Processing (Week 1)
  Read again now that you know Kafka — it will click much deeper
  After reading: implement one concept from the chapter in your Kafka project

**System Design — Read:**
- Chapter 13: Design a Search Autocomplete System (Week 2)
  Trie data structures, top-K problems — common in interviews
  After reading: note how ranking connects to your ML work

- Chapter 14: Design YouTube (Week 3)
  Video pipeline, large file storage, CDN — large scale data movement
  After reading: identify the data engineering components in YouTube's system

- Chapter 15: Design Google Drive (Week 4)
  File storage, sync, consistency — ties cloud storage to DE concepts
  After reading: explain how S3 or ADLS relates to this design

**FDE — Read these chapters:**
- Chapter 11: The Future of Data Engineering (Week 4)
  Where the field is heading, AI in data engineering, emerging patterns
  After reading: write a 1-paragraph personal reflection on your career direction

**October reading total: 5 chapters**

---

## MONTH 7 — November 2026
### Main study: Deep Learning + NLP + Interview prep

**DDIA — Read these chapters:**
- Chapter 12: The Future of Data Systems (Week 1)
  Dataflow, derived data, end-to-end correctness
  Final DDIA chapter — you finish the book this week

**System Design Vol 2 (if you buy it) or review:**
- Week 2-3: Re-read your 5 most important System Design chapters
  Focus on chapters most relevant to your portfolio projects
  Practice explaining each design out loud — timed at 15 minutes

**Review week (Week 4):**
- Re-read your GitHub notes from all book chapters
- Identify 5 concepts you still feel shaky on
- Ask Claude Code to quiz you on those 5 concepts

**November reading total: 1 new chapter + full review**

---

## MONTH 8 — December 2026
### Main study: FAANG applications + interviews

**No new reading — consolidation only:**

Week 1: Re-read FDE Chapters 1-3 (foundation refresh)
Week 2: Re-read DDIA Chapters 1, 5, 6, 10, 11 (most interview-relevant)
Week 3: Re-read all System Design chapters you felt weakest on
Week 4: Read your own GitHub notes — they are your best study material now

**December reading goal: full consolidation, no new material**

---

## Chapter Note Template
After every chapter push this to GitHub in notes/book-notes/:

```
# [Book Name] — Chapter [X]: [Title]
Date read: [date]
Month of study plan: [month]

## 3 Key Things I Learned
1.
2.
3.

## How This Connects to My Current Study Topic
[one paragraph]

## One Thing I Will Implement This Week
[specific action]

## One Question I Still Have
[question — ask Claude Code]
```

---

## Complete Reading Schedule Summary

| Month | FDE Chapters | DDIA Chapters | System Design Chapters | Total |
|---|---|---|---|---|
| May | 1,2,3 | 1 | 1 | 5 |
| June | 4,5 | 2,3 | 2,3 | 6 |
| July | 8,9 | 4,5,7 | 4,5 | 7 |
| August | 6,7 | 6,10,11 | 6,8 | 7 |
| September | 10 | 8,9 | 9,10,11,12 | 7 |
| October | 11 | 11 revisit | 13,14,15 | 5 |
| November | — | 12 | Review | 1+review |
| December | — | — | Review only | Consolidation |

FDE total chapters: 11 of 11 — complete
DDIA total chapters: 11 of 12 — complete
System Design: 12 chapters — complete

---

## The One Rule That Makes This Work

Read the chapter BEFORE you build that week's project — not after.

Reading DDIA Chapter 10 on Batch Processing before you build your
PySpark job means you understand WHY Spark works the way it does,
not just HOW to use it. That understanding is exactly what separates
candidates who pass FAANG system design from those who fail.

Interviewers do not want someone who memorized commands.
They want someone who understands the principles behind the tools.
These books give you the principles. Your hands-on projects give you
the practice. Together they make you dangerous in an interview.
