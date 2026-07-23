# Databricks notebook source
# MAGIC %md
# MAGIC # Optimization — compaction, Z-ORDER, VACUUM
# MAGIC Run on a schedule after loads — same spirit as the SQL framework's
# MAGIC `src/sql/12-maintenance/01_Rebuild_Columnstore_Indexes.sql`. Gold fact
# MAGIC tables benefit most from Z-ORDER on their most-filtered column
# MAGIC (`date_key`, mirroring the SQL framework's `ix_fact_*_date_key`
# MAGIC indexes in `src/sql/08-indexes/`).

# COMMAND ----------

dbutils.widgets.text("table_name", "adea.gold.fact_sales")
dbutils.widgets.text("zorder_columns", "date_key", "Comma-separated Z-ORDER columns (blank to skip)")
dbutils.widgets.text("vacuum_retention_hours", "168", "VACUUM retention, in hours (168 = 7 days, the safe minimum)")

table_name = dbutils.widgets.get("table_name")
zorder_columns = dbutils.widgets.get("zorder_columns")
vacuum_retention_hours = dbutils.widgets.get("vacuum_retention_hours")

# COMMAND ----------

if zorder_columns.strip():
    spark.sql(f"OPTIMIZE {table_name} ZORDER BY ({zorder_columns})")
else:
    spark.sql(f"OPTIMIZE {table_name}")

# COMMAND ----------

# MAGIC %md
# MAGIC Retention below the 7-day default risks deleting files a concurrent
# MAGIC reader or a Delta time-travel query still needs — don't go lower
# MAGIC without a specific reason, same caution as any other destructive
# MAGIC cleanup job.

# COMMAND ----------

spark.sql(f"VACUUM {table_name} RETAIN {vacuum_retention_hours} HOURS")

# COMMAND ----------

spark.sql(f"ANALYZE TABLE {table_name} COMPUTE STATISTICS FOR ALL COLUMNS")

# COMMAND ----------

# MAGIC %md
# MAGIC ### One-time, per table: enable auto-optimize on write
# MAGIC Reduces (but doesn't eliminate) the need for scheduled `OPTIMIZE` by
# MAGIC compacting small files as they're written. Run once when a Gold table
# MAGIC is created, not on every scheduled maintenance pass.

# COMMAND ----------

# MAGIC %md
# MAGIC ```sql
# MAGIC ALTER TABLE adea.gold.fact_sales SET TBLPROPERTIES (
# MAGIC   'delta.autoOptimize.optimizeWrite' = 'true',
# MAGIC   'delta.autoOptimize.autoCompact' = 'true'
# MAGIC );
# MAGIC ```
