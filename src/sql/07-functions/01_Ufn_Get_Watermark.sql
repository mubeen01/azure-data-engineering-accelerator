-- =============================================================================
-- Milestone 2.4 — ETL Components
-- etl.ufn_get_watermark — returns the last successful watermark for a
-- source/object pair, defaulting to 1900-01-01 if none recorded yet (first
-- run = full load). Read by ADF's incremental pipelines (Phase 4); written
-- to etl.ctrl_watermark by those same pipelines after a successful load.
-- Scalar function — call once per pipeline run, not per row.
-- =============================================================================

USE [AdeaDW];
GO

CREATE OR ALTER FUNCTION etl.ufn_get_watermark
(
    @p_source_system VARCHAR(20),
    @p_object_name   VARCHAR(100)
)
RETURNS DATETIME2
AS
BEGIN
    DECLARE @v_watermark DATETIME2;

    SELECT @v_watermark = last_watermark_value
    FROM etl.ctrl_watermark
    WHERE source_system = @p_source_system
      AND object_name = @p_object_name;

    RETURN ISNULL(@v_watermark, '1900-01-01');
END
GO
