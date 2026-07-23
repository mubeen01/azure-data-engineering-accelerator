# Retail — Industry Accelerator

The third fully wired end-to-end example, and the one that actually tests
the claim `.github/GOOD_FIRST_ISSUES.md` made about it: "Retail is
probably the closest fit to the existing generic `fact_orders`/
`dim_product` model." It mostly was — three of retail's four entities
reuse **generic tables unmodified** (`dim.dim_customer`, `dim.dim_product`,
`fact.fact_orders`), a meaningfully different story from banking's
`dim_account`/`dim_loan` (two entirely new tables) and healthcare's
`dim_patient`/`dim_provider`/`fact_claims`/`fact_pharmacy` (four entirely
new tables). Only `inventory` needed a genuinely new table.

## Data

`datasets/retail/*.csv` are real output from `tools/synthetic-data-generator`
(`python -m generator.cli --domain retail --rows 2000 --seed 42`) — 2,000
customers, 160 products, 320 inventory rows, 8,000 orders. See
`tools/synthetic-data-generator/generator/domains/retail.py`.

## The schema gap: only inventory is new

- `dim.dim_customer`, `dim.dim_product` — **no new tables.** Retail
  customers/products load straight into the same generic dimensions
  banking's customers and (as of this accelerator) retail's own products
  use, distinguished by `source_system = 'RETAIL_CORE'`. This is the
  generic framework working exactly as `src/sql/00-standards/naming-standards.md`
  intends: industry accelerators reuse the layered schemas, they don't
  get their own.
- `fact.fact_orders` — **no new table.** Retail's orders load into the
  same `fact.fact_orders` (`src/sql/04-facts/02_Create_Fact_Orders.sql`)
  Phase 2 already built for exactly this purpose.
- `sql/01_Create_Fact_Inventory.sql` — the one genuinely new table.
  Nothing in the generic model has an inventory concept at all. Modeled
  as a periodic snapshot fact — see its header comment and
  `sql/05_Load_Fact_Inventory_Retail.sql`'s for the real simplification
  this implies (insert-only, not a true recurring-snapshot history).

## The reconciliation gap: table reuse still needed bespoke load procedures

Reusing a *table* doesn't mean reusing its *load procedure* — every one
of retail's four objects needed its own procedure, even the three that
target generic tables:

| Object | Target table | Why it needed its own procedure |
|---|---|---|
| Customer | `dim.dim_customer` (generic) | Same embedded-address mismatch banking's customer and healthcare's patient already hit — `sql/02_Load_Dim_Customer_Retail.sql` synthesizes `location_id = customer_id`, same pattern as those two. |
| Product | `dim.dim_product` (generic) | The generic `etl.usp_load_dim_product` hardcodes `FROM staging.stg_product`, and even setting that aside, the generic staging table isn't a drop-in fit for retail's CSV either — column order differs and there's no `created_date` column there at all (see `sql/00_Create_Staging_Tables.sql`'s header comment). `sql/03_Load_Dim_Product_Retail.sql` is otherwise a straight copy of the generic procedure's logic, just pointed at `staging.stg_retail_product`. |
| Order | `fact.fact_orders` (generic) | The generator produces one complete order line per row with a discount *percentage*, not `order_line_number`/`discount_amount`/`tax_amount`/`net_amount` pre-computed. `sql/04_Load_Fact_Orders_Retail.sql` computes them and sets `order_line_number = 1`. |
| Inventory | `fact.fact_inventory` (new) | No generic procedure exists to diverge from — genuinely new. |

The honest takeaway: the *dimensional model* generalizes very well
(3 of 4 tables needed zero schema changes), but the *load procedures*
still don't, because every generator's CSV shape is its own thing. This
is worth contrasting directly with `examples/healthcare/README.md`, where
the schema itself didn't generalize at all — two different failure modes
of "the generic framework doesn't just work," both real, both now
documented instead of asserted away.

## The load-order dependency

`sql/06_Seed_Pipeline_Metadata_Retail.sql` sets customer=10, product=10
(independent), order=20 (FKs to both), inventory=20 (FKs to product only,
no relative ordering needed against order). See `adf/README.md`.

## Databricks

`databricks/databricks.yml` wires a 10-task job: Bronze (4 entities) →
Silver (4 entities) → Gold dimensions (`dim_customer`, `dim_product` — via
the generic SCD Type 2 notebook, writing into the same Gold tables
banking's and healthcare's bundles would) → Gold facts
(`gold_load_fact_orders_retail.py`, `gold_load_fact_inventory_retail.py`
— bespoke, same reasoning as the SQL path: the generic fact notebook is
written for `fact_sales` specifically, and `fact_inventory` has no
generic notebook to begin with).

## Validation status

- **Data generation**: ran for real, verified (2,000/160/320/8,000 rows,
  correct headers, referentially consistent — see
  `tools/synthetic-data-generator/README.md`).
- **SQL**: written and reviewed against the same patterns
  `examples/banking/sql/` and `examples/healthcare/sql/` already
  established; not executed against a live SQL Server/Azure SQL instance
  in this environment — same caveat as the rest of `src/sql/`.
- **ADF**: no new pipeline JSON to validate (metadata-driven — see
  `adf/README.md`).
- **Databricks bundle**: YAML structurally reviewed (10 tasks, dependency
  graph checked by hand); notebook Python syntax-checked
  (`python3 -m py_compile`). `databricks bundle validate` needs a
  reachable workspace to fully pass — same caveat as banking's and
  healthcare's Databricks sections.

## What's still not done

- Insurance accelerator — its generator doesn't exist yet either.
- `fact_inventory`'s snapshot grain is insert-only, not a true recurring
  periodic snapshot (see `sql/05_Load_Fact_Inventory_Retail.sql`'s header
  comment) — a real gap if this were used to track inventory changes over
  time rather than a single point-in-time load.
- The generic staging tables (`src/sql/06-stored-procedures/00_Create_Staging_Tables.sql`)
  have never actually been used by any real pipeline in this repo —
  every industry accelerator so far (banking, healthcare, retail) has
  needed its own, shaped exactly to its generator's CSV. Not a blocker
  (each accelerator's own staging table is a small, cheap thing to add),
  but worth knowing before assuming the generic ones are load-bearing
  anywhere.
- The actual ADF linked service source path / Databricks mount path
  (`/mnt/adea/raw/retail/...`) assumes the generated CSVs have been
  uploaded to the storage account's `raw` container — not automated here,
  same as banking and healthcare.
