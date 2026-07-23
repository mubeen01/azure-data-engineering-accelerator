# Changelog

All notable changes to this project will be documented in this file.

The format follows the principles of Keep a Changelog and Semantic Versioning.

---

## [Unreleased]

### Added

- Healthcare and Retail industry accelerators (`examples/healthcare/`,
  `examples/retail/`), the second and third fully wired end-to-end
  examples after banking, each with `sql/`, `adf/README.md` (no pipeline
  JSON — the framework is metadata-driven, so each contribution is a
  `etl.ctrl_pipeline_metadata` seed script plus an explanation),
  `databricks/` (a bundle + bespoke Gold fact notebooks), `README.md`,
  and `architecture.md`. Healthcare needed 4 entirely new tables
  (`dim_patient`, `dim_provider`, `fact_claims`, `fact_pharmacy` — no
  generic-model equivalent exists) and hit the same embedded-address
  reconciliation banking's customer loader already solved, now
  generalized into a repeatable pattern. Retail is the opposite case:
  `dim.dim_customer`, `dim.dim_product`, and `fact.fact_orders` are all
  *reused generic tables, unmodified* — only `fact.fact_inventory` is
  new — but every object still needed its own load procedure, since the
  generic procedures hardcode their staging table by name and the
  generic staging tables (`src/sql/06-stored-procedures/00_Create_Staging_Tables.sql`)
  turn out not to be a column-for-column match for any real generator
  output, banking's/healthcare's/retail's included — confirmed those
  generic staging tables have never actually been used by a real
  pipeline in this repo. `.github/workflows/ci.yml`'s `validate-sql` and
  `validate-python` jobs extended to cover both new accelerators'
  scripts and notebooks, alongside banking's.
