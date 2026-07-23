# Databricks notebook source
# MAGIC %md
# MAGIC # Streaming — continuous ingestion with per-batch Silver merge
# MAGIC Same Auto Loader source as `01_bronze/01_Bronze_Autoloader_Ingest.py`,
# MAGIC but running continuously (`trigger(processingTime=...)` instead of
# MAGIC `availableNow`) and applying cleansing + upsert to each micro-batch via
# MAGIC `foreachBatch`, instead of a separate scheduled job rescanning the
# MAGIC whole Bronze table the way `02_silver/01_Silver_Conform_Generic.py`
# MAGIC does. Suited to sources where near-real-time matters — e.g. banking
# MAGIC transactions — not every entity needs this; most can stay on the
# MAGIC simpler batch Bronze/Silver notebooks.

# COMMAND ----------

# MAGIC %run ../00_common/utils

# COMMAND ----------

dbutils.widgets.text("source_path", "/mnt/adea/raw/banking/transactions", "Source folder (ADLS path)")
dbutils.widgets.text("source_format", "csv", "Source file format")
dbutils.widgets.text("silver_table", "adea.silver.transactions", "Silver table (catalog.schema.table)")
dbutils.widgets.text("checkpoint_path", "/mnt/adea/_checkpoints/streaming/transactions", "Checkpoint location")
dbutils.widgets.text("natural_key_columns", "source_system,transaction_id", "Comma-separated natural key columns")
dbutils.widgets.text("trigger_seconds", "60", "Micro-batch interval, in seconds")

source_path = dbutils.widgets.get("source_path")
source_format = dbutils.widgets.get("source_format")
silver_table_name = dbutils.widgets.get("silver_table")
checkpoint = dbutils.widgets.get("checkpoint_path")
natural_keys = dbutils.widgets.get("natural_key_columns").split(",")
trigger_seconds = int(dbutils.widgets.get("trigger_seconds"))

# COMMAND ----------

from pyspark.sql import DataFrame, functions as F
from pyspark.sql.types import StringType

stream_df = (
    spark.readStream.format("cloudFiles")
    .option("cloudFiles.format", source_format)
    .option("cloudFiles.schemaLocation", checkpoint + "/_schema")
    .option("cloudFiles.schemaEvolutionMode", "addNewColumns")
    .option("header", "true")
    .load(source_path)
    .withColumn("_ingest_file", F.col("_metadata.file_path"))
    .withColumn("_ingest_timestamp", F.current_timestamp())
)

# COMMAND ----------

def upsert_batch(batch_df: DataFrame, batch_id: int) -> None:
    trimmed_df = batch_df
    for field in batch_df.schema.fields:
        if isinstance(field.dataType, StringType):
            trimmed_df = trimmed_df.withColumn(field.name, F.trim(F.col(field.name)))

    deduped_df = trimmed_df.dropDuplicates(natural_keys)
    # Events are immutable (a transaction doesn't get amended in place), so
    # an idempotent insert-only merge is the right upsert here — same
    # merge_fact helper the Gold fact notebooks use.
    merge_fact(deduped_df, silver_table_name, natural_keys)


query = (
    stream_df.writeStream.foreachBatch(upsert_batch)
    .option("checkpointLocation", checkpoint)
    .trigger(processingTime=f"{trigger_seconds} seconds")
    .start()
)

# Blocks the notebook so a Databricks Job running this as a continuous task
# stays "running" rather than reporting success the moment .start() returns
# while the stream keeps going unattended.
query.awaitTermination()
