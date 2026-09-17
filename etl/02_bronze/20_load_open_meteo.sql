-- Bronze landing for the Open-Meteo historical weather source.
-- Bronze preserves the response structure: one row per API response, arrays intact.

-- Table definition lives here so this file runs on its own. Safe to rerun.
CREATE TABLE IF NOT EXISTS `ftw-week-08`.`02-bronze`.open_meteo_weather_raw (
    coordinate_id STRING,
    requested_latitude DOUBLE,
    requested_longitude DOUBLE,
    requested_start_date STRING,
    requested_end_date STRING,
    weather_model STRING,
    returned_latitude DOUBLE,
    returned_longitude DOUBLE,
    elevation_m DOUBLE,
    utc_offset_seconds INT,
    timezone STRING,
    timezone_abbreviation STRING,
    generationtime_ms DOUBLE,
    -- Hourly arrays (preserved from API response)
    hourly_time ARRAY<STRING>,
    hourly_temperature_2m ARRAY<DOUBLE>,
    hourly_precipitation ARRAY<DOUBLE>,
    hourly_weather_code ARRAY<LONG>,
    -- Hourly units metadata
    hourly_units_time STRING,
    hourly_units_temperature_2m STRING,
    hourly_units_precipitation STRING,
    hourly_units_weather_code STRING,
    -- Provenance
    source_system STRING,
    source_url STRING,
    source_file STRING,
    content_sha256 STRING,
    source_response_version STRING,
    run_id STRING,
    batch_id STRING,
    ingested_at TIMESTAMP
);

-- ---------------------------------------------------------------------
-- REQUEST / INJECTED CONFIG -- declared once, referenced everywhere below.
-- These are the "Weather config" values from source_to_target_mapping.md
-- (rows 59-63): coordinate_id, requested_latitude/longitude,
-- requested_start_date/end_date, weather_model. Previously these were
-- repeated as separate literals in the SELECT list (and weather_model was
-- wrapped in a COALESCE('era5', 'api_default_unpinned') that could never
-- actually produce 'api_default_unpinned', since its first argument was
-- itself a non-null literal -- COALESCE only helps if the left side can
-- genuinely be NULL). Declaring these as variables makes that fallback
-- real: set requested_weather_model to NULL (or leave the SET out) to
-- represent an actual unpinned run, and the MERGE below will correctly
-- record 'api_default_unpinned' instead of silently claiming a model that
-- was never requested.
-- ---------------------------------------------------------------------
DECLARE OR REPLACE VARIABLE weather_raw_file_path STRING;
SET VARIABLE weather_raw_file_path =
    '/Volumes/ftw-week-08/00-source/group_a_source/weather/open_meteo_mar_may_2026.json';

DECLARE OR REPLACE VARIABLE weather_coordinate_id STRING;
SET VARIABLE weather_coordinate_id = 'nyc_approved_point';

DECLARE OR REPLACE VARIABLE weather_requested_latitude DOUBLE;
SET VARIABLE weather_requested_latitude = CAST(40.7128 AS DOUBLE);

DECLARE OR REPLACE VARIABLE weather_requested_longitude DOUBLE;
SET VARIABLE weather_requested_longitude = CAST(-74.0060 AS DOUBLE);

DECLARE OR REPLACE VARIABLE weather_requested_start_date STRING;
SET VARIABLE weather_requested_start_date = '2026-03-01';

DECLARE OR REPLACE VARIABLE weather_requested_end_date STRING;
SET VARIABLE weather_requested_end_date = '2026-05-31';

-- Set to NULL (or omit the SET) for an unpinned request
DECLARE OR REPLACE VARIABLE requested_weather_model STRING;
SET VARIABLE requested_weather_model = 'era5';

