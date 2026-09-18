-- ============================================================
-- Gold: fact_weather_hourly  (issue #38)
--
-- Stage:      05 Gold
-- Runs after: Silver weather gate, dim_date, dim_hour, dim_weather_classification
-- Target:     `ftw-week-08`.`05-gold`.fact_weather_hourly
-- Grain:      one row per coordinate, UTC observation hour and weather model
-- Contract:   docs/data_dictionary.md (fact_weather_hourly), docs/data_model.md
-- Owner:      Ina
--
-- Keys
--   weather_observation_key     reused from Silver, where it is a SHA-256 of
--                               coordinate_id + observation_timestamp_utc +
--                               weather_model, so Silver and Gold can never
--                               disagree about the same observation
--   observation_date_key        YYYYMMDD of the DST-aware local date
--   observation_hour_key        local hour, 0-23
--   weather_classification_key  from dim_weather_classification, matched on
--                               (weather_code, precipitation_band); the band is
--                               derived here with the D12 rules
--
-- Measures stay here: temperature_2m_c and precipitation_mm are never copied
-- onto trip rows (D12), so trip counts can never multiply a temperature.
--
-- Not populated: requested_timezone. The data dictionary lists it, but neither
-- Bronze nor Silver captures the request's timezone parameter today. Recorded
-- as a gap in decisions.md D18 rather than filled with a guess.
--
-- Rerun behaviour: MERGE on weather_observation_key. A repeated response is a
-- no-op for business content; a revised response updates the measures and
-- lineage of the same natural key. gold_processed_at is the only value expected
-- to change on a replay.
-- ============================================================

CREATE TABLE IF NOT EXISTS `ftw-week-08`.`05-gold`.fact_weather_hourly (
    weather_observation_key STRING NOT NULL,

    coordinate_id STRING,
    observation_timestamp_utc TIMESTAMP,
    weather_model STRING,
    observation_timestamp_local TIMESTAMP,

    observation_date_key INT,
    observation_hour_key INT,
    weather_classification_key STRING,

    weather_code INT,
    temperature_2m_c DECIMAL(8,3),
    precipitation_mm DECIMAL(10,3),

    requested_latitude DECIMAL(9,6),
    requested_longitude DECIMAL(9,6),
    returned_latitude DECIMAL(9,6),
    returned_longitude DECIMAL(9,6),
    elevation_m DECIMAL(10,3),

    source_system STRING,
    source_url STRING,
    source_response_version STRING,
    batch_id STRING,
    run_id STRING,
    ingested_at TIMESTAMP,
    gold_processed_at TIMESTAMP
)
USING DELTA;


-- Precipitation bands are the D12 rules, derived only to find the classification
-- row. The band itself is not stored: dim_weather_classification owns it.
CREATE OR REPLACE TEMP VIEW gold_weather_banded AS
SELECT
    s.*,
    CASE
        WHEN s.precipitation_mm IS NULL THEN NULL
        WHEN s.precipitation_mm = 0 THEN 'dry'
        WHEN s.precipitation_mm <= 2.5 THEN 'light'
        WHEN s.precipitation_mm <= 7.5 THEN 'moderate'
        ELSE 'heavy'
    END AS precipitation_band
FROM `ftw-week-08`.`03-silver`.weather_hourly s;


-- LEFT JOIN, so a missing classification row shows up as a null key that the
-- Gold gate reports, instead of dropping an observation.
CREATE OR REPLACE TEMP VIEW gold_weather_resolved AS
SELECT
    w.weather_observation_key,
    w.coordinate_id,
    w.observation_timestamp_utc,
    w.weather_model,
    w.observation_timestamp_local,

    CAST(date_format(w.observation_date_local, 'yyyyMMdd') AS INT) AS observation_date_key,
    w.observation_hour_local AS observation_hour_key,
    c.weather_classification_key,

    w.weather_code,
    w.temperature_2m_c,
    w.precipitation_mm,

    w.requested_latitude,
    w.requested_longitude,
    w.returned_latitude,
    w.returned_longitude,
    w.elevation_m,

    w.source_system,
    w.source_url,
    w.source_response_version,
    w.batch_id,
    w.run_id,
    w.ingested_at,
    current_timestamp() AS gold_processed_at
FROM gold_weather_banded w
LEFT JOIN `ftw-week-08`.`05-gold`.dim_weather_classification c
    ON w.weather_code = c.weather_code
   AND w.precipitation_band <=> c.precipitation_band;


-- Guard: dim_weather_classification must be unique on
-- (weather_code, precipitation_band), or one observation would fan out into
-- several fact rows. Stop before writing.
SELECT CASE
         WHEN (SELECT COUNT(*) FROM gold_weather_resolved)
              > (SELECT COUNT(*) FROM `ftw-week-08`.`03-silver`.weather_hourly)
         THEN raise_error('fact_weather_hourly: dim_weather_classification is not unique on (weather_code, precipitation_band)')
       END;


MERGE INTO `ftw-week-08`.`05-gold`.fact_weather_hourly AS target
USING gold_weather_resolved AS source
ON target.weather_observation_key = source.weather_observation_key
WHEN MATCHED THEN UPDATE SET *
WHEN NOT MATCHED THEN INSERT *
WHEN NOT MATCHED BY SOURCE THEN DELETE;


-- Counts for the run log. Blocking checks live in 90_validate_gold.sql.
SELECT
    (SELECT COUNT(*) FROM `ftw-week-08`.`03-silver`.weather_hourly) AS silver_rows,
    (SELECT COUNT(*) FROM `ftw-week-08`.`05-gold`.fact_weather_hourly) AS gold_rows,
    (SELECT COUNT_IF(weather_classification_key IS NULL)
     FROM `ftw-week-08`.`05-gold`.fact_weather_hourly) AS unclassified_rows;
