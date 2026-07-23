# Fabric notebook source
# MAGIC %md
# MAGIC # Silver — cleanse & conform (Fabric Lakehouse)
# MAGIC Same logic as `src/databricks/02_silver/01_Silver_Conform_Generic.py`
# MAGIC — this layer's transform doesn't depend on Databricks-specific APIs,
# MAGIC so it ports directly. Trim strings, drop rows missing a natural key,
# MAGIC de-duplicate on natural key keeping the latest `_ingest_timestamp`.

# COMMAND ----------

# PARAMETERS CELL
bronze_table_name = "lh_bronze.banking_customers"
silver_table_name = "lh_silver.banking_customers"
natural_key_columns = "customer_id"

# COMMAND ----------

from pyspark.sql import functions as F, Window
from pyspark.sql.types import StringType

natural_keys = natural_key_columns.split(",")
bronze_df = spark.table(bronze_table_name)

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

silver_df = deduped_df  # entity-specific rules go here, passthrough by default

# COMMAND ----------

silver_df.write.format("delta").mode("overwrite").option("overwriteSchema", "true").saveAsTable(
    silver_table_name
)
