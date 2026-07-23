-- =============================================================================
-- Milestone 2.5 — Optimization (Maintenance)
-- etl.usp_maintain_columnstore_indexes — merges open/trickle rowgroups on
-- the fact tables' clustered columnstore indexes. Intended to run on a
-- schedule (e.g. nightly) after incremental loads, per the rowgroup
-- guidance in src/sql/11-performance/performance-guidance.md.
-- REORGANIZE is used over REBUILD: it's an online, incremental compaction
-- rather than a full index rebuild, appropriate for a routine job.
-- =============================================================================

USE [AdeaDW];
GO

CREATE OR ALTER PROCEDURE etl.usp_maintain_columnstore_indexes
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v_run_key BIGINT;

    INSERT INTO audit.log_etl_run (procedure_name, start_time, status)
    VALUES ('etl.usp_maintain_columnstore_indexes', SYSUTCDATETIME(), 'RUNNING');
    SET @v_run_key = SCOPE_IDENTITY();

    BEGIN TRY
        ALTER INDEX cci_fact_sales ON fact.fact_sales REORGANIZE;
        ALTER INDEX cci_fact_orders ON fact.fact_orders REORGANIZE;
        ALTER INDEX cci_fact_transactions ON fact.fact_transactions REORGANIZE;

        UPDATE audit.log_etl_run
        SET end_time = SYSUTCDATETIME(), status = 'SUCCESS'
        WHERE run_key = @v_run_key;
    END TRY
    BEGIN CATCH
        UPDATE audit.log_etl_run
        SET end_time = SYSUTCDATETIME(), status = 'FAILED', error_message = ERROR_MESSAGE()
        WHERE run_key = @v_run_key;

        THROW;
    END CATCH
END
GO
