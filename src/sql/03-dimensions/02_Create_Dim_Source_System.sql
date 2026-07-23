-- =============================================================================
-- Milestone 2.2 — Core Dimensions
-- dim.dim_source_system — reference list of upstream systems (SCD Type 1:
-- small, static reference data, overwritten in place).
-- =============================================================================

USE [AdeaDW];
GO

IF OBJECT_ID('dim.dim_source_system', 'U') IS NULL
BEGIN
    CREATE TABLE dim.dim_source_system
    (
        source_system_key   INT IDENTITY(1,1) NOT NULL,
        source_system_code  VARCHAR(20)   NOT NULL,  -- e.g. 'BANKING_CORE', 'RETAIL_POS'
        source_system_name  VARCHAR(100)  NOT NULL,
        description         VARCHAR(400)  NULL,
        is_active           BIT           NOT NULL DEFAULT (1),
        created_date        DATETIME2     NOT NULL DEFAULT (SYSUTCDATETIME()),
        created_by          SYSNAME       NOT NULL DEFAULT (SUSER_SNAME()),
        updated_date        DATETIME2     NULL,
        updated_by          SYSNAME       NULL,

        CONSTRAINT pk_dim_source_system PRIMARY KEY CLUSTERED (source_system_key),
        CONSTRAINT uq_dim_source_system_code UNIQUE (source_system_code)
    );
END
GO
