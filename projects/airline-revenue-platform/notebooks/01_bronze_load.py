# Databricks notebook source
# MAGIC %sql
# MAGIC CREATE CATALOG airline_dev MANAGED LOCATION 'abfss://lakehouse@airlinesrev.dfs.core.windows.net/';
# MAGIC CREATE SCHEMA airline_dev.airline;
# MAGIC CREATE EXTERNAL VOLUME airline_dev.airline.raw LOCATION 'abfss://landing@airlinesrev.dfs.core.windows.net/raw';

# COMMAND ----------

import os
os.listdir('/Volumes/airline_dev/airline/raw/db1b/')

# COMMAND ----------

# MAGIC %md
# MAGIC Bronze fares

# COMMAND ----------

src = "/Volumes/airline_dev/airline/raw/db1b/"
chk = "/Volumes/airline_dev/airline/raw/_checkpoints/bronze_fares"
sch = "/Volumes/airline_dev/airline/raw/_schemas/bronze_fares"

# COMMAND ----------

from pyspark.sql import functions as F

df = (spark.readStream
      .format("cloudFiles")
      .option("cloudFiles.format", "csv")
      .option("header", "true")
      .option("cloudFiles.schemaLocation", sch)
      .load(src)
      .withColumn("ingest_ts", F.current_timestamp())
      .withColumn("source_file", F.col("_metadata.file_path")))

df.printSchema()

# COMMAND ----------

(df.writeStream
   .option("checkpointLocation", chk)
   .trigger(availableNow=True)
   .toTable("airline_dev.airline.bronze_fares")
   .awaitTermination())

# COMMAND ----------

# MAGIC %sql
# MAGIC SELECT COUNT(*) FROM airline_dev.airline.bronze_fares

# COMMAND ----------

# MAGIC %sql
# MAGIC SELECT source_file, ingest_ts FROM airline_dev.airline.bronze_fares LIMIT 5

# COMMAND ----------

# MAGIC %sql
# MAGIC DESCRIBE DETAIL airline_dev.airline.bronze_fares

# COMMAND ----------

# MAGIC %sql
# MAGIC DESCRIBE HISTORY airline_dev.airline.bronze_fares

# COMMAND ----------

# MAGIC %md
# MAGIC BRONZE CAPACITY 

# COMMAND ----------

src = "/Volumes/airline_dev/airline/raw/t100/"
chk = "/Volumes/airline_dev/airline/raw/_checkpoints/bronze_capacity"
sch = "/Volumes/airline_dev/airline/raw/_schemas/bronze_capacity"

# COMMAND ----------

from pyspark.sql import functions as F

df = (spark.readStream
      .format("cloudFiles")
      .option("cloudFiles.format", "csv")
      .option("header", "true")
      .option("cloudFiles.schemaLocation", sch)
      .load(src)
      .withColumn("ingest_ts", F.current_timestamp())
      .withColumn("source_file", F.col("_metadata.file_path")))

df.printSchema()

# COMMAND ----------

(df.writeStream
   .option("checkpointLocation", chk)
   .trigger(availableNow=True)
   .toTable("airline_dev.airline.bronze_capacity")
   .awaitTermination())

# COMMAND ----------

# MAGIC %sql
# MAGIC SELECT COUNT(*) FROM airline_dev.airline.bronze_capacity

# COMMAND ----------

# MAGIC %sql 
# MAGIC DESCRIBE DETAIL airline_dev.airline.bronze_capacity

# COMMAND ----------

# MAGIC %sql 
# MAGIC DESCRIBE HISTORY airline_dev.airline.bronze_capacity

# COMMAND ----------

