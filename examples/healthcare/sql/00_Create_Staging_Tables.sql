-- =============================================================================
-- Phase 8 — Healthcare Industry Accelerator
-- Healthcare-specific staging tables, shaped to match
-- tools/synthetic-data-generator's healthcare domain CSV output column-for-
-- column, so ADF's generic file-to-SQL Copy activity
-- (src/adf/pipeline/pl_load_generic_full.json) needs no transformation step.
-- Same rationale as examples/banking/sql/00_Create_Staging_Tables.sql: the
-- generator produces an industry-realistic shape (embedded patient address,
-- no location_id) that doesn't match the generic
-- src/sql/06-stored-procedures/00_Create_Staging_Tables.sql staging tables.
-- =============================================================================

USE [AdeaDW];
GO

IF OBJECT_ID('staging.stg_healthcare_patient', 'U') IS NULL
BEGIN
    CREATE TABLE staging.stg_healthcare_patient
    (
        source_system        VARCHAR(20)  NOT NULL DEFAULT ('HEALTHCARE_CORE'),
        staging_loaded_date  DATETIME2    NOT NULL DEFAULT (SYSUTCDATETIME()),
        patient_id           VARCHAR(50)  NULL,
        first_name           VARCHAR(100) NULL,
        last_name            VARCHAR(100) NULL,
        gender               VARCHAR(10)  NULL,
        date_of_birth        VARCHAR(20)  NULL,
        blood_type           VARCHAR(5)   NULL,
        email                VARCHAR(200) NULL,
        phone                VARCHAR(30)  NULL,
        address_line1        VARCHAR(200) NULL,
        city                 VARCHAR(100) NULL,
        region               VARCHAR(100) NULL,
        postal_code          VARCHAR(20)  NULL,
        country              VARCHAR(100) NULL,
        insurance_plan       VARCHAR(50)  NULL,
        created_date         VARCHAR(20)  NULL
    );
END
GO

IF OBJECT_ID('staging.stg_healthcare_provider', 'U') IS NULL
BEGIN
    CREATE TABLE staging.stg_healthcare_provider
    (
        source_system        VARCHAR(20)  NOT NULL DEFAULT ('HEALTHCARE_CORE'),
        staging_loaded_date  DATETIME2    NOT NULL DEFAULT (SYSUTCDATETIME()),
        provider_id           VARCHAR(50)  NULL,
        first_name            VARCHAR(100) NULL,
        last_name             VARCHAR(100) NULL,
        specialty             VARCHAR(100) NULL,
        npi_number            VARCHAR(20)  NULL,
        facility_name         VARCHAR(200) NULL,
        city                  VARCHAR(100) NULL,
        region                VARCHAR(100) NULL,
        phone                 VARCHAR(30)  NULL,
        created_date          VARCHAR(20)  NULL
    );
END
GO

IF OBJECT_ID('staging.stg_healthcare_claim', 'U') IS NULL
BEGIN
    CREATE TABLE staging.stg_healthcare_claim
    (
        source_system        VARCHAR(20)  NOT NULL DEFAULT ('HEALTHCARE_CORE'),
        staging_loaded_date  DATETIME2    NOT NULL DEFAULT (SYSUTCDATETIME()),
        claim_id              VARCHAR(50)  NULL,
        patient_id            VARCHAR(50)  NULL,
        provider_id           VARCHAR(50)  NULL,
        claim_date            VARCHAR(20)  NULL,
        diagnosis_code        VARCHAR(20)  NULL,
        procedure_code        VARCHAR(20)  NULL,
        claim_amount          VARCHAR(30)  NULL,
        claim_status          VARCHAR(30)  NULL,
        payer                 VARCHAR(100) NULL
    );
END
GO

IF OBJECT_ID('staging.stg_healthcare_pharmacy', 'U') IS NULL
BEGIN
    CREATE TABLE staging.stg_healthcare_pharmacy
    (
        source_system        VARCHAR(20)  NOT NULL DEFAULT ('HEALTHCARE_CORE'),
        staging_loaded_date  DATETIME2    NOT NULL DEFAULT (SYSUTCDATETIME()),
        prescription_id       VARCHAR(50)  NULL,
        patient_id            VARCHAR(50)  NULL,
        provider_id            VARCHAR(50)  NULL,
        drug_name              VARCHAR(100) NULL,
        ndc_code                VARCHAR(20)  NULL,
        quantity                VARCHAR(10)  NULL,
        days_supply             VARCHAR(10)  NULL,
        fill_date                VARCHAR(20)  NULL,
        pharmacy_name             VARCHAR(200) NULL,
        cost                      VARCHAR(30)  NULL
    );
END
GO
