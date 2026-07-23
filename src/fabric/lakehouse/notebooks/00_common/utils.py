# Fabric notebook source
# MAGIC %md
# MAGIC # Common utilities (Fabric Lakehouse)
# MAGIC Adapted from `src/databricks/00_common/utils.py`. Import with
# MAGIC `%run 00_common_utils` (Fabric notebook `%run` resolves by notebook
# MAGIC name within the workspace, not a relative file path — attach this
# MAGIC notebook and the caller to the same workspace, or use the
# MAGIC `%run notebookName { parameters }` form if you need to pass values).
# MAGIC
# MAGIC **Not verified against a live Fabric workspace** — written and
# MAGIC reviewed against Fabric's documented notebook/Lakehouse APIs, same
# MAGIC honesty standard as `src/databricks/`'s own "not cluster-tested" note.
# MAGIC Fabric's exact Git-sync item format (the `.platform` metadata file
# MAGIC alongside a synced notebook) isn't reproduced here — this is the
# MAGIC notebook body only.

# COMMAND ----------

from pyspark.sql import DataFrame, functions as F
from delta.tables import DeltaTable

# Fabric Lakehouse tables are referenced as <lakehouse_name>.<table_name>
# (two-part) rather than Databricks Unity Catalog's <catalog>.<schema>.<table>
# (three-part) — Fabric doesn't have a three-level catalog/schema namespace
# the same way. Medallion layers are modeled as three separate Lakehouse
# items rather than three schemas in one catalog.
BRONZE_LAKEHOUSE = "lh_bronze"
SILVER_LAKEHOUSE = "lh_silver"
GOLD_LAKEHOUSE = "lh_gold"


def bronze_table(entity: str) -> str:
    return f"{BRONZE_LAKEHOUSE}.{entity}"


def silver_table(entity: str) -> str:
    return f"{SILVER_LAKEHOUSE}.{entity}"


def gold_table(entity: str) -> str:
    return f"{GOLD_LAKEHOUSE}.{entity}"


# COMMAND ----------

# MAGIC %md
# MAGIC ## SCD Type 1 — overwrite in place
# MAGIC Identical logic to the Databricks version — Delta `MERGE` isn't
# MAGIC platform-specific. SQL Server equivalent:
# MAGIC `etl.usp_load_dim_source_system` in `src/sql/06-stored-procedures/`.

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
# MAGIC Same pattern as `src/databricks/00_common/utils.py` — see that file's
# MAGIC comment for the full walkthrough of why the NULL merge-key is needed.

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
