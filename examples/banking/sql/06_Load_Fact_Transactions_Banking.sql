-- =============================================================================
-- Phase 8 — Banking Industry Accelerator
-- etl.usp_load_fact_transactions_banking — the generator's transaction
-- records carry account_id only, not customer_id directly (realistic: a
-- transaction belongs to an account, which belongs to a customer). The
-- generic loader (src/sql/06-stored-procedures/10_Load_Fact_Transactions.sql)
-- assumes staging already has customer_id, so it doesn't fit here — this
-- resolves customer_key by joining through dim.dim_account instead. No
-- employee/location dimensions exist in the generator's model (no
-- teller/branch concept), so those stay NULL, same as the generic loader's
-- optional dimensions.
-- =============================================================================

USE [AdeaDW];
GO

CREATE OR ALTER PROCEDURE etl.usp_load_fact_transactions_banking
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v_run_key BIGINT;
    DECLARE @v_rows_inserted INT = 0;

    INSERT INTO audit.log_etl_run (procedure_name, start_time, status)
    VALUES ('etl.usp_load_fact_transactions_banking', SYSUTCDATETIME(), 'RUNNING');
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
            acct.customer_key,
            NULL, -- employee_key: no teller/agent concept in the generated data
            NULL, -- location_key: no branch concept in the generated data
            cur.currency_key,
            stg.source_system,
            stg.transaction_id,
            stg.account_id,
            stg.transaction_type,
            TRY_CAST(stg.amount AS DECIMAL(18,4)),
            TRY_CAST(stg.running_balance AS DECIMAL(18,4))
        FROM staging.stg_banking_transaction AS stg
        INNER JOIN dim.dim_account AS acct
            ON acct.account_id = stg.account_id
           AND acct.source_system = stg.source_system
           AND acct.is_current = 1
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
