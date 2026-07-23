-- =============================================================================
-- Seeds dim.dim_date with one row per calendar day between @p_start_date and
-- @p_end_date. Deterministic date spine — not synthetic data, so it lives
-- here rather than in the Phase 3 Python generator. Idempotent: reruns only
-- insert dates not already present.
-- Fiscal columns are left NULL — this framework has no fiscal calendar
-- opinion; industry accelerators (Phase 8) can UPDATE them if a fiscal year
-- differs from the calendar year.
-- =============================================================================

USE [AdeaDW];
GO

SET DATEFIRST 7; -- so day_of_week below is always 1 = Sunday .. 7 = Saturday, regardless of session default
GO

DECLARE @p_start_date DATE = '2015-01-01';
DECLARE @p_end_date   DATE = '2035-12-31';

;WITH tally AS (
    SELECT TOP (DATEDIFF(DAY, @p_start_date, @p_end_date) + 1)
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS rn
    FROM sys.all_objects AS a
    CROSS JOIN sys.all_objects AS b
),
dates AS (
    SELECT DATEADD(DAY, rn, @p_start_date) AS full_date
    FROM tally
)
INSERT INTO dim.dim_date (
    date_key, full_date, day_of_week, day_name, day_of_month, day_of_year,
    week_of_year, month_number, month_name, quarter_number, year_number,
    is_weekend, is_holiday
)
SELECT
    CONVERT(INT, FORMAT(d.full_date, 'yyyyMMdd'))  AS date_key,
    d.full_date,
    DATEPART(WEEKDAY, d.full_date)                 AS day_of_week,
    DATENAME(WEEKDAY, d.full_date)                  AS day_name,
    DATEPART(DAY, d.full_date)                      AS day_of_month,
    DATEPART(DAYOFYEAR, d.full_date)                AS day_of_year,
    DATEPART(ISO_WEEK, d.full_date)                 AS week_of_year,
    MONTH(d.full_date)                              AS month_number,
    DATENAME(MONTH, d.full_date)                    AS month_name,
    DATEPART(QUARTER, d.full_date)                  AS quarter_number,
    YEAR(d.full_date)                               AS year_number,
    CASE WHEN DATEPART(WEEKDAY, d.full_date) IN (1, 7) THEN 1 ELSE 0 END AS is_weekend,
    0                                                AS is_holiday
FROM dates AS d
WHERE NOT EXISTS (
    SELECT 1 FROM dim.dim_date AS existing WHERE existing.full_date = d.full_date
);
GO
