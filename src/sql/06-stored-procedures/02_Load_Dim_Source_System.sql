-- =============================================================================
-- Milestone 2.4 — ETL Components
-- etl.usp_load_dim_source_system — SCD Type 1 upsert (overwrite in place).
-- Uses MERGE with OUTPUT $action for precise inserted/updated counts; MERGE
-- is not supported on Synapse dedicated SQL pools — replace with an
-- INSERT/UPDATE pair there (see src/sql/00-standards/sql-coding-standards.md).
-- =============================================================================

USE [AdeaDW];
GO

CREATE OR ALTER PROCEDURE etl.usp_load_dim_source_system
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v_run_key BIGINT;
    DECLARE @v_rows_inserted INT = 0, @v_rows_updated INT = 0;

    INSERT INTO audit.log_etl_run (procedure_name, start_time, status)
    VALUES ('etl.usp_load_dim_source_system', SYSUTCDATETIME(), 'RUNNING');
    SET @v_run_key = SCOPE_IDENTITY();

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @merge_output TABLE (action_type VARCHAR(10));

        MERGE dim.dim_source_system AS tgt
        USING (
            SELECT DISTINCT source_system_code, source_system_name, description
            FROM staging.stg_source_system
            WHERE source_system_code IS NOT NULL
        ) AS src
            ON tgt.source_system_code = src.source_system_code
        WHEN MATCHED AND (
                ISNULL(tgt.source_system_name, '') <> ISNULL(src.source_system_name, '')
             OR ISNULL(tgt.description, '') <> ISNULL(src.description, '')
        )
        THEN UPDATE SET
            source_system_name = src.source_system_name,
            description = src.description,
            updated_date = SYSUTCDATETIME(),
            updated_by = SUSER_SNAME()
        WHEN NOT MATCHED BY TARGET
        THEN INSERT (source_system_code, source_system_name, description)
             VALUES (src.source_system_code, src.source_system_name, src.description)
        OUTPUT $action INTO @merge_output;

        SELECT
            @v_rows_inserted = COUNT(CASE WHEN action_type = 'INSERT' THEN 1 END),
            @v_rows_updated  = COUNT(CASE WHEN action_type = 'UPDATE' THEN 1 END)
        FROM @merge_output;

        COMMIT TRANSACTION;

        UPDATE audit.log_etl_run
        SET end_time = SYSUTCDATETIME(), status = 'SUCCESS',
            rows_inserted = @v_rows_inserted, rows_updated = @v_rows_updated
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
