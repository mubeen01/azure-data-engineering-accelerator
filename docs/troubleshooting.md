# Troubleshooting

Real gotchas this repo's own development ran into, not a hypothetical
FAQ — each of these was hit, diagnosed, and fixed (or deliberately
accepted) while building the phases that follow. Grouped by area.

## SQL / T-SQL

**"It works on Azure SQL Database but not on my Synapse dedicated pool."**
Three real divergences, all documented in
`src/sql/00-standards/sql-coding-standards.md`'s compatibility table:
- `MERGE` isn't supported on Synapse dedicated pools. Every SCD Type 2
  loader in this repo already avoids it (expire-then-insert via plain
  `UPDATE`/`INSERT`) for exactly this reason — only the SCD Type 1 loaders
  use `MERGE`, and only those need rewriting for Synapse.
- Filtered indexes (`CREATE INDEX ... WHERE is_current = 1`) aren't
  supported there either — enforce that invariant in the load procedure
  instead.
- `PRIMARY KEY`/`FOREIGN KEY`/`UNIQUE` constraints are `NOT ENFORCED`
  (informational only, not validated on write) on Synapse dedicated pools.

**"My ADF orchestrator loaded the fact table before the dimension it
depends on."**
`etl.ctrl_pipeline_metadata`'s `is_active = 1` filter alone doesn't
guarantee order — `isSequential: true` on the `ForEach` only guarantees
rows run one at a time, not in a specific sequence. You need both the
`load_priority` column and the Lookup activity's
`ORDER BY load_priority ASC, object_name ASC` (already in
`src/adf/pipeline/pl_master_orchestrator.json` — this was a real bug found
while wiring Phase 8's banking accelerator, not a hypothetical).

**"I don't have Azure — how do I actually test any of this?"**
Spin up SQL Server locally in Docker rather than needing a real
subscription:
```bash
docker run -e "ACCEPT_EULA=Y" -e "MSSQL_SA_PASSWORD=<strong-password>" \
  -p 1433:1433 --name adea-sql -d mcr.microsoft.com/mssql/server:2022-latest
```
This is exactly how Phase 8's SQL layer was verified — `sqlcmd` or
`pyodbc` against `localhost,1433`. Remove the container (`docker rm -f
adea-sql`) and, if you started Docker Desktop just for this, shut it down
afterward — a 2GB+ SQL Server image left cached is easy to forget about.

## Bicep

**"I tried to write one generic diagnostic-settings module and Bicep
rejected it."**
`scope:` on a `resource` block needs an actual resource symbol (declared
via `existing` or created in the same file) — it cannot take an arbitrary
`resourceId(...)` string, even though that's valid for ARM JSON directly.
This is why `src/monitoring/bicep/modules/` has one small typed module
per resource type (`storageDiagnostics.bicep`, `keyVaultDiagnostics.bicep`,
etc.) instead of a single parameterized one — confirmed by testing the
generic version first and watching `az bicep build` reject it with
`BCP036`. Terraform doesn't have this limitation (`target_resource_id` is
just a string there), which is why `src/monitoring/terraform/modules/diagnostic_settings`
*is* fully generic.

**"Can I manage Entra ID app registrations in Bicep?"**
Not cleanly, at least not with this repo's Bicep CLI version — the
built-in Microsoft Graph extension is retired (`az bicep build` fails with
`BCP407: Built-in extension "microsoftGraph" is retired`). Use Terraform's
`azuread` provider instead (`src/security/terraform/modules/entra_cicd_app`),
or a plain `az ad app create` / `az ad app federated-credential create`
script if you're Bicep-only.

## Terraform

**"`terraform validate` warns my SQL Entra admin resource is deprecated."**
Correct — `azurerm_sql_active_directory_administrator` is deprecated in
favor of an `azuread_administrator` block nested inside the
`azurerm_mssql_server` resource itself in azurerm 4.x. That block can only
be set where the server resource is actually defined
(`src/infrastructure/terraform`), not from a separate security
configuration (`src/security/terraform`) — migrating means moving this
concern across that boundary, not just renaming a resource. This repo
pins `azurerm ~> 3.100` specifically so this stays a documented warning,
not a break.

**"Storage account diagnostic settings don't show blob logs."**
Blob read/write/delete logs are emitted at the blob service sub-resource,
not the storage account itself. Target
`"${azurerm_storage_account.this.id}/blobServices/default"` (Terraform)
or the `blobServices/default` child resource (Bicep), not the account's
own resource ID.

## Databricks

**"`databricks bundle validate` fails even though my YAML looks right."**
`bundle validate` makes a live `GET /api/2.0/preview/scim/v2/Me` call as
part of validation — it needs a genuinely reachable workspace, it's not a
pure offline schema check the way `terraform validate` is. Confirmed by
running it with dummy credentials against a fake host and watching it fail
on that specific call, not on YAML parsing. If you don't have a workspace
to validate against yet, at minimum confirm the YAML parses
(`python -c "import yaml; yaml.safe_load(open('databricks.yml'))"`) and
review the task dependency graph by hand.

**"Should every Gold dimension resolve its foreign keys to surrogate
keys, like the SQL warehouse does?"**
Not necessarily, and this repo doesn't pretend otherwise: the generic
Gold SCD Type 2 notebook (`src/databricks/03_gold/02_Gold_Load_Dim_Scd2.py`)
doesn't do cross-dimension key resolution — only fact-loading notebooks
do (see `examples/banking/databricks/gold_load_fact_transactions_banking.py`'s
two-hop join for a worked example). If you need a Gold dimension itself to
carry a resolved surrogate FK, that's a bespoke notebook, not the generic
one — documented as a deliberate simplification in
`examples/banking/README.md`, not an oversight.

## Local dev tooling (this repo's own scripts)

**"The synthetic data generator wrote its output to the wrong folder."**
Already fixed, but worth knowing the failure mode: `Path(__file__).resolve().parents[N]`
off-by-one errors are easy to introduce and easy to miss if your test
always passes an explicit `--output-dir` (Phase 3's smoke test did this,
which is exactly why the bug survived until Phase 8 ran the generator for
real). If you add a new domain generator, run it once *without*
`--output-dir` and check where the files actually landed.

**On Windows, mixing Git Bash and native Python:** paths like `/tmp/...`
resolve correctly for Git Bash-native tools (redirection, `az`, `terraform`)
but not for a native `python.exe` invocation, which doesn't do MSYS path
translation. If a Python script can't find a file that a shell command
just wrote, check whether you're crossing that boundary — write to a
path under the current working directory instead of `/tmp` when a Python
script needs to read it back.
