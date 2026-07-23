-- =============================================================================
-- Milestone 2.4 — ETL Components
-- rpt.vw_sales_summary — monthly sales rollup by product category and
-- customer segment. Representative reporting view; the same join shape
-- (fact -> dim_date/dim_product/dim_customer) extends to fact_orders.
-- =============================================================================

USE [AdeaDW];
GO

CREATE OR ALTER VIEW rpt.vw_sales_summary
AS
SELECT
    d.year_number,
    d.month_number,
    d.month_name,
    p.category,
    p.product_name,
    c.customer_segment,
    SUM(f.quantity)   AS total_quantity,
    SUM(f.net_amount) AS total_net_amount
FROM fact.fact_sales AS f
INNER JOIN dim.dim_date AS d
    ON d.date_key = f.date_key
INNER JOIN dim.dim_product AS p
    ON p.product_key = f.product_key
INNER JOIN dim.dim_customer AS c
    ON c.customer_key = f.customer_key
GROUP BY
    d.year_number, d.month_number, d.month_name,
    p.category, p.product_name, c.customer_segment;
GO
