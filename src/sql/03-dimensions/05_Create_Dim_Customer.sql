-- =============================================================================
-- Milestone 2.2 — Core Dimensions
-- dim.dim_customer — SCD Type 2: attribute changes (address, segment, etc.)
-- are tracked as new rows so historical facts still join to the customer
-- state that was true at the time.
-- =============================================================================

USE [AdeaDW];
GO

IF OBJECT_ID('dim.dim_customer', 'U') IS NULL
BEGIN
    CREATE TABLE dim.dim_customer
    (
        customer_key     INT IDENTITY(1,1) NOT NULL,
        customer_id      VARCHAR(50)   NOT NULL,  -- natural key from source system
        source_system    VARCHAR(20)   NOT NULL,  -- dim_source_system.source_system_code
        location_key     INT           NULL,
        first_name       VARCHAR(100)  NULL,
        last_name        VARCHAR(100)  NULL,
        email            VARCHAR(200)  NULL,
        phone            VARCHAR(30)   NULL,
        customer_segment VARCHAR(50)   NULL,
        is_current       BIT           NOT NULL DEFAULT (1),
        effective_date   DATE          NOT NULL DEFAULT (CAST(SYSUTCDATETIME() AS DATE)),
        expiry_date      DATE          NOT NULL DEFAULT ('9999-12-31'),
        created_date     DATETIME2     NOT NULL DEFAULT (SYSUTCDATETIME()),
        created_by       SYSNAME       NOT NULL DEFAULT (SUSER_SNAME()),
        updated_date     DATETIME2     NULL,
        updated_by       SYSNAME       NULL,

        CONSTRAINT pk_dim_customer PRIMARY KEY CLUSTERED (customer_key),
        CONSTRAINT fk_dim_customer_dim_location FOREIGN KEY (location_key)
            REFERENCES dim.dim_location (location_key)
    );
END
GO

-- Only one current row per natural key — the filtered index enforces the
-- SCD Type 2 invariant that the loader (Milestone 2.4) depends on.
-- Filtered indexes are not supported on Synapse dedicated SQL pools; on that
-- target, enforce this invariant in the load procedure instead.
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'uq_dim_customer_current' AND object_id = OBJECT_ID('dim.dim_customer')
)
BEGIN
    CREATE UNIQUE INDEX uq_dim_customer_current
        ON dim.dim_customer (customer_id, source_system)
        WHERE is_current = 1;
END
GO
