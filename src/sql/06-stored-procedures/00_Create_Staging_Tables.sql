-- =============================================================================
-- Milestone 2.4 — ETL Components
-- Landing tables for staging.*. Columns are loosely typed (VARCHAR) on
-- purpose: staging is the forgiving landing zone before type/quality
-- enforcement, which happens in the etl.usp_load_* procedures. ADF (Phase 4)
-- is responsible for landing source-system extracts into these tables,
-- stamping each batch with staging_batch_id so it can be tied back to
-- audit.log_etl_run / etl.ctrl_watermark.
-- =============================================================================

USE [AdeaDW];
GO

IF OBJECT_ID('staging.stg_source_system', 'U') IS NULL
BEGIN
    CREATE TABLE staging.stg_source_system
    (
        staging_batch_id   BIGINT      NOT NULL,
        staging_loaded_date DATETIME2  NOT NULL DEFAULT (SYSUTCDATETIME()),
        source_system_code VARCHAR(20)  NULL,
        source_system_name VARCHAR(100) NULL,
        description        VARCHAR(400) NULL
    );
END
GO

IF OBJECT_ID('staging.stg_currency', 'U') IS NULL
BEGIN
    CREATE TABLE staging.stg_currency
    (
        staging_batch_id    BIGINT      NOT NULL,
        staging_loaded_date DATETIME2   NOT NULL DEFAULT (SYSUTCDATETIME()),
        source_system       VARCHAR(20) NULL,
        currency_code       VARCHAR(3)  NULL,
        currency_name       VARCHAR(100) NULL,
        symbol              VARCHAR(5)  NULL
    );
END
GO

IF OBJECT_ID('staging.stg_location', 'U') IS NULL
BEGIN
    CREATE TABLE staging.stg_location
    (
        staging_batch_id    BIGINT      NOT NULL,
        staging_loaded_date DATETIME2   NOT NULL DEFAULT (SYSUTCDATETIME()),
        source_system       VARCHAR(20) NULL,
        location_id         VARCHAR(50) NULL,
        address_line1       VARCHAR(200) NULL,
        address_line2       VARCHAR(200) NULL,
        city                VARCHAR(100) NULL,
        region              VARCHAR(100) NULL,
        postal_code         VARCHAR(20) NULL,
        country             VARCHAR(100) NULL,
        latitude            VARCHAR(20) NULL,
        longitude           VARCHAR(20) NULL
    );
END
GO

IF OBJECT_ID('staging.stg_customer', 'U') IS NULL
BEGIN
    CREATE TABLE staging.stg_customer
    (
        staging_batch_id    BIGINT      NOT NULL,
        staging_loaded_date DATETIME2   NOT NULL DEFAULT (SYSUTCDATETIME()),
        source_system       VARCHAR(20) NULL,
        customer_id         VARCHAR(50) NULL,
        location_id         VARCHAR(50) NULL,
        first_name          VARCHAR(100) NULL,
        last_name           VARCHAR(100) NULL,
        email               VARCHAR(200) NULL,
        phone               VARCHAR(30) NULL,
        customer_segment    VARCHAR(50) NULL
    );
END
GO

IF OBJECT_ID('staging.stg_product', 'U') IS NULL
BEGIN
    CREATE TABLE staging.stg_product
    (
        staging_batch_id    BIGINT      NOT NULL,
        staging_loaded_date DATETIME2   NOT NULL DEFAULT (SYSUTCDATETIME()),
        source_system       VARCHAR(20) NULL,
        product_id          VARCHAR(50) NULL,
        product_name        VARCHAR(200) NULL,
        category            VARCHAR(100) NULL,
        subcategory         VARCHAR(100) NULL,
        brand               VARCHAR(100) NULL,
        unit_price          VARCHAR(30) NULL,
        unit_cost           VARCHAR(30) NULL,
        currency_code       VARCHAR(3) NULL
    );
END
GO

IF OBJECT_ID('staging.stg_employee', 'U') IS NULL
BEGIN
    CREATE TABLE staging.stg_employee
    (
        staging_batch_id     BIGINT      NOT NULL,
        staging_loaded_date  DATETIME2   NOT NULL DEFAULT (SYSUTCDATETIME()),
        source_system        VARCHAR(20) NULL,
        employee_id          VARCHAR(50) NULL,
        location_id          VARCHAR(50) NULL,
        first_name           VARCHAR(100) NULL,
        last_name            VARCHAR(100) NULL,
        email                VARCHAR(200) NULL,
        job_title             VARCHAR(100) NULL,
        department            VARCHAR(100) NULL,
        manager_employee_id  VARCHAR(50) NULL,
        hire_date             VARCHAR(20) NULL,
        termination_date      VARCHAR(20) NULL
    );
END
GO

IF OBJECT_ID('staging.stg_sales', 'U') IS NULL
BEGIN
    CREATE TABLE staging.stg_sales
    (
        staging_batch_id    BIGINT      NOT NULL,
        staging_loaded_date DATETIME2   NOT NULL DEFAULT (SYSUTCDATETIME()),
        source_system       VARCHAR(20) NULL,
        sale_id             VARCHAR(50) NULL,
        sale_date           VARCHAR(20) NULL,
        customer_id         VARCHAR(50) NULL,
        product_id          VARCHAR(50) NULL,
        employee_id         VARCHAR(50) NULL,
        location_id         VARCHAR(50) NULL,
        currency_code       VARCHAR(3) NULL,
        quantity            VARCHAR(30) NULL,
        unit_price          VARCHAR(30) NULL,
        discount_amount     VARCHAR(30) NULL,
        tax_amount          VARCHAR(30) NULL,
        net_amount          VARCHAR(30) NULL
    );
END
GO

IF OBJECT_ID('staging.stg_orders', 'U') IS NULL
BEGIN
    CREATE TABLE staging.stg_orders
    (
        staging_batch_id    BIGINT      NOT NULL,
        staging_loaded_date DATETIME2   NOT NULL DEFAULT (SYSUTCDATETIME()),
        source_system       VARCHAR(20) NULL,
        order_id            VARCHAR(50) NULL,
        order_line_number   VARCHAR(10) NULL,
        order_date          VARCHAR(20) NULL,
        order_status        VARCHAR(30) NULL,
        customer_id         VARCHAR(50) NULL,
        product_id          VARCHAR(50) NULL,
        employee_id         VARCHAR(50) NULL,
        location_id         VARCHAR(50) NULL,
        currency_code       VARCHAR(3) NULL,
        quantity            VARCHAR(30) NULL,
        unit_price          VARCHAR(30) NULL,
        discount_amount     VARCHAR(30) NULL,
        tax_amount          VARCHAR(30) NULL,
        net_amount          VARCHAR(30) NULL
    );
END
GO

IF OBJECT_ID('staging.stg_transactions', 'U') IS NULL
BEGIN
    CREATE TABLE staging.stg_transactions
    (
        staging_batch_id    BIGINT      NOT NULL,
        staging_loaded_date DATETIME2   NOT NULL DEFAULT (SYSUTCDATETIME()),
        source_system       VARCHAR(20) NULL,
        transaction_id      VARCHAR(50) NULL,
        transaction_date    VARCHAR(20) NULL,
        account_id          VARCHAR(50) NULL,
        customer_id         VARCHAR(50) NULL,
        employee_id         VARCHAR(50) NULL,
        location_id         VARCHAR(50) NULL,
        currency_code       VARCHAR(3) NULL,
        transaction_type    VARCHAR(30) NULL,
        transaction_amount  VARCHAR(30) NULL,
        running_balance     VARCHAR(30) NULL
    );
END
GO
