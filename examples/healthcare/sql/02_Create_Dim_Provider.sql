-- =============================================================================
-- Phase 8 — Healthcare Industry Accelerator
-- dim.dim_provider — SCD Type 2. Deliberately does *not* FK to dim.dim_location
-- the way dim_patient does: the generator's provider records carry only
-- city/region (no street address/postal code), so there's no real location
-- entity to synthesize the way examples/healthcare/sql/05_Load_Dim_Patient_Healthcare.sql
-- does for patients — city/region are kept as plain denormalized attributes
-- instead. A deliberate simplification, not every dimension needs a location
-- FK (dim.dim_employee is the only generic dimension that has one, and even
-- there it's nullable).
-- =============================================================================

USE [AdeaDW];
GO

IF OBJECT_ID('dim.dim_provider', 'U') IS NULL
BEGIN
    CREATE TABLE dim.dim_provider
    (
        provider_key    INT IDENTITY(1,1) NOT NULL,
        provider_id     VARCHAR(50)   NOT NULL,  -- natural key from source system
        source_system   VARCHAR(20)   NOT NULL,
        first_name      VARCHAR(100)  NULL,
        last_name       VARCHAR(100)  NULL,
        specialty       VARCHAR(100)  NULL,
        npi_number      VARCHAR(20)   NULL,
        facility_name   VARCHAR(200)  NULL,
        city            VARCHAR(100)  NULL,
        region          VARCHAR(100)  NULL,
        phone           VARCHAR(30)   NULL,
        is_current      BIT           NOT NULL DEFAULT (1),
        effective_date  DATE          NOT NULL DEFAULT (CAST(SYSUTCDATETIME() AS DATE)),
        expiry_date     DATE          NOT NULL DEFAULT ('9999-12-31'),
        created_date    DATETIME2     NOT NULL DEFAULT (SYSUTCDATETIME()),
        created_by      SYSNAME       NOT NULL DEFAULT (SUSER_SNAME()),
        updated_date    DATETIME2     NULL,
        updated_by      SYSNAME       NULL,

        CONSTRAINT pk_dim_provider PRIMARY KEY CLUSTERED (provider_key)
    );
END
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'uq_dim_provider_current' AND object_id = OBJECT_ID('dim.dim_provider')
)
BEGIN
    CREATE UNIQUE INDEX uq_dim_provider_current
        ON dim.dim_provider (provider_id, source_system)
        WHERE is_current = 1;
END
GO
