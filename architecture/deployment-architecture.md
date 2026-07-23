# Deployment Architecture

What actually gets provisioned, in what order, and why it's split the way
it is. Covers `src/infrastructure/` (Phase 6) and `src/monitoring/` +
`src/security/` (Phase 7) — see each folder's own README for exact deploy
commands; this document is about the shape and sequencing.

## Why three separate deployments, not one

`src/infrastructure/` provisions resources. `src/monitoring/` and
`src/security/` configure observability and access control *on top of*
those resources, via `data`/`existing` references rather than creating
anything new. This split exists so:

- Changing an alert threshold or adding a diagnostic setting never risks
  touching (or requiring re-plan of) the underlying storage account, SQL
  database, or Data Factory.
- A team that wants the compute/storage layer but not this repo's specific
  monitoring opinions can deploy `src/infrastructure/` alone.

All three are available in both Bicep and Terraform, kept functionally
identical (same resource names, same auth model) — see
`src/infrastructure/README.md` for why both exist rather than picking one.

## Deployment order

```text
1. src/infrastructure/   (bicep/ or terraform/)
   → Resource Group, Storage (ADLS Gen2), Key Vault, SQL Server + AdeaDW,
     Data Factory (System-Assigned Identity), Databricks Workspace,
     Log Analytics Workspace, RBAC for ADF's identity

2. src/monitoring/       (deploy into the same resource group)
   → Diagnostic settings (storage/Key Vault/SQL/ADF/Databricks → Log
     Analytics), an action group + 2 metric alerts

3. src/security/         (deploy into the same resource group)
   → SQL Entra ID admin, a shared user-assigned identity, a Databricks
     Access Connector (Unity Catalog's storage auth), an opt-in CI/CD
     app registration

4. src/sql/               (run against the deployed AdeaDW database)
   → 00-standards through 12-maintenance, in numeric folder order

5. examples/<industry>/sql/  (e.g. examples/banking/sql/, in numeric order)
   → industry-specific extensions (e.g. dim_account, dim_loan) and seed
     data for etl.ctrl_pipeline_metadata

6. src/adf/ and src/databricks/
   → import/publish the pipeline JSON and notebooks/bundle into the
     already-provisioned Data Factory and Databricks workspace
```

Steps 2 and 3 both depend on step 1's outputs (resource names) but not on
each other — they can run in either order or in parallel.

## Resource topology

```text
rg-adea-<environment>
├── stadea<suffix>            Storage Account (ADLS Gen2)
│   └── containers: raw, checkpoints
├── kv-adea-<suffix>          Key Vault (RBAC-authorized)
│   └── secret: adea-dw-sql-password
├── sql-adea-<suffix>         SQL Server
│   └── AdeaDW                 Database
├── adf-adea-<environment>    Data Factory (System-Assigned Identity)
├── dbw-adea-<environment>    Databricks Workspace (Premium)
├── log-adea-<environment>    Log Analytics Workspace
├── dbac-adea-<environment>   Databricks Access Connector (Phase 7)
└── id-adea-shared-<environment>  User-Assigned Managed Identity (Phase 7)

rg-adea-<environment>-databricks   Databricks-managed (created automatically
                                     by the Databricks Workspace resource,
                                     not something this repo provisions
                                     directly)
```

`<suffix>` is a deterministic hash of subscription/tenant + environment
name, so storage/Key Vault/SQL server names (which must be globally
unique) stay stable across re-deployments instead of changing every run.

## Environments

A single `environmentName`/`environment_name` variable (`dev`/`test`/`prod`)
drives every resource name. There's no separate per-environment
configuration beyond that today — scaling to genuinely different
environment shapes (e.g. `prod` needing Key Vault purge protection on by
default, a higher SQL SKU, geo-redundant storage) is a natural extension
but not built as separate parameter files yet beyond
`bicep/parameters/main.dev.parameters.json`.

## What isn't automated

- Uploading `datasets/<industry>/*.csv` into the storage account's `raw`
  container — that hand-off from "generator output" to "ADF's actual
  source" is still a manual step (`az storage blob upload-batch` or
  equivalent).
- Running `src/sql/`/`examples/*/sql/` scripts against the deployed
  database — no CI/CD pipeline invokes `sqlcmd` automatically (see the
  "Out of v1.0 scope" note in `ROADMAP.md` on `src/cicd/`).
- Importing `src/adf/`'s pipeline JSON into the actual Data Factory
  instance, and `src/databricks/databricks.yml`-style bundles into the
  actual workspace — both are "the files exist and are correct," not
  "already wired into a running factory/workspace."

## Verification status

Bicep: every template compiles cleanly via `az bicep build` (zero errors,
zero warnings). Terraform: every configuration passes `terraform init` +
`terraform validate` (one intentionally-accepted deprecation warning on
the SQL Entra admin resource — see `src/security/README.md`). Neither has
been applied against a real Azure subscription — offline-validated only,
consistently across Phases 6 and 7.
