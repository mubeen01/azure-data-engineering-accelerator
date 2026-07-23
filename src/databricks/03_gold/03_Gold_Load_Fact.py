# Databricks notebook source
# MAGIC %md
# MAGIC # Gold — fact_sales load
# MAGIC Resolves dimension surrogate keys from Silver's natural keys against
# MAGIC the *current* Gold dimension rows, then does an idempotent append via
# MAGIC `merge_fact`. `date_key` is computed directly (same as the SQL loader
# MAGIC in `src/sql/06-stored-procedures/08_Load_Fact_Sales.sql`) rather than
# MAGIC joined from `dim_date`, since it's a deterministic function of the
# MAGIC date. `fact_orders`/`fact_transactions` follow the same shape — swap
# MAGIC the dimension joins for the ones each fact actually needs.
# MAGIC
# MAGIC Each dimension lookup below selects *only* its join keys and surrogate
# MAGIC key before joining, on purpose — chaining joins against full
# MAGIC dimension DataFrames risks ambiguous column references once several
# MAGIC tables share attribute names (`location_key` is both a `dim_customer`
# MAGIC FK and `dim_location`'s own PK, for example).

# COMMAND ----------

# MAGIC %run ../00_common/utils

# COMMAND ----------

dbutils.widgets.text("silver_table", "adea.silver.sales")
dbutils.widgets.text("gold_table", "adea.gold.fact_sales")

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
dim_employee_keys = (
    spark.table(gold_table("dim_employee"))
    .filter("is_current = true")
    .select("employee_id", "source_system", "employee_key")
)
dim_location_keys = spark.table(gold_table("dim_location")).select(
    "location_id", "source_system", "location_key"
)
dim_currency_keys = spark.table(gold_table("dim_currency")).select("currency_code", "currency_key")

fact_df = (
    silver_df.withColumn("date_key", F.date_format("sale_date", "yyyyMMdd").cast("int"))
    .join(dim_customer_keys, ["customer_id", "source_system"], "inner")
    .join(dim_product_keys, ["product_id", "source_system"], "inner")
    .join(dim_employee_keys, ["employee_id", "source_system"], "left")
    .join(dim_location_keys, ["location_id", "source_system"], "left")
    .join(dim_currency_keys, ["currency_code"], "left")
    .select(
        "date_key",
        "customer_key",
        "product_key",
        "employee_key",
        "location_key",
        "currency_key",
        "source_system",
        "sale_id",
        "quantity",
        "unit_price",
        "discount_amount",
        "tax_amount",
        "net_amount",
    )
)

merge_fact(fact_df, gold_table_name, natural_keys=["source_system", "sale_id"])
