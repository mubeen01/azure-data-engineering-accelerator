-- =============================================================================
-- Milestone 2.2 — Core Dimensions
-- dim.dim_currency — ISO currency reference (SCD Type 1: small, static
-- reference data, overwritten in place).
-- =============================================================================

USE [AdeaDW];
GO

IF OBJECT_ID('dim.dim_currency', 'U') IS NULL
BEGIN
    CREATE TABLE dim.dim_currency
    (
        currency_key   INT IDENTITY(1,1) NOT NULL,
        currency_code  CHAR(3)      NOT NULL,  -- ISO 4217, e.g. 'USD'
        currency_name  VARCHAR(100) NOT NULL,
        symbol         NVARCHAR(5)  NULL,
        is_active      BIT          NOT NULL DEFAULT (1),
        created_date   DATETIME2    NOT NULL DEFAULT (SYSUTCDATETIME()),
        created_by     SYSNAME      NOT NULL DEFAULT (SUSER_SNAME()),
        updated_date   DATETIME2    NULL,
        updated_by     SYSNAME      NULL,

        CONSTRAINT pk_dim_currency PRIMARY KEY CLUSTERED (currency_key),
        CONSTRAINT uq_dim_currency_code UNIQUE (currency_code)
    );
END
GO
