-- ============================================================
-- Gold: fact_taxi_trip
--
-- Stage:     05 Gold
-- Runs after: etl/04_integration/90_validate_integration.sql
-- Target:    `ftw-week-08`.`05-gold`.fact_taxi_trip
-- Grain:     one row per accepted Green Taxi trip after the duplicate policy
-- Contract:  docs/data_model.md, docs/source_to_target_mapping.md
-- Owner:     TODO
--
-- Dimensions are built before facts; facts resolve keys only against built dimensions.
-- ============================================================

-- To implement:
--   - trip_key deterministic from the D10 identity inputs; never include batch_id,
--     run_id or ingestion time
--   - role-playing FKs: pickup and drop-off date, hour and zone keys
--   - pickup_weather_classification_key nullable, with a match status
--   - FKs resolve only against the built dimensions, never against Silver
--   - measures: trip_count = 1, trip_distance_miles, trip_duration_seconds,
--     fare_amount_usd, plus retained amounts and quality flags

-- ------------------------------------------------------------
-- Remove this block when the query above is implemented. It keeps an
-- unfinished stage from looking successful in a Databricks job run.
-- ------------------------------------------------------------
SELECT raise_error('30_fact_taxi_trip.sql is not implemented yet');
