-- =============================================================================
-- Phase 8 — Retail Industry Accelerator
-- fact.fact_inventory — the one entity with no generic equivalent anywhere
-- in src/sql/ (dim.dim_customer, dim.dim_product, fact.fact_orders are all
-- reused unmodified — see README.md). Modeled as a periodic snapshot fact:
-- one row per (product, warehouse) as of the generator's run, not a
-- continuously time-versioned snapshot series — see the load procedure's
-- header comment for what that simplification means in practice.
-- On Synapse dedicated SQL pools, PK/FK below are NOT ENFORCED (informational
-- only) — see src/sql/00-standards/sql-coding-standards.md.
-- =============================================================================

USE [AdeaDW];
GO

IF OBJECT_ID('fact.fact_inventory', 'U') IS NULL
BEGIN
    CREATE TABLE fact.fact_inventory
    (
        inventory_key      BIGINT IDENTITY(1,1) NOT NULL,
        snapshot_date_key   INT           NOT NULL,   -- load date, not a source-provided date
        product_key         INT           NOT NULL,
        source_system        VARCHAR(20)   NOT NULL,
        inventory_id          VARCHAR(50)   NOT NULL,  -- degenerate dimension
        warehouse              VARCHAR(30)   NULL,
        quantity_on_hand         INT           NOT NULL,
        reorder_level              INT           NULL,
        last_restock_date           DATE          NULL,
        created_date                  DATETIME2     NOT NULL DEFAULT (SYSUTCDATETIME()),
        created_by                      SYSNAME       NOT NULL DEFAULT (SUSER_SNAME()),

        CONSTRAINT pk_fact_inventory PRIMARY KEY NONCLUSTERED (inventory_key),
        CONSTRAINT uq_fact_inventory_natural UNIQUE (source_system, inventory_id),
        CONSTRAINT fk_fact_inventory_dim_date FOREIGN KEY (snapshot_date_key)
            REFERENCES dim.dim_date (date_key),
        CONSTRAINT fk_fact_inventory_dim_product FOREIGN KEY (product_key)
            REFERENCES dim.dim_product (product_key)
    );
END
GO
