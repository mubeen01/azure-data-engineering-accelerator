# Azure Data Engineering Accelerator (ADEA) — v1.0 Master Plan

Status legend: ✅ done · 🚧 in progress · ⏳ not started

---

## Current status at a glance (2026-07-23)

**Fully built and pushed to `origin/main`** (`github.com/mubeen01/Azure-Data-Engineering-Accelerator`,
commit `482e8a6`): Phases 1, 2, 6, 7, 9, plus Fabric, Synapse, and CI/CD
(all three reversed from an earlier "deferred" decision). Phases 3, 4, 5,
8, 10 are 🚧 partially done — see each phase section below for exactly
what's missing.

### What's done, module by module

| Module | Status |
|---|---|
| `src/sql/` | ✅ Full star schema, ETL, optimization. Database/schema/dimension creation **verified against a real, live SQL Server 2022 container** (facts/procs/banking extensions reviewed but not run the same way) |
| `tools/synthetic-data-generator/` | 🚧 Banking, Healthcare, Retail domains done (`datasets/{banking,healthcare,retail}/` all populated at 2,000-row scale); Insurance not started |
| `src/adf/` | ✅ Generic metadata-driven framework. JSON structurally validated, not run against a live Data Factory |
| `src/databricks/` | ✅ Bronze/Silver/Gold/streaming/optimization notebooks. Python-valid, not run against a live Spark cluster |
| `src/infrastructure/` | ✅ Bicep + Terraform, full resource set. Offline-validated (zero errors), not deployed to a real subscription |
| `src/monitoring/`, `src/security/` | ✅ Diagnostic settings, alerts, RBAC, Entra admin, CI/CD app registration. Offline-validated, not deployed |
| `src/fabric/` | ✅ Warehouse compatibility doc, Lakehouse notebooks, one pipeline. Python/JSON-valid, no Fabric-equivalent of `bicep build` exists to validate further |
| `src/synapse/` | ✅ Serverless SQL views, Spark notebooks, one pipeline. Same verification ceiling as Fabric |
| `examples/banking/`, `examples/healthcare/`, `examples/retail/` | ✅ All three built end-to-end — real generated data through SQL → ADF (metadata-driven) → Databricks, plus per-example `architecture.md`. Insurance blocked on the generator gap above |
| `architecture/`, `docs/` | ✅ All written, cross-referenced to real files |
| `.github/workflows/ci.yml` | ✅ 5 real jobs (Bicep, Terraform, JSON, Python, live-SQL-Server). **Not yet observed running** — first real execution happens whenever GitHub picks up a push |
| Phase 10 (Release/Issues/Discussions/Project board) | 🚧 Content drafted (`RELEASE_NOTES_v1.0.0.md`, `.github/GOOD_FIRST_ISSUES.md`, `.github/COMMUNITY_LAUNCH.md`); none of the actual GitHub-side objects created yet (needs `gh` CLI or the web UI) |

### The three genuinely open threads

1. **Insurance is the one remaining industry with nothing built** — no
   generator, no dataset shape, no accelerator. Banking, Healthcare, and
   Retail are all now built end-to-end (Phase 8); see
   `.github/GOOD_FIRST_ISSUES.md`'s "Add the Insurance domain to the
   synthetic data generator" for the concrete starting point — real
   design work (no existing shape to copy), more so than the other three
   were.
2. **Nothing has been deployed anywhere real yet.** Every SQL/Bicep/
   Terraform/ADF/Databricks/Fabric/Synapse artifact is written and
   validated to the ceiling this environment allows (offline compilers,
   or one live SQL Server container test) — none of it has touched a
   real Azure subscription, Databricks workspace, Fabric tenant, or
   Synapse workspace. That first real deployment is the next thing that
   would surface genuinely new information, the way the banking
   accelerator surfaced the generator path bug and the ADF load-order bug,
   and the healthcare/retail accelerators surfaced that the framework's
   own generic staging tables (`src/sql/06-stored-procedures/00_Create_Staging_Tables.sql`)
   have never actually been used by any real pipeline in this repo —
   every accelerator so far needed its own (see `examples/retail/README.md`'s
   "what's still not done" section).
