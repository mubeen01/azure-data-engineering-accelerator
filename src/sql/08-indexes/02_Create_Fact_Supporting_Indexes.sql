-- =============================================================================
-- Milestone 2.5 — Optimization
-- Supporting nonclustered rowstore indexes on top of the clustered
-- columnstore. Columnstore segment elimination handles most scans well on
-- its own, so this is deliberately minimal: one index per fact on date_key,
-- since almost every reporting query filters by a date range. Add more only
-- once an observed query pattern justifies it — don't pre-index every FK
-- speculatively (see src/sql/00-standards/sql-coding-standards.md).
-- =============================================================================

USE [AdeaDW];
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'ix_fact_sales_date_key' AND object_id = OBJECT_ID('fact.fact_sales')
)
BEGIN
    CREATE NONCLUSTERED INDEX ix_fact_sales_date_key ON fact.fact_sales (date_key);
END
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'ix_fact_orders_date_key' AND object_id = OBJECT_ID('fact.fact_orders')
)
BEGIN
    CREATE NONCLUSTERED INDEX ix_fact_orders_date_key ON fact.fact_orders (date_key);
END
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'ix_fact_transactions_date_key' AND object_id = OBJECT_ID('fact.fact_transactions')
)
BEGIN
    CREATE NONCLUSTERED INDEX ix_fact_transactions_date_key ON fact.fact_transactions (date_key);
END
GO
