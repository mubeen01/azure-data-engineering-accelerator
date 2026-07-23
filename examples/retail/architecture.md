# Retail — Architecture

Example-specific architecture notes. For framework-wide patterns, see
`architecture/` at the repo root.

## Star schema

```text
        dim.dim_location  (generic, shared with banking/healthcare)
              ▲
              │ location_key
        dim.dim_customer  (generic — reused, not extended)
              ▲
              │ customer_key
    fact.fact_orders  (generic — reused, not extended)
              │
              │ product_key
              ▼
        dim.dim_product  (generic — reused, not extended)
              ▲
              │ product_key
    fact.fact_inventory  (new)

dim.dim_date (generic) FKs into both facts via date_key, not shown above.
```

Contrast this with `examples/healthcare/architecture.md`'s diagram, where
almost everything is new. Here, only `fact.fact_inventory` is — see
`README.md`'s "schema gap" section for the full reasoning, including why
table reuse still required new load procedures for the other three.

## Medallion flow

```text
raw/retail/{customers,products,inventory,orders}/*.csv
        │
        ▼  (ADF pl_load_generic_full, metadata-driven — see adf/README.md)
staging.stg_retail_{customer,product,inventory,order}
        │
        ▼  (etl.usp_load_dim_customer_retail / _product_retail /
        │   usp_load_fact_orders_retail / _inventory_retail)
dim.dim_customer, dim.dim_product, fact.fact_orders, fact.fact_inventory
        (the first three are the *same tables* banking's and healthcare's
         data also lands in, distinguished by source_system)

Databricks path, same source data, independent engine:
Bronze (Auto Loader) → Silver (generic conform) → Gold
  (dim_customer/dim_product via generic SCD2 notebook, writing into the
   same Gold tables other accelerators' bundles would;
   fact_orders/fact_inventory via bespoke notebooks)
```

## Grain

- `fact.fact_orders`: one row per order line (`order_id`,
  `order_line_number` — always 1 here, since the generator produces
  complete order lines, not multi-line order headers).
- `fact.fact_inventory`: one row per `(product, warehouse)` as of the
  load date — a periodic snapshot, and specifically a single-snapshot one
  (see `README.md`'s "what's still not done" section for what a
  genuine recurring snapshot would need beyond this).

## Why product needed no schema change but still needed a new procedure

Worth calling out explicitly since it's a subtle distinction: `dim.dim_product`
required zero DDL changes — the generic table's columns already cover
everything retail's product data has. What blocked reusing the generic
*procedure* (`etl.usp_load_dim_product`) is that it hardcodes its source
staging table by name, and the generic staging table itself isn't a
column-for-column match to retail's CSV either (see
`sql/00_Create_Staging_Tables.sql`'s header comment). Schema reuse and
procedure reuse are two different questions with two different answers
here — this accelerator is the first place in the repo where that
distinction actually shows up.
