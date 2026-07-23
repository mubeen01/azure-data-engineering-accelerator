# Databricks notebook source
# MAGIC %md
# MAGIC # Gold — fact_pharmacy load (healthcare)
# MAGIC Same shape as `gold_load_fact_claims_healthcare.py` — single-hop joins
# MAGIC to `gold.dim_patient` and `gold.dim_provider` (provider here is the
# MAGIC prescriber), then an idempotent append via `merge_fact`. Mirrors
# MAGIC `examples/healthcare/sql/08_Load_Fact_Pharmacy_Healthcare.sql`.

# COMMAND ----------

# MAGIC %run ../../../src/databricks/00_common/utils

# COMMAND ----------

dbutils.widgets.text("silver_table", "adea.silver.healthcare_pharmacy")
dbutils.widgets.text("gold_table", "adea.gold.fact_pharmacy")

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
    silver_df.withColumn("date_key", F.date_format("fill_date", "yyyyMMdd").cast("int"))
    .join(dim_patient_keys, ["patient_id", "source_system"], "inner")
    .join(dim_provider_keys, ["provider_id", "source_system"], "inner")
    .select(
        "date_key",
        "patient_key",
        "provider_key",
        "source_system",
        "prescription_id",
        "drug_name",
        "ndc_code",
        F.col("quantity").cast("decimal(18,4)"),
        F.col("days_supply").cast("int"),
        "pharmacy_name",
        F.col("cost").cast("decimal(18,4)"),
    )
)

merge_fact(fact_df, gold_table_name, natural_keys=["source_system", "prescription_id"])