- Healthcare and Retail domains for the synthetic data generator
  (`generator/domains/healthcare.py`, `generator/domains/retail.py`),
  completing Phase 3 Milestone 3.2 for two of the three remaining
  domains (Insurance still open — no dataset shape defined yet). Same
  pattern as `banking.py`: a primary entity count (`--rows`) scaled to
  related tables via fixed ratios, referentially consistent. Healthcare:
  `patients`, `providers`, `claims` (ICD-10/CPT-style diagnosis/procedure
  code pairs), `pharmacy`. Retail: `customers`, `products`, `inventory`,
  `orders`. Both registered in `cli.py`'s `DOMAIN_GENERATORS`, smoke-tested
  locally (`--rows 50`) before generating real output, and now included in
  `.github/workflows/ci.yml`'s `validate-python` smoke-test step alongside
  banking. `datasets/healthcare/` and `datasets/retail/` populated for
  real at `--rows 2000 --seed 42` (matching banking's existing scale) —
  previously 0-byte placeholder files.
- Expanded `docs/`: `installation.md` (per-path tooling prerequisites),
  `architecture.md` (a task-oriented map into `architecture/`'s detailed
  design docs), `best-practices.md` (design decisions this repo actually
  follows, e.g. extend `src/` via `examples/` rather than forking it),
  `coding-standards.md` (project-wide, covering Python/ADF JSON/Bicep/
  Terraform — SQL's own standard is summarized and linked, not
  duplicated), `naming-conventions.md` (same treatment for naming), and
  `faq.md`. Also filled `architecture/overview.md`, previously a 0-byte
  placeholder despite `docs/getting-started.md` already linking to it as
  "the high-level vision and principles." README's Documentation section
  and `docs/getting-started.md` now link to all of the above.
- Synthetic data generator scaffold (`tools/synthetic-data-generator/`) with
  a working banking domain implementation (customers, accounts,
  transactions, loans) and a configurable `--rows`/`--seed` CLI.
- Metadata-driven Azure Data Factory framework (`src/adf/`): linked services
  (Key Vault, ADLS Gen2 via Managed Identity, AdeaDW via Key
  Vault-referenced SQL auth), generic parameterized file/SQL datasets,
  generic full-load and incremental-load pipelines (file-level watermark
  pattern via `Get Metadata` + `etl.ufn_get_watermark`), a metadata-driven
  orchestrator (`Lookup` + `ForEach` over `etl.ctrl_pipeline_metadata`), and
  a webhook failure-notification pipeline.
- `etl.ctrl_pipeline_metadata` control table and `etl.usp_update_watermark`
  procedure in `src/sql/`, supporting the ADF framework above.

- Databricks medallion framework (`src/databricks/`): shared SCD Type 1/2
  and fact merge helpers (Delta Lake's NULL merge-key SCD2 pattern), a
  generic Auto Loader Bronze ingestion notebook, a generic Silver
  cleanse/conform template, generic SCD1/SCD2 Gold dimension load
  notebooks, a `fact_sales` Gold load notebook, a continuous
  streaming + `foreachBatch` upsert variant, and an
  OPTIMIZE/ZORDER/VACUUM maintenance notebook.

- Infrastructure as Code (`src/infrastructure/`) in both Bicep and
  Terraform, kept functionally identical: Resource Group, ADLS Gen2 storage
  (raw/checkpoints containers), RBAC-authorized Key Vault, Azure SQL Server
  + `AdeaDW` database, Data Factory (system-assigned identity), Databricks
  workspace (premium), Log Analytics workspace, and the RBAC role
  assignments ADF needs for storage + Key Vault access. Bicep validated
  with `az bicep build` (zero errors/warnings); Terraform validated with
  `terraform init` + `terraform validate` (both pass) and formatted with
  `terraform fmt`.

- Monitoring and Security (`src/monitoring/`, `src/security/`), both in
  Bicep and Terraform, both deploying on top of `src/infrastructure/`
  rather than duplicating it: diagnostic settings (storage, Key Vault, SQL,
  Data Factory, Databricks) into the Phase 6 Log Analytics workspace, an
  action group + ADF-failure/SQL-high-DTU metric alerts, an Entra ID admin
  on the SQL server, a shared user-assigned managed identity with
  read-only storage access, a Databricks Access Connector (Unity Catalog's
  Azure-native storage identity) with read-write storage access, and an
  opt-in Entra ID app registration + GitHub Actions OIDC federated
  credential for CI/CD (Terraform only). All offline-validated.

- Banking industry accelerator (`examples/banking/`), the first fully
  wired end-to-end example: real generated data (2,000 customers/2,800
  accounts/24,000 transactions/600 loans), `dim_account` + `dim_loan`
  (SCD Type 2, layered on the generic SQL framework via FK), banking-shaped
  staging tables, load procedures reconciling two real data-shape
  mismatches (embedded customer address, transaction-to-customer via
  account), real `etl.ctrl_pipeline_metadata` rows, and a 12-task
  Databricks Asset Bundle job.
- `load_priority` column on `etl.ctrl_pipeline_metadata` plus an
  `ORDER BY` on the ADF orchestrator's Lookup query
  (`src/adf/pipeline/pl_master_orchestrator.json`) — dependent load order
  (dimensions before facts) had no actual guarantee before this.

- Documentation (Phase 9): `architecture/medallion-architecture.md`,
  `architecture/deployment-architecture.md`, and
  `architecture/security-architecture.md` written (previously empty
  placeholders); `docs/getting-started.md` and `docs/troubleshooting.md`
  added; `README.md`'s Documentation section now links to real docs
  instead of "Coming Soon".

- Phase 10 launch-prep content (drafted, not yet executed — see below):
  `RELEASE_NOTES_v1.0.0.md`, `.github/GOOD_FIRST_ISSUES.md`,
  `.github/COMMUNITY_LAUNCH.md` (Project board + Discussions welcome
  post), and a rewritten `CONTRIBUTING.md` describing the actual project
  structure instead of generic placeholder text.

- Microsoft Fabric support (`src/fabric/`), reversing the earlier
  post-v1.0 deferral: a Fabric Warehouse compatibility document (the one
  non-negotiable difference from `src/sql/` is that Fabric Warehouse
  doesn't support `IDENTITY` columns at all — documented with the
  `SEQUENCE`-based rewrite pattern), Lakehouse notebooks adapted from
  `src/databricks/` (batch read replacing Databricks-proprietary Auto
  Loader; two-part `lakehouse.table` naming instead of Unity Catalog's
  three-part namespace), and a Fabric Data Factory pipeline chaining
  Bronze → Silver → Gold for one entity, adapted from `src/adf/`'s
  pattern. Notebook Python syntax validated (`py_compile`); pipeline JSON
  confirmed well-formed. Not verified against a live Fabric workspace —
  no offline validation tool exists for Fabric item definitions the way
  `az bicep build`/`terraform validate` exist for IaC.

- Azure Synapse Analytics support (`src/synapse/`), reversing the earlier
  post-v1.0 deferral: a serverless SQL Pool layer querying Gold Delta
  tables directly via `OPENROWSET ... FORMAT = 'DELTA'` (no data
  movement), Spark pool notebooks adapted from `src/databricks/` (Synapse's
  own default Spark metastore naming), and one pipeline demonstrating the
  `SynapseNotebook` activity type. Dedicated SQL Pool was already covered
  by Phase 2's compatibility notes. Not verified against a live Synapse
  workspace — same caveat as Fabric.
- Real CI (`.github/workflows/ci.yml`), reversing the earlier "intentionally
  skipped for v1.0" decision: 5 jobs — `validate-bicep`, `validate-terraform`
  (matrixed across all 3 IaC configs), `validate-json` (every ADF/Fabric/
  Synapse pipeline file), `validate-python` (syntax-checks every notebook
  plus a live smoke-test run of the synthetic data generator), and
  `validate-sql` (a real SQL Server 2022 service container running every
  script in `src/sql/` and `examples/banking/sql/`, in order — automating
  the manual Docker verification done earlier in this project rather than
  duplicating a separate check). Not yet observed running on GitHub's
  actual infrastructure — written and reasoned through carefully, first
  real run happens on push.

### Verified

- Ran `src/sql/01_Create_Database.sql`, `02_Create_Schemas.sql`, and all 7
  `03-dimensions/` scripts against a real, live SQL Server 2022 Docker
  container (`mcr.microsoft.com/mssql/server:2022-latest`) — every script
  executed with zero errors: database, all 6 schemas, and `dim_date`,
  `dim_source_system`, `dim_currency`, `dim_location`, `dim_customer`,
  `dim_product`, `dim_employee` all created successfully, including the
  filtered unique indexes enforcing the SCD Type 2 `is_current` invariant.
  Stopped there at the user's request before covering facts, stored
  procedures, or the banking extensions — those remain reviewed-but-not-executed,
  same as before. Test container and cached image removed afterward.

### Fixed

- `tools/synthetic-data-generator/generator/cli.py`: default `--output-dir`
  resolved one directory level too shallow (`tools/datasets/<domain>/`
  instead of `datasets/<domain>/`) — invisible in Phase 3's smoke test
  since that test always passed an explicit `--output-dir`. Found by
  actually running the generator for real in Phase 8.

### Changed

- Clarified in `ROADMAP.md` that `src/cicd/`, `src/fabric/`, and
  `src/synapse/` (scaffolded in Phase 1) are explicitly out of v1.0 scope,
  not forgotten work — Fabric/Synapse deferred to post-v1.0 per the
  original pre-master-plan ROADMAP, CI/CD staying at the Phase 1 placeholder
  for now.

### In Progress

- Healthcare, retail, and insurance generators and accelerators (Phase 3
  Milestone 3.2 / Phase 8) — blocked on the generators not existing yet.
- Databricks notebooks (generic and banking-specific) are written and
  reviewed but not yet run against a real Spark/Databricks cluster;
  `databricks bundle validate` needs a reachable workspace to fully pass.
- None of the IaC (Phase 6 or Phase 7) or banking's SQL/ADF has been run
  against a real Azure subscription yet — offline-validated/reviewed only.
- None of this work (Phases 2-9) has been committed to git yet, and
  nothing has been pushed to `origin/main` — pending review of the
  working tree. The actual GitHub Release, Issues, Discussions, and
  Project board (Phase 10) haven't been created either; `gh` CLI isn't
  installed in this environment, so that's a manual step using the
  drafted content above.

---

## [0.2.0] - 2026-07-22

### Added

- SQL framework under `src/sql/`: naming and coding standards, database and
  schema creation scripts, 7 core dimensions (including `dim_date` seed
  data), 3 core facts, staging landing tables, audit/watermark control
  tables, SCD Type 1 and Type 2 load procedures, a watermark utility
  function, a data quality validation procedure, a representative reporting
  view, columnstore/supporting indexes, performance guidance, and
  maintenance jobs (columnstore rebuild, audit log purge).

### Changed

- Moved the SQL framework from a root-level `sql/` folder into `src/sql/`,
  aligning it with the `src/{adf,databricks,infrastructure,monitoring,...}`
  layered structure already scaffolded in Phase 1.

---

## [0.1.0] - 2026-07-22

### Added

- Initial repository structure
- Documentation framework
- Project roadmap
- Contributing guidelines
- Security policy
- Code of conduct
- MIT License
- Azure Data Engineering Accelerator foundation