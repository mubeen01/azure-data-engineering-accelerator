-- =============================================================================
-- Phase 8 — Healthcare Industry Accelerator
-- fact.fact_claims — one row per insurance claim. diagnosis_code/
-- procedure_code/payer are kept as degenerate attributes on the fact rather
-- than dimensionalized (no dim_diagnosis/dim_procedure exists) — same
-- "keep it as a plain attribute unless there's a real reason to dimensionalize"
-- judgment call src/sql/04-facts/03_Create_Fact_Transactions.sql makes for
-- transaction_type. On Synapse dedicated SQL pools, PK/FK below are NOT
-- ENFORCED (informational only) — see src/sql/00-standards/sql-coding-standards.md.
-- =============================================================================

USE [AdeaDW];
GO

IF OBJECT_ID('fact.fact_claims', 'U') IS NULL
BEGIN
    CREATE TABLE fact.fact_claims
    (
        claim_key         BIGINT IDENTITY(1,1) NOT NULL,
        date_key          INT           NOT NULL,   -- claim date
        patient_key       INT           NOT NULL,
        provider_key      INT           NOT NULL,
        source_system     VARCHAR(20)   NOT NULL,
        claim_id          VARCHAR(50)   NOT NULL,    -- degenerate dimension
        diagnosis_code    VARCHAR(20)   NULL,
        procedure_code    VARCHAR(20)   NULL,
        claim_amount      DECIMAL(18,4) NOT NULL,
        claim_status      VARCHAR(30)   NULL,        -- Paid, Denied, Pending, Under Review
        payer             VARCHAR(100)  NULL,
        created_date      DATETIME2     NOT NULL DEFAULT (SYSUTCDATETIME()),
        created_by        SYSNAME       NOT NULL DEFAULT (SUSER_SNAME()),

        CONSTRAINT pk_fact_claims PRIMARY KEY NONCLUSTERED (claim_key),
        CONSTRAINT uq_fact_claims_natural UNIQUE (source_system, claim_id),
        CONSTRAINT fk_fact_claims_dim_date FOREIGN KEY (date_key)
            REFERENCES dim.dim_date (date_key),
        CONSTRAINT fk_fact_claims_dim_patient FOREIGN KEY (patient_key)
            REFERENCES dim.dim_patient (patient_key),
        CONSTRAINT fk_fact_claims_dim_provider FOREIGN KEY (provider_key)
            REFERENCES dim.dim_provider (provider_key)
    );
END
GO
