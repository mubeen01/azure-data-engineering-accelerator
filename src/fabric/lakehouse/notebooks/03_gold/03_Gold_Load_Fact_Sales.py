# Fabric notebook source
# MAGIC %md
# MAGIC # Gold — fact_sales load (Fabric Lakehouse)
# MAGIC Same dimension-resolution approach as
# MAGIC `src/databricks/03_gold/03_Gold_Load_Fact.py` — resolves each
# MAGIC dimension surrogate key by selecting only join keys + the surrogate
# MAGIC key before joining, to avoid ambiguous column collisions once several
# MAGIC tables share attribute names.

# COMMAND ----------

# MAGIC %run 00_common_utils

# COMMAND ----------

# PARAMETERS CELL
silver_table_name = "lh_silver.sales"
gold_table_name = "lh_gold.fact_sales"

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
