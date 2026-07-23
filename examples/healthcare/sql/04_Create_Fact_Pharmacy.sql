-- =============================================================================
-- Phase 8 — Healthcare Industry Accelerator
-- fact.fact_pharmacy — one row per prescription fill. drug_name/ndc_code/
-- pharmacy_name kept as degenerate attributes, same judgment call as
-- fact_claims (see that file's header comment).
-- =============================================================================

USE [AdeaDW];
GO

IF OBJECT_ID('fact.fact_pharmacy', 'U') IS NULL
BEGIN
    CREATE TABLE fact.fact_pharmacy
    (
        pharmacy_key      BIGINT IDENTITY(1,1) NOT NULL,
        date_key          INT           NOT NULL,   -- fill date
        patient_key       INT           NOT NULL,
        provider_key      INT           NOT NULL,
        source_system     VARCHAR(20)   NOT NULL,
        prescription_id   VARCHAR(50)   NOT NULL,    -- degenerate dimension
        drug_name         VARCHAR(100)  NULL,
        ndc_code          VARCHAR(20)   NULL,
        quantity          DECIMAL(18,4) NULL,
        days_supply       INT           NULL,
        pharmacy_name     VARCHAR(200)  NULL,
        cost              DECIMAL(18,4) NOT NULL,
        created_date      DATETIME2     NOT NULL DEFAULT (SYSUTCDATETIME()),
        created_by        SYSNAME       NOT NULL DEFAULT (SUSER_SNAME()),

        CONSTRAINT pk_fact_pharmacy PRIMARY KEY NONCLUSTERED (pharmacy_key),
        CONSTRAINT uq_fact_pharmacy_natural UNIQUE (source_system, prescription_id),
        CONSTRAINT fk_fact_pharmacy_dim_date FOREIGN KEY (date_key)
            REFERENCES dim.dim_date (date_key),
        CONSTRAINT fk_fact_pharmacy_dim_patient FOREIGN KEY (patient_key)
            REFERENCES dim.dim_patient (patient_key),
        CONSTRAINT fk_fact_pharmacy_dim_provider FOREIGN KEY (provider_key)
            REFERENCES dim.dim_provider (provider_key)
    );
END
GO
