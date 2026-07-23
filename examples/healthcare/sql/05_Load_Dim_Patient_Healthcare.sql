-- =============================================================================
-- Phase 8 — Healthcare Industry Accelerator
-- etl.usp_load_dim_patient_healthcare — the generator's patient records embed
-- a single address directly (no separate location entity/ID), same mismatch
-- examples/banking/sql/03_Load_Dim_Customer_Banking.sql already reconciles
-- for customers. Synthesizes location_id = patient_id (a valid 1:1
-- patient-to-address relationship) before running the same SCD Type 2
-- expire-then-insert pattern as the generic loaders.
-- =============================================================================

USE [AdeaDW];
GO

CREATE OR ALTER PROCEDURE etl.usp_load_dim_patient_healthcare
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v_run_key BIGINT;
    DECLARE @v_locations_inserted INT = 0, @v_locations_updated INT = 0;
    DECLARE @v_rows_expired INT = 0, @v_rows_inserted INT = 0;
    DECLARE @v_load_date DATE = CAST(SYSUTCDATETIME() AS DATE);

    INSERT INTO audit.log_etl_run (procedure_name, start_time, status)
    VALUES ('etl.usp_load_dim_patient_healthcare', SYSUTCDATETIME(), 'RUNNING');
    SET @v_run_key = SCOPE_IDENTITY();

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Step 1: upsert dim_location (SCD1 — address corrections overwrite
        -- in place, same as the generic framework's dim_location).
        DECLARE @merge_output TABLE (action_type VARCHAR(10));

        MERGE dim.dim_location AS tgt
        USING (
            SELECT DISTINCT
                stg.source_system,
                stg.patient_id AS location_id,
                stg.address_line1,
                stg.city,
                stg.region,
                stg.postal_code,
                stg.country
            FROM staging.stg_healthcare_patient AS stg
            WHERE stg.patient_id IS NOT NULL
        ) AS src
            ON tgt.location_id = src.location_id
           AND tgt.source_system = src.source_system
        WHEN MATCHED AND (
                ISNULL(tgt.address_line1, '') <> ISNULL(src.address_line1, '')
             OR ISNULL(tgt.city, '') <> ISNULL(src.city, '')
             OR ISNULL(tgt.region, '') <> ISNULL(src.region, '')
             OR ISNULL(tgt.postal_code, '') <> ISNULL(src.postal_code, '')
             OR ISNULL(tgt.country, '') <> ISNULL(src.country, '')
        )
        THEN UPDATE SET
            address_line1 = src.address_line1,
            city = src.city,
            region = src.region,
            postal_code = src.postal_code,
            country = src.country,
            updated_date = SYSUTCDATETIME(),
            updated_by = SUSER_SNAME()
        WHEN NOT MATCHED BY TARGET
        THEN INSERT (source_system, location_id, address_line1, city, region, postal_code, country)
             VALUES (src.source_system, src.location_id, src.address_line1, src.city, src.region, src.postal_code, src.country)
        OUTPUT $action INTO @merge_output;

        SELECT
            @v_locations_inserted = COUNT(CASE WHEN action_type = 'INSERT' THEN 1 END),
            @v_locations_updated  = COUNT(CASE WHEN action_type = 'UPDATE' THEN 1 END)
        FROM @merge_output;

        -- Step 2: SCD Type 2 load of dim_patient, joined to the location rows
        -- just upserted.
        ;WITH src AS (
            SELECT DISTINCT
                stg.source_system,
                stg.patient_id,
                loc.location_key,
                stg.first_name,
                stg.last_name,
                stg.gender,
                TRY_CAST(stg.date_of_birth AS DATE) AS date_of_birth,
                stg.blood_type,
                stg.email,
                stg.phone,
                stg.insurance_plan
            FROM staging.stg_healthcare_patient AS stg
            INNER JOIN dim.dim_location AS loc
                ON loc.location_id = stg.patient_id
               AND loc.source_system = stg.source_system
            WHERE stg.patient_id IS NOT NULL
        )
        UPDATE tgt
        SET is_current = 0,
            expiry_date = DATEADD(DAY, -1, @v_load_date),
            updated_date = SYSUTCDATETIME(),
            updated_by = SUSER_SNAME()
        FROM dim.dim_patient AS tgt
        INNER JOIN src
            ON src.patient_id = tgt.patient_id
           AND src.source_system = tgt.source_system
        WHERE tgt.is_current = 1
          AND (
                ISNULL(tgt.location_key, -1) <> ISNULL(src.location_key, -1)
             OR ISNULL(tgt.first_name, '') <> ISNULL(src.first_name, '')
             OR ISNULL(tgt.last_name, '') <> ISNULL(src.last_name, '')
             OR ISNULL(tgt.email, '') <> ISNULL(src.email, '')
             OR ISNULL(tgt.phone, '') <> ISNULL(src.phone, '')
             OR ISNULL(tgt.insurance_plan, '') <> ISNULL(src.insurance_plan, '')
          );
          -- gender/date_of_birth/blood_type are treated as immutable
          -- attributes, not compared here — same judgment call banking's
          -- loan loader makes for principal/rate/term.

        SET @v_rows_expired = @@ROWCOUNT;

        ;WITH src AS (
            SELECT DISTINCT
                stg.source_system,
                stg.patient_id,
                loc.location_key,
                stg.first_name,
                stg.last_name,
                stg.gender,
                TRY_CAST(stg.date_of_birth AS DATE) AS date_of_birth,
                stg.blood_type,
                stg.email,
                stg.phone,
                stg.insurance_plan
            FROM staging.stg_healthcare_patient AS stg
            INNER JOIN dim.dim_location AS loc
                ON loc.location_id = stg.patient_id
               AND loc.source_system = stg.source_system
            WHERE stg.patient_id IS NOT NULL
        )
        INSERT INTO dim.dim_patient (
            patient_id, source_system, location_key, first_name, last_name,
            gender, date_of_birth, blood_type, email, phone, insurance_plan,
            is_current, effective_date, expiry_date
        )
        SELECT
            src.patient_id, src.source_system, src.location_key, src.first_name, src.last_name,
            src.gender, src.date_of_birth, src.blood_type, src.email, src.phone, src.insurance_plan,
            1, @v_load_date, '9999-12-31'
        FROM src
        LEFT JOIN dim.dim_patient AS cur
            ON cur.patient_id = src.patient_id
           AND cur.source_system = src.source_system
           AND cur.is_current = 1
        WHERE cur.patient_key IS NULL;

        SET @v_rows_inserted = @@ROWCOUNT;

        COMMIT TRANSACTION;

        UPDATE audit.log_etl_run
        SET end_time = SYSUTCDATETIME(), status = 'SUCCESS',
            rows_updated = @v_rows_expired + @v_locations_updated,
            rows_inserted = @v_rows_inserted + @v_locations_inserted
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
