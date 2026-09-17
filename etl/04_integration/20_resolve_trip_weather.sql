-- ============================================================
-- Resolve trips to the pickup weather hour
--
-- Stage:     04 Integration
-- Runs after: etl/04_integration/10_resolve_trip_zones.sql
-- Target:    intermediate result consumed by etl/05_gold/30_fact_taxi_trip.sql
-- Grain:     one row per accepted trip, unchanged
-- Contract:  docs/data_model.md, docs/source_to_target_mapping.md
-- Owner:     TODO
--
-- Copies only weather_classification_key onto a trip. Temperature and precipitation stay in fact_weather_hourly (D12).
-- ============================================================

-- To implement:
--   - convert the trip pickup timestamp to UTC with a DST-aware conversion (D09)
--   - truncate to the hour and match Silver `weather_hourly` on
--     coordinate_id, observation hour and the pinned weather model
--   - require zero or one match; more than one match must fail the stage
--   - set pickup_weather_match_status: matched, no_match, invalid_pickup_timestamp
--   - leave the classification key null for no_match, do not invent a member

-- ------------------------------------------------------------
-- Remove this block when the query above is implemented. It keeps an
-- unfinished stage from looking successful in a Databricks job run.
-- ------------------------------------------------------------
SELECT raise_error('20_resolve_trip_weather.sql is not implemented yet');
