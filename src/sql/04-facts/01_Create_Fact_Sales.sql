-- =============================================================================
-- Milestone 2.3 — Core Facts
-- fact.fact_sales — one row per sale line item.
-- The surrogate key is UNIQUE NONCLUSTERED, not the clustered index: fact
-- tables get a clustered columnstore index in src/sql/08-indexes/ per
-- src/sql/00-standards/sql-coding-standards.md.
-- On Synapse dedicated SQL pools, PK/FK/UNIQUE below are NOT ENFORCED
-- (informational only) — see the compatibility table in that same doc.
-- =============================================================================

USE [AdeaDW];
GO

IF OBJECT_ID('fact.fact_sales', 'U') IS NULL
BEGIN
    CREATE TABLE fact.fact_sales
    (
        sale_key         BIGINT IDENTITY(1,1) NOT NULL,
        date_key         INT           NOT NULL,
        customer_key     INT           NOT NULL,
        product_key      INT           NOT NULL,
        employee_key     INT           NULL,      -- salesperson
        location_key     INT           NULL,       -- store/branch
        currency_key     INT           NULL,
        source_system    VARCHAR(20)   NOT NULL,
        sale_id          VARCHAR(50)   NOT NULL,   -- degenerate dimension: source line id
        quantity         DECIMAL(18,4) NOT NULL,
        unit_price       DECIMAL(18,4) NOT NULL,
        discount_amount  DECIMAL(18,4) NOT NULL DEFAULT (0),
        tax_amount       DECIMAL(18,4) NOT NULL DEFAULT (0),
        net_amount       DECIMAL(18,4) NOT NULL,
        created_date     DATETIME2     NOT NULL DEFAULT (SYSUTCDATETIME()),
        created_by       SYSNAME       NOT NULL DEFAULT (SUSER_SNAME()),
        updated_date     DATETIME2     NULL,
        updated_by       SYSNAME       NULL,

        CONSTRAINT pk_fact_sales PRIMARY KEY NONCLUSTERED (sale_key),
        CONSTRAINT uq_fact_sales_natural UNIQUE (source_system, sale_id),
        CONSTRAINT fk_fact_sales_dim_date FOREIGN KEY (date_key)
            REFERENCES dim.dim_date (date_key),
        CONSTRAINT fk_fact_sales_dim_customer FOREIGN KEY (customer_key)
            REFERENCES dim.dim_customer (customer_key),
        CONSTRAINT fk_fact_sales_dim_product FOREIGN KEY (product_key)
            REFERENCES dim.dim_product (product_key),
        CONSTRAINT fk_fact_sales_dim_employee FOREIGN KEY (employee_key)
            REFERENCES dim.dim_employee (employee_key),
        CONSTRAINT fk_fact_sales_dim_location FOREIGN KEY (location_key)
            REFERENCES dim.dim_location (location_key),
        CONSTRAINT fk_fact_sales_dim_currency FOREIGN KEY (currency_key)
            REFERENCES dim.dim_currency (currency_key)
    );
END
GO
