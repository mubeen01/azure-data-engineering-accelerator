-- =============================================================================
-- Phase 8 — Banking Industry Accelerator
-- Banking-specific staging tables, shaped to match
-- tools/synthetic-data-generator's actual CSV output column-for-column, so
-- ADF's generic file-to-SQL Copy activity (src/adf/pipeline/pl_load_generic_full.json)
-- needs no transformation step. This is deliberately a different shape
-- from the generic src/sql/06-stored-procedures/00_Create_Staging_Tables.sql
-- staging tables — see examples/banking/README.md for why (the generator
-- produces an industry-realistic shape: embedded customer address, no
-- location_id; transactions keyed by account, not customer).
-- =============================================================================

USE [AdeaDW];
GO

IF OBJECT_ID('staging.stg_banking_customer', 'U') IS NULL
BEGIN
    CREATE TABLE staging.stg_banking_customer
    (
        source_system        VARCHAR(20)  NOT NULL DEFAULT ('BANKING_CORE'),
        staging_loaded_date  DATETIME2    NOT NULL DEFAULT (SYSUTCDATETIME()),
        customer_id          VARCHAR(50)  NULL,
        first_name           VARCHAR(100) NULL,
        last_name            VARCHAR(100) NULL,
        email                VARCHAR(200) NULL,
        phone                VARCHAR(30)  NULL,
        date_of_birth        VARCHAR(20)  NULL,
        address_line1        VARCHAR(200) NULL,
        city                 VARCHAR(100) NULL,
        region               VARCHAR(100) NULL,
        postal_code          VARCHAR(20)  NULL,
        country              VARCHAR(100) NULL,
        customer_segment     VARCHAR(50)  NULL,
        created_date         VARCHAR(20)  NULL
    );
END
GO

IF OBJECT_ID('staging.stg_banking_account', 'U') IS NULL
BEGIN
    CREATE TABLE staging.stg_banking_account
    (
        source_system        VARCHAR(20)  NOT NULL DEFAULT ('BANKING_CORE'),
        staging_loaded_date  DATETIME2    NOT NULL DEFAULT (SYSUTCDATETIME()),
        account_id           VARCHAR(50)  NULL,
        customer_id          VARCHAR(50)  NULL,
        account_type         VARCHAR(30)  NULL,
        account_status       VARCHAR(30)  NULL,
        open_date            VARCHAR(20)  NULL,
        currency_code        VARCHAR(3)   NULL,
        balance              VARCHAR(30)  NULL
    );
END
GO

IF OBJECT_ID('staging.stg_banking_loan', 'U') IS NULL
BEGIN
    CREATE TABLE staging.stg_banking_loan
    (
        source_system        VARCHAR(20)  NOT NULL DEFAULT ('BANKING_CORE'),
        staging_loaded_date  DATETIME2    NOT NULL DEFAULT (SYSUTCDATETIME()),
        loan_id              VARCHAR(50)  NULL,
        customer_id          VARCHAR(50)  NULL,
        loan_type            VARCHAR(30)  NULL,
        principal_amount     VARCHAR(30)  NULL,
        interest_rate        VARCHAR(30)  NULL,
        term_months          VARCHAR(10)  NULL,
        origination_date     VARCHAR(20)  NULL,
        status               VARCHAR(30)  NULL
    );
END
GO

IF OBJECT_ID('staging.stg_banking_transaction', 'U') IS NULL
BEGIN
    CREATE TABLE staging.stg_banking_transaction
    (
        source_system        VARCHAR(20)  NOT NULL DEFAULT ('BANKING_CORE'),
        staging_loaded_date  DATETIME2    NOT NULL DEFAULT (SYSUTCDATETIME()),
        transaction_id       VARCHAR(50)  NULL,
        account_id           VARCHAR(50)  NULL,
        transaction_date     VARCHAR(20)  NULL,
        transaction_type     VARCHAR(30)  NULL,
        amount               VARCHAR(30)  NULL,
        currency_code        VARCHAR(3)   NULL,
        running_balance      VARCHAR(30)  NULL,
        channel              VARCHAR(30)  NULL
    );
END
GO
