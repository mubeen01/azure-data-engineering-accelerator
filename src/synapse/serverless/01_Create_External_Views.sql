-- =============================================================================
-- Azure Synapse Analytics — Serverless SQL Pool
-- Queries the Gold Delta tables directly from the lake via OPENROWSET —
-- no data movement, no dedicated pool, billed per TB scanned rather than
-- per compute-hour. This is the genuinely Synapse-serverless-specific
-- piece of this repo: src/sql/'s star schema targets a provisioned
-- database (Azure SQL DB / dedicated pool), this queries the same Gold
-- layer's Delta files (src/databricks/03_gold/ or src/fabric/lakehouse/'s
-- output) in place.
--
-- Not verified against a live Synapse workspace — OPENROWSET ... FORMAT =
-- 'DELTA' syntax reviewed against Microsoft's documented serverless SQL
-- pool support for Delta Lake, not executed against a real serverless
-- endpoint.
-- =============================================================================

CREATE SCHEMA rpt;
GO

CREATE OR ALTER VIEW rpt.vw_dim_customer_external
AS
SELECT *
FROM OPENROWSET(
    BULK 'https://<storage-account>.dfs.core.windows.net/<container>/gold/dim_customer/',
    FORMAT = 'DELTA'
) AS result
WHERE is_current = 1;
GO

CREATE OR ALTER VIEW rpt.vw_fact_sales_external
AS
SELECT *
FROM OPENROWSET(
    BULK 'https://<storage-account>.dfs.core.windows.net/<container>/gold/fact_sales/',
    FORMAT = 'DELTA'
) AS result;
GO

-- Join across the two external views the same way you'd join real tables
-- — the serverless pool pushes the filter/projection down to the Delta
-- transaction log, it doesn't read every file.
CREATE OR ALTER VIEW rpt.vw_sales_by_customer_segment_external
AS
SELECT
    c.customer_segment,
    SUM(f.net_amount) AS total_net_amount,
    COUNT(*) AS transaction_count
FROM rpt.vw_fact_sales_external AS f
INNER JOIN rpt.vw_dim_customer_external AS c
    ON c.customer_key = f.customer_key
GROUP BY c.customer_segment;
GO
