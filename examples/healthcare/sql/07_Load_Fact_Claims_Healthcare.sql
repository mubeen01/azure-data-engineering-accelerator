-- =============================================================================
-- Phase 8 — Healthcare Industry Accelerator
-- etl.usp_load_fact_claims_healthcare — idempotent append (anti-join on the
-- natural key), same shape as the generic fact loaders
-- (src/sql/06-stored-procedures/09_Load_Fact_Orders.sql). Must run after
-- usp_load_dim_patient_healthcare and usp_load_dim_provider_healthcare.
-- =============================================================================

USE [AdeaDW];
GO

CREATE OR ALTER PROCEDURE etl.usp_load_fact_claims_healthcare
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v_run_key BIGINT;
    DECLARE @v_rows_inserted INT = 0;

    INSERT INTO audit.log_etl_run (procedure_name, start_time, status)
    VALUES ('etl.usp_load_fact_claims_healthcare', SYSUTCDATETIME(), 'RUNNING');
    SET @v_run_key = SCOPE_IDENTITY();

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO fact.fact_claims (
            date_key, patient_key, provider_key, source_system, claim_id,
            diagnosis_code, procedure_code, claim_amount, claim_status, payer
        )
        SELECT
            CONVERT(INT, FORMAT(TRY_CAST(stg.claim_date AS DATE), 'yyyyMMdd')) AS date_key,
            pat.patient_key,
            prov.provider_key,
            stg.source_system,
            stg.claim_id,
            stg.diagnosis_code,
            stg.procedure_code,
            TRY_CAST(stg.claim_amount AS DECIMAL(18,4)),
            stg.claim_status,
            stg.payer
        FROM staging.stg_healthcare_claim AS stg
        INNER JOIN dim.dim_patient AS pat
            ON pat.patient_id = stg.patient_id
           AND pat.source_system = stg.source_system
           AND pat.is_current = 1
        INNER JOIN dim.dim_provider AS prov
            ON prov.provider_id = stg.provider_id
           AND prov.source_system = stg.source_system
           AND prov.is_current = 1
        WHERE stg.claim_id IS NOT NULL
          AND NOT EXISTS (
              SELECT 1 FROM fact.fact_claims AS f
              WHERE f.source_system = stg.source_system AND f.claim_id = stg.claim_id
          );

        SET @v_rows_inserted = @@ROWCOUNT;

        COMMIT TRANSACTION;

        UPDATE audit.log_etl_run
        SET end_time = SYSUTCDATETIME(), status = 'SUCCESS', rows_inserted = @v_rows_inserted
        WHERE run_key = @v_run_key;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;

        UPDATE audit.log_etl_run
        SET end_time = SYSUTCDATETIME(), status = 'FAILED', error_message = ERROR_MESSAGE()
        WHERE run_key = @v_run_key;

        THROW;
    END CATCH
END
GO
