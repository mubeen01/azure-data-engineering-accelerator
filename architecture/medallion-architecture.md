# Medallion Architecture

ADEA implements the Bronze → Silver → Gold pattern twice, on purpose: once
as a SQL/T-SQL star schema (`src/sql/`), once as Delta Lake notebooks
(`src/databricks/`). They're not duplicates of each other — they're two
engines solving the same modeling problem, so a team can pick one, the
other, or both depending on where their workloads run. This document
describes the pattern once and cross-references both implementations.

## The three layers

**Bronze — raw, as-ingested.**
In the SQL path, this is `staging.*` (`src/sql/06-stored-procedures/00_Create_Staging_Tables.sql`)
— loosely typed (mostly `VARCHAR`), one landing table per source object,
no validation yet. In the Databricks path, it's `{catalog}.bronze.*`,
populated by Auto Loader (`src/databricks/01_bronze/01_Bronze_Autoloader_Ingest.py`)
with schema evolution on and `_ingest_file`/`_ingest_timestamp` columns
added for lineage. Both are deliberately forgiving: type/quality
enforcement happens one layer up, not here.

**Silver — cleansed and conformed.**
The SQL path doesn't have a separate physical Silver layer — type
casting/validation happens inline in each `etl.usp_load_*` procedure as it
reads from staging (e.g. `TRY_CAST(stg.quantity AS DECIMAL(18,4))` in
`src/sql/06-stored-procedures/08_Load_Fact_Sales.sql`). The Databricks path
does have a physical Silver layer (`src/databricks/02_silver/01_Silver_Conform_Generic.py`):
trim, drop rows missing a natural key, de-duplicate keeping the latest
`_ingest_timestamp`. This is the one deliberate structural difference
between the two engines' medallion implementations — Delta workloads
benefit from a materialized, queryable "clean" checkpoint; a stored
procedure doesn't need one to get the same effect.

**Gold — the dimensional model.**
Both paths converge on the same star schema: `dim_date`, `dim_customer`,
`dim_product`, `dim_location`, `dim_employee`, `dim_currency`,
`dim_source_system`, plus `fact_sales`, `fact_orders`, `fact_transactions`
(`src/sql/03-dimensions/`, `src/sql/04-facts/`). The Databricks path
targets the same table and column names (`{catalog}.gold.dim_customer`,
etc.) via `src/databricks/03_gold/`, so a BI tool or downstream consumer
doesn't need to know or care which engine actually produced a given Gold
table.

## Slowly Changing Dimensions

Both engines implement SCD Type 1 (overwrite in place: `dim_date`,
`dim_currency`, `dim_source_system`, `dim_location`) and SCD Type 2
(track history: `dim_customer`, `dim_product`, `dim_employee`, and Phase
8's banking-specific `dim_account`/`dim_loan`) — same tables get the same
treatment regardless of engine.

- **SQL**: SCD1 uses `MERGE` (`src/sql/06-stored-procedures/02_Load_Dim_Source_System.sql`
  and similar). SCD2 uses an expire-then-insert pattern —
  `UPDATE ... SET is_current = 0` for changed rows, then `INSERT` the new
  current version — deliberately *not* `MERGE`, so it stays portable to
  Synapse dedicated pools where `MERGE` isn't supported
  (`src/sql/06-stored-procedures/05_Load_Dim_Customer.sql`).
- **Databricks**: SCD1 is a straightforward Delta `MERGE`
  (`src/databricks/00_common/utils.py`'s `merge_scd1`). SCD2 uses the
  standard Delta "NULL merge-key" trick — every changed/new row is staged
  twice, once tagged with its real key (matches and expires the current
  row) and once tagged with `merge_key = NULL` (guaranteed not to match
  anything, forcing an insert) — see `merge_scd2` in the same file for the
  full walkthrough. Necessary because Delta's `MERGE` can't expire an old
  row and insert its replacement in a single `WHEN MATCHED` clause.

## Facts

Both engines use append-only, idempotent loads keyed on each fact's
natural/degenerate key (`source_system` + `sale_id`, etc.) — an anti-join
(`WHERE NOT EXISTS`) in SQL, `merge_fact`'s `whenNotMatchedInsertAll` in
Databricks. Neither ever updates a fact row in place.

Not every fact notebook/procedure is fully generic — `fact_sales` is (one
parameterized procedure/notebook), but `fact_transactions` needed its own
banking-specific version in both engines (`examples/banking/sql/06_Load_Fact_Transactions_Banking.sql`,
`examples/banking/databricks/gold_load_fact_transactions_banking.py`),
because banking's source data only carries `account_id`, not `customer_id`
directly — `customer_key` has to be resolved through `dim_account` first.
This is the real, worked example of "the generic pattern doesn't always
fit as-is" — see `examples/banking/README.md`'s reconciliation section for
the full story.

## Streaming

The Databricks path has a continuous variant
(`src/databricks/04_streaming/01_Streaming_Bronze_To_Silver.py`): the same
Auto Loader source, `trigger(processingTime=...)` instead of
`availableNow`, applying cleanse + upsert per micro-batch via
`foreachBatch`. Not every entity needs this — it's suited to
near-real-time sources (transactions), not slowly-changing reference data.
There's no SQL-side equivalent; the ADF pipelines
(`src/adf/pipeline/pl_load_generic_incremental.json`) handle "how fresh"
differently, via a file-level watermark check rather than a continuous
stream.

## Optimization

- **SQL**: clustered columnstore index on every fact table
  (`src/sql/08-indexes/01_Create_Fact_Columnstore_Indexes.sql`), a `date_key`
  index for common time-range filters, periodic `REORGANIZE` maintenance
  (`src/sql/12-maintenance/01_Rebuild_Columnstore_Indexes.sql`).
- **Databricks**: `OPTIMIZE ... ZORDER BY` (typically on `date_key`, same
  filtering rationale) and `VACUUM` with the 7-day-minimum retention
  guardrail (`src/databricks/05_optimization/01_Optimize_And_Vacuum.py`).

## Status

Both implementations are written and internally consistent; the SQL path
has been partially verified against a real, live SQL Server 2022 container
(database, schemas, and all 7 dimension tables created successfully — see
the CHANGELOG for what was and wasn't covered before that test run was
intentionally stopped). The Databricks path has not been run against a
real Spark cluster — see `src/databricks/README.md`.
