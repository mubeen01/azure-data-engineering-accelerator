-- =============================================================================
-- Milestone 2.3 — Core Facts
-- fact.fact_transactions — one row per financial transaction (banking grain:
-- deposit/withdrawal/transfer/payment). There is no dim_account in Milestone
-- 2.2's scope, so account_id is a degenerate dimension here rather than a FK.
-- The surrogate key is UNIQUE NONCLUSTERED, not the clustered index: fact
-- tables get a clustered columnstore index in src/sql/08-indexes/ per
-- src/sql/00-standards/sql-coding-standards.md.
-- On Synapse dedicated SQL pools, PK/FK/UNIQUE below are NOT ENFORCED
-- (informational only) — see the compatibility table in that same doc.
-- =============================================================================

USE [AdeaDW];
GO

IF OBJECT_ID('fact.fact_transactions', 'U') IS NULL
BEGIN
    CREATE TABLE fact.fact_transactions
    (
        transaction_key    BIGINT IDENTITY(1,1) NOT NULL,
        date_key           INT           NOT NULL,
        customer_key       INT           NOT NULL,
        employee_key       INT           NULL,      -- teller/agent
        location_key       INT           NULL,       -- branch
        currency_key       INT           NULL,
        source_system      VARCHAR(20)   NOT NULL,
        transaction_id     VARCHAR(50)   NOT NULL,   -- degenerate dimension: source transaction id
        account_id         VARCHAR(50)   NOT NULL,   -- degenerate dimension: source account id
        transaction_type   VARCHAR(30)   NOT NULL,   -- e.g. Deposit, Withdrawal, Transfer, Payment
        transaction_amount DECIMAL(18,4) NOT NULL,
        running_balance    DECIMAL(18,4) NULL,
        created_date       DATETIME2     NOT NULL DEFAULT (SYSUTCDATETIME()),
        created_by         SYSNAME       NOT NULL DEFAULT (SUSER_SNAME()),
        updated_date       DATETIME2     NULL,
        updated_by         SYSNAME       NULL,

        CONSTRAINT pk_fact_transactions PRIMARY KEY NONCLUSTERED (transaction_key),
        CONSTRAINT uq_fact_transactions_natural UNIQUE (source_system, transaction_id),
        CONSTRAINT fk_fact_transactions_dim_date FOREIGN KEY (date_key)
            REFERENCES dim.dim_date (date_key),
        CONSTRAINT fk_fact_transactions_dim_customer FOREIGN KEY (customer_key)
            REFERENCES dim.dim_customer (customer_key),
        CONSTRAINT fk_fact_transactions_dim_employee FOREIGN KEY (employee_key)
            REFERENCES dim.dim_employee (employee_key),
        CONSTRAINT fk_fact_transactions_dim_location FOREIGN KEY (location_key)
            REFERENCES dim.dim_location (location_key),
        CONSTRAINT fk_fact_transactions_dim_currency FOREIGN KEY (currency_key)
            REFERENCES dim.dim_currency (currency_key)
    );
END
GO
