-- =============================================================================
-- Milestone 2.4 — ETL Components
-- etl.usp_load_dim_product — SCD Type 2, same expire-then-insert pattern as
-- etl.usp_load_dim_customer. Pure INSERT/UPDATE, portable to Synapse.
-- =============================================================================

USE [AdeaDW];
GO

CREATE OR ALTER PROCEDURE etl.usp_load_dim_product
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v_run_key BIGINT;
    DECLARE @v_rows_expired INT = 0, @v_rows_inserted INT = 0;
    DECLARE @v_load_date DATE = CAST(SYSUTCDATETIME() AS DATE);

    INSERT INTO audit.log_etl_run (procedure_name, start_time, status)
    VALUES ('etl.usp_load_dim_product', SYSUTCDATETIME(), 'RUNNING');
    SET @v_run_key = SCOPE_IDENTITY();

    BEGIN TRY
        BEGIN TRANSACTION;

        ;WITH src AS (
            SELECT DISTINCT
                stg.source_system,
                stg.product_id,
                stg.product_name,
                stg.category,
                stg.subcategory,
                stg.brand,
                TRY_CAST(stg.unit_price AS DECIMAL(18,4)) AS unit_price,
                TRY_CAST(stg.unit_cost AS DECIMAL(18,4)) AS unit_cost,
                cur.currency_key
            FROM staging.stg_product AS stg
            LEFT JOIN dim.dim_currency AS cur
                ON cur.currency_code = stg.currency_code
            WHERE stg.product_id IS NOT NULL AND stg.source_system IS NOT NULL
        )
        UPDATE tgt
        SET is_current = 0,
            expiry_date = DATEADD(DAY, -1, @v_load_date),
            updated_date = SYSUTCDATETIME(),
            updated_by = SUSER_SNAME()
        FROM dim.dim_product AS tgt
        INNER JOIN src
            ON src.product_id = tgt.product_id
           AND src.source_system = tgt.source_system
        WHERE tgt.is_current = 1
          AND (
                ISNULL(tgt.product_name, '') <> ISNULL(src.product_name, '')
             OR ISNULL(tgt.category, '') <> ISNULL(src.category, '')
             OR ISNULL(tgt.subcategory, '') <> ISNULL(src.subcategory, '')
             OR ISNULL(tgt.brand, '') <> ISNULL(src.brand, '')
             OR ISNULL(tgt.unit_price, -1) <> ISNULL(src.unit_price, -1)
             OR ISNULL(tgt.unit_cost, -1) <> ISNULL(src.unit_cost, -1)
             OR ISNULL(tgt.currency_key, -1) <> ISNULL(src.currency_key, -1)
          );

        SET @v_rows_expired = @@ROWCOUNT;

        ;WITH src AS (
            SELECT DISTINCT
                stg.source_system,
                stg.product_id,
                stg.product_name,
                stg.category,
                stg.subcategory,
                stg.brand,
                TRY_CAST(stg.unit_price AS DECIMAL(18,4)) AS unit_price,
                TRY_CAST(stg.unit_cost AS DECIMAL(18,4)) AS unit_cost,
                cur.currency_key
            FROM staging.stg_product AS stg
            LEFT JOIN dim.dim_currency AS cur
                ON cur.currency_code = stg.currency_code
            WHERE stg.product_id IS NOT NULL AND stg.source_system IS NOT NULL
        )
        INSERT INTO dim.dim_product (
            product_id, source_system, product_name, category, subcategory,
            brand, unit_price, unit_cost, currency_key, is_current, effective_date, expiry_date
        )
        SELECT
            src.product_id, src.source_system, src.product_name, src.category, src.subcategory,
            src.brand, src.unit_price, src.unit_cost, src.currency_key, 1, @v_load_date, '9999-12-31'
        FROM src
        LEFT JOIN dim.dim_product AS cur
            ON cur.product_id = src.product_id
           AND cur.source_system = src.source_system
           AND cur.is_current = 1
        WHERE cur.product_key IS NULL; -- true for brand-new products and those just expired above

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
