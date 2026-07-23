# Synapse notebook source
# MAGIC %md
# MAGIC # Gold — SCD Type 2 dimension load (Synapse Spark pool)
# MAGIC Generic: works for any dimension whose history is tracked
# MAGIC (`dim_customer`, `dim_product`, `dim_employee`). Same parameters-cell
# MAGIC mechanism as Fabric notebooks (Synapse notebooks originated this
# MAGIC pattern) — no `dbutils.widgets`.

# COMMAND ----------

# MAGIC %run /utils_00_common

# COMMAND ----------

# Parameters
silver_table_name = "silver.banking_customers"
gold_table_name = "gold.dim_customer"
natural_key_columns = "customer_id"
tracked_columns_csv = "first_name,last_name,email,phone,customer_segment"

# COMMAND ----------

natural_keys = natural_key_columns.split(",")
tracked_columns = tracked_columns_csv.split(",")

source_df = spark.table(silver_table_name)
merge_scd2(source_df, gold_table_name, natural_keys, tracked_columns)
