# Naming Conventions

Project-wide naming, one section per area. SQL has its own detailed
standard (`src/sql/00-standards/naming-standards.md`) — this page
summarizes it and covers everything else: ADF objects, Databricks
notebooks, Bicep/Terraform, Azure resources, and Python.

## SQL

Full standard: `src/sql/00-standards/naming-standards.md`. Highlights:

| What | Pattern | Example |
|---|---|---|
| Schema | one of `staging`, `dim`, `fact`, `etl`, `audit`, `rpt` | — |
| Dimension table | `dim.dim_<entity>` | `dim.dim_customer` |
| Fact table | `fact.fact_<entity>` | `fact.fact_transactions` |
| Staging table | `staging.stg_<source>_<entity>` | `staging.stg_banking_customers` |
| Control table | `etl.ctrl_<purpose>` | `etl.ctrl_pipeline_metadata` |
| Audit table | `audit.log_<purpose>` | `audit.log_etl_run` |
| Stored procedure | `etl.usp_<verb>_<object>` (never `sp_`) | `etl.usp_load_dim_customer` |
| Function | `etl.ufn_<purpose>` | `etl.ufn_get_watermark` |
| View | `rpt.vw_<purpose>` | `rpt.vw_sales_summary` |
| Primary key | `pk_<table>` | `pk_dim_customer` |
| Foreign key | `fk_<table>_<referenced_table>` | `fk_fact_sales_dim_customer` |
| Script file | `<NN>_<Verb>_<Object>.sql`, numeric folder order | `02_Create_Dim_Customer.sql` |

Surrogate keys are `<entity>_key`; natural/business keys from the source
system are `<entity>_id` — never conflate the two.

## Azure Data Factory objects

Three-letter type prefix + `snake_case` name (`src/adf/pipeline/`,
`src/adf/dataset/`, `src/adf/linkedService/`):

| Type | Prefix | Example |
|---|---|---|
| Pipeline | `pl_` | `pl_load_generic_full`, `pl_master_orchestrator` |
| Dataset | `ds_` | `ds_generic_delimited_file`, `ds_ctrl_pipeline_metadata` |
| Linked service | `ls_` | `ls_AdeaDW_AzureSqlDatabase`, `ls_AdeaKeyVault` |

Generic, reusable objects say so in the name (`pl_load_generic_full`);
industry- or source-specific ones name the thing itself, not "generic"
(e.g. a future `pl_load_banking_transactions` would be industry-specific
if the generic pipeline genuinely couldn't fit it — today it does, so no
such pipeline exists).

## Databricks / Fabric / Synapse notebooks

Folder = medallion layer, numbered in execution/dependency order;
filename = numbered within its folder, `Title_Case_With_Underscores`
(`src/databricks/`):

```text
00_common/        Shared helpers (utils.py — no number prefix on the file
                   itself, since it's imported, not run in sequence)
01_bronze/        01_Bronze_Autoloader_Ingest.py
02_silver/        01_Silver_Conform_Generic.py
03_gold/          01_Gold_Load_Dim_Scd1.py, 02_Gold_Load_Dim_Scd2.py,
                   03_Gold_Load_Fact.py
04_streaming/     01_Streaming_Bronze_To_Silver.py
05_optimization/  01_Optimize_And_Vacuum.py
```

A notebook name states what it does generically (`Gold_Load_Dim_Scd2`,
reusable via widgets for any SCD2 dimension); an industry-specific
notebook that can't be generic says which industry
(`examples/banking/databricks/gold_load_fact_transactions_banking.py`).

## Bicep

Module files: `camelCase.bicep`, one per resource type
(`src/infrastructure/bicep/modules/`):

```text
storage.bicep, keyVault.bicep, keyVaultSecret.bicep, sqlDatabase.bicep,
dataFactory.bicep, databricks.bicep, logAnalytics.bicep, rbac.bicep
```

## Terraform

Module folders: `snake_case`, mirroring the Bicep module list 1:1
(`src/infrastructure/terraform/modules/`):

```text
storage/, key_vault/, sql_database/, data_factory/, databricks/,
log_analytics/, rbac/
```

The pairing is deliberate — `keyVault.bicep` and `key_vault/` provision
the identical resource, just named per each tool's own convention. See
`docs/best-practices.md`'s "keep Bicep and Terraform functionally
identical" section.

## Azure resource names

`<type-abbreviation>-adea-<environment>`, with a deterministic hash
suffix on anything requiring global uniqueness
(`architecture/deployment-architecture.md`):

| Resource | Pattern | Example |
|---|---|---|
| Resource Group | `rg-adea-<environment>` | `rg-adea-dev` |
| Storage Account | `stadea<suffix>` | `stadea7f3k2p` |
| Key Vault | `kv-adea-<suffix>` | `kv-adea-7f3k2p` |
| SQL Server | `sql-adea-<suffix>` | `sql-adea-7f3k2p` |
| SQL Database | fixed name | `AdeaDW` |
| Data Factory | `adf-adea-<environment>` | `adf-adea-dev` |
| Databricks Workspace | `dbw-adea-<environment>` | `dbw-adea-dev` |
| Log Analytics | `log-adea-<environment>` | `log-adea-dev` |
| Databricks Access Connector | `dbac-adea-<environment>` | `dbac-adea-dev` |
| Shared managed identity | `id-adea-shared-<environment>` | `id-adea-shared-dev` |

Storage containers: `raw` (landing zone for source data) and
`checkpoints` (Structured Streaming checkpoint locations) — not per-source
or per-industry containers; industry data is partitioned by path within
`raw`, not by container.

Key Vault secrets: `<purpose>-<detail>`, e.g. `adea-dw-sql-password`.

## Python (synthetic data generator)

- Domain modules: `snake_case`, matching the domain name exactly
  (`generator/domains/banking.py`, registered as `"banking"` in
  `cli.py`'s `DOMAIN_GENERATORS`).
- Every domain module exposes one function, `generate(rows, seed) ->
  dict[str, pd.DataFrame]` — the dict keys become output filenames
  (`{table_name}.csv`), so key names should match the target staging
  table's entity name (`customers`, `accounts`, not abbreviations).
- CLI flags: `kebab-case`, long-form only (`--domain`, `--rows`,
  `--output-dir`, `--seed`) — no single-letter short flags, so a command
  is self-documenting without `--help`.

## Documentation files

`kebab-case.md` throughout `docs/` and `architecture/`
(`getting-started.md`, `deployment-architecture.md`) — matches this file's
own name. Every module folder under `src/`, `tools/`, and `examples/`
names its own doc simply `README.md`, not a topic-specific name, since
there's exactly one per folder.
