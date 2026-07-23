-- =============================================================================
-- Milestone 2.5 — Optimization
-- Clustered columnstore index for each fact table. This is the table's
-- storage structure, not an addition alongside the rowstore — it coexists
-- with the NONCLUSTERED surrogate-key PK declared in src/sql/04-facts/ (SQL
-- Server / Azure SQL DB have allowed a nonclustered PK next to a clustered
-- columnstore index since 2016; Synapse dedicated pools use columnstore as
-- the default table structure already, so this statement is informational
-- there — see src/sql/00-standards/sql-coding-standards.md).
-- =============================================================================

USE [AdeaDW];
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'cci_fact_sales' AND object_id = OBJECT_ID('fact.fact_sales')
)
BEGIN
    CREATE CLUSTERED COLUMNSTORE INDEX cci_fact_sales ON fact.fact_sales;
END
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'cci_fact_orders' AND object_id = OBJECT_ID('fact.fact_orders')
)
BEGIN
    CREATE CLUSTERED COLUMNSTORE INDEX cci_fact_orders ON fact.fact_orders;
END
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'cci_fact_transactions' AND object_id = OBJECT_ID('fact.fact_transactions')
)
BEGIN
    CREATE CLUSTERED COLUMNSTORE INDEX cci_fact_transactions ON fact.fact_transactions;
END
GO
