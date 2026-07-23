-- =============================================================================
-- Milestone 2.4 — ETL Components
-- audit.log_etl_run       — one row per stored procedure execution.
-- audit.log_data_quality  — one row per validation check result (10-validation).
-- etl.ctrl_watermark      — last successful watermark per source/object,
--                           read by etl.ufn_get_watermark (07-functions),
--                           written by ADF's incremental pipelines (Phase 4).
-- =============================================================================

USE [AdeaDW];
GO

IF OBJECT_ID('audit.log_etl_run', 'U') IS NULL
BEGIN
    CREATE TABLE audit.log_etl_run
    (
        run_key         BIGINT IDENTITY(1,1) NOT NULL,
        procedure_name  SYSNAME         NOT NULL,
        start_time      DATETIME2       NOT NULL,
        end_time        DATETIME2       NULL,
        status          VARCHAR(20)     NOT NULL DEFAULT ('RUNNING'), -- RUNNING | SUCCESS | FAILED
        rows_inserted   INT             NULL,
        rows_updated    INT             NULL,
        error_message   NVARCHAR(4000)  NULL,

        CONSTRAINT pk_log_etl_run PRIMARY KEY NONCLUSTERED (run_key)
    );
END
GO

IF OBJECT_ID('audit.log_data_quality', 'U') IS NULL
BEGIN
    CREATE TABLE audit.log_data_quality
    (
        check_key       BIGINT IDENTITY(1,1) NOT NULL,
        check_date      DATETIME2       NOT NULL DEFAULT (SYSUTCDATETIME()),
        check_name      VARCHAR(200)    NOT NULL,
        object_name     VARCHAR(200)    NOT NULL,
        check_result    VARCHAR(10)     NOT NULL, -- PASS | FAIL
        expected_value  VARCHAR(200)    NULL,
        actual_value    VARCHAR(200)    NULL,

        CONSTRAINT pk_log_data_quality PRIMARY KEY NONCLUSTERED (check_key)
    );
END
GO

IF OBJECT_ID('etl.ctrl_watermark', 'U') IS NULL
BEGIN
    CREATE TABLE etl.ctrl_watermark
    (
        watermark_key       INT IDENTITY(1,1) NOT NULL,
        source_system       VARCHAR(20)  NOT NULL,
        object_name         VARCHAR(100) NOT NULL,
        last_watermark_value DATETIME2   NOT NULL,
        updated_date         DATETIME2   NOT NULL DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT pk_ctrl_watermark PRIMARY KEY CLUSTERED (watermark_key),
        CONSTRAINT uq_ctrl_watermark_source_object UNIQUE (source_system, object_name)
    );
END
GO
