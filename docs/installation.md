# Installation

What to install locally, and for which of this repo's paths. Nothing here
is required for all four — pick the row(s) that match what you're trying
to do (see `docs/getting-started.md` for the paths themselves).

## Baseline (every path)

| Tool | Why | Verify |
|---|---|---|
| Git | Clone the repo | `git --version` |
| Python 3.10+ | Runs the synthetic data generator and every Databricks/Fabric/Synapse notebook's syntax checks — 3.10 is what CI pins (`.github/workflows/ci.yml`) | `python --version` |

Clone and stop here if you only want to read the code and docs — nothing
else below is needed just to browse.

```bash
git clone https://github.com/mubeen01/Azure-Data-Engineering-Accelerator.git
cd Azure-Data-Engineering-Accelerator
```

## Path 1 — Synthetic data generator

| Tool | Why | Verify |
|---|---|---|
| pip | Install `faker>=22.0`, `pandas>=2.0` (`tools/synthetic-data-generator/requirements.txt`) | `pip --version` |

```bash
cd tools/synthetic-data-generator
pip install -r requirements.txt
```

No Azure account, Docker, or cloud resource needed for this path.

## Path 2 — SQL warehouse locally (no Azure needed)

| Tool | Why | Verify |
|---|---|---|
| Docker | Runs `mcr.microsoft.com/mssql/server:2022-latest` locally — this is how the SQL framework was actually verified (see `CHANGELOG.md`) | `docker --version` |
| A SQL client | Run the scripts in `src/sql/` against the container | see options below |

SQL client options, any one of:
- `sqlcmd` (what CI uses — install via the `mssql-tools18` package, see
  `.github/workflows/ci.yml`'s `validate-sql` job for the exact install
  steps on Ubuntu, or `winget install sqlcmd` on Windows)
- Azure Data Studio or SQL Server Management Studio (GUI)
- `pyodbc` from Python, if you'd rather script it

No Azure account needed for this path — everything runs against the local
container.

## Path 3 — Deploy the infrastructure (Bicep or Terraform)

Requires an actual Azure subscription. Pick Bicep or Terraform (both
provision the same resources — see `src/infrastructure/README.md`), not
necessarily both.

| Tool | Why | Verify |
|---|---|---|
| Azure CLI (`az`) | Auth (`az login`) and, for Bicep, the deployment command itself | `az --version` |
| Bicep CLI | `az bicep install` — used by `az deployment sub create` and by `az bicep build` for offline validation | `az bicep version` |
| Terraform 1.9.8 | Pinned in CI (`hashicorp/setup-terraform@v3`); other 1.x versions likely work but aren't what's tested against | `terraform --version` |

```bash
az bicep install
az login
```

or

```bash
terraform -version   # confirm 1.9.x
az login             # Terraform's azurerm provider still authenticates via az CLI context
```

You'll also need **"Key Vault Secrets Officer" (or higher) on the target
Key Vault** for whichever identity runs the deployment — RBAC-mode Key
Vault doesn't implicitly grant the deployer write access the way the
older access-policy model did. See `src/infrastructure/README.md` for the
exact deploy commands once tooling is installed.

## Path 4 — Databricks notebooks

| Tool | Why | Verify |
|---|---|---|
| Databricks CLI (optional) | `databricks bundle validate` for the Asset Bundle in `examples/banking/databricks/` — note this makes a live API call to a real workspace, it isn't a pure offline schema check (see `docs/troubleshooting.md`) | `databricks --version` |

A reachable Databricks workspace is required to actually run
`databricks bundle validate` or execute a notebook — none of the
notebooks under `src/databricks/`, `src/fabric/lakehouse/`, or
`src/synapse/spark/` have been run against a live Spark cluster from this
environment; only `python3 -m py_compile` syntax-checked (same as CI's
`validate-python` job).

## What you do *not* need

- An Azure subscription, for Paths 1 and 2.
- Docker, for Paths 1, 3, or 4.
- Databricks or a Spark cluster, for Paths 1, 2, or 3.

## Next

- `docs/getting-started.md` — the four paths above, with the actual
  commands to run once tooling is installed.
- `docs/troubleshooting.md` — gotchas specific to each tool above
  (Bicep's `scope` typing, Terraform's SQL Entra admin deprecation warning,
  `databricks bundle validate` needing a live workspace, Windows/Git Bash
  path quirks).
