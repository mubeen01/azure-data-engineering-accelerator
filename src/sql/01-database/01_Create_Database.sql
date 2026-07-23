-- =============================================================================
-- Milestone 2.1 — SQL Foundation
-- Creates the ADEA data warehouse database.
--
-- Target: Azure SQL Database or SQL Server. Not applicable to Azure Synapse
-- dedicated SQL pool — that database is provisioned as an Azure resource
-- (ARM/Bicep/Terraform/portal), not via CREATE DATABASE T-SQL. See
-- src/sql/00-standards/sql-coding-standards.md for target differences.
-- =============================================================================

IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = N'AdeaDW')
BEGIN
    CREATE DATABASE [AdeaDW];
END
GO

-- Azure SQL Database ignores ALTER DATABASE ... SET options that are
-- SQL-Server-only (e.g. file placement, recovery model); the settings below
-- are supported on both.
IF SERVERPROPERTY('EngineEdition') <> 5 -- 5 = Azure SQL Database
BEGIN
    ALTER DATABASE [AdeaDW] SET RECOVERY SIMPLE;
END
GO

ALTER DATABASE [AdeaDW] SET READ_COMMITTED_SNAPSHOT ON;
GO
