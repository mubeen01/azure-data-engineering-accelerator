-- =============================================================================
-- Milestone 2.4 — ETL Components
-- etl.usp_load_fact_transactions — same pattern as etl.usp_load_fact_sales.
-- account_id is a degenerate dimension (no dim_account in scope), carried
-- through as-is from staging.
-- =============================================================================

USE [AdeaDW];
GO

CREATE OR ALTER PROCEDURE etl.usp_load_fact_transactions
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v_run_key BIGINT;
    DECLARE @v_rows_inserted INT = 0;

    INSERT INTO audit.log_etl_run (procedure_name, start_time, status)
    VALUES ('etl.usp_load_fact_transactions', SYSUTCDATETIME(), 'RUNNING');
    SET @v_run_key = SCOPE_IDENTITY();

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO fact.fact_transactions (
            date_key, customer_key, employee_key, location_key, currency_key,
            source_system, transaction_id, account_id, transaction_type,
            transaction_amount, running_balance
        )
        SELECT
            CONVERT(INT, FORMAT(TRY_CAST(stg.transaction_date AS DATE), 'yyyyMMdd')) AS date_key,
            cust.customer_key,
            emp.employee_key,
            loc.location_key,
            cur.currency_key,
            stg.source_system,
            stg.transaction_id,
            stg.account_id,
            stg.transaction_type,
            TRY_CAST(stg.transaction_amount AS DECIMAL(18,4)),
            TRY_CAST(stg.running_balance AS DECIMAL(18,4))
        FROM staging.stg_transactions AS stg
        INNER JOIN dim.dim_customer AS cust
            ON cust.customer_id = stg.customer_id
           AND cust.source_system = stg.source_system
           AND cust.is_current = 1
        LEFT JOIN dim.dim_employee AS emp
            ON emp.employee_id = stg.employee_id
           AND emp.source_system = stg.source_system
           AND emp.is_current = 1
        LEFT JOIN dim.dim_location AS loc
            ON loc.location_id = stg.location_id
           AND loc.source_system = stg.source_system
        LEFT JOIN dim.dim_currency AS cur
            ON cur.currency_code = stg.currency_code
        WHERE stg.transaction_id IS NOT NULL
          AND NOT EXISTS (
              SELECT 1 FROM fact.fact_transactions AS f
              WHERE f.source_system = stg.source_system AND f.transaction_id = stg.transaction_id
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
