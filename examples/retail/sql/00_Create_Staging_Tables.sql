-- =============================================================================
-- Phase 8 — Retail Industry Accelerator
-- Retail-specific staging tables, shaped to match
-- tools/synthetic-data-generator's retail domain CSV output column-for-column,
-- same rationale as examples/banking/sql/00_Create_Staging_Tables.sql and
-- examples/healthcare/sql/00_Create_Staging_Tables.sql.
--
-- Note this repo's *generic* staging tables (src/sql/06-stored-procedures/
-- 00_Create_Staging_Tables.sql — staging.stg_customer, staging.stg_product,
-- staging.stg_orders) aren't a drop-in fit even for retail's product data,
-- the closest match of the four: column order differs (unit_price/unit_cost
-- are swapped), there's no created_date column there at all, and
-- staging_batch_id is NOT NULL with no default — ADF's generic Copy
-- activity (src/adf/pipeline/pl_load_generic_full.json) supplies none of
-- that, only the CSV's own columns. A bespoke staging table shaped exactly
-- to the CSV, same as banking's and healthcare's, is the safe choice
-- regardless — not just a staging_batch_id workaround. What *is* reused
-- unmodified is the generic dim.dim_customer, dim.dim_product, and
-- fact.fact_orders TABLES themselves (see this folder's load procedures)
-- — only the staging landing zone and load procedure are retail-specific,
-- not the target schema. See README.md's "reconciliation gap" section.
-- =============================================================================

USE [AdeaDW];
GO

IF OBJECT_ID('staging.stg_retail_customer', 'U') IS NULL
BEGIN
    CREATE TABLE staging.stg_retail_customer
    (
        source_system        VARCHAR(20)  NOT NULL DEFAULT ('RETAIL_CORE'),
        staging_loaded_date  DATETIME2    NOT NULL DEFAULT (SYSUTCDATETIME()),
        customer_id          VARCHAR(50)  NULL,
        first_name            VARCHAR(100) NULL,
        last_name              VARCHAR(100) NULL,
        email                   VARCHAR(200) NULL,
        phone                   VARCHAR(30)  NULL,
        address_line1           VARCHAR(200) NULL,
        city                    VARCHAR(100) NULL,
        region                  VARCHAR(100) NULL,
        postal_code             VARCHAR(20)  NULL,
        country                 VARCHAR(100) NULL,
        customer_segment        VARCHAR(50)  NULL,
        signup_date              VARCHAR(20)  NULL
    );
END
GO

IF OBJECT_ID('staging.stg_retail_product', 'U') IS NULL
BEGIN
    CREATE TABLE staging.stg_retail_product
    (
        source_system        VARCHAR(20)  NOT NULL DEFAULT ('RETAIL_CORE'),
        staging_loaded_date  DATETIME2    NOT NULL DEFAULT (SYSUTCDATETIME()),
        product_id            VARCHAR(50)  NULL,
        product_name           VARCHAR(200) NULL,
        category                VARCHAR(100) NULL,
        subcategory             VARCHAR(100) NULL,
        brand                    VARCHAR(100) NULL,
        unit_cost                VARCHAR(30)  NULL,
        unit_price                VARCHAR(30)  NULL,
        created_date               VARCHAR(20)  NULL
    );
END
GO

IF OBJECT_ID('staging.stg_retail_order', 'U') IS NULL
BEGIN
    CREATE TABLE staging.stg_retail_order
    (
        source_system        VARCHAR(20)  NOT NULL DEFAULT ('RETAIL_CORE'),
        staging_loaded_date  DATETIME2    NOT NULL DEFAULT (SYSUTCDATETIME()),
        order_id               VARCHAR(50)  NULL,
        customer_id             VARCHAR(50)  NULL,
        product_id               VARCHAR(50)  NULL,
        order_date                 VARCHAR(20)  NULL,
        quantity                    VARCHAR(10)  NULL,
        unit_price                   VARCHAR(30)  NULL,
        discount_pct                   VARCHAR(10)  NULL,
        order_status                     VARCHAR(30)  NULL,
        channel                            VARCHAR(30)  NULL
    );
END
GO

IF OBJECT_ID('staging.stg_retail_inventory', 'U') IS NULL
BEGIN
    CREATE TABLE staging.stg_retail_inventory
    (
        source_system        VARCHAR(20)  NOT NULL DEFAULT ('RETAIL_CORE'),
        staging_loaded_date  DATETIME2    NOT NULL DEFAULT (SYSUTCDATETIME()),
        inventory_id           VARCHAR(50)  NULL,
        product_id               VARCHAR(50)  NULL,
        warehouse                 VARCHAR(30)  NULL,
        quantity_on_hand            VARCHAR(10)  NULL,
        reorder_level                 VARCHAR(10)  NULL,
        last_restock_date               VARCHAR(20)  NULL
    );
END
GO
