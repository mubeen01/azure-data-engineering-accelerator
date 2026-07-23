-- =============================================================================
-- Phase 8 — Healthcare Industry Accelerator
-- etl.usp_load_fact_pharmacy_healthcare — same idempotent-append shape as
-- usp_load_fact_claims_healthcare. Must run after usp_load_dim_patient_healthcare
-- and usp_load_dim_provider_healthcare (provider here is the prescriber).
-- =============================================================================

USE [AdeaDW];
GO

CREATE OR ALTER PROCEDURE etl.usp_load_fact_pharmacy_healthcare
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v_run_key BIGINT;
    DECLARE @v_rows_inserted INT = 0;

    INSERT INTO audit.log_etl_run (procedure_name, start_time, status)
    VALUES ('etl.usp_load_fact_pharmacy_healthcare', SYSUTCDATETIME(), 'RUNNING');
    SET @v_run_key = SCOPE_IDENTITY();

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO fact.fact_pharmacy (
            date_key, patient_key, provider_key, source_system, prescription_id,
            drug_name, ndc_code, quantity, days_supply, pharmacy_name, cost
        )
        SELECT
            CONVERT(INT, FORMAT(TRY_CAST(stg.fill_date AS DATE), 'yyyyMMdd')) AS date_key,
            pat.patient_key,
            prov.provider_key,
            stg.source_system,
            stg.prescription_id,
            stg.drug_name,
            stg.ndc_code,
            TRY_CAST(stg.quantity AS DECIMAL(18,4)),
            TRY_CAST(stg.days_supply AS INT),
            stg.pharmacy_name,
            TRY_CAST(stg.cost AS DECIMAL(18,4))
        FROM staging.stg_healthcare_pharmacy AS stg
        INNER JOIN dim.dim_patient AS pat
            ON pat.patient_id = stg.patient_id
           AND pat.source_system = stg.source_system
           AND pat.is_current = 1
        INNER JOIN dim.dim_provider AS prov
            ON prov.provider_id = stg.provider_id
           AND prov.source_system = stg.source_system
           AND prov.is_current = 1
        WHERE stg.prescription_id IS NOT NULL
          AND NOT EXISTS (
              SELECT 1 FROM fact.fact_pharmacy AS f
              WHERE f.source_system = stg.source_system AND f.prescription_id = stg.prescription_id
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
