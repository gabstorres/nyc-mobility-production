-- ============================================================
-- Q3: which areas show the strongest mobility patterns
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
--   - measures: pickup count, drop-off count, average duration, distance, fare
--   - by Taxi Zone, time and weather condition
--   - keep pickup and drop-off roles in separate results

-- ------------------------------------------------------------
-- Remove this block when the query above is implemented. It keeps an
-- unfinished stage from looking successful in a Databricks job run.
-- ------------------------------------------------------------
SELECT raise_error('30_mobility_patterns_by_zone.sql is not implemented yet');
