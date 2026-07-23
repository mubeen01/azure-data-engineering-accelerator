-- =============================================================================
-- Phase 8 — Banking Industry Accelerator
-- dim.dim_account — SCD Type 2. Not part of the generic framework
-- (src/sql/03-dimensions/) since "account" is banking-specific, not every
-- industry's domain model. Layered here on top of the generic dim.dim_customer
-- and dim.dim_currency via FK, same naming/audit-column conventions as
-- src/sql/00-standards/naming-standards.md.
-- =============================================================================

USE [AdeaDW];
GO

IF OBJECT_ID('dim.dim_account', 'U') IS NULL
BEGIN
    CREATE TABLE dim.dim_account
    (
        account_key     INT IDENTITY(1,1) NOT NULL,
        account_id      VARCHAR(50)   NOT NULL,  -- natural key from source system
        source_system   VARCHAR(20)   NOT NULL,
        customer_key    INT           NOT NULL,
        account_type    VARCHAR(30)   NULL,       -- Checking, Savings, Credit Card, Money Market
        account_status  VARCHAR(30)   NULL,       -- Active, Dormant, Closed
        open_date       DATE          NULL,
        currency_key    INT           NULL,
        is_current      BIT           NOT NULL DEFAULT (1),
        effective_date  DATE          NOT NULL DEFAULT (CAST(SYSUTCDATETIME() AS DATE)),
        expiry_date     DATE          NOT NULL DEFAULT ('9999-12-31'),
        created_date    DATETIME2     NOT NULL DEFAULT (SYSUTCDATETIME()),
        created_by      SYSNAME       NOT NULL DEFAULT (SUSER_SNAME()),
        updated_date    DATETIME2     NULL,
        updated_by      SYSNAME       NULL,

        CONSTRAINT pk_dim_account PRIMARY KEY CLUSTERED (account_key),
        CONSTRAINT fk_dim_account_dim_customer FOREIGN KEY (customer_key)
            REFERENCES dim.dim_customer (customer_key),
        CONSTRAINT fk_dim_account_dim_currency FOREIGN KEY (currency_key)
            REFERENCES dim.dim_currency (currency_key)
    );
END
GO

-- Only one current row per natural key — see src/sql/03-dimensions/05_Create_Dim_Customer.sql
-- for the same pattern and its Synapse caveat (filtered indexes unsupported there).
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'uq_dim_account_current' AND object_id = OBJECT_ID('dim.dim_account')
)
BEGIN
    CREATE UNIQUE INDEX uq_dim_account_current
        ON dim.dim_account (account_id, source_system)
        WHERE is_current = 1;
END
GO
