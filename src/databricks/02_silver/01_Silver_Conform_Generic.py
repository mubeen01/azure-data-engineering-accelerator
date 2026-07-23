# Databricks notebook source
# MAGIC %md
# MAGIC # Silver — cleanse & conform
# MAGIC Reads a Bronze table, applies the shared cleansing rules (trim
# MAGIC strings, drop rows missing a natural key, de-duplicate on natural key
# MAGIC keeping the latest `_ingest_timestamp`), and writes a Silver Delta
# MAGIC table. Entity-specific type casting/validation goes in the marked
# MAGIC section below — this notebook is a template, not a one-size-fits-all
# MAGIC transform.
# MAGIC
# MAGIC **Known limitation:** this recomputes dedup over the *entire* Bronze
# MAGIC table every run, which is simple but not incremental. Fine at this
# MAGIC accelerator's scale; revisit with a streaming or MERGE-based upsert if
# MAGIC Bronze volume grows large enough for that to matter.

# COMMAND ----------

dbutils.widgets.text("bronze_table", "adea.bronze.customers")
dbutils.widgets.text("silver_table", "adea.silver.customers")
dbutils.widgets.text("natural_key_columns", "source_system,customer_id", "Comma-separated natural key columns")

bronze_table = dbutils.widgets.get("bronze_table")
silver_table = dbutils.widgets.get("silver_table")
natural_keys = dbutils.widgets.get("natural_key_columns").split(",")

# COMMAND ----------

from pyspark.sql import functions as F, Window
from pyspark.sql.types import StringType

bronze_df = spark.table(bronze_table)

string_cols = [f.name for f in bronze_df.schema.fields if isinstance(f.dataType, StringType)]
trimmed_df = bronze_df
for c in string_cols:
    trimmed_df = trimmed_df.withColumn(c, F.trim(F.col(c)))

not_null_df = trimmed_df.na.drop(subset=natural_keys)

window = Window.partitionBy(*natural_keys).orderBy(F.col("_ingest_timestamp").desc())
deduped_df = (
    not_null_df.withColumn("_row_rank", F.row_number().over(window))
    .filter("_row_rank = 1")
    .drop("_row_rank")
)

# COMMAND ----------

# MAGIC %md
# MAGIC ### Entity-specific rules go here
# MAGIC e.g. type casts, domain-specific validation, enrichment joins.
# MAGIC Passthrough by default.

# COMMAND ----------

silver_df = deduped_df

# COMMAND ----------

silver_df.write.format("delta").mode("overwrite").option("mergeSchema", "true").saveAsTable(silver_table)
