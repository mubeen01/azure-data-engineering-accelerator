-- =============================================================================
-- Milestone 2.2 — Core Dimensions
-- dim.dim_date — static calendar dimension (SCD Type 1: rows are overwritten,
-- no history needed for a calendar). Populated by a seed script in
-- src/sql/09-seed-data/, not here.
-- =============================================================================

USE [AdeaDW];
GO

IF OBJECT_ID('dim.dim_date', 'U') IS NULL
BEGIN
    CREATE TABLE dim.dim_date
    (
        date_key        INT          NOT NULL,   -- surrogate + natural, format YYYYMMDD
        full_date       DATE         NOT NULL,
        day_of_week     TINYINT      NOT NULL,    -- 1 = Sunday .. 7 = Saturday
        day_name        VARCHAR(10)  NOT NULL,
        day_of_month    TINYINT      NOT NULL,
        day_of_year     SMALLINT     NOT NULL,
        week_of_year    TINYINT      NOT NULL,
        month_number    TINYINT      NOT NULL,
        month_name      VARCHAR(10)  NOT NULL,
        quarter_number  TINYINT      NOT NULL,
        year_number     SMALLINT     NOT NULL,
        is_weekend      BIT          NOT NULL DEFAULT (0),
        is_holiday      BIT          NOT NULL DEFAULT (0),
        fiscal_year     SMALLINT     NULL,
        fiscal_quarter  TINYINT      NULL,
        fiscal_period   TINYINT      NULL,
        created_date    DATETIME2    NOT NULL DEFAULT (SYSUTCDATETIME()),
        created_by      SYSNAME      NOT NULL DEFAULT (SUSER_SNAME()),
        updated_date    DATETIME2    NULL,
        updated_by      SYSNAME      NULL,

        CONSTRAINT pk_dim_date PRIMARY KEY CLUSTERED (date_key),
        CONSTRAINT uq_dim_date_full_date UNIQUE (full_date)
    );
END
GO
