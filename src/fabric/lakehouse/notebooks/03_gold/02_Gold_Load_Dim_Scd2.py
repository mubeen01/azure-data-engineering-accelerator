# Fabric notebook source
# MAGIC %md
# MAGIC # Gold — SCD Type 2 dimension load (Fabric Lakehouse)
# MAGIC Generic: works for any dimension whose history is tracked
# MAGIC (`dim_customer`, `dim_product`, `dim_employee`).

# COMMAND ----------

# MAGIC %run 00_common_utils

# COMMAND ----------

# PARAMETERS CELL
silver_table_name = "lh_silver.banking_customers"
gold_table_name = "lh_gold.dim_customer"
natural_key_columns = "customer_id"
tracked_columns_csv = "first_name,last_name,email,phone,customer_segment"

# COMMAND ----------

natural_keys = natural_key_columns.split(",")
tracked_columns = tracked_columns_csv.split(",")

source_df = spark.table(silver_table_name)
merge_scd2(source_df, gold_table_name, natural_keys, tracked_columns)
