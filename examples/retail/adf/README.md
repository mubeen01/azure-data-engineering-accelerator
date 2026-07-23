# Retail — ADF

Same story as `examples/healthcare/adf/README.md`: no retail-specific
pipeline JSON, because `src/adf/` is metadata-driven (see
`src/adf/README.md`). Retail's actual "ADF contribution" is
[`../sql/06_Seed_Pipeline_Metadata_Retail.sql`](../sql/06_Seed_Pipeline_Metadata_Retail.sql) —
four rows, one per source object:

| `object_name` | `load_priority` | `load_procedure_name` |
|---|---|---|
| `retail_customer` | 10 | `etl.usp_load_dim_customer_retail` |
| `retail_product` | 10 | `etl.usp_load_dim_product_retail` |
| `retail_order` | 20 | `etl.usp_load_fact_orders_retail` |
| `retail_inventory` | 20 | `etl.usp_load_fact_inventory_retail` |

`customer` and `product` are independent of each other (priority 10,
no FK between them); `order` FKs to both, so it needs both loaded first
(priority 20); `inventory` only FKs to `product` but is seeded at
priority 20 too — there's no ordering requirement between `order` and
`inventory` themselves, so tying them for third place is correct, not
arbitrary (see `examples/banking/README.md`'s `account`/`loan` for the
same "same tier, no relative ordering needed" situation).

Once `src/infrastructure/` is deployed and the generated CSVs
(`datasets/retail/*.csv`) are uploaded to the storage account's `raw`
container at `raw/retail/<object>/`, `pl_master_orchestrator` picks up
these four rows the same way it does banking's and healthcare's — no
additional ADF authoring required.