-- INCREMENTAL / IDEMPOTENT MERGE
-- Business key: (coordinate_id, requested_start_date, requested_end_date, weather_model)
-- Bronze preserves response-grain (one row per API response with arrays intact).
MERGE INTO `ftw-week-08`.`02-bronze`.open_meteo_weather_raw AS target
USING (
    SELECT
        weather_coordinate_id AS coordinate_id,
        weather_requested_latitude AS requested_latitude,
        weather_requested_longitude AS requested_longitude,
        weather_requested_start_date AS requested_start_date,
        weather_requested_end_date AS requested_end_date,
        COALESCE(requested_weather_model, 'api_default_unpinned') AS weather_model,
        latitude AS returned_latitude,
        longitude AS returned_longitude,
        elevation AS elevation_m,
        CAST(utc_offset_seconds AS INT) AS utc_offset_seconds,
        timezone,
        timezone_abbreviation,
        generationtime_ms,
        -- Preserve hourly arrays from API response
        hourly.time AS hourly_time,
        hourly.temperature_2m AS hourly_temperature_2m,
        hourly.precipitation AS hourly_precipitation,
        hourly.weather_code AS hourly_weather_code,
        -- Capture hourly_units metadata
        hourly_units.time AS hourly_units_time,
        hourly_units.temperature_2m AS hourly_units_temperature_2m,
        hourly_units.precipitation AS hourly_units_precipitation,
        hourly_units.weather_code AS hourly_units_weather_code,
        -- Provenance
        'open_meteo_archive' AS source_system,
        'https://archive-api.open-meteo.com/v1/archive' AS source_url,
        weather_raw_file_path AS source_file,
        -- Immutable file identity: hash of the entire landed payload,
        -- including generationtime_ms. This is deliberately different
        -- from source_response_version below.
        sha2(to_json(struct(*)), 256) AS content_sha256,
        -- Normalized content identity: everything that describes the
        -- actual weather content and its request/response context,
        -- EXCLUDING only generationtime_ms (the one field documented to
        -- vary across otherwise-identical requests). Previously this
        -- only hashed latitude/longitude/elevation/hourly, so a change in
        -- utc_offset_seconds, timezone, timezone_abbreviation, or
        -- hourly_units (e.g. a units drift) would not have moved this
        -- hash at all -- exactly the kind of silent content change this
        -- field exists to catch.
        sha2(to_json(named_struct(
            'latitude', latitude,
            'longitude', longitude,
            'elevation', elevation,
            'utc_offset_seconds', utc_offset_seconds,
            'timezone', timezone,
            'timezone_abbreviation', timezone_abbreviation,
            'hourly_units', hourly_units,
            'hourly', hourly
        )), 256) AS source_response_version,
        uuid() AS run_id,
        format_string('%s', date_format(current_date(), 'yyyyMMdd')) AS batch_id,
        current_timestamp() AS ingested_at
    FROM read_files(
        '/Volumes/ftw-week-08/00-source/group_a_source/weather/open_meteo_mar_may_2026.json',
        format => 'json',
        multiLine => true
    )
) AS source
ON target.coordinate_id = source.coordinate_id
   AND target.requested_start_date = source.requested_start_date
   AND target.requested_end_date = source.requested_end_date
   AND target.weather_model = source.weather_model
WHEN NOT MATCHED THEN
    INSERT (
        coordinate_id,
        requested_latitude,
        requested_longitude,
        requested_start_date,
        requested_end_date,
        weather_model,
        returned_latitude,
        returned_longitude,
        elevation_m,
        utc_offset_seconds,
        timezone,
        timezone_abbreviation,
        generationtime_ms,
        hourly_time,
        hourly_temperature_2m,
        hourly_precipitation,
        hourly_weather_code,
        hourly_units_time,
        hourly_units_temperature_2m,
        hourly_units_precipitation,
        hourly_units_weather_code,
        source_system,
        source_url,
        source_file,
        content_sha256,
        source_response_version,
        run_id,
        batch_id,
        ingested_at
    )
    VALUES (
        source.coordinate_id,
        source.requested_latitude,
        source.requested_longitude,
        source.requested_start_date,
        source.requested_end_date,
        source.weather_model,
        source.returned_latitude,
        source.returned_longitude,
        source.elevation_m,
        source.utc_offset_seconds,
        source.timezone,
        source.timezone_abbreviation,
        source.generationtime_ms,
        source.hourly_time,
        source.hourly_temperature_2m,
        source.hourly_precipitation,
        source.hourly_weather_code,
        source.hourly_units_time,
        source.hourly_units_temperature_2m,
        source.hourly_units_precipitation,
        source.hourly_units_weather_code,
        source.source_system,
        source.source_url,
        source.source_file,
        source.content_sha256,
        source.source_response_version,
        source.run_id,
        source.batch_id,
        source.ingested_at
    );

-- Row-count sanity check: Bronze should have 1 response-grain row per landed API response.
-- For the initial historical load, expect 1 row (one response covering Mar-May 2026).
SELECT COUNT(*) AS response_count FROM `ftw-week-08`.`02-bronze`.open_meteo_weather_raw
WHERE batch_id = date_format(current_date(), 'yyyyMMdd');