# Databricks notebook source
# MAGIC %md
# MAGIC # Gold — fact_claims load (healthcare)
# MAGIC Healthcare-specific: resolves `patient_key` and `provider_key` from
# MAGIC `gold.dim_patient` / `gold.dim_provider` against their current rows,
# MAGIC then an idempotent append via `merge_fact`, same shape as the generic
# MAGIC `src/databricks/03_gold/03_Gold_Load_Fact.py` (fact_sales). Both joins
# MAGIC are single-hop — unlike banking's `fact_transactions`, which needs a
# MAGIC two-hop join through `dim_account` (see
# MAGIC `examples/banking/databricks/gold_load_fact_transactions_banking.py`) —
# MAGIC since claims reference patient and provider directly.
# MAGIC Mirrors `examples/healthcare/sql/07_Load_Fact_Claims_Healthcare.sql`.

# COMMAND ----------

# MAGIC %run ../../../src/databricks/00_common/utils

# COMMAND ----------

dbutils.widgets.text("silver_table", "adea.silver.healthcare_claims")
dbutils.widgets.text("gold_table", "adea.gold.fact_claims")

silver_table_name = dbutils.widgets.get("silver_table")
gold_table_name = dbutils.widgets.get("gold_table")

# COMMAND ----------

from pyspark.sql import functions as F

silver_df = spark.table(silver_table_name)

dim_patient_keys = (
    spark.table(gold_table("dim_patient"))
    .filter("is_current = true")
    .select("patient_id", "source_system", "patient_key")
)
dim_provider_keys = (
    spark.table(gold_table("dim_provider"))
    .filter("is_current = true")
    .select("provider_id", "source_system", "provider_key")
)

fact_df = (
    silver_df.withColumn("date_key", F.date_format("claim_date", "yyyyMMdd").cast("int"))
    .join(dim_patient_keys, ["patient_id", "source_system"], "inner")
    .join(dim_provider_keys, ["provider_id", "source_system"], "inner")
    .select(
        "date_key",
        "patient_key",
        "provider_key",
        "source_system",
        "claim_id",
        "diagnosis_code",
        "procedure_code",
        F.col("claim_amount").cast("decimal(18,4)"),
        "claim_status",
        "payer",
    )
)

merge_fact(fact_df, gold_table_name, natural_keys=["source_system", "claim_id"])
