-- =============================================================================
-- Phase 8 — Healthcare Industry Accelerator
-- etl.usp_load_dim_provider_healthcare — plain SCD Type 2 expire-then-insert,
-- no dim_location resolution needed (see dim_provider's own header comment
-- for why). Simpler than usp_load_dim_patient_healthcare as a direct result.
-- =============================================================================

USE [AdeaDW];
GO

CREATE OR ALTER PROCEDURE etl.usp_load_dim_provider_healthcare
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v_run_key BIGINT;
    DECLARE @v_rows_expired INT = 0, @v_rows_inserted INT = 0;
    DECLARE @v_load_date DATE = CAST(SYSUTCDATETIME() AS DATE);

    INSERT INTO audit.log_etl_run (procedure_name, start_time, status)
    VALUES ('etl.usp_load_dim_provider_healthcare', SYSUTCDATETIME(), 'RUNNING');
    SET @v_run_key = SCOPE_IDENTITY();

    BEGIN TRY
        BEGIN TRANSACTION;

        ;WITH src AS (
            SELECT DISTINCT
                stg.source_system,
                stg.provider_id,
                stg.first_name,
                stg.last_name,
                stg.specialty,
                stg.npi_number,
                stg.facility_name,
                stg.city,
                stg.region,
                stg.phone
            FROM staging.stg_healthcare_provider AS stg
            WHERE stg.provider_id IS NOT NULL
        )
        UPDATE tgt
        SET is_current = 0,
            expiry_date = DATEADD(DAY, -1, @v_load_date),
            updated_date = SYSUTCDATETIME(),
            updated_by = SUSER_SNAME()
        FROM dim.dim_provider AS tgt
        INNER JOIN src
            ON src.provider_id = tgt.provider_id
           AND src.source_system = tgt.source_system
        WHERE tgt.is_current = 1
          AND (
                ISNULL(tgt.specialty, '') <> ISNULL(src.specialty, '')
             OR ISNULL(tgt.facility_name, '') <> ISNULL(src.facility_name, '')
             OR ISNULL(tgt.city, '') <> ISNULL(src.city, '')
             OR ISNULL(tgt.region, '') <> ISNULL(src.region, '')
             OR ISNULL(tgt.phone, '') <> ISNULL(src.phone, '')
          );

        SET @v_rows_expired = @@ROWCOUNT;

        ;WITH src AS (
            SELECT DISTINCT
                stg.source_system,
                stg.provider_id,
                stg.first_name,
                stg.last_name,
                stg.specialty,
                stg.npi_number,
                stg.facility_name,
                stg.city,
                stg.region,
                stg.phone
            FROM staging.stg_healthcare_provider AS stg
            WHERE stg.provider_id IS NOT NULL
        )
        INSERT INTO dim.dim_provider (
            provider_id, source_system, first_name, last_name, specialty,
            npi_number, facility_name, city, region, phone,
            is_current, effective_date, expiry_date
        )
        SELECT
            src.provider_id, src.source_system, src.first_name, src.last_name, src.specialty,
            src.npi_number, src.facility_name, src.city, src.region, src.phone,
            1, @v_load_date, '9999-12-31'
        FROM src
        LEFT JOIN dim.dim_provider AS cur
            ON cur.provider_id = src.provider_id
           AND cur.source_system = src.source_system
           AND cur.is_current = 1
        WHERE cur.provider_key IS NULL;

        SET @v_rows_inserted = @@ROWCOUNT;

        COMMIT TRANSACTION;

        UPDATE audit.log_etl_run
        SET end_time = SYSUTCDATETIME(), status = 'SUCCESS',
            rows_updated = @v_rows_expired, rows_inserted = @v_rows_inserted
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
