-- =============================================================================
-- Milestone 2.4 — ETL Components
-- etl.usp_load_dim_employee — SCD Type 2, same expire-then-insert pattern as
-- etl.usp_load_dim_customer. Pure INSERT/UPDATE, portable to Synapse.
-- =============================================================================

USE [AdeaDW];
GO

CREATE OR ALTER PROCEDURE etl.usp_load_dim_employee
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v_run_key BIGINT;
    DECLARE @v_rows_expired INT = 0, @v_rows_inserted INT = 0;
    DECLARE @v_load_date DATE = CAST(SYSUTCDATETIME() AS DATE);

    INSERT INTO audit.log_etl_run (procedure_name, start_time, status)
    VALUES ('etl.usp_load_dim_employee', SYSUTCDATETIME(), 'RUNNING');
    SET @v_run_key = SCOPE_IDENTITY();

    BEGIN TRY
        BEGIN TRANSACTION;

        ;WITH src AS (
            SELECT DISTINCT
                stg.source_system,
                stg.employee_id,
                loc.location_key,
                stg.first_name,
                stg.last_name,
                stg.email,
                stg.job_title,
                stg.department,
                stg.manager_employee_id,
                TRY_CAST(stg.hire_date AS DATE) AS hire_date,
                TRY_CAST(stg.termination_date AS DATE) AS termination_date
            FROM staging.stg_employee AS stg
            LEFT JOIN dim.dim_location AS loc
                ON loc.location_id = stg.location_id
               AND loc.source_system = stg.source_system
            WHERE stg.employee_id IS NOT NULL AND stg.source_system IS NOT NULL
        )
        UPDATE tgt
        SET is_current = 0,
            expiry_date = DATEADD(DAY, -1, @v_load_date),
            updated_date = SYSUTCDATETIME(),
            updated_by = SUSER_SNAME()
        FROM dim.dim_employee AS tgt
        INNER JOIN src
            ON src.employee_id = tgt.employee_id
           AND src.source_system = tgt.source_system
        WHERE tgt.is_current = 1
          AND (
                ISNULL(tgt.location_key, -1) <> ISNULL(src.location_key, -1)
             OR ISNULL(tgt.first_name, '') <> ISNULL(src.first_name, '')
             OR ISNULL(tgt.last_name, '') <> ISNULL(src.last_name, '')
             OR ISNULL(tgt.email, '') <> ISNULL(src.email, '')
             OR ISNULL(tgt.job_title, '') <> ISNULL(src.job_title, '')
             OR ISNULL(tgt.department, '') <> ISNULL(src.department, '')
             OR ISNULL(tgt.manager_employee_id, '') <> ISNULL(src.manager_employee_id, '')
             OR ISNULL(tgt.termination_date, '1900-01-01') <> ISNULL(src.termination_date, '1900-01-01')
          );

        SET @v_rows_expired = @@ROWCOUNT;

        ;WITH src AS (
            SELECT DISTINCT
                stg.source_system,
                stg.employee_id,
                loc.location_key,
                stg.first_name,
                stg.last_name,
                stg.email,
                stg.job_title,
                stg.department,
                stg.manager_employee_id,
                TRY_CAST(stg.hire_date AS DATE) AS hire_date,
                TRY_CAST(stg.termination_date AS DATE) AS termination_date
            FROM staging.stg_employee AS stg
            LEFT JOIN dim.dim_location AS loc
                ON loc.location_id = stg.location_id
               AND loc.source_system = stg.source_system
            WHERE stg.employee_id IS NOT NULL AND stg.source_system IS NOT NULL
        )
        INSERT INTO dim.dim_employee (
            employee_id, source_system, location_key, first_name, last_name, email,
            job_title, department, manager_employee_id, hire_date, termination_date,
            is_current, effective_date, expiry_date
        )
        SELECT
            src.employee_id, src.source_system, src.location_key, src.first_name, src.last_name, src.email,
            src.job_title, src.department, src.manager_employee_id, src.hire_date, src.termination_date,
            1, @v_load_date, '9999-12-31'
        FROM src
        LEFT JOIN dim.dim_employee AS cur
            ON cur.employee_id = src.employee_id
           AND cur.source_system = src.source_system
           AND cur.is_current = 1
        WHERE cur.employee_key IS NULL; -- true for brand-new employees and those just expired above

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
