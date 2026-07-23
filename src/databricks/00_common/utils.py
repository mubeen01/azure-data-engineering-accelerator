# Databricks notebook source
# MAGIC %md
# MAGIC # Common utilities
# MAGIC Shared by every Bronze/Silver/Gold notebook — import with
# MAGIC `%run ../00_common/utils` (adjust the relative path from wherever the
# MAGIC calling notebook lives). Not a standalone job; this is a library
# MAGIC notebook only.

# COMMAND ----------

from pyspark.sql import DataFrame, functions as F
from delta.tables import DeltaTable

CATALOG = "adea"


def bronze_table(entity: str) -> str:
    return f"{CATALOG}.bronze.{entity}"


def silver_table(entity: str) -> str:
    return f"{CATALOG}.silver.{entity}"


def gold_table(entity: str) -> str:
    return f"{CATALOG}.gold.{entity}"


def checkpoint_path(layer: str, entity: str) -> str:
    return f"/mnt/adea/_checkpoints/{layer}/{entity}"


# COMMAND ----------

# MAGIC %md
# MAGIC ## SCD Type 1 — overwrite in place
# MAGIC SQL Server equivalent: `etl.usp_load_dim_source_system` /
# MAGIC `_currency` / `_location` in `src/sql/06-stored-procedures/`.

# COMMAND ----------

def merge_scd1(
    source_df: DataFrame,
    target_table: str,
    natural_keys: list[str],
    tracked_columns: list[str],
) -> None:
    if not spark.catalog.tableExists(target_table):
        source_df.write.format("delta").saveAsTable(target_table)
        return

    target = DeltaTable.forName(spark, target_table)
    merge_condition = " AND ".join(f"tgt.{k} = src.{k}" for k in natural_keys)
    change_condition = " OR ".join(f"tgt.{c} <> src.{c}" for c in tracked_columns)
    set_clause = {c: f"src.{c}" for c in tracked_columns}
    set_clause["updated_date"] = "current_timestamp()"

    (
        target.alias("tgt")
        .merge(source_df.alias("src"), merge_condition)
        .whenMatchedUpdate(condition=change_condition, set=set_clause)
        .whenNotMatchedInsertAll()
        .execute()
    )


# COMMAND ----------

# MAGIC %md
# MAGIC ## SCD Type 2 — expire + insert, via the NULL merge-key trick
# MAGIC Every new-or-changed row is staged twice: once tagged with its natural
# MAGIC key (matches the existing current row, if any, and expires it) and once
# MAGIC tagged with `merge_key = NULL` (guaranteed not to match anything,
# MAGIC forcing an insert of the new current row). This is the standard Delta
# MAGIC Lake SCD2 recipe. SQL Server equivalent: the expire-then-insert pattern
# MAGIC in `etl.usp_load_dim_customer` / `_product` / `_employee`.

# COMMAND ----------

def merge_scd2(
    source_df: DataFrame,
    target_table: str,
    natural_keys: list[str],
    tracked_columns: list[str],
) -> None:
    if not spark.catalog.tableExists(target_table):
        (
            source_df.withColumn("is_current", F.lit(True))
            .withColumn("effective_date", F.current_date())
            .withColumn("expiry_date", F.to_date(F.lit("9999-12-31")))
            .write.format("delta")
            .saveAsTable(target_table)
        )
        return

    target = DeltaTable.forName(spark, target_table)
    current_df = target.toDF().filter("is_current = true")
    current_renamed = current_df.select(*[F.col(c).alias(f"cur_{c}") for c in current_df.columns])

    join_cond = [F.col(k) == F.col(f"cur_{k}") for k in natural_keys]
    change_cond = " OR ".join(f"cur_{c} IS NULL OR cur_{c} <> {c}" for c in tracked_columns)

    changed_or_new = (
        source_df.join(current_renamed, join_cond, "left")
        .where(change_cond)
        .select(source_df["*"])
    )

    key_expr = F.concat_ws("||", *[F.col(k) for k in natural_keys])
    staged_updates = changed_or_new.withColumn("merge_key", key_expr).unionByName(
        changed_or_new.withColumn("merge_key", F.lit(None).cast("string"))
    )

    target_key_expr = "concat_ws('||', " + ", ".join(f"tgt.{k}" for k in natural_keys) + ")"

    (
        target.alias("tgt")
        .merge(
            staged_updates.alias("src"),
            f"{target_key_expr} = src.merge_key AND tgt.is_current = true",
        )
        .whenMatchedUpdate(
            set={
                "is_current": "false",
                "expiry_date": "date_sub(current_date(), 1)",
                "updated_date": "current_timestamp()",
            }
        )
        .whenNotMatchedInsert(
            values={
                **{c: f"src.{c}" for c in natural_keys + tracked_columns},
                "is_current": "true",
                "effective_date": "current_date()",
                "expiry_date": "to_date('9999-12-31')",
            }
        )
        .execute()
    )


# COMMAND ----------

# MAGIC %md
# MAGIC ## Fact load — idempotent append
# MAGIC SQL Server equivalent: the anti-join pattern in
# MAGIC `etl.usp_load_fact_sales` / `_orders` / `_transactions`.

# COMMAND ----------

def merge_fact(source_df: DataFrame, target_table: str, natural_keys: list[str]) -> None:
    if not spark.catalog.tableExists(target_table):
        source_df.write.format("delta").saveAsTable(target_table)
        return

    target = DeltaTable.forName(spark, target_table)
    merge_condition = " AND ".join(f"tgt.{k} = src.{k}" for k in natural_keys)

    (
        target.alias("tgt")
        .merge(source_df.alias("src"), merge_condition)
        .whenNotMatchedInsertAll()
        .execute()
    )
