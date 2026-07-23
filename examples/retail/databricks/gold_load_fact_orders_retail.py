# Databricks notebook source
# MAGIC %md
# MAGIC # Gold — fact_orders load (retail)
# MAGIC Retail-specific: the generator's order records carry a discount
# MAGIC *percentage*, not a dollar amount, and each row is already a complete
# MAGIC order line (no multi-line order header), so `order_line_number` is
# MAGIC always 1. `discount_amount`/`net_amount` are computed here.
# MAGIC `employee_key`/`location_key`/`currency_key` stay null — no
# MAGIC order-taker, fulfilling-location, or currency-variance concept in the
# MAGIC generated data. The generic `src/databricks/03_gold/03_Gold_Load_Fact.py`
# MAGIC assumes those fields already exist upstream, so it doesn't fit this
# MAGIC shape. Mirrors `examples/retail/sql/04_Load_Fact_Orders_Retail.sql`.
# MAGIC
# MAGIC Writes into the *generic* `gold.fact_orders` table — same table
# MAGIC `03_Gold_Load_Fact.py` would target for `fact_sales`'s sibling fact,
# MAGIC unmodified.

# COMMAND ----------

# MAGIC %run ../../../src/databricks/00_common/utils

# COMMAND ----------

dbutils.widgets.text("silver_table", "adea.silver.retail_orders")
dbutils.widgets.text("gold_table", "adea.gold.fact_orders")

silver_table_name = dbutils.widgets.get("silver_table")
gold_table_name = dbutils.widgets.get("gold_table")

# COMMAND ----------

from pyspark.sql import functions as F

silver_df = spark.table(silver_table_name)

dim_customer_keys = (
    spark.table(gold_table("dim_customer"))
    .filter("is_current = true")
    .select("customer_id", "source_system", "customer_key")
)
dim_product_keys = (
    spark.table(gold_table("dim_product"))
    .filter("is_current = true")
    .select("product_id", "source_system", "product_key")
)

fact_df = (
    silver_df.withColumn("date_key", F.date_format("order_date", "yyyyMMdd").cast("int"))
    .withColumn("quantity", F.col("quantity").cast("decimal(18,4)"))
    .withColumn("unit_price", F.col("unit_price").cast("decimal(18,4)"))
    .withColumn("discount_pct", F.col("discount_pct").cast("decimal(9,4)"))
    .withColumn(
        "discount_amount",
        F.round(F.col("quantity") * F.col("unit_price") * F.coalesce(F.col("discount_pct"), F.lit(0)) / 100, 4),
    )
    .withColumn("tax_amount", F.lit(0).cast("decimal(18,4)"))
    .withColumn(
        "net_amount", (F.col("quantity") * F.col("unit_price")) - F.col("discount_amount")
    )
    .withColumn("order_line_number", F.lit(1))
    .join(dim_customer_keys, ["customer_id", "source_system"], "inner")
    .join(dim_product_keys, ["product_id", "source_system"], "inner")
    .select(
        "date_key",
        "customer_key",
        "product_key",
        F.lit(None).cast("int").alias("employee_key"),
        F.lit(None).cast("int").alias("location_key"),
        F.lit(None).cast("int").alias("currency_key"),
        "source_system",
        "order_id",
        "order_line_number",
        "order_status",
        "quantity",
        "unit_price",
        "discount_amount",
        "tax_amount",
        "net_amount",
    )
)

merge_fact(fact_df, gold_table_name, natural_keys=["source_system", "order_id", "order_line_number"])
