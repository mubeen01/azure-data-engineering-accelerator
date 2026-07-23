-- =============================================================================
-- Phase 8 — Banking Industry Accelerator
-- dim.dim_loan — SCD Type 2 (a loan's status transitions Active -> Paid Off
-- / Default over time; modeled as a dimension, not a fact, since there's no
-- recurring transactional event here — origination is a one-time attribute,
-- status is what changes). Banking-specific, layered on the generic
-- dim.dim_customer via FK, same conventions as dim_account.
-- =============================================================================

USE [AdeaDW];
GO

IF OBJECT_ID('dim.dim_loan', 'U') IS NULL
BEGIN
    CREATE TABLE dim.dim_loan
    (
        loan_key          INT IDENTITY(1,1) NOT NULL,
        loan_id           VARCHAR(50)   NOT NULL,  -- natural key from source system
        source_system     VARCHAR(20)   NOT NULL,
        customer_key      INT           NOT NULL,
        loan_type         VARCHAR(30)   NULL,       -- Mortgage, Auto, Personal, Student
        principal_amount  DECIMAL(18,4) NULL,
        interest_rate     DECIMAL(9,4)  NULL,
        term_months       INT           NULL,
        origination_date  DATE          NULL,
        status            VARCHAR(30)   NULL,       -- Active, Paid Off, Default
        is_current        BIT           NOT NULL DEFAULT (1),
        effective_date    DATE          NOT NULL DEFAULT (CAST(SYSUTCDATETIME() AS DATE)),
        expiry_date       DATE          NOT NULL DEFAULT ('9999-12-31'),
        created_date      DATETIME2     NOT NULL DEFAULT (SYSUTCDATETIME()),
        created_by        SYSNAME       NOT NULL DEFAULT (SUSER_SNAME()),
        updated_date      DATETIME2     NULL,
        updated_by        SYSNAME       NULL,

        CONSTRAINT pk_dim_loan PRIMARY KEY CLUSTERED (loan_key),
        CONSTRAINT fk_dim_loan_dim_customer FOREIGN KEY (customer_key)
            REFERENCES dim.dim_customer (customer_key)
    );
END
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'uq_dim_loan_current' AND object_id = OBJECT_ID('dim.dim_loan')
)
BEGIN
    CREATE UNIQUE INDEX uq_dim_loan_current
        ON dim.dim_loan (loan_id, source_system)
        WHERE is_current = 1;
END
GO
