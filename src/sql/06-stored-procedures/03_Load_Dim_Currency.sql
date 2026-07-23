-- =============================================================================
-- Milestone 2.4 — ETL Components
-- etl.usp_load_dim_currency — SCD Type 1 upsert (overwrite in place).
-- Same MERGE/Synapse caveat as etl.usp_load_dim_source_system.
-- =============================================================================

USE [AdeaDW];
GO

CREATE OR ALTER PROCEDURE etl.usp_load_dim_currency
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v_run_key BIGINT;
    DECLARE @v_rows_inserted INT = 0, @v_rows_updated INT = 0;

    INSERT INTO audit.log_etl_run (procedure_name, start_time, status)
    VALUES ('etl.usp_load_dim_currency', SYSUTCDATETIME(), 'RUNNING');
    SET @v_run_key = SCOPE_IDENTITY();

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @merge_output TABLE (action_type VARCHAR(10));

        MERGE dim.dim_currency AS tgt
        USING (
            SELECT DISTINCT currency_code, currency_name, symbol
            FROM staging.stg_currency
            WHERE currency_code IS NOT NULL
        ) AS src
            ON tgt.currency_code = src.currency_code
        WHEN MATCHED AND (
                ISNULL(tgt.currency_name, '') <> ISNULL(src.currency_name, '')
             OR ISNULL(tgt.symbol, '') <> ISNULL(src.symbol, '')
        )
        THEN UPDATE SET
            currency_name = src.currency_name,
            symbol = src.symbol,
            updated_date = SYSUTCDATETIME(),
            updated_by = SUSER_SNAME()
        WHEN NOT MATCHED BY TARGET
        THEN INSERT (currency_code, currency_name, symbol)
             VALUES (src.currency_code, src.currency_name, src.symbol)
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
