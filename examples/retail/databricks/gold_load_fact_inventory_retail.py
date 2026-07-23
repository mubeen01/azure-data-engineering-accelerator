# Databricks notebook source
# MAGIC %md
# MAGIC # Gold — fact_inventory load (retail)
# MAGIC `fact_inventory` has no generic equivalent (see
# MAGIC `examples/retail/README.md`'s "schema gap" section) — this is a
# MAGIC periodic-snapshot fact, `snapshot_date_key` is today's date (the load
# MAGIC date), not a source-provided date. `merge_fact` makes this
# MAGIC insert-only, keyed on `(source_system, inventory_id)` — correct for a
# MAGIC one-time generated snapshot, but see
# MAGIC `examples/retail/sql/05_Load_Fact_Inventory_Retail.sql`'s header
# MAGIC comment for what a genuine recurring-snapshot pipeline would need
# MAGIC instead (the natural key would have to include the snapshot date).

# COMMAND ----------

# MAGIC %run ../../../src/databricks/00_common/utils

# COMMAND ----------

dbutils.widgets.text("silver_table", "adea.silver.retail_inventory")
dbutils.widgets.text("gold_table", "adea.gold.fact_inventory")

silver_table_name = dbutils.widgets.get("silver_table")
gold_table_name = dbutils.widgets.get("gold_table")

# COMMAND ----------

from pyspark.sql import functions as F

silver_df = spark.table(silver_table_name)

dim_product_keys = (
    spark.table(gold_table("dim_product"))
    .filter("is_current = true")
    .select("product_id", "source_system", "product_key")
)

fact_df = (
    silver_df.withColumn("snapshot_date_key", F.date_format(F.current_date(), "yyyyMMdd").cast("int"))
    .join(dim_product_keys, ["product_id", "source_system"], "inner")
    .select(
        "snapshot_date_key",
        "product_key",
        "source_system",
        "inventory_id",
        "warehouse",
        F.col("quantity_on_hand").cast("int"),
        F.col("reorder_level").cast("int"),
        F.col("last_restock_date").cast("date"),
    )
)

merge_fact(fact_df, gold_table_name, natural_keys=["source_system", "inventory_id"])
