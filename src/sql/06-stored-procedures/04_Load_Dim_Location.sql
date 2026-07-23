-- =============================================================================
-- Milestone 2.4 — ETL Components
-- etl.usp_load_dim_location — SCD Type 1 upsert (overwrite in place; this
-- table does not track relocation history). Same MERGE/Synapse caveat as
-- etl.usp_load_dim_source_system.
-- =============================================================================

USE [AdeaDW];
GO

CREATE OR ALTER PROCEDURE etl.usp_load_dim_location
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v_run_key BIGINT;
    DECLARE @v_rows_inserted INT = 0, @v_rows_updated INT = 0;

    INSERT INTO audit.log_etl_run (procedure_name, start_time, status)
    VALUES ('etl.usp_load_dim_location', SYSUTCDATETIME(), 'RUNNING');
    SET @v_run_key = SCOPE_IDENTITY();

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @merge_output TABLE (action_type VARCHAR(10));

        MERGE dim.dim_location AS tgt
        USING (
            SELECT DISTINCT
                source_system, location_id, address_line1, address_line2,
                city, region, postal_code, country,
                TRY_CAST(latitude AS DECIMAL(9,6)) AS latitude,
                TRY_CAST(longitude AS DECIMAL(9,6)) AS longitude
            FROM staging.stg_location
            WHERE location_id IS NOT NULL AND source_system IS NOT NULL
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
            address_line2 = src.address_line2,
            city = src.city,
            region = src.region,
            postal_code = src.postal_code,
            country = src.country,
            latitude = src.latitude,
            longitude = src.longitude,
            updated_date = SYSUTCDATETIME(),
            updated_by = SUSER_SNAME()
        WHEN NOT MATCHED BY TARGET
        THEN INSERT (
                source_system, location_id, address_line1, address_line2,
                city, region, postal_code, country, latitude, longitude
             )
             VALUES (
                src.source_system, src.location_id, src.address_line1, src.address_line2,
                src.city, src.region, src.postal_code, src.country, src.latitude, src.longitude
             )
        OUTPUT $action INTO @merge_output;

        SELECT
            @v_rows_inserted = COUNT(CASE WHEN action_type = 'INSERT' THEN 1 END),
            @v_rows_updated  = COUNT(CASE WHEN action_type = 'UPDATE' THEN 1 END)
        FROM @merge_output;

        COMMIT TRANSACTION;

        UPDATE audit.log_etl_run
        SET end_time = SYSUTCDATETIME(), status = 'SUCCESS',
            rows_inserted = @v_rows_inserted, rows_updated = @v_rows_updated
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
