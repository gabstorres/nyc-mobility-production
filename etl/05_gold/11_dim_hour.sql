-- ============================================================
-- Gold: dim_hour
--
-- Stage:     05 Gold
-- Runs after: Integration gate
-- Target:    `ftw-week-08`.`05-gold`.dim_hour
-- Grain:     one row per hour of day, 0 through 23
-- Contract:  docs/data_model.md, docs/source_to_target_mapping.md
-- Owner:     TODO
--
-- Dimensions are built before facts; facts resolve keys only against built dimensions.
-- ============================================================

-- To implement:
--   - hour_key equals hour_of_day, exactly 24 rows
--   - zero-padded hour label and the approved time-of-day band
--   - deterministic 24-row seed

-- ------------------------------------------------------------
-- Remove this block when the query above is implemented. It keeps an
-- unfinished stage from looking successful in a Databricks job run.
-- ------------------------------------------------------------
SELECT raise_error('11_dim_hour.sql is not implemented yet');
