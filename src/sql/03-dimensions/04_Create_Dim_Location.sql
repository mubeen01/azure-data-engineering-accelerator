-- =============================================================================
-- Milestone 2.2 — Core Dimensions
-- dim.dim_location — physical/postal locations (SCD Type 1: address corrections
-- overwrite in place; this is not tracking branch/store relocation history).
-- Referenced by dim_customer and dim_employee.
-- =============================================================================

USE [AdeaDW];
GO

IF OBJECT_ID('dim.dim_location', 'U') IS NULL
BEGIN
    CREATE TABLE dim.dim_location
    (
        location_key    INT IDENTITY(1,1) NOT NULL,
        location_id     VARCHAR(50)   NOT NULL,  -- natural key from source system
        source_system   VARCHAR(20)   NOT NULL,
        address_line1   VARCHAR(200)  NULL,
        address_line2   VARCHAR(200)  NULL,
        city            VARCHAR(100)  NULL,
        region          VARCHAR(100)  NULL,      -- state/province
        postal_code     VARCHAR(20)   NULL,
        country         VARCHAR(100)  NOT NULL,
        latitude        DECIMAL(9,6)  NULL,
        longitude       DECIMAL(9,6)  NULL,
        created_date    DATETIME2     NOT NULL DEFAULT (SYSUTCDATETIME()),
        created_by      SYSNAME       NOT NULL DEFAULT (SUSER_SNAME()),
        updated_date    DATETIME2     NULL,
        updated_by      SYSNAME       NULL,

        CONSTRAINT pk_dim_location PRIMARY KEY CLUSTERED (location_key),
        CONSTRAINT uq_dim_location_id UNIQUE (location_id, source_system)
    );
END
GO
