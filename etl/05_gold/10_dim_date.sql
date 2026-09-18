-- ============================================================
-- Gold: dim_date
--
-- Stage:     05 Gold
-- Runs after: Integration gate
-- Target:    `ftw-week-08`.`05-gold`.dim_date
-- Grain:     one row per NYC-local calendar date
-- Contract:  docs/data_model.md, docs/source_to_target_mapping.md
-- Owner:     TODO
--
-- Dimensions are built before facts; facts resolve keys only against built dimensions.
-- ============================================================

-- To implement:
--   - date_key as YYYYMMDD integer, non-null and unique
--   - cover the reporting window plus every retained observed trip date
--   - calendar year, quarter, month, day, ISO day-of-week, weekday name, weekend flag
--   - deterministic rebuild or merge by date_key; no unknown member (D12)

-- ------------------------------------------------------------
-- Remove this block when the query above is implemented. It keeps an
-- unfinished stage from looking successful in a Databricks job run.
-- ------------------------------------------------------------
SELECT raise_error('10_dim_date.sql is not implemented yet');

-- Gold dimension: dim_date (issue #36). Calendar seed dimension -- one row
-- per local calendar date. Full rebuild (CREATE OR REPLACE), not an
-- incremental MERGE: a calendar has no revision history to preserve, so a
-- deterministic full recompute keeps this idempotent on rerun, matching
-- green_taxi_clean's own CREATE OR REPLACE precedent.
--
-- Grain: one row per unique local (America/New_York) calendar date.
-- SCD: Type 0 / full rebuild -- no history retained, none needed.
--
-- Date range is derived from actual Silver data (taxi pickup/drop-off local
-- dates + weather observation local dates) rather than a hardcoded literal
-- window, per source_to_target_mapping.md's requirement that dim_date cover
-- "the reporting interval and every retained observed taxi date." This also
-- means dim_date grows/shrinks automatically as more Silver data lands, with
-- no manual date-range maintenance.
CREATE OR REPLACE TABLE `ftw-week-08`.`05-gold`.dim_date AS
WITH date_bounds AS (
    SELECT MIN(d) AS min_date, MAX(d) AS max_date
    FROM (
        SELECT CAST(pickup_datetime_local AS DATE) AS d
        FROM `ftw-week-08`.`03-silver`.green_taxi_clean
        WHERE pickup_datetime_local IS NOT NULL

        UNION ALL

        SELECT CAST(dropoff_datetime_local AS DATE) AS d
        FROM `ftw-week-08`.`03-silver`.green_taxi_clean
        WHERE dropoff_datetime_local IS NOT NULL

        UNION ALL

        SELECT observation_date_local AS d
        FROM `ftw-week-08`.`03-silver`.weather_hourly
        WHERE observation_date_local IS NOT NULL
    )
),
calendar_seed AS (
    -- One row per calendar day, inclusive, with zero gaps by construction.
    SELECT explode(sequence(db.min_date, db.max_date, interval 1 day)) AS full_date
    FROM date_bounds db
),
calendar_enriched AS (
    -- weekday(): 0 = Monday ... 6 = Sunday. +1 gives ISO numbering (Monday=1
    -- ... Sunday=7), computed once here so weekend_flag below reuses it
    -- instead of a second date-math expression that could drift out of sync.
    SELECT
        full_date,
        weekday(full_date) + 1 AS day_of_week_number
    FROM calendar_seed
)
SELECT
    full_date,
    CAST(date_format(full_date, 'yyyyMMdd') AS INT) AS date_key,
    YEAR(full_date)    AS calendar_year,
    QUARTER(full_date) AS calendar_quarter,
    MONTH(full_date)   AS month_number,
    date_format(full_date, 'MMMM') AS month_name,
    DAY(full_date)     AS day_of_month,
    day_of_week_number,
    date_format(full_date, 'EEEE') AS day_of_week_name,
    day_of_week_number IN (6, 7) AS weekend_flag
FROM calendar_enriched;

