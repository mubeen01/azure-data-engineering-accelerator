# Microsoft Fabric

Was explicitly deferred to post-v1.0 (see `ROADMAP.md`'s former "Out of
v1.0 scope" note) — built now on request. Covers Fabric's four pillars by
reusing or adapting what already exists elsewhere in this repo, rather
than starting from a blank slate:

| Fabric pillar | This repo's answer |
|---|---|
| **Data Warehouse** | `warehouse/fabric-warehouse-compatibility.md` — Fabric Warehouse is T-SQL, so `src/sql/` mostly ports. Documented as a compatibility table, not a duplicated tree (the delta is small and mechanical) |
| **Lakehouse** | `lakehouse/notebooks/` — Bronze/Silver/Gold, adapted from `src/databricks/` |
| **Pipelines** | `pipelines/` — adapted from `src/adf/` |
| **Notebooks** | Same files as Lakehouse, above — Fabric notebooks and Lakehouse are the same underlying Spark/Delta surface, not two separate things to build |

## The one non-negotiable difference: no `IDENTITY`

**Fabric Warehouse doesn't support `IDENTITY` columns at all** — every
surrogate key in `src/sql/03-dimensions/` and `04-facts/` would need to
switch to `NEXT VALUE FOR` a `SEQUENCE` to run there. This is the single
biggest incompatibility, spelled out with the exact rewrite pattern in
`warehouse/fabric-warehouse-compatibility.md`.

## The one thing deliberately not copied from Databricks: Auto Loader

`src/databricks/01_bronze/01_Bronze_Autoloader_Ingest.py` uses `cloudFiles`
— a Databricks-proprietary Spark connector that doesn't exist on Fabric's
runtime. `lakehouse/notebooks/01_bronze/01_Bronze_Ingest.py` uses a plain
batch read over the Lakehouse's `Files/` area instead, since that's the
idiomatic Fabric pattern, not a lesser copy of something that doesn't
port. See that notebook's header comment for the incremental-pickup
tradeoff this implies.

## Fabric-specific notebook adaptations

- **No `dbutils.widgets`** — Fabric notebooks parameterize via a cell
  tagged `parameters` holding plain variable assignments (marked
  `# PARAMETERS CELL` in these files), which a pipeline Notebook activity
  overrides at runtime by injecting a new cell after it.
- **Two-part table names** (`<lakehouse_name>.<table>`), not Unity
  Catalog's three-part `<catalog>.<schema>.<table>` — Fabric doesn't have
  a three-level catalog/schema namespace the same way. Medallion layers
  are modeled as three separate Lakehouse items (`lh_bronze`, `lh_silver`,
  `lh_gold`) rather than three schemas in one catalog.
- **`%run` resolves by notebook name**, not a relative file path — Fabric
  and Databricks differ here, so `%run 00_common_utils` (this repo) looks
  different from Databricks' `%run ../00_common/utils`.
- The SCD Type 1/2/fact merge logic itself (`00_common/utils.py`) is
  **unchanged** from the Databricks version — Delta `MERGE` isn't
  platform-specific, only the surrounding APIs are.

## Verification status

**Not verified against a live Fabric workspace or tenant** — there's no
offline validation tool available for Fabric item definitions comparable
to `az bicep build`, `terraform validate`, or even `databricks bundle
validate` (which at least attempts a live check). Notebook Python syntax
is confirmed valid (`py_compile`); the pipeline JSON is confirmed
well-formed. The exact Git-sync item wrapper Fabric uses (a `.platform`
metadata file alongside each synced item, and Fabric's specific notebook
cell-metadata format) is not reproduced here — these files are the item
bodies, reviewed against Fabric's documented APIs, not exported from or
tested in a real workspace. Treat this the same way as
`src/databricks/`'s "not cluster-tested" caveat, one level more
uncertain.

## Not built

- A metadata-driven Fabric orchestrator equivalent to
  `src/adf/pipeline/pl_master_orchestrator.json` (a Fabric Warehouse
  control table + Lookup activity driving every entity) — the one
  pipeline here chains Bronze → Silver → Gold for a single entity
  (customers), matching this repo's per-entity example scope rather than
  building a second full orchestration layer.
- Gold notebooks beyond `dim_source_system` (SCD1), `dim_customer`
  (SCD2), and `fact_sales` — same one-worked-example-per-pattern scope as
  every other phase in this repo.
