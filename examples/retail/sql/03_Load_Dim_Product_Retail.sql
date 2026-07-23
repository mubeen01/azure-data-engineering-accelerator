-- =============================================================================
-- Phase 8 — Retail Industry Accelerator
-- etl.usp_load_dim_product_retail — writes into the *generic* dim.dim_product
-- (src/sql/03-dimensions/06_Create_Dim_Product.sql) unmodified. Retail's
-- product data matches that table's shape column-for-column except
-- currency_code (the generator has no currency variance — everything is
-- implicitly USD, so currency_key stays NULL, same as leaving an optional
-- FK unresolved elsewhere in this repo). This procedure exists only because
-- the generic etl.usp_load_dim_product hardcodes `FROM staging.stg_product`
-- (src/sql/06-stored-procedures/06_Load_Dim_Product.sql), and retail's
-- staging table is necessarily named differently
-- (staging.stg_retail_product — see 00_Create_Staging_Tables.sql's header
-- comment for why the generic staging table can't be reused directly
-- either). Same expire-then-insert SCD Type 2 pattern as the generic
-- procedure, just pointed at a different staging source.
-- =============================================================================

USE [AdeaDW];
GO

CREATE OR ALTER PROCEDURE etl.usp_load_dim_product_retail
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v_run_key BIGINT;
    DECLARE @v_rows_expired INT = 0, @v_rows_inserted INT = 0;
    DECLARE @v_load_date DATE = CAST(SYSUTCDATETIME() AS DATE);

    INSERT INTO audit.log_etl_run (procedure_name, start_time, status)
    VALUES ('etl.usp_load_dim_product_retail', SYSUTCDATETIME(), 'RUNNING');
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
                TRY_CAST(stg.unit_cost AS DECIMAL(18,4)) AS unit_cost
            FROM staging.stg_retail_product AS stg
            WHERE stg.product_id IS NOT NULL
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
                TRY_CAST(stg.unit_cost AS DECIMAL(18,4)) AS unit_cost
            FROM staging.stg_retail_product AS stg
            WHERE stg.product_id IS NOT NULL
        )
        INSERT INTO dim.dim_product (
            product_id, source_system, product_name, category, subcategory,
            brand, unit_price, unit_cost, currency_key, is_current, effective_date, expiry_date
        )
        SELECT
            src.product_id, src.source_system, src.product_name, src.category, src.subcategory,
            src.brand, src.unit_price, src.unit_cost, NULL, 1, @v_load_date, '9999-12-31'
        FROM src
        LEFT JOIN dim.dim_product AS cur
            ON cur.product_id = src.product_id
           AND cur.source_system = src.source_system
           AND cur.is_current = 1
        WHERE cur.product_key IS NULL;

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
