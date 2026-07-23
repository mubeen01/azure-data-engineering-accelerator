-- =============================================================================
-- Phase 8 — Banking Industry Accelerator
-- etl.usp_load_dim_loan — SCD Type 2, same expire-then-insert pattern as
-- the generic loaders. Resolves customer_key from dim.dim_customer (must
-- run after etl.usp_load_dim_customer_banking).
-- =============================================================================

USE [AdeaDW];
GO

CREATE OR ALTER PROCEDURE etl.usp_load_dim_loan
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v_run_key BIGINT;
    DECLARE @v_rows_expired INT = 0, @v_rows_inserted INT = 0;
    DECLARE @v_load_date DATE = CAST(SYSUTCDATETIME() AS DATE);

    INSERT INTO audit.log_etl_run (procedure_name, start_time, status)
    VALUES ('etl.usp_load_dim_loan', SYSUTCDATETIME(), 'RUNNING');
    SET @v_run_key = SCOPE_IDENTITY();

    BEGIN TRY
        BEGIN TRANSACTION;

        ;WITH src AS (
            SELECT DISTINCT
                stg.source_system,
                stg.loan_id,
                cust.customer_key,
                stg.loan_type,
                TRY_CAST(stg.principal_amount AS DECIMAL(18,4)) AS principal_amount,
                TRY_CAST(stg.interest_rate AS DECIMAL(9,4)) AS interest_rate,
                TRY_CAST(stg.term_months AS INT) AS term_months,
                TRY_CAST(stg.origination_date AS DATE) AS origination_date,
                stg.status
            FROM staging.stg_banking_loan AS stg
            INNER JOIN dim.dim_customer AS cust
                ON cust.customer_id = stg.customer_id
               AND cust.source_system = stg.source_system
               AND cust.is_current = 1
            WHERE stg.loan_id IS NOT NULL
        )
        UPDATE tgt
        SET is_current = 0,
            expiry_date = DATEADD(DAY, -1, @v_load_date),
            updated_date = SYSUTCDATETIME(),
            updated_by = SUSER_SNAME()
        FROM dim.dim_loan AS tgt
        INNER JOIN src
            ON src.loan_id = tgt.loan_id
           AND src.source_system = tgt.source_system
        WHERE tgt.is_current = 1
          AND ISNULL(tgt.status, '') <> ISNULL(src.status, '');
          -- status is the only attribute expected to change post-origination;
          -- principal/rate/term are fixed at origination and not compared here.

        SET @v_rows_expired = @@ROWCOUNT;

        ;WITH src AS (
            SELECT DISTINCT
                stg.source_system,
                stg.loan_id,
                cust.customer_key,
                stg.loan_type,
                TRY_CAST(stg.principal_amount AS DECIMAL(18,4)) AS principal_amount,
                TRY_CAST(stg.interest_rate AS DECIMAL(9,4)) AS interest_rate,
                TRY_CAST(stg.term_months AS INT) AS term_months,
                TRY_CAST(stg.origination_date AS DATE) AS origination_date,
                stg.status
            FROM staging.stg_banking_loan AS stg
            INNER JOIN dim.dim_customer AS cust
                ON cust.customer_id = stg.customer_id
               AND cust.source_system = stg.source_system
               AND cust.is_current = 1
            WHERE stg.loan_id IS NOT NULL
        )
        INSERT INTO dim.dim_loan (
            loan_id, source_system, customer_key, loan_type, principal_amount,
            interest_rate, term_months, origination_date, status,
            is_current, effective_date, expiry_date
        )
        SELECT
            src.loan_id, src.source_system, src.customer_key, src.loan_type, src.principal_amount,
            src.interest_rate, src.term_months, src.origination_date, src.status,
            1, @v_load_date, '9999-12-31'
        FROM src
        LEFT JOIN dim.dim_loan AS cur
            ON cur.loan_id = src.loan_id
           AND cur.source_system = src.source_system
           AND cur.is_current = 1
        WHERE cur.loan_key IS NULL;

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
