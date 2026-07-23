<!--
Draft content for the GitHub Release titled "v1.0.0" — paste this into the
release description box at github.com/mubeen01/Azure-Data-Engineering-Accelerator/releases/new.
Tag suggestion: v1.0.0, targeting main once Phases 2-9's work is committed.
This file is a draft, not a permanent part of the repo's documentation —
CHANGELOG.md remains the authoritative running history.
-->

# Azure Data Engineering Accelerator v1.0.0

A reusable, end-to-end framework for building Azure data platforms:
SQL warehouse, Azure Data Factory, Databricks, Infrastructure as Code,
monitoring/security — plus one complete industry accelerator (Banking)
proving all of it actually fits together.

## Highlights

**SQL Framework** (`src/sql/`) — a full star schema: 7 dimensions with
SCD Type 1 and Type 2 support, 3 fact tables, staging landing tables,
metadata-driven ETL (watermark pattern, audit logging, data quality
validation), columnstore indexing, and Synapse dedicated-pool
compatibility notes throughout.

**Synthetic Data Generator** (`tools/synthetic-data-generator/`) — a
configurable Python tool that generates realistic sample data instead of
committing static CSVs. Generate 1,000 rows for a quick test or 1,000,000
for load testing with one parameter. Banking domain fully implemented.

**Azure Data Factory Framework** (`src/adf/`) — metadata-driven, not
hand-built per table: a control table drives a generic orchestrator that
branches between full and incremental (watermark-based) load pipelines,
with retry policies and webhook failure notification.

**Databricks Medallion Framework** (`src/databricks/`) — Bronze (Auto
Loader), Silver (cleanse/conform), Gold (the same star schema as the SQL
path, via Delta Lake `MERGE` — including the NULL-merge-key trick for SCD
Type 2), a streaming variant, and OPTIMIZE/ZORDER/VACUUM maintenance.

**Infrastructure as Code** (`src/infrastructure/`) — the full resource set
in both Bicep and Terraform, kept functionally identical: storage, Key
Vault, SQL, Data Factory, Databricks, Log Analytics, and the RBAC wiring
between them. Zero errors/warnings on `az bicep build` and
`terraform validate`.

**Monitoring & Security** (`src/monitoring/`, `src/security/`) —
diagnostic settings and alerting layered on top of the infrastructure
above (not duplicating it), Entra ID admin access, a Databricks Access
Connector for Unity Catalog, and an opt-in CI/CD app registration using
GitHub Actions OIDC — no stored secrets.

**Banking Accelerator** (`examples/banking/`) — the proof that everything
above actually works together: real generated data, industry-specific SQL
extensions (`dim_account`, `dim_loan`), and load logic that reconciles two
genuine data-shape mismatches between the generator's output and the
generic framework's assumptions. Building this surfaced and fixed two real
bugs elsewhere in the stack (an off-by-one path bug in the generator, a
missing load-order guarantee in the ADF orchestrator) — see
`examples/banking/README.md`.

**Documentation** — `docs/getting-started.md`, `docs/troubleshooting.md`,
and three architecture deep-dives (medallion, deployment, security), plus
a README in every module.

## What's verified vs. what's reviewed

This release is honest about its own verification status rather than
overclaiming:

- **SQL**: database creation, schema creation, and all 7 dimension tables
  were run against a real, live SQL Server 2022 instance with zero errors.
  Facts, stored procedures, and the banking extensions are carefully
  reviewed but not yet run the same way.
- **Bicep/Terraform**: every template offline-validates cleanly. None has
  been applied against a real Azure subscription yet.
- **Databricks**: notebooks and the banking Asset Bundle are written and
  reviewed; none has run against a real Spark/Databricks cluster.
- **ADF**: pipeline JSON is structurally validated; none has run against a
  live Data Factory.

See `docs/troubleshooting.md` and each module's README for specifics.

## What's not in this release

- Healthcare, Retail, and Insurance accelerators — blocked on their
  synthetic data generators not existing yet (tracked for a future
  release).
- Microsoft Fabric and Azure Synapse-specific builds — deliberately
  deferred post-v1.0 (Synapse *compatibility* is already handled
  throughout `src/sql/` and `src/adf/`; a dedicated Synapse deployment is
  not).
- CI/CD pipelines beyond the Phase 1 placeholder workflow.

Full detail in `ROADMAP.md`'s "Out of v1.0 scope" section.

## Getting started

`docs/getting-started.md` has four paths in, including a Docker-only path
that needs no Azure subscription at all.

## Thanks

This is a v1.0.0 baseline, not a finished product — issues, discussions,
and PRs are welcome. See `CONTRIBUTING.md`.
