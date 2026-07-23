-- =============================================================================
-- Milestone 2.4 — ETL Components
-- etl.usp_load_dim_customer — SCD Type 2: expire the current row for any
-- customer whose tracked attributes changed, then insert a new current row
-- for both changed and brand-new customers. Pure INSERT/UPDATE — no MERGE —
-- so this pattern is portable to Synapse dedicated SQL pools unmodified.
-- =============================================================================

USE [AdeaDW];
GO

CREATE OR ALTER PROCEDURE etl.usp_load_dim_customer
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v_run_key BIGINT;
    DECLARE @v_rows_expired INT = 0, @v_rows_inserted INT = 0;
    DECLARE @v_load_date DATE = CAST(SYSUTCDATETIME() AS DATE);

    INSERT INTO audit.log_etl_run (procedure_name, start_time, status)
    VALUES ('etl.usp_load_dim_customer', SYSUTCDATETIME(), 'RUNNING');
    SET @v_run_key = SCOPE_IDENTITY();

    BEGIN TRY
        BEGIN TRANSACTION;

        ;WITH src AS (
            SELECT DISTINCT
                stg.source_system,
                stg.customer_id,
                loc.location_key,
                stg.first_name,
                stg.last_name,
                stg.email,
                stg.phone,
                stg.customer_segment
            FROM staging.stg_customer AS stg
            LEFT JOIN dim.dim_location AS loc
                ON loc.location_id = stg.location_id
               AND loc.source_system = stg.source_system
            WHERE stg.customer_id IS NOT NULL AND stg.source_system IS NOT NULL
        )
        UPDATE tgt
        SET is_current = 0,
            expiry_date = DATEADD(DAY, -1, @v_load_date),
            updated_date = SYSUTCDATETIME(),
            updated_by = SUSER_SNAME()
        FROM dim.dim_customer AS tgt
        INNER JOIN src
            ON src.customer_id = tgt.customer_id
           AND src.source_system = tgt.source_system
        WHERE tgt.is_current = 1
          AND (
                ISNULL(tgt.location_key, -1) <> ISNULL(src.location_key, -1)
             OR ISNULL(tgt.first_name, '') <> ISNULL(src.first_name, '')
             OR ISNULL(tgt.last_name, '') <> ISNULL(src.last_name, '')
             OR ISNULL(tgt.email, '') <> ISNULL(src.email, '')
             OR ISNULL(tgt.phone, '') <> ISNULL(src.phone, '')
             OR ISNULL(tgt.customer_segment, '') <> ISNULL(src.customer_segment, '')
          );

        SET @v_rows_expired = @@ROWCOUNT;

        ;WITH src AS (
            SELECT DISTINCT
                stg.source_system,
                stg.customer_id,
                loc.location_key,
                stg.first_name,
                stg.last_name,
                stg.email,
                stg.phone,
                stg.customer_segment
            FROM staging.stg_customer AS stg
            LEFT JOIN dim.dim_location AS loc
                ON loc.location_id = stg.location_id
               AND loc.source_system = stg.source_system
            WHERE stg.customer_id IS NOT NULL AND stg.source_system IS NOT NULL
        )
        INSERT INTO dim.dim_customer (
            customer_id, source_system, location_key, first_name, last_name,
            email, phone, customer_segment, is_current, effective_date, expiry_date
        )
        SELECT
            src.customer_id, src.source_system, src.location_key, src.first_name, src.last_name,
            src.email, src.phone, src.customer_segment, 1, @v_load_date, '9999-12-31'
        FROM src
        LEFT JOIN dim.dim_customer AS cur
            ON cur.customer_id = src.customer_id
           AND cur.source_system = src.source_system
           AND cur.is_current = 1
        WHERE cur.customer_key IS NULL; -- true for brand-new customers and those just expired above

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