3. **CI just went live in this push and hasn't run yet.** Worth checking
   the Actions tab on GitHub after this — if the `validate-sql` job's
   SQL Server service container doesn't come up cleanly on GitHub's
   runners the way it did locally, that's the first thing to debug. It
   now runs three examples' worth of SQL (banking, healthcare, retail),
   not just banking's.

### Suggested next session's starting point

Pick one, depending on what you want to learn next:

- **Design the Insurance domain**: no existing shape to copy from this
  time (`.github/GOOD_FIRST_ISSUES.md`) — real schema design work
  (policies, claims, premiums?) before any generator code gets written.
- **Compare how the three accelerators' reconciliation stories differ**:
  `examples/banking/README.md`, `examples/healthcare/README.md`, and
  `examples/retail/README.md` each hit a different flavor of "the generic
  framework doesn't just work" — worth reading together before deciding
  what Insurance's accelerator should reuse vs. rebuild.
- **Prove a real deployment**: run `src/infrastructure/`'s Bicep or
  Terraform against an actual Azure subscription for the first time —
  everything since Phase 6 has been offline-validated, never deployed.
- **Watch CI actually run**: check the Actions tab on GitHub now that
  `.github/workflows/ci.yml` has real jobs, and fix whatever the
  `validate-sql` job's live SQL Server container reveals that local
  testing didn't.

---

## Phase 1 — Foundation ✅

- ✅ Repository created
- ✅ Folder structure
- ✅ README
- ✅ LICENSE
- ✅ CONTRIBUTING
- ✅ CODE_OF_CONDUCT
- ✅ SECURITY
- ✅ ROADMAP
- ✅ CHANGELOG
- ✅ GitHub templates
- ✅ CI workflow
- ✅ Architecture folder
- ✅ Dataset structure

---

## Phase 2 — SQL Framework ✅

Goal: a reusable SQL framework that all future examples use. Lives in `src/sql/`.

- ✅ **2.1 SQL Foundation** — `src/sql/README.md`, naming standards, SQL coding
  standards (`src/sql/00-standards/`), database + schema creation scripts.
- ✅ **2.2 Core Dimensions** — `dim_date`, `dim_customer`, `dim_product`,
  `dim_location`, `dim_employee`, `dim_currency`, `dim_source_system`
  (`src/sql/03-dimensions/`).
- ✅ **2.3 Core Facts** — `fact_sales`, `fact_orders`, `fact_transactions`
  (`src/sql/04-facts/`).
- ✅ **2.4 ETL Components** — staging landing tables, audit/watermark control
  tables, SCD Type 1 and Type 2 load procedures, a watermark utility function,
  a validation procedure, and a representative reporting view
  (`src/sql/06-stored-procedures/`, `07-functions/`, `10-validation/`, `05-views/`).
- ✅ **2.5 Optimization** — clustered columnstore + supporting indexes,
  performance guidance (including Synapse distribution strategy), statistics
  refresh, columnstore maintenance job, audit log retention purge
  (`src/sql/08-indexes/`, `11-performance/`, `12-maintenance/`).
- ✅ **dim_date seed script** — `src/sql/09-seed-data/01_Seed_Dim_Date.sql`.

**Deliverable:** a reusable SQL framework. Done.

---

## Phase 3 — Synthetic Data Generator 🚧

Goal: a configurable Python tool (`tools/synthetic-data-generator/`) that
generates realistic data for Healthcare, Banking, Retail, and Insurance,
instead of committing large static CSVs. Row count is a single `--rows`
parameter (1,000 or 1,000,000, same code path).

- ✅ **3.1 Scaffolding + Banking domain** — CLI (`generator/cli.py`), the
  domain-registration pattern, and a full working implementation for banking
  (customers, accounts, transactions, loans — referentially consistent,
  smoke-tested).
