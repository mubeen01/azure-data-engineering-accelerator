# Databricks notebook source
# MAGIC %md
# MAGIC # Bronze — Auto Loader ingestion
# MAGIC Generic ingestion notebook: point it at a source folder and a Bronze
# MAGIC table via widgets, one job task per entity (or drive the widgets from
# MAGIC ADF's Databricks Notebook activity). Schema evolution is on, so new
# MAGIC source columns land automatically instead of failing the run.
# MAGIC `availableNow` processes whatever is currently in the source folder
# MAGIC and then stops — appropriate for a batch-scheduled trigger. See
# MAGIC `04_streaming/` for the continuously-running variant.

# COMMAND ----------

dbutils.widgets.text("source_path", "/mnt/adea/raw/banking/customers", "Source folder (ADLS path)")
dbutils.widgets.text("source_format", "csv", "Source file format")
dbutils.widgets.text("bronze_table", "adea.bronze.customers", "Bronze table (catalog.schema.table)")
dbutils.widgets.text("checkpoint_path", "/mnt/adea/_checkpoints/bronze/customers", "Checkpoint location")

source_path = dbutils.widgets.get("source_path")
source_format = dbutils.widgets.get("source_format")
bronze_table = dbutils.widgets.get("bronze_table")
checkpoint_path = dbutils.widgets.get("checkpoint_path")

# COMMAND ----------

from pyspark.sql import functions as F

stream_df = (
    spark.readStream.format("cloudFiles")
    .option("cloudFiles.format", source_format)
    .option("cloudFiles.schemaLocation", checkpoint_path + "/_schema")
    .option("cloudFiles.schemaEvolutionMode", "addNewColumns")
    .option("header", "true")
    .load(source_path)
    .withColumn("_ingest_file", F.col("_metadata.file_path"))
    .withColumn("_ingest_timestamp", F.current_timestamp())
)

# COMMAND ----------

(
    stream_df.writeStream.option("checkpointLocation", checkpoint_path)
    .trigger(availableNow=True)
    .toTable(bronze_table)
)
