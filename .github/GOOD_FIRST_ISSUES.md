<!--
Draft content — each "###" section below is one candidate GitHub Issue.
Copy each into a new issue (title + body), apply a `good first issue`
label, and delete this file once all of them exist as real issues (or
keep it as a source list and re-generate issues as they're closed).
Every item below traces to a gap already documented somewhere in the
repo — none of these are speculative "wouldn't it be nice" ideas.
-->

# Good First Issues

## Add the Insurance domain to the synthetic data generator

**Difficulty:** Medium · **Area:** `tools/synthetic-data-generator/`

`generator/domains/banking.py`, `healthcare.py`, and `retail.py` are all
the same reference pattern — a primary entity count scaled to related
tables via fixed ratios, referentially consistent (see
`docs/naming-conventions.md`'s "Python (synthetic data generator)"
section for the exact contract). Insurance is the one domain with no
existing dataset shape defined anywhere in the repo yet — this issue
includes designing a reasonable schema (policies, claims, premiums?)
before generating it, more design work than the three already done.

## Build the Insurance accelerator end-to-end

**Difficulty:** Large · **Area:** `examples/`

`examples/banking/`, `examples/healthcare/`, and `examples/retail/` are
all built and prove the generic framework generalizes across three quite
different reconciliation stories (see each one's README). Insurance would
be the fourth, but it's blocked on "Add the Insurance domain to the
synthetic data generator" above — there's no data to build an accelerator
from yet.

## Reconcile the generic staging tables with ADF's generic Copy activity

**Difficulty:** Small · **Area:** `src/sql/`, `src/adf/`

`src/sql/06-stored-procedures/00_Create_Staging_Tables.sql`'s generic
staging tables (`staging.stg_customer`, `stg_product`, `stg_orders`, etc.)
have never actually been used by any real pipeline in this repo — banking,
healthcare, and retail all needed their own instead, shaped exactly to
their generator's CSV (see `examples/retail/README.md`'s "what's still
not done" section for the specifics: column order mismatches, missing
columns, and `staging_batch_id` being `NOT NULL` with no default, which
ADF's generic Copy activity has no way to supply). Worth deciding whether
these generic tables should be reconciled to be genuinely reusable, or
documented as an illustrative reference shape that every real accelerator
is expected to adapt rather than reuse directly.

## Add a worked Databricks Gold notebook for `fact_orders`

**Difficulty:** Medium · **Area:** `src/databricks/`

`03_gold/03_Gold_Load_Fact.py` is written for `fact_sales` specifically
(documented as not fully generic — see the notebook's own header comment).
`examples/retail/databricks/gold_load_fact_orders_retail.py` is a worked
`fact_orders` example, but it's retail-specific (handles that domain's
`discount_pct`-to-`discount_amount` conversion) — a genuinely generic
`fact_orders` notebook in `src/databricks/03_gold/`, following
`03_Gold_Load_Fact.py`'s dimension-resolution pattern without any
industry-specific logic, is still open.

## Wire Unity Catalog's storage credential to the Databricks Access Connector

**Difficulty:** Medium · **Area:** `src/security/`

`databricksAccessConnector.bicep` / `databricks_access_connector`
(Terraform) provision the Azure-side identity, but the Unity
Catalog-side objects that consume it (`databricks_storage_credential`,
`databricks_external_location`, via the `databricks` Terraform provider)
were deliberately not built — they need a Unity Catalog metastore already
assigned to the workspace. If you have one, this is a small, well-scoped
addition. See `src/security/README.md`'s "Why Unity Catalog's storage
credential itself isn't built here" section.

## Add a security-specific alert rule for Key Vault audit events

**Difficulty:** Small · **Area:** `src/monitoring/`

The two existing alerts (ADF pipeline failures, SQL high DTU) are
operational, not security-focused, even though Key Vault `AuditEvent` logs
already flow into Log Analytics via the diagnostic settings. Add an alert
rule (Bicep + Terraform, matching the existing pattern in
`src/monitoring/*/modules/alerts`) for suspicious secret-access patterns.

## Automate the dataset-to-storage-account upload step

**Difficulty:** Small · **Area:** `src/infrastructure/` or a new script

`datasets/<industry>/*.csv` need to land in the storage account's `raw`
container before ADF's pipelines can read them — currently a manual
`az storage blob upload-batch` step, called out as not automated in
`architecture/deployment-architecture.md`. A small script or a Bicep/
Terraform deployment script resource would close this gap.

## Add a "prod" Bicep parameters file

**Difficulty:** Small · **Area:** `src/infrastructure/bicep/`

Only `parameters/main.dev.parameters.json` exists. A `main.prod.parameters.json`
with production-appropriate defaults (e.g. `enableKeyVaultPurgeProtection: true`,
a real SQL SKU instead of `Basic`) would round this out — see
`ROADMAP.md`'s Phase 6 section, "Environments" in
`architecture/deployment-architecture.md`.

## Verify the SQL framework's facts, procedures, and all three accelerators against a live SQL Server

**Difficulty:** Medium · **Area:** `src/sql/`, `examples/*/sql/`

Database creation, schema creation, and all 7 core dimensions were
verified against a real SQL Server 2022 Docker container (see
`CHANGELOG.md`'s `[Unreleased]` → `Verified` section) before that test run
was intentionally stopped partway through. Facts, stored procedures, and
all three accelerators' extensions (banking, healthcare, retail) are
reviewed but not yet run the same way — `.github/workflows/ci.yml`'s
`validate-sql` job runs all of it on every push now, but hasn't been
*observed* running on GitHub's infrastructure yet either (see the CI
item elsewhere in `ROADMAP.md`). `docs/getting-started.md`'s Path 2 has
the exact Docker command to pick
this back up.
