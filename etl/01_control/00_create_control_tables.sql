-- ============================================================
-- 00 Control setup: operational tables in `01-control`.
-- Safe to rerun.
-- ============================================================

-- ------------------------------------------------------------
-- One row per external source batch or source version (D14).
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `ftw-week-08`.`01-control`.ingestion_batches (
    batch_id STRING NOT NULL,

    -- what this batch is
    source_system STRING,        -- e.g. 'green_taxi', 'open_meteo', 'taxi_zones'
    source_object STRING,        -- e.g. filename or API endpoint identifier
    source_period STRING,        -- e.g. '2026-03' for taxi, request window for weather
    request_parameters STRING,   -- JSON string; null for file-based sources, populated for weather

    -- identity / change detection
    content_sha256 STRING,       -- proves whether content actually changed, not just the filename
    source_version_id STRING,
    schema_fingerprint STRING,   -- hash of the column name+type signature

    -- location
    raw_uri STRING,              -- path in the source Volume

    -- lifecycle
    status STRING,               -- DISCOVERED / STARTED / SUCCESS / FAILED
    discovered_at TIMESTAMP,
    started_at TIMESTAMP,
    completed_at TIMESTAMP,

    -- failure and retry history
    error_message STRING,        -- why a FAILED batch failed; null otherwise
    supersedes_batch_id STRING,  -- the failed attempt this batch retries; null for a first attempt

    -- evidence
    row_count BIGINT,
    file_size BIGINT,
    file_modified_time TIMESTAMP
)
USING DELTA;


-- ------------------------------------------------------------
-- One row per pipeline run. Exists so every DQ result has a run_id
-- and a code_revision to trace back to (validation.md lineage rule,
-- evidence/README.md code-revision rule). Minimal on purpose: this
-- un-defers only the part of D14's pipeline_runs that the gates need.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `ftw-week-08`.`01-control`.pipeline_runs (
    run_id STRING NOT NULL,
    code_revision STRING,        -- git SHA or tag of the code that ran
    triggered_by STRING,         -- job name, user, or 'manual'
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    status STRING                -- STARTED / SUCCESS / FAILED
)
USING DELTA;


-- ------------------------------------------------------------
-- One row per check per run, for every gate in every layer (D17).
-- Column set follows the shared result contract in docs/validation.md.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `ftw-week-08`.`01-control`.data_quality_results (
    run_id STRING NOT NULL,
    executed_at TIMESTAMP,

    -- what was checked
    layer STRING,                -- control / bronze / silver / integration / gold / analytics
    dataset STRING,              -- e.g. 'green_taxi', 'weather_hourly', 'ingestion_batches'
    check_name STRING,
    check_type STRING,           -- e.g. uniqueness / completeness / reconciliation / lifecycle

    -- outcome
    severity STRING,             -- INFO / WARN / FAIL  (how bad a failure would be)
    status STRING,               -- INFO / PASS / WARN / FAIL  (what actually happened)
    fail_count BIGINT,
    total_count BIGINT,
    fail_pct DOUBLE,             -- percentage, 0-100
    threshold_pct DOUBLE,        -- percentage, 0-100; documented tolerance, not tuned to today's data

    -- lineage
    batch_id STRING,
    source_version_id STRING,
    code_revision STRING,

    -- follow-up
    owner STRING,
    evidence_location STRING,
    details STRING               -- short human-readable note; keep large output in R2
)
USING DELTA;


-- ------------------------------------------------------------
-- The shared status rule from docs/validation.md, defined once so six
-- gates stop re-implementing the same CASE expression differently.
--
-- Deliberately NOT handling empty inputs: a check whose input has zero
-- rows reports fail_count = 0 and would land on PASS here. Per the
-- contract ("an empty dataset never passes silently"), each gate must
-- carry its own explicit row-count check — see check 1 in
-- 90_validate_control.sql.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION `ftw-week-08`.`01-control`.dq_status(
    severity STRING,
    fail_count BIGINT,
    fail_pct DOUBLE,
    threshold_pct DOUBLE
)
RETURNS STRING
COMMENT 'Shared gate status rule (docs/validation.md). Order of evaluation is significant.'
RETURN
    CASE
        WHEN severity = 'INFO'                                    THEN 'INFO'
        WHEN fail_count = 0                                       THEN 'PASS'
        WHEN severity = 'FAIL'                                    THEN 'FAIL'
        WHEN severity = 'WARN'
             AND COALESCE(fail_pct, 0) > COALESCE(threshold_pct, 0) THEN 'FAIL'
        ELSE 'WARN'
    END;