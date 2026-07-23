-- =============================================================================
-- Phase 8 — Banking Industry Accelerator
-- etl.usp_load_dim_customer_banking — the generator's customer records embed
-- a single address directly (no separate location entity/ID), unlike the
-- generic framework's dim.dim_customer which expects a location_key FK.
-- Reconciled here by synthesizing location_id = customer_id (a 1:1
-- customer-to-address relationship, not shared locations — still a valid
-- dim.dim_location row) before running the same SCD Type 2 expire-then-insert
-- pattern as src/sql/06-stored-procedures/05_Load_Dim_Customer.sql.
-- =============================================================================

USE [AdeaDW];
GO

CREATE OR ALTER PROCEDURE etl.usp_load_dim_customer_banking
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v_run_key BIGINT;
    DECLARE @v_locations_inserted INT = 0, @v_locations_updated INT = 0;
    DECLARE @v_rows_expired INT = 0, @v_rows_inserted INT = 0;
    DECLARE @v_load_date DATE = CAST(SYSUTCDATETIME() AS DATE);

    INSERT INTO audit.log_etl_run (procedure_name, start_time, status)
    VALUES ('etl.usp_load_dim_customer_banking', SYSUTCDATETIME(), 'RUNNING');
    SET @v_run_key = SCOPE_IDENTITY();

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Step 1: upsert dim_location (SCD1 — address corrections overwrite
        -- in place, same as the generic framework's dim_location).
        DECLARE @merge_output TABLE (action_type VARCHAR(10));

        MERGE dim.dim_location AS tgt
        USING (
            SELECT DISTINCT
                stg.source_system,
                stg.customer_id AS location_id,
                stg.address_line1,
                stg.city,
                stg.region,
                stg.postal_code,
                stg.country
            FROM staging.stg_banking_customer AS stg
            WHERE stg.customer_id IS NOT NULL
        ) AS src
            ON tgt.location_id = src.location_id
           AND tgt.source_system = src.source_system
        WHEN MATCHED AND (
                ISNULL(tgt.address_line1, '') <> ISNULL(src.address_line1, '')
             OR ISNULL(tgt.city, '') <> ISNULL(src.city, '')
             OR ISNULL(tgt.region, '') <> ISNULL(src.region, '')
             OR ISNULL(tgt.postal_code, '') <> ISNULL(src.postal_code, '')
             OR ISNULL(tgt.country, '') <> ISNULL(src.country, '')
        )
        THEN UPDATE SET
            address_line1 = src.address_line1,
            city = src.city,
            region = src.region,
            postal_code = src.postal_code,
            country = src.country,
            updated_date = SYSUTCDATETIME(),
            updated_by = SUSER_SNAME()
        WHEN NOT MATCHED BY TARGET
        THEN INSERT (source_system, location_id, address_line1, city, region, postal_code, country)
             VALUES (src.source_system, src.location_id, src.address_line1, src.city, src.region, src.postal_code, src.country)
        OUTPUT $action INTO @merge_output;

        SELECT
            @v_locations_inserted = COUNT(CASE WHEN action_type = 'INSERT' THEN 1 END),
            @v_locations_updated  = COUNT(CASE WHEN action_type = 'UPDATE' THEN 1 END)
        FROM @merge_output;

        -- Step 2: SCD Type 2 load of dim_customer, same expire-then-insert
        -- shape as the generic loader, joined to the location rows just upserted.
        ;WITH src AS (
            SELECT DISTINCT
                stg.source_system,
                stg.customer_id,
                loc.location_key,
                stg.first_name,
                stg.last_name,
                stg.email,
                stg.phone,
                stg.customer_segment
            FROM staging.stg_banking_customer AS stg
            INNER JOIN dim.dim_location AS loc
                ON loc.location_id = stg.customer_id
               AND loc.source_system = stg.source_system
            WHERE stg.customer_id IS NOT NULL
        )
        UPDATE tgt
        SET is_current = 0,
            expiry_date = DATEADD(DAY, -1, @v_load_date),
            updated_date = SYSUTCDATETIME(),
            updated_by = SUSER_SNAME()
        FROM dim.dim_customer AS tgt
        INNER JOIN src
            ON src.customer_id = tgt.customer_id
           AND src.source_system = tgt.source_system
        WHERE tgt.is_current = 1
          AND (
                ISNULL(tgt.location_key, -1) <> ISNULL(src.location_key, -1)
             OR ISNULL(tgt.first_name, '') <> ISNULL(src.first_name, '')
             OR ISNULL(tgt.last_name, '') <> ISNULL(src.last_name, '')
             OR ISNULL(tgt.email, '') <> ISNULL(src.email, '')
             OR ISNULL(tgt.phone, '') <> ISNULL(src.phone, '')
             OR ISNULL(tgt.customer_segment, '') <> ISNULL(src.customer_segment, '')
          );

        SET @v_rows_expired = @@ROWCOUNT;

        ;WITH src AS (
            SELECT DISTINCT
                stg.source_system,
                stg.customer_id,
                loc.location_key,
                stg.first_name,
                stg.last_name,
                stg.email,
                stg.phone,
                stg.customer_segment
            FROM staging.stg_banking_customer AS stg
            INNER JOIN dim.dim_location AS loc
                ON loc.location_id = stg.customer_id
               AND loc.source_system = stg.source_system
            WHERE stg.customer_id IS NOT NULL
        )
        INSERT INTO dim.dim_customer (
            customer_id, source_system, location_key, first_name, last_name,
            email, phone, customer_segment, is_current, effective_date, expiry_date
        )
        SELECT
            src.customer_id, src.source_system, src.location_key, src.first_name, src.last_name,
            src.email, src.phone, src.customer_segment, 1, @v_load_date, '9999-12-31'
        FROM src
        LEFT JOIN dim.dim_customer AS cur
            ON cur.customer_id = src.customer_id
           AND cur.source_system = src.source_system
           AND cur.is_current = 1
        WHERE cur.customer_key IS NULL;

        SET @v_rows_inserted = @@ROWCOUNT;

        COMMIT TRANSACTION;

        UPDATE audit.log_etl_run
        SET end_time = SYSUTCDATETIME(), status = 'SUCCESS',
            rows_updated = @v_rows_expired + @v_locations_updated,
            rows_inserted = @v_rows_inserted + @v_locations_inserted
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
