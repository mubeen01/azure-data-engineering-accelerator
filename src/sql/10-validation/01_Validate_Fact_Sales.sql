-- =============================================================================
-- Milestone 2.4 — ETL Components (Validation)
-- etl.usp_validate_fact_sales — post-load data quality checks, logged to
-- audit.log_data_quality rather than just raising an error, so failures stay
-- queryable after the fact. Same shape applies to fact_orders/fact_transactions
-- — swap the table names and required-key list per fact.
-- =============================================================================

USE [AdeaDW];
GO

CREATE OR ALTER PROCEDURE etl.usp_validate_fact_sales
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v_staging_count INT, @v_fact_count INT, @v_null_key_count INT;

    SELECT @v_staging_count = COUNT(*) FROM staging.stg_sales WHERE sale_id IS NOT NULL;
    SELECT @v_fact_count = COUNT(*) FROM fact.fact_sales;

    INSERT INTO audit.log_data_quality (check_name, object_name, check_result, expected_value, actual_value)
    VALUES (
        'staging_vs_fact_row_count',
        'fact.fact_sales',
        CASE WHEN @v_fact_count >= @v_staging_count THEN 'PASS' ELSE 'FAIL' END,
        CAST(@v_staging_count AS VARCHAR(20)),
        CAST(@v_fact_count AS VARCHAR(20))
    );

    SELECT @v_null_key_count = COUNT(*)
    FROM fact.fact_sales
    WHERE date_key IS NULL OR customer_key IS NULL OR product_key IS NULL;

    INSERT INTO audit.log_data_quality (check_name, object_name, check_result, expected_value, actual_value)
    VALUES (
        'required_dimension_keys_not_null',
        'fact.fact_sales',
        CASE WHEN @v_null_key_count = 0 THEN 'PASS' ELSE 'FAIL' END,
        '0',
        CAST(@v_null_key_count AS VARCHAR(20))
    );
END
GO
