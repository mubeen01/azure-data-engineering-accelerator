-- =============================================================================
-- Milestone 2.2 — Core Dimensions
-- dim.dim_employee — SCD Type 2: role/department/manager changes are tracked
-- as new rows so historical facts still join to the employee state that was
-- true at the time.
-- =============================================================================

USE [AdeaDW];
GO

IF OBJECT_ID('dim.dim_employee', 'U') IS NULL
BEGIN
    CREATE TABLE dim.dim_employee
    (
        employee_key     INT IDENTITY(1,1) NOT NULL,
        employee_id      VARCHAR(50)   NOT NULL,  -- natural key from source system
        source_system    VARCHAR(20)   NOT NULL,  -- dim_source_system.source_system_code
        location_key     INT           NULL,
        first_name       VARCHAR(100)  NULL,
        last_name        VARCHAR(100)  NULL,
        email            VARCHAR(200)  NULL,
        job_title        VARCHAR(100)  NULL,
        department       VARCHAR(100)  NULL,
        manager_employee_id VARCHAR(50) NULL,      -- natural key, not a surrogate FK
        hire_date        DATE          NULL,
        termination_date DATE          NULL,
        is_current       BIT           NOT NULL DEFAULT (1),
        effective_date   DATE          NOT NULL DEFAULT (CAST(SYSUTCDATETIME() AS DATE)),
        expiry_date      DATE          NOT NULL DEFAULT ('9999-12-31'),
        created_date      DATETIME2    NOT NULL DEFAULT (SYSUTCDATETIME()),
        created_by        SYSNAME      NOT NULL DEFAULT (SUSER_SNAME()),
        updated_date      DATETIME2    NULL,
        updated_by        SYSNAME      NULL,

        CONSTRAINT pk_dim_employee PRIMARY KEY CLUSTERED (employee_key),
        CONSTRAINT fk_dim_employee_dim_location FOREIGN KEY (location_key)
            REFERENCES dim.dim_location (location_key)
    );
END
GO

-- Only one current row per natural key — see dim_customer for the same
-- pattern and its Synapse caveat.
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'uq_dim_employee_current' AND object_id = OBJECT_ID('dim.dim_employee')
)
BEGIN
    CREATE UNIQUE INDEX uq_dim_employee_current
        ON dim.dim_employee (employee_id, source_system)
        WHERE is_current = 1;
END
GO