- 🚧 **3.2 Remaining domains** — Healthcare (`patients`, `providers`,
  `claims`, `pharmacy`) and Retail (`customers`, `products`, `inventory`,
  `orders`) done, same pattern as banking (primary entity count scaled to
  related tables via fixed ratios). Insurance still ⏳ — no dataset shape
  defined anywhere yet, more design work than the other three.
- ✅ **Populate `datasets/*`** for the three implemented domains — ran the
  generator at `--rows 2000 --seed 42` (matching banking's existing scale)
  against its default output path. `datasets/insurance/` doesn't exist yet
  since that domain isn't designed.

---

## Phase 4 — Azure Data Factory Framework 🚧

Metadata-driven framework: full load pipelines, incremental load pipelines,
watermark pattern (reads/writes `etl.ctrl_watermark` from Phase 2), error
handling, retry, logging, notifications. Lives in `src/adf/` — see
`src/adf/README.md` for how the pieces fit together.

- ✅ `etl.ctrl_pipeline_metadata` control table + `etl.usp_update_watermark`
  procedure (`src/sql/06-stored-procedures/11_*`, `12_*`), with one
  illustrative seed row (`src/sql/09-seed-data/02_*`).
- ✅ Linked services: Key Vault, ADLS Gen2 storage (Managed Identity auth),
  AdeaDW Azure SQL DB (Key Vault-referenced SQL auth).
- ✅ Generic parameterized datasets (one file dataset, one SQL table dataset)
  and the fixed dataset over the control table.
- ✅ `pl_load_generic_full` — truncate + copy + run load procedure.
- ✅ `pl_load_generic_incremental` — file-level watermark check via
  `Get Metadata` + `etl.ufn_get_watermark`, then copy + load + advance
  watermark.
- ✅ `pl_master_orchestrator` — Lookup + ForEach over active metadata rows,
  full/incremental branch, retry policies, failure notification via
  `pl_notify_failure` (Web Activity to a webhook).
- ⏳ **Not done**: wiring real source objects per industry (only one
  illustrative metadata row exists) and real deployed resource names in the
  linked services — both depend on Phase 6 (IaC) and Phase 8 (Industry
  Accelerators).

---

## Phase 5 — Azure Databricks Framework 🚧

Reusable notebooks: Bronze → Silver → Gold, Delta Lake, Auto Loader,
Streaming, SCD Type 1/2, optimization. Lives in `src/databricks/` — see
`src/databricks/README.md` for how it maps to the SQL framework.

- ✅ `00_common/utils.py` — shared `merge_scd1`, `merge_scd2` (the Delta
  NULL merge-key SCD2 pattern), `merge_fact` helpers.
- ✅ `01_bronze` — generic Auto Loader ingestion (schema evolution,
  `availableNow` trigger).
- ✅ `02_silver` — generic cleanse/conform template (trim, drop-null-key,
  dedup on natural key).
- ✅ `03_gold` — SCD1 dimension load (generic), SCD2 dimension load
  (generic), fact load (worked for `fact_sales`, same shape documented for
  the other two facts).
- ✅ `04_streaming` — continuous Auto Loader + `foreachBatch` upsert
  variant.
- ✅ `05_optimization` — `OPTIMIZE`/`ZORDER`/`VACUUM` + auto-optimize table
  properties.
- ⏳ **Not done**: written and reviewed but not executed against a real
  Spark/Databricks cluster (none available here) — treat as unverified
  until run once for real. Also no Databricks Job/workflow definitions
  scheduling these yet, and only one worked example per notebook rather
  than every dimension/fact pre-populated.

---

## Phase 6 — Infrastructure as Code 🚧

Bicep and Terraform to provision: Resource Group, Storage, Data Factory,
Databricks, Key Vault, Monitor, SQL Database. Lives in `src/infrastructure/`
— see `src/infrastructure/README.md` for the resource list, auth model, and
deploy commands.

- ✅ Bicep: `main.bicep` (subscription scope) + 7 modules (Log Analytics,
  storage, Key Vault, SQL, Data Factory, Databricks, RBAC) + a Key Vault
  secret module for the SQL password. Compiles cleanly with `az bicep
  build` — zero errors, zero warnings.
- ✅ Terraform: root config + 7 matching modules, same resources/names/auth
  model as the Bicep version. `terraform init` + `terraform validate` both
  pass; `terraform fmt` clean.
- ✅ Auth model: Data Factory's system-assigned identity gets Storage Blob
  Data Contributor + Key Vault Secrets User via RBAC; SQL admin password is
  a secure/sensitive parameter written straight into Key Vault, never left
  in plaintext.
- ⏳ **Not done**: neither has been deployed against a real Azure
  subscription — only offline-validated (compiles / plans), not proven
  end-to-end. Alert rules, diagnostic settings, and any RBAC beyond ADF's
  own needs are Phase 7.

---

## Phase 7 — Monitoring & Security ✅

Monitoring: Azure Monitor, Log Analytics, Alerts.
Security: Microsoft Entra ID, Managed Identity, Key Vault, RBAC.
Lives in `src/monitoring/`, `src/security/` — both deploy *after*
`src/infrastructure/`, wiring observability/security onto resources that
already exist rather than creating new ones. Both available in Bicep and
Terraform (except the CI/CD app registration, Terraform-only — see below),
both offline-validated (`az bicep build`, `terraform validate`).

- ✅ **Monitoring** — diagnostic settings (logs + metrics into the Phase 6
  Log Analytics workspace) for storage, Key Vault, SQL database, Data
  Factory, and Databricks; an action group + two metric alerts (ADF
  pipeline failures, SQL high DTU).
- ✅ **Security** — Entra ID admin on the SQL server (additive to Phase 6's
  SQL auth, not a replacement); a shared user-assigned managed identity
  with read-only storage access; a Databricks Access Connector (the
  Azure-native identity Unity Catalog storage credentials need) with
  read-write storage access; and an opt-in Entra ID app registration +
  GitHub Actions OIDC federated credential for CI/CD (Terraform only —
  Bicep's Microsoft Graph extension is retired in this CLI version, so
  that piece is a `az ad app` script for Bicep-only users instead).
- **Deliberately not built**: the Unity Catalog-side objects
  (`databricks_storage_credential`, `databricks_external_location`) that
  would consume the Access Connector — those need a Unity Catalog
  metastore already assigned to the workspace, which is normally a
  one-time per-region/per-org setup done outside any single project, not
  something to provision speculatively here.
- ⏳ **Deployment**: neither Bicep nor Terraform has been deployed against
  a real subscription — offline-validated only, same as Phase 6. Terraform's
  SQL Entra admin resource is on a documented deprecation path (azurerm 4.x
  moves it inline into the server resource, which lives in a different
  Terraform root — a real migration, not a rename, deferred until this
  repo upgrades off azurerm 3.x).

---

## Phase 8 — Industry Accelerators 🚧

Each industry reuses the same framework: source data, SQL schema, ADF
pipelines, Databricks notebooks, curated outputs. Folders scaffolded:
`examples/{banking,healthcare,retail,insurance}` — banking, healthcare,
and retail are all now built end-to-end; only insurance remains empty.
Every accelerator's folder now consistently has `sql/`, `adf/README.md`
(ADF is metadata-driven — see below — so there's no per-industry pipeline
JSON, just an explanation and a pointer to the metadata seed script),
`databricks/`, `README.md`, and `architecture.md`.

- ✅ **Banking, end-to-end** — see `examples/banking/README.md`. Real
  generated data (2,000 customers / 2,800 accounts / 24,000 transactions /
  600 loans), `dim_account` + `dim_loan` (SCD Type 2, layered on the
  generic framework via FK), banking-shaped staging tables, load
  procedures that reconcile two real mismatches (embedded customer address
  → synthesized `dim_location` row; transaction → customer resolved via
  account, not directly), real `etl.ctrl_pipeline_metadata` rows, and a
  12-task Databricks Asset Bundle job (Bronze → Silver → Gold dims → a
  banking-specific Gold fact notebook).
- ✅ **Healthcare, end-to-end** — see `examples/healthcare/README.md`.
  Real generated data (2,000 patients / 100 providers / 6,000 claims /
  4,000 prescriptions). Unlike banking, *nothing* here reuses a generic
  table — `dim_patient`, `dim_provider`, `fact_claims`, `fact_pharmacy`
  are all new, since healthcare has no generic-model equivalent at all.
  Same reconciliation pattern as banking's customer (embedded address →
  synthesized `dim_location` row) shows up again for patient — the second
  time that exact mismatch has appeared, good evidence it's a real
  recurring generator shape, not a banking one-off. 10-task Databricks job.
