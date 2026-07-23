# Databricks notebook source
# MAGIC %md
# MAGIC # Gold — SCD Type 1 dimension load
# MAGIC Generic: works for any reference dimension that's overwritten in place
# MAGIC (`dim_source_system`, `dim_currency`, `dim_location`). Example widget
# MAGIC defaults below are for `dim_source_system`.

# COMMAND ----------

# MAGIC %run ../00_common/utils

# COMMAND ----------

dbutils.widgets.text("silver_table", "adea.silver.source_system")
dbutils.widgets.text("gold_table", "adea.gold.dim_source_system")
dbutils.widgets.text("natural_key_columns", "source_system_code", "Comma-separated natural key columns")
dbutils.widgets.text("tracked_columns", "source_system_name,description", "Comma-separated tracked columns")

silver_table_name = dbutils.widgets.get("silver_table")
gold_table_name = dbutils.widgets.get("gold_table")
natural_keys = dbutils.widgets.get("natural_key_columns").split(",")
tracked_columns = dbutils.widgets.get("tracked_columns").split(",")

# COMMAND ----------

source_df = spark.table(silver_table_name)
merge_scd1(source_df, gold_table_name, natural_keys, tracked_columns)
