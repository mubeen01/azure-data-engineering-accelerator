# Azure Data Factory Framework

A metadata-driven ingestion framework: one generic pipeline pair (full load,
incremental load) plus an orchestrator, instead of hand-building a pipeline
per source object. Adding a new object means inserting a row in
`etl.ctrl_pipeline_metadata` (`src/sql/06-stored-procedures/11_Create_Pipeline_Metadata_Table.sql`),
not authoring new ADF resources.

## Folder structure (ADF Git-mode layout)

```text
linkedService/   Connections: Key Vault, ADLS Gen2 storage, AdeaDW Azure SQL DB
dataset/         Generic parameterized datasets (one file dataset, one SQL
                 table dataset, reused by every source object) + the fixed
                 dataset over etl.ctrl_pipeline_metadata
pipeline/        pl_master_orchestrator, pl_load_generic_full,
                 pl_load_generic_incremental, pl_notify_failure
```

This mirrors the folder structure ADF Studio itself uses when a factory is
Git-connected — these JSON files are what you'd see (and could import) in
that repo.

## How it fits together

1. **`pl_master_orchestrator`** looks up every active row in
   `etl.ctrl_pipeline_metadata` — ordered by `load_priority` (lower runs
   first), then `object_name` — then `ForEach`-loops over them sequentially.
   `load_priority` is what actually enforces dimension-before-fact load
   order (e.g. Phase 8's banking `customer` before `account`/`loan` before
   `transaction`, since accounts and transactions FK to customers);
   `isSequential: true` alone only guarantees rows run one at a time, not
   in a particular order without that column and the Lookup's `ORDER BY`.
2. For each row, an `If Condition` on `load_type` calls either
   **`pl_load_generic_full`** or **`pl_load_generic_incremental`**, passing
   the row's columns as pipeline parameters — source file location, sink
   staging table, and which `etl.usp_load_*` procedure to run afterward.
3. **Full load**: truncate the staging table, copy the source file in,
   run the load procedure.
4. **Incremental load**: a flat file has no row-level change-tracking
   column, so "incremental" here is file-level — a `Get Metadata` activity
   reads the file's `lastModified`, compares it to
   `etl.ufn_get_watermark(source_system, object_name)` via a `Lookup`, and
   only copies + loads + advances the watermark
   (`etl.usp_update_watermark`) if the file is newer. Once a real
   transactional source is wired in (Phase 8), the copy activity's source
   query can filter by `watermark_column` instead — the pipeline shape
   doesn't need to change.
5. On failure of the `ForEach`, **`pl_notify_failure`** posts to a webhook
   (Teams/Slack). Retry policies (2–3 attempts) sit on the Copy and
   Execute Pipeline activities themselves — per-object failures don't need
   a human until retries are exhausted.

Every load procedure invoked here already writes its own start/end/status
row to `audit.log_etl_run` (Phase 2) — ADF isn't responsible for that
logging, only for triggering it and reacting to failure.

## What Phase 8 still has to do

- Populate `etl.ctrl_pipeline_metadata` with one row per real source object
  per industry (only one illustrative row exists today —
  `src/sql/09-seed-data/02_Seed_Pipeline_Metadata_Example.sql`).
- Replace the placeholder values in the linked services (`<storage-account-name>`,
  `<server-name>`, `<key-vault-name>`, `<secret-name>`) with real deployed
  resource names — those come from Phase 6 (Infrastructure as Code).
- Set a real `p_webhook_url` for `pl_notify_failure`.

## Auth model

- Storage: system-assigned Managed Identity — no stored secret. Grant the
  Data Factory's identity `Storage Blob Data Contributor` on the storage
  account.
- Azure SQL Database: SQL authentication, password stored as an Azure Key
  Vault secret, never inline in the linked service.

Both choices anticipate Phase 7 (Security) rather than duplicate it.
