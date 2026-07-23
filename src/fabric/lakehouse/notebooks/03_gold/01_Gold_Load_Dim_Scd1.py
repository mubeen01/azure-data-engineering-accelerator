# Fabric notebook source
# MAGIC %md
# MAGIC # Gold — SCD Type 1 dimension load (Fabric Lakehouse)
# MAGIC Generic: works for any reference dimension overwritten in place
# MAGIC (`dim_source_system`, `dim_currency`, `dim_location`).

# COMMAND ----------

# MAGIC %run 00_common_utils

# COMMAND ----------

# PARAMETERS CELL
silver_table_name = "lh_silver.source_system"
gold_table_name = "lh_gold.dim_source_system"
natural_key_columns = "source_system_code"
tracked_columns_csv = "source_system_name,description"

# COMMAND ----------

natural_keys = natural_key_columns.split(",")
tracked_columns = tracked_columns_csv.split(",")

source_df = spark.table(silver_table_name)
merge_scd1(source_df, gold_table_name, natural_keys, tracked_columns)
