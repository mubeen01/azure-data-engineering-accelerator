-- =============================================================================
-- Milestone 2.5 — Optimization (Maintenance)
-- etl.usp_purge_audit_logs — deletes audit.log_etl_run / audit.log_data_quality
-- rows older than @p_retention_days (default 90). Run on a schedule; these
-- tables grow one row per procedure execution / validation check and are
-- not otherwise bounded.
-- =============================================================================

USE [AdeaDW];
GO

CREATE OR ALTER PROCEDURE etl.usp_purge_audit_logs
    @p_retention_days INT = 90
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v_cutoff_date DATETIME2 = DATEADD(DAY, -@p_retention_days, SYSUTCDATETIME());

    DELETE FROM audit.log_etl_run
    WHERE start_time < @v_cutoff_date;

    DELETE FROM audit.log_data_quality
    WHERE check_date < @v_cutoff_date;
END
GO
