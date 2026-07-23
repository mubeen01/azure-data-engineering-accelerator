-- =============================================================================
-- Milestone 2.2 — Core Dimensions
-- dim.dim_product — SCD Type 2: price/category changes are tracked as new
-- rows so historical facts still join to the product state that was true at
-- the time of the transaction.
-- =============================================================================

USE [AdeaDW];
GO

IF OBJECT_ID('dim.dim_product', 'U') IS NULL
BEGIN
    CREATE TABLE dim.dim_product
    (
        product_key     INT IDENTITY(1,1) NOT NULL,
        product_id      VARCHAR(50)   NOT NULL,  -- natural key from source system
        source_system   VARCHAR(20)   NOT NULL,  -- dim_source_system.source_system_code
        product_name    VARCHAR(200)  NOT NULL,
        category        VARCHAR(100)  NULL,
        subcategory     VARCHAR(100)  NULL,
        brand           VARCHAR(100)  NULL,
        unit_price      DECIMAL(18,4) NULL,
        unit_cost       DECIMAL(18,4) NULL,
        currency_key    INT           NULL,
        is_current      BIT           NOT NULL DEFAULT (1),
        effective_date  DATE          NOT NULL DEFAULT (CAST(SYSUTCDATETIME() AS DATE)),
        expiry_date     DATE          NOT NULL DEFAULT ('9999-12-31'),
        created_date    DATETIME2     NOT NULL DEFAULT (SYSUTCDATETIME()),
        created_by      SYSNAME       NOT NULL DEFAULT (SUSER_SNAME()),
        updated_date    DATETIME2     NULL,
        updated_by      SYSNAME       NULL,

        CONSTRAINT pk_dim_product PRIMARY KEY CLUSTERED (product_key),
        CONSTRAINT fk_dim_product_dim_currency FOREIGN KEY (currency_key)
            REFERENCES dim.dim_currency (currency_key)
    );
END
GO

-- Only one current row per natural key — see dim_customer for the same
-- pattern and its Synapse caveat.
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'uq_dim_product_current' AND object_id = OBJECT_ID('dim.dim_product')
)
BEGIN
    CREATE UNIQUE INDEX uq_dim_product_current
        ON dim.dim_product (product_id, source_system)
        WHERE is_current = 1;
END
GO
