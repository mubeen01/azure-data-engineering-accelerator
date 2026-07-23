-- =============================================================================
-- Phase 4 — Azure Data Factory Framework
-- etl.ctrl_pipeline_metadata — one row per source object to load, driving
-- ADF's metadata-driven orchestrator (src/adf/pipeline/pl_master_orchestrator.json)
-- instead of one hand-built pipeline per table. Added here (Phase 2's etl
-- schema) since it's control/metadata, same as etl.ctrl_watermark.
-- =============================================================================

USE [AdeaDW];
GO

IF OBJECT_ID('etl.ctrl_pipeline_metadata', 'U') IS NULL
BEGIN
    CREATE TABLE etl.ctrl_pipeline_metadata
    (
        metadata_key        INT IDENTITY(1,1) NOT NULL,
        source_system       VARCHAR(20)   NOT NULL,
        object_name         VARCHAR(100)  NOT NULL,  -- matches etl.ctrl_watermark.object_name
        load_priority       INT           NOT NULL DEFAULT (100), -- lower runs first; e.g. dim_customer before a dependent fact
        load_type           VARCHAR(20)   NOT NULL,  -- 'FULL' | 'INCREMENTAL'
        source_container    VARCHAR(100)  NULL,       -- storage container for file-based sources
        source_folder_path  VARCHAR(200)  NULL,
        source_file_name    VARCHAR(200)  NULL,
        watermark_column    VARCHAR(100)  NULL,       -- source column read for incremental filtering
        sink_schema         VARCHAR(50)   NOT NULL,   -- e.g. 'staging'
        sink_table          VARCHAR(100)  NOT NULL,   -- e.g. 'stg_customer'
        load_procedure_name VARCHAR(200)  NOT NULL,   -- e.g. 'etl.usp_load_dim_customer'
        is_active           BIT           NOT NULL DEFAULT (1),
        created_date        DATETIME2     NOT NULL DEFAULT (SYSUTCDATETIME()),
        created_by          SYSNAME       NOT NULL DEFAULT (SUSER_SNAME()),
        updated_date        DATETIME2     NULL,
        updated_by          SYSNAME       NULL,

        CONSTRAINT pk_ctrl_pipeline_metadata PRIMARY KEY CLUSTERED (metadata_key),
        CONSTRAINT uq_ctrl_pipeline_metadata_object UNIQUE (source_system, object_name)
    );
END
GO
