-- ============================================================
-- Gold: dim_taxi_zone
--
-- Stage:     05 Gold
-- Runs after: Integration gate
-- Target:    `ftw-week-08`.`05-gold`.dim_taxi_zone
-- Grain:     one row per source LocationID in the selected snapshot
-- Contract:  docs/data_model.md, docs/source_to_target_mapping.md
-- Owner:     TODO
--
-- Dimensions are built before facts; facts resolve keys only against built dimensions.
-- ============================================================

-- To implement:
--   - zone_key surrogate PK, location_id unique business key
--   - borough, zone name, service zone and snapshot lineage retained
--   - zone_classification rules in order: 264 unknown, 265 outside_nyc,
--     borough EWR ewr, five NYC boroughs nyc_borough, otherwise other_special
--   - full refresh from the pinned snapshot (D11)

-- ------------------------------------------------------------
-- Remove this block when the query above is implemented. It keeps an
-- unfinished stage from looking successful in a Databricks job run.
-- ------------------------------------------------------------
SELECT raise_error('12_dim_taxi_zone.sql is not implemented yet');
