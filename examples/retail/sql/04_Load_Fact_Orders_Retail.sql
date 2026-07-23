-- =============================================================================
-- Phase 8 — Retail Industry Accelerator
-- etl.usp_load_fact_orders_retail — writes into the *generic* fact.fact_orders
-- (src/sql/04-facts/02_Create_Fact_Orders.sql) unmodified. Exists because
-- the generic etl.usp_load_fact_orders (src/sql/06-stored-procedures/
-- 09_Load_Fact_Orders.sql) expects staging.stg_orders to already carry
-- order_line_number, discount_amount, tax_amount, and net_amount — the
-- generator instead produces one already-complete order line per row (no
-- multi-line order header) with a discount *percentage*, not a dollar
-- amount, and no employee/location/currency concept. Reconciled here:
-- order_line_number is always 1 (each generated row is a complete,
-- self-contained order line — a degenerate case of the generic grain, not
-- a different grain), and discount_amount/net_amount are computed from
-- discount_pct. employee_key/location_key/currency_key stay NULL, same
-- "no such concept in the generated data" pattern
-- examples/banking/sql/06_Load_Fact_Transactions_Banking.sql already uses
-- for employee_key/location_key.
-- =============================================================================

USE [AdeaDW];
GO

CREATE OR ALTER PROCEDURE etl.usp_load_fact_orders_retail
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v_run_key BIGINT;
    DECLARE @v_rows_inserted INT = 0;

    INSERT INTO audit.log_etl_run (procedure_name, start_time, status)
    VALUES ('etl.usp_load_fact_orders_retail', SYSUTCDATETIME(), 'RUNNING');
    SET @v_run_key = SCOPE_IDENTITY();

    BEGIN TRY
        BEGIN TRANSACTION;

        ;WITH src AS (
            SELECT
                stg.source_system,
                stg.order_id,
                TRY_CAST(stg.order_date AS DATE) AS order_date,
                stg.order_status,
                stg.customer_id,
                stg.product_id,
                TRY_CAST(stg.quantity AS DECIMAL(18,4)) AS quantity,
                TRY_CAST(stg.unit_price AS DECIMAL(18,4)) AS unit_price,
                TRY_CAST(stg.discount_pct AS DECIMAL(9,4)) AS discount_pct
            FROM staging.stg_retail_order AS stg
            WHERE stg.order_id IS NOT NULL
        ),
        computed AS (
            SELECT
                *,
                ROUND(quantity * unit_price * ISNULL(discount_pct, 0) / 100.0, 4) AS discount_amount
            FROM src
        )
        INSERT INTO fact.fact_orders (
            date_key, customer_key, product_key, employee_key, location_key,
            currency_key, source_system, order_id, order_line_number, order_status,
            quantity, unit_price, discount_amount, tax_amount, net_amount
        )
        SELECT
            CONVERT(INT, FORMAT(c.order_date, 'yyyyMMdd')) AS date_key,
            cust.customer_key,
            prod.product_key,
            NULL, -- employee_key: no order-taker concept in the generated data
            NULL, -- location_key: no fulfilling store/warehouse concept for orders (see fact_inventory for warehouse)
            NULL, -- currency_key: generator has no currency variance (implicitly USD)
            c.source_system,
            c.order_id,
            1, -- order_line_number: each generated row is already a complete order line
            c.order_status,
            c.quantity,
            c.unit_price,
            c.discount_amount,
            0, -- tax_amount: not modeled in the generated data
            (c.quantity * c.unit_price) - c.discount_amount AS net_amount
        FROM computed AS c
        INNER JOIN dim.dim_customer AS cust
            ON cust.customer_id = c.customer_id
           AND cust.source_system = c.source_system
           AND cust.is_current = 1
        INNER JOIN dim.dim_product AS prod
            ON prod.product_id = c.product_id
           AND prod.source_system = c.source_system
           AND prod.is_current = 1
        WHERE NOT EXISTS (
            SELECT 1 FROM fact.fact_orders AS f
            WHERE f.source_system = c.source_system
              AND f.order_id = c.order_id
              AND f.order_line_number = 1
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
