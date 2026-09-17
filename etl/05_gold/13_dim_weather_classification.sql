-- ============================================================
-- Gold: dim_weather_classification
--
-- Stage:     05 Gold
-- Runs after: Integration gate
-- Target:    `ftw-week-08`.`05-gold`.dim_weather_classification
-- Grain:     one row per weather code and precipitation band
-- Contract:  docs/data_model.md, docs/source_to_target_mapping.md
-- Owner:     TODO
--
-- Dimensions are built before facts; facts resolve keys only against built dimensions.
-- ============================================================

-- To implement:
--   - weather_classification_key deterministic from weather_code and precipitation_band
--   - precipitation bands: dry 0mm, light <=2.5mm, moderate <=7.5mm, heavy >7.5mm
--   - unrecognized non-null WMO code maps to unknown_code and raises a DQ review item

-- ------------------------------------------------------------
-- Remove this block when the query above is implemented. It keeps an
-- unfinished stage from looking successful in a Databricks job run.
-- ------------------------------------------------------------
SELECT raise_error('13_dim_weather_classification.sql is not implemented yet');
