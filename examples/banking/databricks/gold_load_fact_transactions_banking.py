# Databricks notebook source
# MAGIC %md
# MAGIC # Gold — fact_transactions load (banking)
# MAGIC Banking-specific: the generator's transaction records carry
# MAGIC `account_id` only, not `customer_id` directly, so `customer_key` is
# MAGIC resolved with a two-hop join — transaction -> `gold.dim_account`
# MAGIC (by `account_id`, current) -> `gold.dim_customer` (by the natural
# MAGIC `customer_id` that `dim_account` carries as a plain attribute,
# MAGIC current). The generic `src/databricks/03_gold/03_Gold_Load_Fact.py`
# MAGIC assumes a direct `customer_id` on the source row, so it doesn't fit
# MAGIC this shape. Mirrors `examples/banking/sql/06_Load_Fact_Transactions_Banking.sql`.
# MAGIC
# MAGIC Assumes `gold.dim_account` and `gold.dim_customer` were already loaded
# MAGIC via the generic SCD Type 2 notebook
# MAGIC (`src/databricks/03_gold/02_Gold_Load_Dim_Scd2.py`), with
# MAGIC `dim_account`'s `tracked_columns` including `customer_id` as a plain
# MAGIC natural-key attribute — not resolved to a surrogate `customer_key` at
# MAGIC that stage, consistent with the generic Gold dimension notebooks never
# MAGIC doing cross-dimension key resolution (only fact notebooks do).

# COMMAND ----------

# MAGIC %run ../../../src/databricks/00_common/utils

# COMMAND ----------

dbutils.widgets.text("silver_table", "adea.silver.banking_transactions")
dbutils.widgets.text("gold_table", "adea.gold.fact_transactions")

silver_table_name = dbutils.widgets.get("silver_table")
gold_table_name = dbutils.widgets.get("gold_table")

# COMMAND ----------

from pyspark.sql import functions as F

silver_df = spark.table(silver_table_name)

dim_account_keys = (
    spark.table(gold_table("dim_account"))
    .filter("is_current = true")
    .select("account_id", "source_system", F.col("customer_id").alias("acct_customer_id"))
)
dim_customer_keys = (
    spark.table(gold_table("dim_customer"))
    .filter("is_current = true")
    .select(F.col("customer_id").alias("acct_customer_id"), "customer_key")
)
dim_currency_keys = spark.table(gold_table("dim_currency")).select("currency_code", "currency_key")

fact_df = (
    silver_df.withColumn("date_key", F.date_format("transaction_date", "yyyyMMdd").cast("int"))
    .join(dim_account_keys, ["account_id", "source_system"], "inner")
    .join(dim_customer_keys, "acct_customer_id", "inner")
    .join(dim_currency_keys, ["currency_code"], "left")
    .select(
        "date_key",
        "customer_key",
        F.lit(None).cast("int").alias("employee_key"),  # no teller/agent concept in the generated data
        F.lit(None).cast("int").alias("location_key"),  # no branch concept in the generated data
        "currency_key",
        "source_system",
        "transaction_id",
        "account_id",
        "transaction_type",
        F.col("amount").cast("decimal(18,4)").alias("transaction_amount"),
        F.col("running_balance").cast("decimal(18,4)"),
    )
)

merge_fact(fact_df, gold_table_name, natural_keys=["source_system", "transaction_id"])
