-- =============================================================================
-- Phase 8 — Healthcare Industry Accelerator
-- dim.dim_patient — SCD Type 2. Not part of the generic framework
-- (src/sql/03-dimensions/) since healthcare has no direct equivalent in the
-- generic model — a patient is meaningfully different from dim.dim_customer
-- (gender, date_of_birth, blood_type, insurance_plan have no generic
-- counterpart), so this is a net-new dimension, not a reuse of dim_customer.
-- Same naming/audit-column/SCD2 conventions as the generic dimensions and
-- examples/banking/sql/01_Create_Dim_Account.sql.
-- =============================================================================

USE [AdeaDW];
GO

IF OBJECT_ID('dim.dim_patient', 'U') IS NULL
BEGIN
    CREATE TABLE dim.dim_patient
    (
        patient_key     INT IDENTITY(1,1) NOT NULL,
        patient_id      VARCHAR(50)   NOT NULL,  -- natural key from source system
        source_system   VARCHAR(20)   NOT NULL,
        location_key    INT           NULL,
        first_name      VARCHAR(100)  NULL,
        last_name       VARCHAR(100)  NULL,
        gender          VARCHAR(10)   NULL,
        date_of_birth   DATE          NULL,
        blood_type      VARCHAR(5)    NULL,
        email           VARCHAR(200)  NULL,
        phone           VARCHAR(30)   NULL,
        insurance_plan  VARCHAR(50)   NULL,
        is_current      BIT           NOT NULL DEFAULT (1),
        effective_date  DATE          NOT NULL DEFAULT (CAST(SYSUTCDATETIME() AS DATE)),
        expiry_date     DATE          NOT NULL DEFAULT ('9999-12-31'),
        created_date    DATETIME2     NOT NULL DEFAULT (SYSUTCDATETIME()),
        created_by      SYSNAME       NOT NULL DEFAULT (SUSER_SNAME()),
        updated_date    DATETIME2     NULL,
        updated_by      SYSNAME       NULL,

        CONSTRAINT pk_dim_patient PRIMARY KEY CLUSTERED (patient_key),
        CONSTRAINT fk_dim_patient_dim_location FOREIGN KEY (location_key)
            REFERENCES dim.dim_location (location_key)
    );
END
GO

-- Only one current row per natural key — see src/sql/03-dimensions/05_Create_Dim_Customer.sql
-- for the same pattern and its Synapse caveat (filtered indexes unsupported there).
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'uq_dim_patient_current' AND object_id = OBJECT_ID('dim.dim_patient')
)
BEGIN
    CREATE UNIQUE INDEX uq_dim_patient_current
        ON dim.dim_patient (patient_id, source_system)
        WHERE is_current = 1;
END
GO
