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
