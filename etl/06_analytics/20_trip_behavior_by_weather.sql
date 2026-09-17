-- ============================================================
-- Q2: how weather is associated with activity and behavior
--
-- Stage:     06 Analytics
-- Runs after: etl/05_gold/90_validate_gold.sql
-- Target:    `ftw-week-08`.`06-analytics` — table name to be approved, see config/naming.yml
-- Grain:     one row per reported combination; state it explicitly when implementing
-- Contract:  docs/data_model.md, docs/source_to_target_mapping.md
-- Owner:     TODO
--
-- Query Gold only. Analytics must never read Silver or Bronze.
-- ============================================================

-- To implement:
--   - measures: trip count, average duration, average distance, average fare
--   - by weather condition and precipitation band, matched at pickup hour
--   - apply each measure's eligibility rule from docs/data_model.md
--   - never sum hourly weather measurements through trip rows

-- ------------------------------------------------------------
-- Remove this block when the query above is implemented. It keeps an
-- unfinished stage from looking successful in a Databricks job run.
-- ------------------------------------------------------------
SELECT raise_error('20_trip_behavior_by_weather.sql is not implemented yet');
