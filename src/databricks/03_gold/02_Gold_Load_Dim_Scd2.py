# Databricks notebook source
# MAGIC %md
# MAGIC # Gold — SCD Type 2 dimension load
# MAGIC Generic: works for any dimension whose history is tracked
# MAGIC (`dim_customer`, `dim_product`, `dim_employee`). Example widget
# MAGIC defaults below are for `dim_customer`. See `00_common/utils`'s
# MAGIC `merge_scd2` for how the NULL merge-key pattern works.

# COMMAND ----------

# MAGIC %run ../00_common/utils

# COMMAND ----------

dbutils.widgets.text("silver_table", "adea.silver.customers")
dbutils.widgets.text("gold_table", "adea.gold.dim_customer")
dbutils.widgets.text("natural_key_columns", "source_system,customer_id", "Comma-separated natural key columns")
dbutils.widgets.text(
    "tracked_columns",
    "location_key,first_name,last_name,email,phone,customer_segment",
    "Comma-separated tracked columns",
)

silver_table_name = dbutils.widgets.get("silver_table")
gold_table_name = dbutils.widgets.get("gold_table")
natural_keys = dbutils.widgets.get("natural_key_columns").split(",")
tracked_columns = dbutils.widgets.get("tracked_columns").split(",")

# COMMAND ----------

source_df = spark.table(silver_table_name)
merge_scd2(source_df, gold_table_name, natural_keys, tracked_columns)
