-- =============================================================================
-- Milestone 2.4 — ETL Components
-- etl.usp_load_fact_orders — same pattern as etl.usp_load_fact_sales, keyed
-- on (source_system, order_id, order_line_number).
-- =============================================================================

USE [AdeaDW];
GO

CREATE OR ALTER PROCEDURE etl.usp_load_fact_orders
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v_run_key BIGINT;
    DECLARE @v_rows_inserted INT = 0;

    INSERT INTO audit.log_etl_run (procedure_name, start_time, status)
    VALUES ('etl.usp_load_fact_orders', SYSUTCDATETIME(), 'RUNNING');
    SET @v_run_key = SCOPE_IDENTITY();

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO fact.fact_orders (
            date_key, customer_key, product_key, employee_key, location_key,
            currency_key, source_system, order_id, order_line_number, order_status,
            quantity, unit_price, discount_amount, tax_amount, net_amount
        )
        SELECT
            CONVERT(INT, FORMAT(TRY_CAST(stg.order_date AS DATE), 'yyyyMMdd')) AS date_key,
            cust.customer_key,
            prod.product_key,
            emp.employee_key,
            loc.location_key,
            cur.currency_key,
            stg.source_system,
            stg.order_id,
            TRY_CAST(stg.order_line_number AS INT),
            stg.order_status,
            TRY_CAST(stg.quantity AS DECIMAL(18,4)),
            TRY_CAST(stg.unit_price AS DECIMAL(18,4)),
            ISNULL(TRY_CAST(stg.discount_amount AS DECIMAL(18,4)), 0),
            ISNULL(TRY_CAST(stg.tax_amount AS DECIMAL(18,4)), 0),
            TRY_CAST(stg.net_amount AS DECIMAL(18,4))
        FROM staging.stg_orders AS stg
        INNER JOIN dim.dim_customer AS cust
            ON cust.customer_id = stg.customer_id
           AND cust.source_system = stg.source_system
           AND cust.is_current = 1
        INNER JOIN dim.dim_product AS prod
            ON prod.product_id = stg.product_id
           AND prod.source_system = stg.source_system
           AND prod.is_current = 1
        LEFT JOIN dim.dim_employee AS emp
            ON emp.employee_id = stg.employee_id
           AND emp.source_system = stg.source_system
           AND emp.is_current = 1
        LEFT JOIN dim.dim_location AS loc
            ON loc.location_id = stg.location_id
           AND loc.source_system = stg.source_system
        LEFT JOIN dim.dim_currency AS cur
            ON cur.currency_code = stg.currency_code
        WHERE stg.order_id IS NOT NULL
          AND NOT EXISTS (
              SELECT 1 FROM fact.fact_orders AS f
              WHERE f.source_system = stg.source_system
                AND f.order_id = stg.order_id
                AND f.order_line_number = TRY_CAST(stg.order_line_number AS INT)
          );

        SET @v_rows_inserted = @@ROWCOUNT;

        COMMIT TRANSACTION;

        UPDATE audit.log_etl_run
        SET end_time = SYSUTCDATETIME(), status = 'SUCCESS', rows_inserted = @v_rows_inserted
        WHERE run_key = @v_run_key;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;

        UPDATE audit.log_etl_run
        SET end_time = SYSUTCDATETIME(), status = 'FAILED', error_message = ERROR_MESSAGE()
        WHERE run_key = @v_run_key;

        THROW;
    END CATCH
END
GO