- ✅ **Retail, end-to-end** — see `examples/retail/README.md`. Real
  generated data (2,000 customers / 160 products / 320 inventory rows /
  8,000 orders). The opposite story from healthcare: `dim.dim_customer`,
  `dim.dim_product`, and `fact.fact_orders` are all *reused generic
  tables, unmodified* — only `fact_inventory` is new. But table reuse
  didn't mean procedure reuse: all four objects still needed their own
  load procedure, because the generic procedures hardcode their staging
  table by name and the generic staging tables aren't a column-for-column
  match to any of these CSVs either. 10-task Databricks job.
- **Bugs/gaps this surfaced and fixed** (integration work doing its job):
  a real off-by-one path bug in the Phase 3 generator's CLI (data was
  landing in `tools/datasets/` instead of `datasets/`); a missing
  `load_priority` column + `ORDER BY` on `etl.ctrl_pipeline_metadata` /
  the orchestrator's Lookup query, without which dependent objects had no
  guaranteed load order; confirmation (via retail) that the generic
  staging tables in `src/sql/06-stored-procedures/00_Create_Staging_Tables.sql`
  have never actually been used by any real pipeline in this repo — every
  accelerator so far has needed its own, shaped exactly to its CSV.
- ⏳ **Not done**: Insurance — blocked on its generator not existing (no
  dataset shape defined anywhere yet, unlike the other three, which each
  had at least an empty placeholder CSV shape to design against). None of
  banking's/healthcare's/retail's SQL/ADF has run against a live
  instance; each Databricks bundle's YAML is confirmed well-formed but
  `databricks bundle validate` itself needs a reachable workspace to
  fully pass (confirmed that's the actual blocker, not a config error).
  The CSV-to-storage-account upload step isn't automated for any of the
  three.

---

## Phase 9 — Documentation ✅

Complete documentation for every module: overview, architecture, setup,
usage, best practices, troubleshooting.

- ✅ Per-module documentation was largely already in place going into this
  phase — every module built since Phase 4 shipped its own README as part
  of that phase's work (`src/adf/`, `src/databricks/`, `src/infrastructure/`,
  `src/monitoring/`, `src/security/`, `src/sql/`, `tools/synthetic-data-generator/`,
  `examples/banking/`). Phase 9's real remaining work was the cross-cutting
  design docs and an orientation layer, not per-module setup/usage docs.
