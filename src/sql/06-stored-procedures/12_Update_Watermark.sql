-- =============================================================================
-- Phase 4 — Azure Data Factory Framework
-- etl.usp_update_watermark — upserts etl.ctrl_watermark after a successful
-- incremental load. Called by pl_load_generic_incremental.json once the
-- copy + load procedure activities both succeed, with the max watermark
-- value observed in that batch.
-- =============================================================================

USE [AdeaDW];
GO

CREATE OR ALTER PROCEDURE etl.usp_update_watermark
    @p_source_system VARCHAR(20),
    @p_object_name   VARCHAR(100),
    @p_watermark_value DATETIME2
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1 FROM etl.ctrl_watermark
        WHERE source_system = @p_source_system AND object_name = @p_object_name
    )
    BEGIN
        UPDATE etl.ctrl_watermark
        SET last_watermark_value = @p_watermark_value,
            updated_date = SYSUTCDATETIME()
        WHERE source_system = @p_source_system AND object_name = @p_object_name;
    END
    ELSE
    BEGIN
        INSERT INTO etl.ctrl_watermark (source_system, object_name, last_watermark_value)
        VALUES (@p_source_system, @p_object_name, @p_watermark_value);
    END
END
GO
