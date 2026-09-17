-- ============================================================
-- Gold: fact_weather_hourly
--
-- Stage:     05 Gold
-- Runs after: etl/04_integration/90_validate_integration.sql
-- Target:    `ftw-week-08`.`05-gold`.fact_weather_hourly
-- Grain:     one row per coordinate, UTC observation hour and weather model
-- Contract:  docs/data_model.md, docs/source_to_target_mapping.md
-- Owner:     TODO
--
-- Dimensions are built before facts; facts resolve keys only against built dimensions.
-- ============================================================

-- To implement:
--   - weather_observation_key deterministic from coordinate_id,
--     observation_timestamp_utc and weather_model
--   - observation_date_key and observation_hour_key from the DST-aware local timestamp
--   - measures temperature_2m_c and precipitation_mm stay here, never on trips
--   - upsert by the natural key; a repeated response is a no-op

-- ------------------------------------------------------------
-- Remove this block when the query above is implemented. It keeps an
-- unfinished stage from looking successful in a Databricks job run.
-- ------------------------------------------------------------
SELECT raise_error('20_fact_weather_hourly.sql is not implemented yet');
