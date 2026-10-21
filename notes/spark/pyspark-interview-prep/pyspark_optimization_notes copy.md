Data Engineering & PySpark Interview Preparation Guide
Comprehensive interview preparation notes covering PySpark, Apache Spark, Performance Tuning, Resource Estimation, Spark Architecture

Table of Contents
Spark Architecture
Spark Session vs Spark Context
Driver & Executors
Spark Memory Management
Resource Estimation
Dynamic Allocation
Spark Resource Planning Scenarios
Spark Joins & Shuffle Planning
Repartition vs Coalesce
Partitioning vs Bucketing
Broadcast Join
Handling Partition Skew
Performance Tuning Techniques
OOM Troubleshooting
Spark Interview Questions
PySpark Coding Questions
Resume Preparation
LinkedIn & Naukri Optimization
Project Discussion Topics
Managerial Round Questions
Spark Architecture
Every Spark Application consists of:

Driver
Cluster Manager
Executors

Driver

Responsible for:

SparkSession creation
SparkContext creation
DAG generation
Job scheduling
Task scheduling
Requesting executors
Ideally, drivers should not perform heavy data processing.

Executors
Responsible for:

Processing data
Running tasks
Shuffling
Aggregations
Caching
Execution Flow
spark-submit
      |
      v
Driver Starts
      |
      v
SparkSession Created
      |
      v
SparkContext Created
      |
      v
Executors Requested
      |
      v
Code Sent To Executors
      |
      v
Tasks Sent
      |
      v
Execution Starts
Spark Session vs Spark Context
SparkSession
Introduced in Spark 2.0.

High-level entry point for:

DataFrames
SQL
Hive
Streaming
MLlib
Example:

from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("demo") \
    .getOrCreate()

SparkContext
Low-level cluster entry point.

Responsible for:

Getting executors
Sending code
Sending tasks
Example:

sc = spark.sparkContext
Relationship:

SparkSession
     |
     v
SparkContext
     |
     v
Cluster
Interview Answer:

SparkSession is the high-level unified entry point introduced in Spark 2.0. SparkContext is the low-level component responsible for communicating with the cluster. SparkSession internally contains SparkContext.

Driver vs Executors
Driver
Common Responsibilities:

Create execution plans
Manage tasks
Broadcast variables
Collect operations
Typical Driver Size:

2 Core
8 GB RAM
Large Jobs:

5 Core
19 GB RAM
Executors
Responsible for actual computation.

Example:

5 CPU Cores
19 GB RAM
Spark Memory Management
Executor Memory:

Reserved Memory
      |
40% User Memory
      |
60% Spark Memory
      |
------------------------
|                      |
Execution        Storage
Memory           Memory
Execution Memory Used For:

Joins
Aggregations
Sort
Shuffle
Storage Memory Used For:

Cache
Persist
Broadcast Variables
Resource Estimation
Two Main Factors
1. Amount Of Data
Examples:

100 GB
1 TB
10 TB
2. Completion Time
Questions:

Batch Job?
Near Real-Time?
SLA Requirements?
Important:

More resources do not always mean faster execution.

Resource Allocation
Static Allocation
Passed during spark-submit

--num-executors
--executor-cores
--executor-memory
Dynamic Allocation
Allocates resources automatically.

Configurations:

spark.dynamicAllocation.enabled=true

spark.dynamicAllocation.initialExecutors

spark.dynamicAllocation.minExecutors

spark.dynamicAllocation.maxExecutors

spark.dynamicAllocation.schedulerBacklogTimeout

spark.dynamicAllocation.executorIdleTimeout
Benefits:

Better cluster utilization
Resources released when idle
Sample Cluster Configuration
100 Nodes

16 CPU Cores
64 GB RAM
Reserve:

1 CPU
1 GB RAM
Available:

15 CPU
63 GB RAM
Executor Layout:

3 Executors Per Node

Each Executor:
5 CPU Cores
19 GB RAM
Total:

300 Executors
1500 CPU Cores
Partition Sizing Principles
Recommended Partition Size:

128 MB
Important:

Data expands in memory.

128 MB on disk

≈

500 MB – 750 MB in memory
Rule of Thumb:

4X – 6X expansion
Scenario 1: Aggregation
Dataset:

Orders = 100 GB
Partition Size:

128 MB
Initial Partitions:

100 GB / 128 MB

≈ 800 partitions
Example Query:

SELECT customerid, SUM(amount)
FROM orders
GROUP BY customerid
Stage 1
800 Partitions
800 Tasks
To execute fully parallel:

800 CPU Cores Required
Executor:

5 Cores
Executors Required:

800 / 5

160 Executors
Stage 2 (Shuffle)
Default:

spark.sql.shuffle.partitions=200
Data per partition:

100 GB / 200

500 MB
This can lead to memory pressure.

Recommended:

spark.conf.set(
    "spark.sql.shuffle.partitions",
    "800"
)
Result:

100 GB / 800

125 MB Partition
Advantages:

Higher parallelism
Less spilling
Better memory utilization
Resource Planning Examples
160 Executors
800 CPU Cores
Recommended:

800 Shuffle Partitions
Everything runs parallel.

