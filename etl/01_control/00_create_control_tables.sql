-- ============================================================
-- 00 Control setup: operational tables in `01-control`.
-- Safe to rerun.
-- ============================================================

-- One row per external source batch or source version (D14).
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

    -- evidence
    row_count BIGINT,
    file_size BIGINT,
    file_modified_time TIMESTAMP
)
USING DELTA;
