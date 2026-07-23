-- =============================================================================
-- Phase 8 — Retail Industry Accelerator
-- etl.usp_load_fact_inventory_retail — loads fact.fact_inventory
-- (this folder's one net-new table). Insert-only anti-join, same idempotent
-- shape as every other fact loader in this repo, but with a real
-- simplification worth being explicit about: this is a periodic snapshot
-- grain, and this procedure treats it as append-only, keyed on
-- (source_system, inventory_id). Since the generator assigns a stable
-- inventory_id per (product, warehouse) row, re-running against the same
-- generated CSV is a correct no-op — but a genuine periodic-snapshot
-- pipeline (a new snapshot each day/week) would need a snapshot_date_key
-- in the natural key instead of relying on inventory_id alone, so that
-- today's snapshot doesn't silently skip because yesterday's inventory_id
-- already exists. Not built here — flagged in README.md's "what's still
-- not done" section rather than silently shipped as if it were a solved
-- SCD-style history problem.
-- =============================================================================

USE [AdeaDW];
GO

CREATE OR ALTER PROCEDURE etl.usp_load_fact_inventory_retail
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v_run_key BIGINT;
    DECLARE @v_rows_inserted INT = 0;
    DECLARE @v_snapshot_date_key INT = CONVERT(INT, FORMAT(SYSUTCDATETIME(), 'yyyyMMdd'));

    INSERT INTO audit.log_etl_run (procedure_name, start_time, status)
    VALUES ('etl.usp_load_fact_inventory_retail', SYSUTCDATETIME(), 'RUNNING');
    SET @v_run_key = SCOPE_IDENTITY();

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO fact.fact_inventory (
            snapshot_date_key, product_key, source_system, inventory_id,
            warehouse, quantity_on_hand, reorder_level, last_restock_date
        )
        SELECT
            @v_snapshot_date_key,
            prod.product_key,
            stg.source_system,
            stg.inventory_id,
            stg.warehouse,
            TRY_CAST(stg.quantity_on_hand AS INT),
            TRY_CAST(stg.reorder_level AS INT),
            TRY_CAST(stg.last_restock_date AS DATE)
        FROM staging.stg_retail_inventory AS stg
        INNER JOIN dim.dim_product AS prod
            ON prod.product_id = stg.product_id
           AND prod.source_system = stg.source_system
           AND prod.is_current = 1
        WHERE stg.inventory_id IS NOT NULL
          AND NOT EXISTS (
              SELECT 1 FROM fact.fact_inventory AS f
              WHERE f.source_system = stg.source_system AND f.inventory_id = stg.inventory_id
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
