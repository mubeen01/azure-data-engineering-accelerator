# Fabric notebook source
# MAGIC %md
# MAGIC # Bronze — ingestion (Fabric Lakehouse)
# MAGIC **Deliberately not a port of `src/databricks/01_bronze/01_Bronze_Autoloader_Ingest.py`.**
# MAGIC Auto Loader (`cloudFiles`) is a Databricks-proprietary Spark
# MAGIC connector — it doesn't exist on Fabric's runtime. The idiomatic
# MAGIC Fabric equivalent is a plain batch read over the Lakehouse's
# MAGIC `Files/` area, which is what this notebook does instead of
# MAGIC pretending Auto Loader parity exists.
# MAGIC
# MAGIC Not verified against a live Fabric workspace — see
# MAGIC `src/fabric/README.md`.

# COMMAND ----------

# PARAMETERS CELL
# Fabric notebooks don't have dbutils.widgets — a cell tagged "parameters"
# holds plain variable assignments like these, and a pipeline Notebook
# activity's base parameters inject a new cell overriding them at runtime.
source_path = "Files/raw/banking/customers.csv"  # relative to the attached Lakehouse
source_format = "csv"
bronze_table_name = "lh_bronze.banking_customers"

# COMMAND ----------

from pyspark.sql import functions as F

raw_df = (
    spark.read.format(source_format)
    .option("header", "true")
    .option("inferSchema", "true")
    .load(source_path)
    .withColumn("_ingest_file", F.input_file_name())
    .withColumn("_ingest_timestamp", F.current_timestamp())
)

# COMMAND ----------

# MAGIC %md
# MAGIC Full reload each run, not an incremental stream — Fabric has no
# MAGIC built-in equivalent to Auto Loader's managed "which files have I
# MAGIC already seen" bookkeeping. If you need incremental file pickup,
# MAGIC track processed file names/mtimes in a small control table and
# MAGIC filter `source_path`'s listing against it before the read above,
# MAGIC mirroring the watermark pattern `src/sql/07-functions/01_Ufn_Get_Watermark.sql`
# MAGIC already uses for SQL-based incremental loads.

raw_df.write.format("delta").mode("overwrite").option("overwriteSchema", "true").saveAsTable(
    bronze_table_name
)
