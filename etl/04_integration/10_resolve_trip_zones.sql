-- ============================================================
-- Resolve trips to pickup and drop-off zones
--
-- Stage:     04 Integration
-- Runs after: Silver gates for green_taxi and taxi_zones
-- Target:    intermediate result consumed by etl/05_gold/30_fact_taxi_trip.sql
-- Grain:     one row per accepted trip, unchanged from Silver
-- Contract:  docs/data_model.md, docs/source_to_target_mapping.md
-- Owner:     TODO
--
-- Adds zone keys to a trip. Must not change the trip grain or drop rows.
-- ============================================================

-- To implement:
--   - LEFT JOIN Silver `green_taxi_clean` to Silver `taxi_zones` on pickup_location_id
--   - LEFT JOIN again on dropoff_location_id, as a separate role
--   - keep the original location ids even when no zone matches
--   - set pickup_zone_match_status and dropoff_zone_match_status to one of
--     matched_regular, matched_special, missing_source_id, unmatched_location_id
--   - count unmatched rows before choosing a join type; never INNER JOIN silently
--   - IDs 264 (unknown) and 265 (outside_nyc) are valid members, not failures

-- ------------------------------------------------------------
-- Remove this block when the query above is implemented. It keeps an
-- unfinished stage from looking successful in a Databricks job run.
-- ------------------------------------------------------------
SELECT raise_error('10_resolve_trip_zones.sql is not implemented yet');
