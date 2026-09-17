-- ============================================================
-- Q1: when and where is recorded activity highest
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
--   - measure: SUM(trip_count)
--   - by pickup date, day of week, hour and Taxi Zone
--   - produce pickup-role and drop-off-role results separately (D12)
--   - both use pickup date, day of week and hour as the time context

-- ------------------------------------------------------------
-- Remove this block when the query above is implemented. It keeps an
-- unfinished stage from looking successful in a Databricks job run.
-- ------------------------------------------------------------
SELECT raise_error('10_activity_by_time_and_zone.sql is not implemented yet');
