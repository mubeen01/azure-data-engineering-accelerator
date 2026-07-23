# Coding Standards

Project-wide rules, one section per language/tool. SQL already has its own
detailed standard (`src/sql/00-standards/sql-coding-standards.md`) — this
page summarizes it and adds the languages that don't have one yet: Python,
ADF pipeline JSON, Bicep, and Terraform. For naming (as opposed to style),
see `docs/naming-conventions.md`.

## SQL

Full standard: `src/sql/00-standards/sql-coding-standards.md`. Highlights:

- Every script is idempotent — existence checks before create/drop,
  `CREATE OR ALTER` for programmable objects, never a bare `INSERT` for
  seed data.
- Keywords `UPPERCASE`, identifiers `snake_case` and always
  schema-qualified (`dim.dim_customer`, never bare `dim_customer`).
- No `SELECT *` outside ad-hoc validation queries.
- `SET NOCOUNT ON` at the top of every procedure; multi-statement writes
  wrapped in `BEGIN TRY/CATCH` with a transaction, rolled back and
  re-thrown (`THROW`) on error.
- Every ETL procedure writes a start/end/status row to `audit.log_etl_run`.
- A script that can't run unmodified on Azure SQL DB, SQL Server, *and*
  Synapse dedicated pools says so in a header comment — see the
  compatibility table at the bottom of the SQL standard (`MERGE`, filtered
  indexes, and enforced constraints are the three real divergences).

## Python (generator + Databricks/Fabric/Synapse notebooks)

- Target Python 3.10 (what `tools/synthetic-data-generator/requirements.txt`
  and CI's `validate-python` job assume).
- Type hints on function signatures where the shape isn't obvious — e.g. a
  domain generator's contract is `generate(rows: int, seed: int | None) ->
  dict[str, pd.DataFrame]` (`generator/domains/banking.py`'s pattern);
  keep new domains to that exact signature so `cli.py`'s
  `DOMAIN_GENERATORS` registration stays uniform.
- CLI flags via `argparse`, not a config file or environment variables, for
  the generator — `--domain`, `--rows`, `--output-dir`, `--seed` is the
  established shape (`generator/cli.py`).
- Every new file must pass `python3 -m py_compile` at minimum — this is
  what CI actually checks for every notebook, since there's no live Spark
  cluster to run them against. Passing that check means "syntactically
  valid," not "correct" — say so if you haven't run it for real.
- Databricks/Fabric/Synapse notebooks are checked in as plain-text source
  (`# Databricks notebook source`, `# COMMAND ----------` cell markers),
  not `.ipynb` — this keeps them diffable and directly importable into a
  Git-connected workspace. Parameterize via widgets
  (`dbutils.widgets.get(...)`), not hardcoded table/path literals, so a
  notebook can be reused across entities without editing its body.
- No secrets or connection strings inline, ever — reference Key Vault
  (`dbutils.secrets.get(...)`) or a widget, matching the identity-first
  approach the rest of the repo uses (`docs/best-practices.md`).

## Azure Data Factory (pipeline/dataset/linked service JSON)

- Prefer the generic, parameterized pattern over a new pipeline/dataset
  per source object — see `src/adf/README.md` for why one full-load
  pipeline, one incremental pipeline, and a metadata table replace
  hand-built pipelines entirely. Only write a bespoke pipeline when a
  source object genuinely can't fit the generic parameter set.
- Every Copy/Execute Pipeline activity that can fail transiently gets a
  retry policy (2–3 attempts is the established pattern —
  `src/adf/pipeline/pl_load_generic_full.json`), not just default
  behavior.
- Linked services authenticate via Managed Identity where the sink/source
  supports it; where it doesn't (Azure SQL DB today), the password is a
  Key Vault reference, never inline (`type: "AzureKeyVaultSecret"`).
- Every pipeline/dataset/linked service JSON file must parse
  (`python3 -m json.tool` is CI's actual check, `validate-json` job) —
  hand-editing raw JSON instead of exporting from ADF Studio makes this
  easy to violate; validate before committing.

## Bicep

- One small, typed module per resource type
  (`src/infrastructure/bicep/modules/`), not one large generic module —
  `scope:` on a `resource` block needs an actual resource symbol, it
  can't take an arbitrary `resourceId(...)` string the way ARM JSON
  allows (`BCP036` — see `docs/troubleshooting.md`).
- Secrets/passwords are `@secure()` parameters, written into Key Vault
  immediately, never left in a variable or output.
- `az bicep build --file <path> --stdout > /dev/null` must succeed with
  zero errors *and* zero warnings before considering a template done —
  this is exactly what CI's `validate-bicep` job checks.

## Terraform

- Module folders mirror the Bicep module list 1:1, `snake_case` per HCL
  convention (`data_factory/`, `key_vault/`, `sql_database/`, matching
  Bicep's `dataFactory.bicep`, `keyVault.bicep`, `sqlDatabase.bicep`) —
  see `docs/naming-conventions.md`.
- Sensitive variables (`sql_admin_password`) are `sensitive = true` and
  passed via `-var`, `TF_VAR_*`, or a pipeline secret store — never
  committed in a `.tfvars` file (`terraform.tfvars.example` is checked in
  specifically as the non-secret template; the real `.tfvars` is
  gitignored).
- `terraform fmt -recursive` and `terraform validate` must both pass
  clean before considering a module done — CI's `validate-terraform` job
  runs `fmt -check` first, so an unformatted file fails CI even if it's
  semantically valid.
- A version pin (`~> 3.100` for `azurerm` today) is a deliberate choice,
  not an oversight — see `docs/troubleshooting.md` for why (the SQL Entra
  admin resource's deprecation path in azurerm 4.x). Don't bump a provider
  major version without checking whether a deprecation like that one
  becomes a break.

## General, across every language above

- **Idempotency is not optional** — see `docs/best-practices.md`'s
  section on this; it applies identically to SQL scripts, ADF pipelines,
  Bicep/Terraform deployments, and Databricks merges.
- **State your verification ceiling.** "Compiles/parses" and "runs
  correctly against a live target" are different claims — CI enforces the
  former for every language here; only say the latter if you've actually
  done it (a live SQL Server container, a real deployed subscription, a
  reachable Databricks workspace).
- **Match the file's neighbors before inventing a new convention.** If
  every existing file in a folder uses a pattern, a new file follows it —
  raise a change to the pattern itself as a separate discussion, not
  silently in the same commit that adds one new file.
