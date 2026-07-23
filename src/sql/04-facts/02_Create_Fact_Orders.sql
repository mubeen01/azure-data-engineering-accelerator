-- =============================================================================
-- Milestone 2.3 — Core Facts
-- fact.fact_orders — one row per order line item (retail/e-commerce grain).
-- The surrogate key is UNIQUE NONCLUSTERED, not the clustered index: fact
-- tables get a clustered columnstore index in src/sql/08-indexes/ per
-- src/sql/00-standards/sql-coding-standards.md.
-- On Synapse dedicated SQL pools, PK/FK/UNIQUE below are NOT ENFORCED
-- (informational only) — see the compatibility table in that same doc.
-- =============================================================================

USE [AdeaDW];
GO

IF OBJECT_ID('fact.fact_orders', 'U') IS NULL
BEGIN
    CREATE TABLE fact.fact_orders
    (
        order_line_key    BIGINT IDENTITY(1,1) NOT NULL,
        date_key          INT           NOT NULL,   -- order date
        customer_key      INT           NOT NULL,
        product_key       INT           NOT NULL,
        employee_key      INT           NULL,       -- order taker/rep
        location_key      INT           NULL,        -- fulfilling store/warehouse
        currency_key      INT           NULL,
        source_system     VARCHAR(20)   NOT NULL,
        order_id          VARCHAR(50)   NOT NULL,    -- degenerate dimension: order header id
        order_line_number INT           NOT NULL,
        order_status      VARCHAR(30)   NULL,        -- e.g. Pending, Shipped, Cancelled
        quantity          DECIMAL(18,4) NOT NULL,
        unit_price        DECIMAL(18,4) NOT NULL,
        discount_amount   DECIMAL(18,4) NOT NULL DEFAULT (0),
        tax_amount        DECIMAL(18,4) NOT NULL DEFAULT (0),
        net_amount        DECIMAL(18,4) NOT NULL,
        created_date      DATETIME2     NOT NULL DEFAULT (SYSUTCDATETIME()),
        created_by        SYSNAME       NOT NULL DEFAULT (SUSER_SNAME()),
        updated_date      DATETIME2     NULL,
        updated_by        SYSNAME       NULL,

        CONSTRAINT pk_fact_orders PRIMARY KEY NONCLUSTERED (order_line_key),
        CONSTRAINT uq_fact_orders_natural UNIQUE (source_system, order_id, order_line_number),
        CONSTRAINT fk_fact_orders_dim_date FOREIGN KEY (date_key)
            REFERENCES dim.dim_date (date_key),
        CONSTRAINT fk_fact_orders_dim_customer FOREIGN KEY (customer_key)
            REFERENCES dim.dim_customer (customer_key),
        CONSTRAINT fk_fact_orders_dim_product FOREIGN KEY (product_key)
            REFERENCES dim.dim_product (product_key),
        CONSTRAINT fk_fact_orders_dim_employee FOREIGN KEY (employee_key)
            REFERENCES dim.dim_employee (employee_key),
        CONSTRAINT fk_fact_orders_dim_location FOREIGN KEY (location_key)
            REFERENCES dim.dim_location (location_key),
        CONSTRAINT fk_fact_orders_dim_currency FOREIGN KEY (currency_key)
            REFERENCES dim.dim_currency (currency_key)
    );
END
GO
