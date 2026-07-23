-- =============================================================================
-- Phase 4 — Azure Data Factory Framework
-- One illustrative row in etl.ctrl_pipeline_metadata, proving the
-- metadata-driven pattern end-to-end for a single, simple object
-- (dim_source_system: no dimension lookups, SCD Type 1, full load).
-- This is NOT the full set of rows needed to actually run every pipeline in
-- this repo — wiring up every source object per industry is Phase 8's job
-- (Industry Accelerators), once real source files/systems are attached.
-- =============================================================================

USE [AdeaDW];
GO

IF NOT EXISTS (
    SELECT 1 FROM etl.ctrl_pipeline_metadata
    WHERE source_system = 'BANKING_CORE' AND object_name = 'source_system'
)
BEGIN
    INSERT INTO etl.ctrl_pipeline_metadata (
        source_system, object_name, load_type,
        source_container, source_folder_path, source_file_name,
        watermark_column, sink_schema, sink_table, load_procedure_name
    )
    VALUES (
        'BANKING_CORE', 'source_system', 'FULL',
        'raw', 'banking', 'source_system.csv',
        NULL, 'staging', 'stg_source_system', 'etl.usp_load_dim_source_system'
    );
END
GO