80 Executors
400 CPU Cores
Stage 1:

2 Batches
Recommended:

400 Shuffle Partitions
250 MB per partition
40 Executors
200 CPU Cores
Stage 1:

4 Batches
Recommended:

400 Shuffle Partitions
Better than:

300 Shuffle Partitions
Because memory pressure is lower.

Scenario 2: Joining Two Datasets
Datasets:

Orders     = 100 GB
Customers  = 50 GB
Partitions:

Orders     = 800
Customers  = 400
Total:

1200 Partitions
Join Key:

customer_id
240 Executors
1200 CPU Cores
Everything runs parallel.

Stage 2 Output:

150 GB
Default:

200 shuffle partitions
Each partition:

750 MB
Very heavy.

Recommended:

1200 shuffle partitions
128 MB average partition
Repartition vs Coalesce
Repartition
Can:

Increase partitions
Decrease partitions
Always causes shuffle.

df.repartition(10)
Coalesce
Mainly used to reduce partitions.

Avoids shuffle.

df.coalesce(5)
Interview Example
Current:

9 partitions
Need:

1 output file
Recommended:

df.coalesce(1)
Avoid:

df.repartition(1)
Because repartition performs a full shuffle.

Partitioning vs Bucketing
Partitioning
Physical directory structure.

Example:

year=2025/
month=06/
day=01/
Benefits:

Less data scanning
Faster reads
Bucketing
Data distributed into fixed buckets.

Useful for:

Repeated joins
Benefits:

Less shuffle
Faster joins
Join Strategies
Broadcast Hash Join
One Small Table

One Large Table

from pyspark.sql.functions import broadcast

large_df.join(
    broadcast(small_df),
    "id"
)
Advantages:

No shuffle of large table
Fastest join
Shuffle Hash Join
Used when:

Medium Table
Large Table
Sort Merge Join
Used when:

Large Table
Large Table
Most common join strategy in production.

Partition Skew
What Is Skew?
Uneven data distribution.

Example:

Customer 100

90% of records
One partition becomes huge.

Solutions
AQE
spark.conf.set(
 "spark.sql.adaptive.enabled",
 "true"
)
Salting
Add random suffix to skewed keys.

Better Join Strategy
Use Broadcast Join when possible.

Performance Tuning Techniques
Filter Early
Reduce data before joins.

df.filter(...)
Broadcast Join
Avoid unnecessary shuffle.

AQE
Handles:

Partition skew
Dynamic coalesce
Tune Shuffle Partitions
spark.conf.set(
 "spark.sql.shuffle.partitions",
 "800"
)
Hash Aggregate
Prefer:

Hash Aggregate
Over:

Sort Aggregate
When appropriate.

Partitioning
Store data according to access patterns.

Bucketing
Useful for repeated joins.

Efficient File Formats
Recommended:

Parquet
ORC
Delta Lake
Compression
Recommended:

Snappy
GZIP
ZSTD
Caching
Use when the same DataFrame is reused multiple times.

df.cache()
or

df.persist()
Out Of Memory Troubleshooting
Driver OOM
Possible Causes:

collect()

Large Broadcast Variables
Executor OOM
Possible Causes:

Partition Skew

Huge Partitions

Heavy Caching

Insufficient Memory Per Core
Solutions
AQE
Increase shuffle partitions
Filter early
Increase executor memory
Repartition data
Remove unnecessary caching
Managed vs External Tables
Managed Table
Spark manages:

Data
Metadata
Drop Table:

Data Removed
Metadata Removed
External Table
Spark manages:

Metadata Only
Drop Table:

Metadata Removed
Data Remains
Frequently Asked Spark Questions
Explain Spark Architecture.
SparkSession vs SparkContext.
Difference between Client Mode and Cluster Mode.
What is DAG?
What is Partition Skew?
How do you solve skew?
Explain AQE.
Broadcast Join vs Sort Merge Join.
Repartition vs Coalesce.
Partitioning vs Bucketing.
Narrow vs Wide Transformations.
DataFrame vs Dataset.
What is Shuffling?
Driver OOM vs Executor OOM.
Managed vs External Tables.
Why Spark over MapReduce?
Explain Spark Memory Management.
How would you debug a slow Spark Job?
Explain your CI/CD process.
How do you unit test PySpark code?
PySpark Coding Questions
Remove Duplicates
df = spark.read.parquet(source)

df_no_duplicates = df.dropDuplicates()

df_no_duplicates.write.mode("overwrite").parquet(destination)
collect_list Example
Input:

a aa 1
a aa 2
b bb 5
b bb 3
Output:

a aa [1,2]
b bb [5,3]
df.groupBy("col1","col2") \
  .agg(collect_list("col3").alias("col3"))
Explode JSON Array
df.select(
    "dept_id",
    explode("e_id").alias("e_id")
)
Team Size Problem
employee_df \
.groupBy("team_id") \
.agg(
   collect_list("employee_id")
      .alias("employee_list")
) \
.withColumn(
   "team_size",
   size("employee_list")
) \
.selectExpr(
   "explode(employee_list) as employee_id",
   "team_size"
)