- ✅ `architecture/medallion-architecture.md`,
  `architecture/deployment-architecture.md`,
  `architecture/security-architecture.md` — written, cross-referencing the
  actual implementation (not aspirational) throughout.
- ✅ `docs/getting-started.md` — orientation with 4 concrete paths (generate
  data, stand up SQL locally in Docker, understand the architecture, deploy
  infrastructure).
- ✅ `docs/troubleshooting.md` — consolidates real gotchas hit during this
  repo's own development (Synapse compatibility, Bicep's `scope` typing
  requirement, Terraform deprecation notes, `databricks bundle validate`
  needing a live workspace, the ADF load-order bug, the generator path
  bug, Windows/Git-Bash path quirks) instead of leaving them scattered
  across module READMEs.
- ✅ `docs/installation.md`, `docs/architecture.md`, `docs/best-practices.md`,
  `docs/coding-standards.md`, `docs/naming-conventions.md`, `docs/faq.md` —
  a second documentation pass rounding out `docs/` beyond the original two
  files, plus filling `architecture/overview.md`, which had been a 0-byte
  placeholder since Phase 1 despite `getting-started.md` already linking to
  it.
- ✅ `README.md`'s Documentation section now links to real docs instead of
  "Coming Soon".

---

## Phase 10 — Community & Releases 🚧

