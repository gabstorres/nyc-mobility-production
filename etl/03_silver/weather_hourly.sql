-- Silver landing + transform for hourly weather (issue #28). CREATE TABLE +
-- MERGE combined into one file to match Bronze's style (departs from
-- sql/README.md's 00/10 split; 90_validate.sql stays separate per that
-- doc's validation rule).
--
-- Explodes Bronze's response-grain hourly arrays into one row per hour,
-- converts UTC -> America/New_York (DST-aware, decision D09), and maps
-- weather_code to source_to_target_mapping.md's WMO category list.
--
-- Excluded on purpose: weather_classification_key / observation_date_key /
-- observation_hour_key (Gold-layer, depend on dimension tables not built
-- yet) and requested_timezone (mapping doc expects it, but Bronze doesn't
-- capture that config value yet -- flagged, not fabricated).
CREATE TABLE IF NOT EXISTS `ftw-week-08`.`03-silver`.weather_hourly (
    weather_observation_key STRING, -- hash of the business key below

    -- Business key
    coordinate_id               STRING,
    observation_timestamp_utc   TIMESTAMP,
    weather_model                STRING,

    -- DST-aware local conversion (D09)
    observation_timestamp_local TIMESTAMP,
    observation_date_local       DATE,
    observation_hour_local       INT,

    -- Measures (mapping-doc DECIMAL precisions)
    temperature_2m_c   DECIMAL(8,3),
    precipitation_mm    DECIMAL(10,3),
    weather_code         INT,
    weather_condition_category STRING, -- readable WMO category; code kept for audit

    -- Response metadata
    returned_latitude    DECIMAL(9,6),
    returned_longitude   DECIMAL(9,6),
    elevation_m          DECIMAL(10,3),

    -- Injected request config
    requested_latitude   DECIMAL(9,6),
    requested_longitude  DECIMAL(9,6),

    -- Lineage / provenance
    source_system              STRING,
    source_file                 STRING,
    source_url                  STRING,
    source_response_version     STRING,
    run_id                       STRING,
    batch_id                     STRING,
    ingested_at                  TIMESTAMP,
    silver_processed_at         TIMESTAMP
);

-- Everything above is DDL (run once); everything below runs on every batch.

-- Explodes the four hourly arrays by position (arrays_zip + explode),
-- converts to America/New_York, and maps weather_code to its WMO category.
-- Trusts Bronze's own ingestion gate for array alignment/non-emptiness.
-- Insert-only, mirroring Bronze's MERGE stance (no revision policy yet).
MERGE INTO `ftw-week-08`.`03-silver`.weather_hourly AS target
USING (
    SELECT
        sha2(to_json(named_struct(
            'coordinate_id', b.coordinate_id,
            'observation_timestamp_utc', to_timestamp(hourly_row.hourly_time),
            'weather_model', b.weather_model
        )), 256) AS weather_observation_key,

        b.coordinate_id,
        to_timestamp(hourly_row.hourly_time) AS observation_timestamp_utc,
        b.weather_model,

        from_utc_timestamp(to_timestamp(hourly_row.hourly_time), 'America/New_York') AS observation_timestamp_local,
        CAST(from_utc_timestamp(to_timestamp(hourly_row.hourly_time), 'America/New_York') AS DATE) AS observation_date_local,
        HOUR(from_utc_timestamp(to_timestamp(hourly_row.hourly_time), 'America/New_York')) AS observation_hour_local,

        CAST(hourly_row.hourly_temperature_2m AS DECIMAL(8,3)) AS temperature_2m_c,
        CAST(hourly_row.hourly_precipitation AS DECIMAL(10,3)) AS precipitation_mm,
        CAST(hourly_row.hourly_weather_code AS INT) AS weather_code,

        -- WMO grouping per source_to_target_mapping.md; unmapped codes fall
        -- through to 'unknown_code' (see 90_validate.sql check 4b).
        CASE
            WHEN hourly_row.hourly_weather_code IS NULL THEN NULL
            WHEN hourly_row.hourly_weather_code = 0  THEN 'clear_sky'
            WHEN hourly_row.hourly_weather_code = 1  THEN 'mainly_clear'
            WHEN hourly_row.hourly_weather_code = 2  THEN 'partly_cloudy'
            WHEN hourly_row.hourly_weather_code = 3  THEN 'overcast'
            WHEN hourly_row.hourly_weather_code IN (45, 48) THEN 'fog'
            WHEN hourly_row.hourly_weather_code IN (51, 53, 55) THEN 'drizzle'
            WHEN hourly_row.hourly_weather_code IN (56, 57) THEN 'freezing_drizzle'
            WHEN hourly_row.hourly_weather_code IN (61, 63, 65) THEN 'rain'
            WHEN hourly_row.hourly_weather_code IN (66, 67) THEN 'freezing_rain'
            WHEN hourly_row.hourly_weather_code IN (71, 73, 75) THEN 'snow'
            WHEN hourly_row.hourly_weather_code = 77 THEN 'snow_grains'
            WHEN hourly_row.hourly_weather_code IN (80, 81, 82) THEN 'rain_showers'
            WHEN hourly_row.hourly_weather_code IN (85, 86) THEN 'snow_showers'
            WHEN hourly_row.hourly_weather_code = 95 THEN 'thunderstorm'
            WHEN hourly_row.hourly_weather_code IN (96, 99) THEN 'thunderstorm_with_hail'
            ELSE 'unknown_code'
        END AS weather_condition_category,

        CAST(b.returned_latitude AS DECIMAL(9,6)) AS returned_latitude,
        CAST(b.returned_longitude AS DECIMAL(9,6)) AS returned_longitude,
        CAST(b.elevation_m AS DECIMAL(10,3)) AS elevation_m,

        CAST(b.requested_latitude AS DECIMAL(9,6)) AS requested_latitude,
        CAST(b.requested_longitude AS DECIMAL(9,6)) AS requested_longitude,

        b.source_system,
        b.source_file,
        b.source_url,
        b.source_response_version,
        b.run_id,
        b.batch_id,
        b.ingested_at,
        current_timestamp() AS silver_processed_at
    FROM `ftw-week-08`.`02-bronze`.open_meteo_weather_raw AS b
    LATERAL VIEW explode(
        arrays_zip(b.hourly_time, b.hourly_temperature_2m, b.hourly_precipitation, b.hourly_weather_code)
    ) exploded_table AS hourly_row
) AS source
ON target.weather_observation_key = source.weather_observation_key
WHEN NOT MATCHED THEN INSERT (
    weather_observation_key, coordinate_id, observation_timestamp_utc, weather_model,
    observation_timestamp_local, observation_date_local, observation_hour_local,
    temperature_2m_c, precipitation_mm, weather_code, weather_condition_category,
    returned_latitude, returned_longitude, elevation_m,
    requested_latitude, requested_longitude,
    source_system, source_file, source_url, source_response_version,
    run_id, batch_id, ingested_at, silver_processed_at
) VALUES (
    source.weather_observation_key, source.coordinate_id, source.observation_timestamp_utc, source.weather_model,
    source.observation_timestamp_local, source.observation_date_local, source.observation_hour_local,
    source.temperature_2m_c, source.precipitation_mm, source.weather_code, source.weather_condition_category,
    source.returned_latitude, source.returned_longitude, source.elevation_m,
    source.requested_latitude, source.requested_longitude,
    source.source_system, source.source_file, source.source_url, source.source_response_version,
    source.run_id, source.batch_id, source.ingested_at, source.silver_processed_at
);