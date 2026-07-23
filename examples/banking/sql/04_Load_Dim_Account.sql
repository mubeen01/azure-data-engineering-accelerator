-- =============================================================================
-- Phase 8 — Banking Industry Accelerator
-- etl.usp_load_dim_account — SCD Type 2, same expire-then-insert pattern as
-- the generic loaders. Resolves customer_key from dim.dim_customer (must
-- run after etl.usp_load_dim_customer_banking) and currency_key from
-- dim.dim_currency.
-- =============================================================================

USE [AdeaDW];
GO

CREATE OR ALTER PROCEDURE etl.usp_load_dim_account
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v_run_key BIGINT;
    DECLARE @v_rows_expired INT = 0, @v_rows_inserted INT = 0;
    DECLARE @v_load_date DATE = CAST(SYSUTCDATETIME() AS DATE);

    INSERT INTO audit.log_etl_run (procedure_name, start_time, status)
    VALUES ('etl.usp_load_dim_account', SYSUTCDATETIME(), 'RUNNING');
    SET @v_run_key = SCOPE_IDENTITY();

    BEGIN TRY
        BEGIN TRANSACTION;

        ;WITH src AS (
            SELECT DISTINCT
                stg.source_system,
                stg.account_id,
                cust.customer_key,
                stg.account_type,
                stg.account_status,
                TRY_CAST(stg.open_date AS DATE) AS open_date,
                cur.currency_key
            FROM staging.stg_banking_account AS stg
            INNER JOIN dim.dim_customer AS cust
                ON cust.customer_id = stg.customer_id
               AND cust.source_system = stg.source_system
               AND cust.is_current = 1
            LEFT JOIN dim.dim_currency AS cur
                ON cur.currency_code = stg.currency_code
            WHERE stg.account_id IS NOT NULL
        )
        UPDATE tgt
        SET is_current = 0,
            expiry_date = DATEADD(DAY, -1, @v_load_date),
            updated_date = SYSUTCDATETIME(),
            updated_by = SUSER_SNAME()
        FROM dim.dim_account AS tgt
        INNER JOIN src
            ON src.account_id = tgt.account_id
           AND src.source_system = tgt.source_system
        WHERE tgt.is_current = 1
          AND (
                ISNULL(tgt.customer_key, -1) <> ISNULL(src.customer_key, -1)
             OR ISNULL(tgt.account_type, '') <> ISNULL(src.account_type, '')
             OR ISNULL(tgt.account_status, '') <> ISNULL(src.account_status, '')
             OR ISNULL(tgt.currency_key, -1) <> ISNULL(src.currency_key, -1)
          );

        SET @v_rows_expired = @@ROWCOUNT;

        ;WITH src AS (
            SELECT DISTINCT
                stg.source_system,
                stg.account_id,
                cust.customer_key,
                stg.account_type,
                stg.account_status,
                TRY_CAST(stg.open_date AS DATE) AS open_date,
                cur.currency_key
            FROM staging.stg_banking_account AS stg
            INNER JOIN dim.dim_customer AS cust
                ON cust.customer_id = stg.customer_id
               AND cust.source_system = stg.source_system
               AND cust.is_current = 1
            LEFT JOIN dim.dim_currency AS cur
                ON cur.currency_code = stg.currency_code
            WHERE stg.account_id IS NOT NULL
        )
        INSERT INTO dim.dim_account (
            account_id, source_system, customer_key, account_type, account_status,
            open_date, currency_key, is_current, effective_date, expiry_date
        )
        SELECT
            src.account_id, src.source_system, src.customer_key, src.account_type, src.account_status,
            src.open_date, src.currency_key, 1, @v_load_date, '9999-12-31'
        FROM src
        LEFT JOIN dim.dim_account AS cur
            ON cur.account_id = src.account_id
           AND cur.source_system = src.source_system
           AND cur.is_current = 1
        WHERE cur.account_key IS NULL;

        SET @v_rows_inserted = @@ROWCOUNT;

        COMMIT TRANSACTION;

        UPDATE audit.log_etl_run
        SET end_time = SYSUTCDATETIME(), status = 'SUCCESS',
            rows_updated = @v_rows_expired, rows_inserted = @v_rows_inserted
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