Before making the repository public: GitHub Release v1.0.0, release notes,
project board, good first issues, discussion board, contribution guide
updates.

**A real blocker found at the start of this phase**: none of Phases 2-9's
work was actually committed to git — only the original Phase 1 commits
existed, with everything since sitting as uncommitted changes. A release
of nothing isn't meaningful, so this had to be surfaced before anything
else. Per direction: not committed yet (pending your own review of the
working tree first), and nothing pushed to `origin/main`.

`gh` CLI isn't installed in this environment, so GitHub-side actions
(actual Release, Issues, Discussions, Project board) can't be done
directly here — content is drafted for you to use manually instead:

- ✅ `CONTRIBUTING.md` — rewritten to describe the actual project
  structure and conventions (was generic Phase 1 boilerplate).
- ✅ `RELEASE_NOTES_v1.0.0.md` — draft GitHub Release description,
  compiled from `CHANGELOG.md`, including an honest verified-vs-reviewed
  section.
- ✅ `.github/GOOD_FIRST_ISSUES.md` — 10 concrete starter issues, each
  traced to a specific documented gap (not speculative).
- ✅ `.github/COMMUNITY_LAUNCH.md` — suggested Project board columns/cards
  and a Discussions welcome post draft.
- ⏳ **Not done**: committing the work itself (your call), pushing to
  `origin/main` (your call), and actually creating the GitHub
  Release/Issues/Discussions/Project board from the drafted content
  (requires `gh` CLI or the GitHub web UI).

---

## Microsoft Fabric ✅

Originally deferred to post-v1.0 (see below) — built on request. Lives in
`src/fabric/`, reusing/adapting the existing framework rather than
starting fresh: `src/sql/` mostly ports to Fabric Warehouse (documented as
a compatibility table — the one non-negotiable difference is `IDENTITY`
columns aren't supported at all), `src/databricks/` notebooks are adapted
for Fabric's Lakehouse (Auto Loader replaced with a plain batch read,
since `cloudFiles` is Databricks-proprietary and doesn't exist on Fabric;
two-part `lakehouse.table` naming instead of Unity Catalog's three-part
`catalog.schema.table`), and `src/adf/`'s pattern is adapted into one
Fabric Data Factory pipeline chaining Bronze → Silver → Gold for a single
entity. See `src/fabric/README.md`.

**Verification status is one level more uncertain than the rest of this
repo**: there's no offline validation tool for Fabric item definitions
comparable to `az bicep build` or `terraform validate` — notebook Python
syntax is confirmed valid and the pipeline JSON is confirmed well-formed,
but none of it has been verified against a live Fabric workspace, and
Fabric's exact Git-sync item wrapper format isn't reproduced.

---

## Azure Synapse Analytics ✅

