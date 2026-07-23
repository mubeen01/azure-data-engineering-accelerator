# Banking — Industry Accelerator

The first (and so far only) fully wired end-to-end example: real generated
data → SQL schema extensions → ADF metadata-driven pipeline → Databricks
medallion job. Every other phase built one representative pattern; this is
where they all actually have to work together, which surfaced several real
gaps the earlier phases didn't — documented below rather than smoothed
over.

## Data

`datasets/banking/*.csv` are real output from
`tools/synthetic-data-generator` (`python -m generator.cli --domain banking
--rows 2000 --seed 42`) — 2,000 customers, 2,800 accounts, 24,000
transactions, 600 loans. Not placeholders.

Running the generator for real surfaced an actual bug: `cli.py`'s default
output path resolved to `tools/datasets/<domain>/` instead of
`datasets/<domain>/` (`Path(__file__).resolve().parents[2]` should have
been `parents[3]` — off by one directory level, invisible in Phase 3's
smoke test because that test always passed an explicit `--output-dir`).
Fixed in `tools/synthetic-data-generator/generator/cli.py`.

## The schema gap: accounts and loans

The generic framework (`src/sql/03-dimensions/`) has no table for "account"
or "loan" — reasonably so, those aren't universal across industries.
Banking-specific dimensions live here instead, layered on top via FK,
same SCD Type 2 pattern as the generic dimensions:

- `sql/01_Create_Dim_Account.sql` — FK to `dim.dim_customer`, `dim.dim_currency`.
- `sql/02_Create_Dim_Loan.sql` — FK to `dim.dim_customer`. Modeled as a
  dimension, not a fact — a loan's status transitions (Active → Paid Off /
  Default) over time, but there's no recurring transactional event, so SCD
  Type 2 fits better than a fact grain.

## The reconciliation gap: generated data vs. generic staging shape

The generator produces an industry-realistic shape that doesn't match the
generic framework's assumptions:

| Mismatch | Generic framework assumed | Generator actually produces | Resolution |
|---|---|---|---|
| Customer address | a separate `location_id` FK | address embedded directly on the customer record | `sql/03_Load_Dim_Customer_Banking.sql` synthesizes `location_id = customer_id` (a valid 1:1 relationship) and upserts `dim.dim_location` before loading `dim.dim_customer` |
| Transaction → customer | `customer_id` directly on the transaction | only `account_id` — a transaction belongs to an account, which belongs to a customer | `sql/06_Load_Fact_Transactions_Banking.sql` resolves `customer_key` by joining through `dim.dim_account` instead of expecting it pre-resolved |

Rather than force the generator to match the generic shape (or force the
generic shape to fit every industry), banking gets its own staging tables
(`sql/00_Create_Staging_Tables.sql`) shaped exactly like the CSVs, and its
own load procedures that do the reconciliation explicitly. This is meant
to be the template for how other industries (Phase 3.2+/future Phase 8
work) handle their own mismatches, not a one-off special case.

## The load-order gap this surfaced in ADF

Wiring 4 dependent objects (customer must load before account/loan, which
must load before transaction) through `pl_master_orchestrator` exposed a
real gap: `etl.ctrl_pipeline_metadata` had no ordering column, and the
Lookup activity's query had no `ORDER BY` — `isSequential: true` alone only
guarantees rows run one at a time, not in a specific order. Fixed by
adding `load_priority` to the metadata table
(`src/sql/06-stored-procedures/11_Create_Pipeline_Metadata_Table.sql`) and
an `ORDER BY load_priority ASC, object_name ASC` to the orchestrator's
Lookup query. `sql/07_Seed_Pipeline_Metadata_Banking.sql` sets
customer=10, account/loan=20, transaction=30.

## Databricks

`databricks/databricks.yml` (a Databricks Asset Bundle) wires a 12-task job:
Bronze (4 entities, generic Auto Loader notebook) → Silver (4 entities,
generic conform notebook) → Gold dimensions (`dim_customer`, `dim_account`,
`dim_loan` — all via the generic SCD Type 2 notebook) → Gold fact
(`gold_load_fact_transactions_banking.py`, a new banking-specific notebook
mirroring the SQL fact loader's account→customer resolution, since the
generic fact notebook assumes a direct `customer_id`).

Note the deliberate simplification: `dim_account`/`dim_loan`, when loaded
via the generic Gold notebook, keep `customer_id` as a plain tracked
attribute rather than resolving it to a surrogate `customer_key` — only
fact notebooks do cross-dimension key resolution in this framework (see
the comment in `gold_load_fact_transactions_banking.py`). The SQL path
(`dim.dim_account`/`dim.dim_loan`) *does* resolve `customer_key` at load
time, since T-SQL procs were already doing that kind of resolution
throughout Phase 2. This is a real, documented difference between the two
engines' banking implementations, not an inconsistency to be embarrassed
about — the SQL warehouse is the fully-normalized star schema; the Delta
Lake path trades some normalization for simplicity in this pass.

## Validation status

- **Data generation**: ran for real, verified (2,000/2,800/24,000/600 rows,
  correct headers, referentially consistent).
- **SQL**: written and carefully reviewed against the same patterns
  Phase 2 already established; not executed against a live SQL Server/Azure
  SQL instance (none available in this environment) — same caveat as the
  rest of `src/sql/`.
- **ADF**: JSON validated for well-formedness; not run against a live Data
  Factory.
- **Databricks bundle**: YAML confirmed well-formed and structurally
  correct (12 tasks, dependency graph checked). `databricks bundle
  validate` itself requires a reachable workspace to complete (it calls a
  live `/api/2.0/preview/scim/v2/Me` whoami check as part of validation) —
  attempted with dummy credentials and confirmed that's genuinely the
  blocker, not a config mistake, but couldn't get a clean pass without a
  real workspace.

## What's still not done

- Healthcare, retail, insurance accelerators — Phase 3's generators for
  those domains don't exist yet either (Milestone 3.2).
- No employee/location dimensions for banking transactions (no
  teller/branch concept in the generator's model) — `employee_key`/
  `location_key` stay `NULL` throughout.
- The actual ADF linked service source path / Databricks mount path
  (`/mnt/adea/raw/banking/...`) assumes the generated CSVs have been
  uploaded to the storage account's `raw` container — that upload step
  itself isn't automated here.
