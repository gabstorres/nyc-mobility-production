-- ============================================================
-- 00 Bronze setup: table definitions for every Bronze source.
-- Run before the 10/20/30 load tasks. Safe to rerun.
-- ============================================================

-- Green Taxi (loaded by 10_load_green_taxi.py)
CREATE TABLE IF NOT EXISTS `ftw-week-08`.`02-bronze`.green_taxi_raw (
    VendorID INT,
    lpep_pickup_datetime TIMESTAMP_NTZ,
    lpep_dropoff_datetime TIMESTAMP_NTZ,
    store_and_fwd_flag STRING,
    RatecodeID BIGINT,
    PULocationID INT,
    DOLocationID INT,
    passenger_count BIGINT,
    trip_distance DOUBLE,
    fare_amount DOUBLE,
    extra DOUBLE,
    mta_tax DOUBLE,
    tip_amount DOUBLE,
    tolls_amount DOUBLE,
    ehail_fee DOUBLE,
    improvement_surcharge DOUBLE,
    total_amount DOUBLE,
    payment_type BIGINT,
    trip_type BIGINT,
    congestion_surcharge DOUBLE,
    cbd_congestion_fee DOUBLE,

    -- provenance columns, per this issue's acceptance evidence
    source_system STRING,
    source_file STRING,
    ingested_at TIMESTAMP,
    batch_id STRING
)
USING DELTA;


-- Open-Meteo weather (loaded by 20_load_open_meteo.sql)
-- Bronze preserves the response structure: one row per API response, arrays intact.
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


-- Taxi Zones (fully refreshed by 30_load_taxi_zones.sql)
CREATE TABLE IF NOT EXISTS `ftw-week-08`.`02-bronze`.taxi_zones_raw (
    location_id INT,
    borough STRING,
    zone STRING,
    service_zone STRING,
    source_file STRING,
    source_file_version STRING,
    batch_id STRING,
    ingested_at TIMESTAMP
);