Originally deferred to post-v1.0 — built on request, same as Fabric
above. Lives in `src/synapse/`. Dedicated SQL Pool was already covered
(compatibility notes in `src/sql/00-standards/sql-coding-standards.md`
since Phase 2); what's new is the genuinely Synapse-specific surfaces:
a serverless SQL Pool layer querying the Gold Delta tables directly via
`OPENROWSET ... FORMAT = 'DELTA'` (no data movement), Spark pool
notebooks adapted from `src/databricks/` (Synapse's own default Spark
metastore naming, not Unity Catalog or Fabric's Lakehouse naming), and
one pipeline demonstrating the `SynapseNotebook` activity type (the one
piece of Synapse Pipelines that's genuinely different from ADF, which the
Copy activity otherwise ports to almost unchanged). See
`src/synapse/README.md`. Same verification caveat as Fabric: no offline
validation tool for Synapse workspace items; Python syntax and JSON
well-formedness confirmed, not run against a live workspace.

## CI/CD ✅

Originally "intentionally skipped for v1.0" — built on request.
`.github/workflows/ci.yml` replaced the Phase 1 echo-statement placeholder
with 5 real jobs: `validate-bicep` (`az bicep build` on all 3 Bicep
configs), `validate-terraform` (`terraform fmt -check` + `validate` on
all 3, matrixed), `validate-json` (every ADF/Fabric/Synapse pipeline file
parses), `validate-python` (syntax-checks every notebook across
Databricks/Fabric/Synapse/the generator, then actually runs the generator
as a smoke test), and `validate-sql` (spins up a real SQL Server 2022
service container and runs every script in `src/sql/` and
`examples/banking/sql/`, in order — this automates exactly the manual
Docker verification done earlier in this project, rather than a new,
separate check). The SQL Server password is a hardcoded, ephemeral,
throwaway value scoped to that one job's container — not a secret,
deliberately not requiring repo configuration before CI works.

**Not yet observed actually running on GitHub's infrastructure** — the
workflow is written, YAML-validated, and each job's logic reasoned through
carefully (the SQL job specifically mirrors commands already proven to
work locally), but nothing here can watch a GitHub Actions run execute
without the `gh` CLI. First real run happens whenever this gets pushed and
GitHub picks it up.

## Out of v1.0 scope

Nothing left in this bucket — Fabric, Synapse, and CI/CD (the three
items previously deferred here) have all been built. This section is kept
as a placeholder in case a future decision defers something else.

---

## Recommended Timeline (1 hour/day)

| Week | Focus | Outcome |
|---|---|---|
| 1 | Foundation | ✅ Completed |
| 2 | SQL Framework | ✅ Completed |
| 3 | Synthetic Data Generator | 🚧 In progress (banking/healthcare/retail done, insurance left) |
| 4 | ADF Framework | 🚧 In progress (generic framework done; banking/healthcare/retail wired via metadata, insurance left) |
| 5 | Databricks Framework | 🚧 In progress (notebooks written, not cluster-tested) |
| 6 | Infrastructure + Monitoring | ✅ Phases 6 & 7 done — Bicep + Terraform validated, not deployed |
| 7 | Banking Example | ✅ Done end-to-end (built first — see Phase 8) |
| 8 | Healthcare + Retail Examples | ✅ Both done end-to-end (see Phase 8) — insurance still ⏳, blocked on its generator |
| 9 | Documentation & Release | ✅ Documentation done; 🚧 release content drafted, not yet executed |

---

## Repository layout

The three-layer split (generic framework vs. end-to-end examples vs. docs)
was scaffolded in Phase 1 and is now in active use:

```text
Azure-Data-Engineering-Accelerator/
├── src/                  ← generic reusable components
│   ├── sql/              ← Phase 2 (done)
│   ├── adf/              ← Phase 4 (generic framework done)
│   ├── databricks/       ← Phase 5 (notebooks written, not cluster-tested)
│   ├── infrastructure/   ← Phase 6 (Bicep + Terraform validated, not deployed)
│   ├── monitoring/       ← Phase 7 (done, validated, not deployed)
│   ├── security/         ← Phase 7 (done, validated, not deployed)
│   ├── fabric/            ← Microsoft Fabric (done — see above)
│   ├── synapse/           ← Azure Synapse Analytics (done — see above)
│   ├── cicd/              ← still empty on purpose: the real CI/CD artifact
│   │                        is .github/workflows/ci.yml, not this folder
│
├── examples/             ← end-to-end implementations (Phase 8)
│   ├── banking/          ← done, end-to-end
│   ├── healthcare/       ← done, end-to-end
│   ├── retail/           ← done, end-to-end
│   ├── insurance/        ← empty, still blocked on Phase 3.2 (no generator yet)
│
├── tools/                ← dev tooling, not part of the deployed framework
│   └── synthetic-data-generator/   ← Phase 3 (banking/healthcare/retail done, insurance left)
│
├── datasets/             ← sample data (banking/healthcare/retail populated; insurance pending Phase 3.2)
├── architecture/         ← design docs (Phase 9, done)
├── docs/                 ← getting-started + troubleshooting (Phase 9, done)
├── assets/, tests/, scripts/
```
