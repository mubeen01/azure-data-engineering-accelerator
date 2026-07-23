# Azure Databricks Framework

Medallion architecture (Bronze → Silver → Gold) on Delta Lake, implementing
the same dimensional model as `src/sql/` — a lakehouse-native alternative
(or complement) to the Azure SQL star schema, for teams that want the
transform layer to run on Databricks instead of, or in addition to, T-SQL
stored procedures.

Notebooks are stored in the plain-text Databricks source format
(`# Databricks notebook source`, `# COMMAND ----------` cell markers) so
they're diffable and importable straight into a Git-connected Databricks
Repo.

**Not executed or cluster-tested** — there's no Spark runtime available
here to run these against. Written and reviewed for correctness, not
verified end-to-end; treat that as the one open item before relying on them.

## Folder structure

```text
00_common/       Shared merge_scd1 / merge_scd2 / merge_fact helpers,
                 imported into other notebooks via %run
01_bronze/       Auto Loader ingestion (schema evolution on, availableNow trigger)
02_silver/       Cleansing/conforming template (trim, drop-null-key, dedup)
03_gold/         SCD1 dimension load, SCD2 dimension load, fact load
04_streaming/    Continuous variant: Auto Loader + foreachBatch upsert
05_optimization/ OPTIMIZE/ZORDER/VACUUM, table properties
```

## How each layer maps to the SQL framework

| Databricks | SQL equivalent |
|---|---|
| `00_common/utils.merge_scd1` | `etl.usp_load_dim_source_system` / `_currency` / `_location` |
| `00_common/utils.merge_scd2` | `etl.usp_load_dim_customer` / `_product` / `_employee` (expire-then-insert) |
| `00_common/utils.merge_fact` | `etl.usp_load_fact_sales` / `_orders` / `_transactions` (anti-join insert) |
| `05_optimization` OPTIMIZE/ZORDER | `src/sql/08-indexes/` columnstore + `12-maintenance` rebuild job |

## SCD Type 2 in Delta: the NULL merge-key pattern

Delta's `MERGE` can't both expire an old row and insert a new one for the
same key in a single `WHEN MATCHED` clause. The standard workaround — used
in `merge_scd2` — stages every new-or-changed row twice: once tagged with
its real natural key (matches the existing current row, if any, and
expires it) and once tagged with `merge_key = NULL` (guaranteed not to
match anything, forcing an insert of the new current row). See the comment
in `00_common/utils.py` for the full walkthrough.

## Generic vs. example-specific notebooks

`01_bronze`, `02_silver`, and `03_gold`'s SCD1/SCD2 notebooks are fully
generic — driven by widgets, reusable for any entity by pointing them at
different tables/columns. `03_gold/03_Gold_Load_Fact.py` is *not* fully
generic: each fact needs a different set of dimension joins, so it's
written for `fact_sales` with a comment on how `fact_orders`/
`fact_transactions` follow the same shape — same tradeoff the SQL framework
made with one stored procedure per fact rather than a single parameterized
one.

## What's not here yet

- Only one worked example per notebook (source_system for SCD1, customer
  for SCD2, sales for the fact) — extending to every dimension/fact is
  mechanical (swap widget values) but not pre-populated as separate files.
- Real ADLS mount paths / Unity Catalog catalog and schema names are
  placeholders (`/mnt/adea/...`, catalog `adea`) — Phase 6 (IaC) is where
  those become real deployed resources.
- No Databricks Job/workflow definitions wiring these notebooks into a
  schedule yet — that's a natural Phase 6/8 follow-on once real
  infrastructure exists to schedule against.
