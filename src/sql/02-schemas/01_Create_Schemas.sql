-- =============================================================================
-- Milestone 2.1 — SQL Foundation
-- Creates the layered schemas used across every dimension/fact/ETL script.
-- Schema-to-folder mapping is documented in
-- src/sql/00-standards/naming-standards.md.
-- =============================================================================

USE [AdeaDW];
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'staging')
    EXEC('CREATE SCHEMA staging'); -- landing zone for raw/incoming data
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dim')
    EXEC('CREATE SCHEMA dim'); -- dimension tables
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'fact')
    EXEC('CREATE SCHEMA fact'); -- fact tables
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'etl')
    EXEC('CREATE SCHEMA etl'); -- stored procedures, functions, watermark/control tables
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'audit')
    EXEC('CREATE SCHEMA audit'); -- ETL run logs, data quality/validation results
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'rpt')
    EXEC('CREATE SCHEMA rpt'); -- reporting views
GO
