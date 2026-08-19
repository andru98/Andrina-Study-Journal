# 📘 Apache Spark — Interview & Revision Notes

![Apache Spark]() ![PySpark]() ![Big Data]() ![Status]()

A condensed, diagram-first walkthrough of how Apache Spark actually works under the hood — written while studying for Data Engineering interviews. Every diagram here is an original, simplified sketch meant for fast visual recall, not a reproduction of any textbook or vendor diagram.

**Why this repo exists:** most Spark tutorials explain *what* the API does, not *why* the engine behaves the way it does. These notes focus on the internals that actually come up in interviews — architecture, shuffles, joins, memory management, and skew handling.

---

## 📑 Table of Contents

1. [Why Distributed Systems?](#1-why-distributed-systems)  
2. [Spark vs. MapReduce](#2-spark-vs-mapreduce)  
3. [Spark Architecture](#3-spark-architecture)  
4. [SparkSession vs. SparkContext](#4-sparksession-vs-sparkcontext)  
5. [RDDs & Partitions](#5-rdds--partitions)  
6. [Narrow vs. Wide Transformations](#6-narrow-vs-wide-transformations)  
7. [Repartition vs. Coalesce](#7-repartition-vs-coalesce)  
8. [Jobs, Stages, Tasks & the DAG](#8-jobs-stages-tasks--the-dag)  
9. [Joins in Spark](#9-joins-in-spark)  
10. [Spark Memory Management](#10-spark-memory-management)  
11. [Data Skew & Salting](#11-data-skew--salting)  
12. [Cache vs. Persist](#12-cache-vs-persist)  
13. [Deployment Modes: Client vs. Cluster](#13-deployment-modes-client-vs-cluster)  
14. [Partitioning, Output Files & Pruning](#14-partitioning-output-files--pruning)  
15. [Adaptive Query Execution (AQE)](#15-adaptive-query-execution-aqe)  
16. [Interview Quick-Hit Q\&A](#16-interview-quick-hit-qa)

---

## ⚡ Cheat Sheet (60-Second Refresh)

| Topic | One-liner |
| :---- | :---- |
| Scaling | Vertical \= bigger machine (limited ceiling). Horizontal \= more machines (near-limitless, needs distribution). |
| Spark vs MapReduce | Spark does in-memory computation → up to \~100x faster; unifies batch \+ streaming under one API. |
| Entry point | `SparkSession` → wraps `SparkContext` → talks to the Cluster Manager. |
| RDD | Immutable, logically partitioned, fault-tolerant collection tracked via lineage (DAG). |
| Narrow transformation | 1 input partition → 1 output partition. No shuffle (`map`, `filter`). |
| Wide transformation | Input partitions → multiple output partitions. Needs a shuffle (`groupBy`, `join`, `distinct`). |
| Repartition | Full shuffle, can increase or decrease partitions. |
| Coalesce | No full shuffle, only decreases partitions by merging. |
| Job → Stage → Task | Action triggers a Job → shuffle boundaries split it into Stages → each Stage runs 1 Task per partition. |
| Broadcast join | Small table copied to every executor — no shuffle. Fast, but driver/executors need enough memory. |
| Sort Merge Join | Default for large-large joins; sorts both sides on the join key, then merges. |
| Shuffle Hash Join | Builds a hash table on the smaller side per partition; needs it to fit in memory. |
| Memory split | Executor memory → \~300MB reserved, then 60% Spark memory pool / 40% user memory (defaults). |
| Executor overhead | `max(384MB, 10% of executor memory)` reserved off-heap. |
| Skew fix | Salting — add a random suffix to hot keys to spread them across partitions. |
| Cache vs Persist | `cache()` \= `persist(MEMORY_AND_DISK)` shortcut; `persist()` lets you choose the storage level. |
| Client mode | Driver runs on your local/client machine — good for dev, risky for prod (dies if client disconnects). |
| Cluster mode | Driver runs inside the cluster — standard for production. |
| AQE | Re-optimizes the query plan at runtime: coalesces partitions, switches join strategy, fixes skew. |

---

## 1\. Why Distributed Systems?

**Monolithic (single machine):**

- Scale *up* by adding RAM/CPU cores to one machine — **vertical scaling**.  
- Hard ceiling: there's only so much RAM/CPU you can cram into one box.  
- Single point of failure — if that one machine goes down, everything goes down (poor availability).

**Distributed (multiple machines):**

- Scale *out* by adding more machines/nodes to the network — **horizontal scaling**.  
- Practically no ceiling — keep adding nodes.  
- High availability — losing one node doesn't take down the whole system.

flowchart LR

    subgraph Mono\["Monolithic — Vertical Scaling"\]

        M\["One Machine\<br/\>+RAM \+CPU Cores\<br/\>⚠️ hard ceiling"\]

    end

    subgraph Dist\["Distributed — Horizontal Scaling"\]

        N1\["Node 1"\] \--- N2\["Node 2"\]

        N2 \--- N3\["Node 3"\]

        N3 \--- N4\["Node 4"\]

    end

Spark is built for the distributed world: it splits data and computation across a cluster of nodes instead of relying on one powerful machine.

---

## 2\. Spark vs. MapReduce

- **Speed:** Spark can be up to \~100x faster than MapReduce because it avoids writing intermediate results to disk between steps — computation stays **in-memory** as much as possible. MapReduce writes to disk after every Map/Reduce phase.  
- **Unified API:** Spark handles **batch and streaming with the same API** (Structured Streaming vs. batch DataFrames share the same engine), whereas MapReduce is batch-only.  
- **Richer engine:** Spark also gives you SQL, ML (MLlib), and graph processing (GraphX) on top of the same core.

---

## 3\. Spark Architecture

Spark follows a **master–slave (driver–executor)** architecture:

- **Driver** — runs your `main()`, creates the `SparkSession`, builds the DAG, and schedules work.  
- **Cluster Manager** — negotiates resources for the application (Standalone, YARN, Kubernetes, Mesos).  
- **Executors (Workers)** — run on worker nodes, execute tasks, and cache data.  
- Driver \+ Executors together form the **cluster of nodes** actually doing the work; the Cluster Manager tracks and updates the state of that cluster as things change (nodes join/leave, resources free up, etc.).

flowchart TB

    Driver\["🧠 Driver Program\<br/\>(SparkContext / SparkSession,\<br/\>builds DAG, schedules tasks)"\]

    CM\["⚙️ Cluster Manager\<br/\>(Standalone / YARN / Kubernetes)"\]

    E1\["Executor 1\<br/\>Tasks \+ Cache"\]

    E2\["Executor 2\<br/\>Tasks \+ Cache"\]

    E3\["Executor 3\<br/\>Tasks \+ Cache"\]

    Driver \<--\>|"negotiates resources"| CM

    CM \--\>|"launches"| E1

    CM \--\>|"launches"| E2

    CM \--\>|"launches"| E3

    Driver \--\>|"sends tasks"| E1

    Driver \--\>|"sends tasks"| E2

    Driver \--\>|"sends tasks"| E3

---

## 4\. SparkSession vs. SparkContext

- **`SparkSession`** is the starting point of any Spark application — it's what you create first.  
- Internally, the `SparkSession` connects the **Driver** to the **Cluster Manager** and coordinates the whole application via the **`SparkContext`**, which is the actual entry point/connection between the driver and the cluster's resources.  
- Whichever process runs your application's `main()` — a PySpark script or a compiled JVM (Java/Scala) `main` — becomes the **Driver** process.  
- **In Databricks**, you don't need to create a `SparkSession` yourself — the notebook environment creates and injects one (`spark`) for you automatically.

flowchart LR

    App\["Your app's main()"\] \--\> SS\["SparkSession\<br/\>(entry point you create)"\]

    SS \--\> SC\["SparkContext\<br/\>(driver ↔ cluster connection)"\]

    SC \--\> CM\["Cluster Manager"\]

    CM \--\> W\["Executors / Worker Nodes"\]

> 💡 Nothing actually runs until you call an **action** (e.g. `.collect()`, `.count()`, `.write()`). That's the moment a **Job** gets created and submitted.

---

## 5\. RDDs & Partitions

An **RDD (Resilient Distributed Dataset)** is the foundational data type in Spark — think of it as a **list that's logically split into partitions**, where each partition can live on a different machine in the cluster.

- **Partition** \= a logical chunk of the dataset that gets processed independently, in parallel, by a task.  
- DataFrames/Datasets are built on top of RDDs and inherit this same partitioning model.

flowchart TB

    RDD\["RDD (logical dataset)"\]

    RDD \--\> P1\["Partition 1"\]

    RDD \--\> P2\["Partition 2"\]

    RDD \--\> P3\["Partition 3"\]

    P1 \--\> N1\["Node A"\]

    P2 \--\> N2\["Node B"\]

    P3 \--\> N3\["Node C"\]

---

## 6\. Narrow vs. Wide Transformations

- **Narrow transformation** — each input partition contributes to exactly **one** output partition. No data movement across the network. Examples: `map`, `filter`, `union`.  
- **Wide transformation** — input partitions can contribute to **multiple** output partitions, requiring a **shuffle** (data movement across the network/disk). Examples: `groupBy`, `join`, `distinct`, `repartition`.  
- In the physical query plan, an `Exchange` node means a **shuffle** is happening.

flowchart LR

    subgraph Narrow\["Narrow — map / filter (no shuffle)"\]

        A1\["Partition 1"\] \--\> B1\["Partition 1"\]

        A2\["Partition 2"\] \--\> B2\["Partition 2"\]

    end

    subgraph Wide\["Wide — groupBy / join (shuffle \= Exchange)"\]

        C1\["Partition 1"\] \--\> D1\["Partition 1"\]

        C1 \--\> D2\["Partition 2"\]

        C2\["Partition 2"\] \--\> D1

        C2 \--\> D2

    end

---

## 7\. Repartition vs. Coalesce

|  | `repartition(n)` | `coalesce(n)` |
| :---- | :---- | :---- |
| Shuffle? | Yes — full shuffle (`Exchange` in plan) | No shuffle — merges adjacent partitions |
| Can increase partitions? | Yes | No — can only decrease |
| Data distribution | Even | Can be uneven if merging unevenly-sized partitions |
| Cost | Expensive | Cheap |

RDDs (and the DataFrames built on them) are all tracked underneath via the **DAG** (lineage graph). If a partition is lost, Spark can **recompute it from the DAG** instead of losing data — this is what makes Spark **fault tolerant**.

---

## 8\. Jobs, Stages, Tasks & the DAG

- **Job** — triggered every time an **action** is called (e.g. `.collect()`, `.write()`).  
- **Stage** — a job is split into stages at every **shuffle boundary** (wide transformation).  
- **Task** — the smallest unit of work; **one task per partition**, so the number of tasks in a stage \= number of partitions being processed.  
- **Number of cores available \= number of tasks that can run in parallel.**

flowchart TB

    Job\["🚀 Job — triggered by an Action"\]

    Job \--\> S1\["Stage 1 (before shuffle)"\]

    Job \--\> S2\["Stage 2 (after shuffle)"\]

    S1 \--\> T1\["Task — Partition 1"\]

    S1 \--\> T2\["Task — Partition 2"\]

    S2 \--\> T3\["Task — Partition 1"\]

    S2 \--\> T4\["Task — Partition 2"\]

---

## 9\. Joins in Spark

A join is a **wide transformation** — by default Spark shuffles both sides into **200 partitions** (`spark.sql.shuffle.partitions`), aligning rows with the same join key into the same partition.

### Types of joins

| Join Strategy | How it works | Best for |
| :---- | :---- | :---- |
| **Sort Merge Join** (default) | Sorts both DataFrames on the join key, then merges them | Large ⋈ large tables |
| **Shuffle Hash Join** | Builds a hash table from the smaller side (per partition), then probes it while scanning the bigger side | Medium-sized side that fits in memory |
| **Broadcast Join** | Driver broadcasts the *entire* small table to every executor — no shuffle needed at all | Small table (few MB–tens of MB) ⋈ huge table |

> ⚠️ For a **Broadcast Join**, make sure the driver (and each executor) has enough memory to hold the broadcasted table — otherwise you risk an out-of-memory error.

flowchart TB

    Driver\["🧠 Driver"\] \--\>|"broadcasts small table"| E1\["Executor 1\<br/\>Big Table Partition 1 \+ 🔹small table copy"\]

    Driver \--\>|"broadcasts small table"| E2\["Executor 2\<br/\>Big Table Partition 2 \+ 🔹small table copy"\]

    Driver \--\>|"broadcasts small table"| E3\["Executor 3\<br/\>Big Table Partition 3 \+ 🔹small table copy"\]

*Broadcast join — no 200-partition shuffle needed.*

flowchart LR

    A1\["Table A · Partition 1"\] \--\> Shuffle\["🔀 Shuffle by join key"\]

    A2\["Table A · Partition 2"\] \--\> Shuffle

    B1\["Table B · Partition 1"\] \--\> Shuffle

    B2\["Table B · Partition 2"\] \--\> Shuffle

    Shuffle \--\> J1\["Joined Partition\<br/\>(key range X)"\]

    Shuffle \--\> J2\["Joined Partition\<br/\>(key range Y)"\]

*Sort Merge / Shuffle Hash join — both sides shuffled by join key.*

---

## 10\. Spark Memory Management

Each executor's JVM heap is split as follows (Spark's **Unified Memory Model**):

1. **Reserved Memory** — a fixed \~300MB, not configurable, reserved for Spark's internal objects.  
2. **Usable Memory** — everything left after the reserved chunk.  
3. Usable memory splits into:  
   - **Spark Memory Pool** (default `spark.memory.fraction` \= 60%) — used for execution \+ storage.  
   - **User Memory** (remaining 40%) — used for user data structures, UDFs, RDD conversion buffers, etc.

**Worked example — 10GB executor:**

- 300MB reserved  
- \~9.7GB usable  
- Spark memory pool: 0.60 × 9.7GB ≈ **5GB**  
- User memory: 0.40 × 9.7GB ≈ **4GB**

Within the Spark memory pool, `spark.memory.storageFraction` (default 50%) sets the **Storage Memory** boundary (for cached DataFrames/RDDs) vs. **Execution Memory** (for joins, shuffles, sorts, aggregations) — but this is just a *soft* boundary:

- Execution and Storage can **borrow memory from each other** as needed.  
- **Execution memory can evict Storage memory** (evicting cached blocks via LRU) if it needs more room.  
- **Storage memory cannot evict Execution memory** — execution has priority since a running task can't simply be paused.

flowchart TB

    Total\["Executor Memory — e.g. 10GB"\]

    Total \--\> Reserved\["Reserved \~300MB (fixed)"\]

    Total \--\> Usable\["Usable \~9.7GB"\]

    Usable \--\> Spark\["Spark Memory Pool (60%) ≈ 5GB"\]

    Usable \--\> User\["User Memory (40%) ≈ 4GB"\]

    Spark \--\> Storage\["Storage Memory\<br/\>(cached DFs/RDDs)"\]

    Spark \--\> Execution\["Execution Memory\<br/\>(joins, shuffles, sorts)"\]

    Execution \--\>|"can evict storage via LRU"| Storage

**Executor memory overhead** (off-heap, for JVM internals, native libraries, etc.):

spark.executor.memoryOverhead \= max(384MB, 10% of executor memory)

**Watch out for:**

- `df.collect()` pulls *all* data to the driver — use it only when the result set is genuinely small, or you risk a driver **out-of-memory** error.  
- **Partition skew**: if one partition needs more memory than is available in the execution pool (e.g. 1.5GB needed but only 1GB available), Spark **spills to disk** to try to cope — if it still can't process it, you get an OOM error. See [Data Skew & Salting](#11-data-skew--salting).

---

## 11\. Data Skew & Salting

**Data skew** happens when one (or a few) join/group-by keys have disproportionately more rows than others — that key's partition becomes a bottleneck (or blows past its memory budget and spills to disk / OOMs), while other partitions sit mostly idle.

**Fix: Salting**

- Append a random "salt" value (e.g. a number 0–9) to the skewed key, spreading its rows across multiple partitions instead of one.  
- The matching side of the join is exploded to match every possible salt value, so rows still find their match.  
- This trades a bit of extra shuffle volume for much more even partition sizes.

flowchart LR

    subgraph Before\["Before Salting"\]

        K1\["Key A — 5M rows"\] \--\> P1\["Partition 1 😰 overloaded"\]

        K2\["Key B — 10 rows"\] \--\> P2\["Partition 2 (idle)"\]

    end

    subgraph After\["After Salting Key A"\]

        K1a\["Key A \+ salt(0)"\] \--\> Q1\["Partition 1"\]

        K1b\["Key A \+ salt(1)"\] \--\> Q2\["Partition 2"\]

        K1c\["Key A \+ salt(2)"\] \--\> Q3\["Partition 3"\]

        K2a\["Key B"\] \--\> Q4\["Partition 4"\]

    end

---

## 12\. Cache vs. Persist

- Only cache data that **fits comfortably in memory** or will be **reused multiple times** — caching data used only once just adds overhead.  
- Check the **Spark UI → Storage tab** to confirm whether a DataFrame is actually cached.

|  | `cache()` | `persist(level)` |
| :---- | :---- | :---- |
| Storage level | Fixed: `MEMORY_AND_DISK` (DataFrame) | You choose: `MEMORY_ONLY`, `MEMORY_AND_DISK`, `DISK_ONLY`, `MEMORY_ONLY_SER`, etc. |
| Flexibility | Low — one-size-fits-all shortcut | High — tune for your memory budget |

---

## 13\. Deployment Modes: Client vs. Cluster

|  | Client Mode | Cluster Mode |
| :---- | :---- | :---- |
| Driver location | Runs on the **client machine** (e.g. your laptop, an edge node) | Runs **inside the cluster** |
| App survives client disconnect? | ❌ No — app dies if the client machine goes down | ✅ Yes |
| Network latency | Higher (driver ↔ executors cross the client's network) | Lower (driver co-located with executors) |
| Good for | Development — you see logs/output directly on your machine | Production |

> It's genuinely architecture/project-dependent which mode makes sense — client mode is great for interactive dev work where you want logs and output locally, but it's generally **not recommended for production** due to the latency and single-point-of-failure risk.

flowchart TB

    subgraph Client\["Client Mode (good for dev)"\]

        CD\["Driver — runs on YOUR machine"\] \--\> CC\["Cluster Manager"\]

        CC \--\> CE\["Executors — on the cluster"\]

    end

    subgraph Cluster\["Cluster Mode (production)"\]

        CM2\["Cluster Manager"\] \--\> CD2\["Driver — runs inside the cluster"\]

        CM2 \--\> CE2\["Executors — on the cluster"\]

    end

---

## 14\. Partitioning, Output Files & Pruning

- With no explicit partitioning, **number of cores ≈ number of output files** written.  
- **Partition pruning**: when data is physically partitioned (e.g. by date) and a filter matches a partition column, Spark only scans the matching partition(s) instead of the whole dataset — much more performant than a full scan.  
- **Dynamic Partition Pruning (DPP)**: extends this idea to joins — if a join's build side filters down to a small set of values, Spark can push that filter down to prune partitions on the probe side too, even when the filter value isn't known until runtime.

---

## 15\. Adaptive Query Execution (AQE)

AQE re-optimizes the physical query plan **during execution**, using runtime statistics instead of relying purely on the (sometimes stale/inaccurate) initial estimates. Key features:

- **Dynamically coalescing shuffle partitions** — merges small post-shuffle partitions to avoid an explosion of tiny tasks.  
- **Dynamically switching join strategies** — e.g. can switch a Sort Merge Join to a Broadcast Join at runtime once it sees the actual (small) size of one side.  
- **Dynamically optimizing skewed joins** — detects skewed partitions at runtime and splits them into smaller sub-partitions automatically.

---

## 16\. Interview Quick-Hit Q\&A

**Q: Why is Spark faster than MapReduce?** A: Spark keeps intermediate data in memory across transformations instead of writing to disk after every step, and it builds an optimized DAG of the whole job before executing — MapReduce writes to disk between every map/reduce phase.

**Q: What makes RDDs fault-tolerant?** A: Lineage. Spark tracks the sequence of transformations (the DAG) that produced each RDD, so a lost partition can be recomputed from its lineage rather than requiring replicated storage.

**Q: When would you use `coalesce` instead of `repartition`?** A: When you only need to *reduce* the number of partitions (e.g. before writing fewer output files) and want to avoid the cost of a full shuffle.

**Q: How do you fix a skewed join?** A: Salting the skewed key(s) to spread them across more partitions, enabling AQE's skew-join optimization, or broadcasting the smaller side if one exists.

**Q: Storage memory vs execution memory — who wins?** A: Execution memory wins — it can evict cached storage blocks (LRU) if it needs more room; storage memory can't evict execution memory back.

**Q: Client mode vs cluster mode — which for production?** A: Cluster mode — the driver runs inside the cluster, avoiding the network latency and single-point-of-failure risk of a driver sitting on a client machine.

---

## 📚 About This Repo

These are personal study notes, kept intentionally concise for quick pre-interview revision. Diagrams are simplified, original sketches (Mermaid, renders natively on GitHub) built to aid recall — not reproductions of any book, course, or vendor documentation.

