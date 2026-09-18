-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Open-Meteo Bronze Data Quality Validation
-- MAGIC
-- MAGIC Validate the Open-Meteo Bronze dataset for structural integrity, metadata completeness, hourly array alignment, observation-level quality, provenance, and source-to-Bronze consistency before Silver transformation.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Validation Approach
-- MAGIC
-- MAGIC Validation is performed in two stages:
-- MAGIC
-- MAGIC 1. **Bronze-level validation** checks the raw API response, metadata, provenance, and hourly arrays.
-- MAGIC 2. **Observation-level validation** temporarily flattens the hourly arrays for timestamp, weather measurement, domain, duplicate, and continuity checks.
-- MAGIC
-- MAGIC The Bronze table is not modified during validation. DQ results are written to the dedicated Open-Meteo validation table.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Dataset and Source Context
-- MAGIC
-- MAGIC **Source:** Open-Meteo Historical Weather API  
-- MAGIC **Endpoint:** `https://archive-api.open-meteo.com/v1/archive`  
-- MAGIC **Requested period:** 2026-03-01 to 2026-05-31  
-- MAGIC **Requested coordinates:** 40.7128, -74.0060  
-- MAGIC **Timezone:** UTC  
-- MAGIC **Hourly variables:** temperature_2m, precipitation, weather_code  
-- MAGIC **Expected observations:** 2,208 hourly records

-- COMMAND ----------

-- Profile the current Bronze table

SELECT
    COUNT(*) AS bronze_row_count,
    MIN(ingested_at) AS first_ingested_at,
    MAX(ingested_at) AS last_ingested_at,
    MAX(batch_id) AS batch_id,
    MAX(source_response_version) AS source_response_version
FROM `ftw-week-08`.`02-bronze`.open_meteo_weather_raw;

-- COMMAND ----------

-- Inspect the current Open-Meteo Bronze response

SELECT
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
FROM `ftw-week-08`.`02-bronze`.open_meteo_weather_raw;

-- COMMAND ----------

CREATE TABLE IF NOT EXISTS `ftw-week-08`.`01-control`.open_meteo_weather_data_quality_results (
    run_id STRING,
    executed_at TIMESTAMP,
    layer STRING,
    dataset STRING,
    batch_id STRING,
    source_version_id STRING,
    code_revision STRING,
    check_name STRING,
    check_type STRING,
    status STRING,
    severity STRING,
    fail_count BIGINT,
    total_count BIGINT,
    fail_pct DOUBLE,
    threshold_pct DOUBLE,
    metric_value DOUBLE,
    owner STRING,
    details STRING,
    evidence_location STRING
);

-- COMMAND ----------

-- DQ results are persisted; do not truncate previous validation runs.

-- COMMAND ----------

-- Create one stable DQ run for the entire validation execution

CREATE OR REPLACE TEMP TABLE open_meteo_dq_run AS
SELECT
    uuid() AS run_id,
    current_timestamp() AS executed_at;

-- COMMAND ----------

SELECT *
FROM open_meteo_dq_run;

-- COMMAND ----------

-- Run Bronze-level structural and metadata checks

WITH bronze AS (
    SELECT *
    FROM `ftw-week-08`.`02-bronze`.open_meteo_weather_raw
),

response_key_counts AS (
    SELECT
        coordinate_id,
        requested_start_date,
        requested_end_date,
        weather_model,
        COUNT(*) AS row_count
    FROM bronze
    GROUP BY
        coordinate_id,
        requested_start_date,
        requested_end_date,
        weather_model
),

duplicate_response_keys AS (
    SELECT
        COALESCE(
            SUM(CASE WHEN row_count > 1 THEN row_count ELSE 0 END),
            0
        ) AS duplicate_response_rows
    FROM response_key_counts
),

profile AS (
    SELECT
        COUNT(*) AS total_count,

        SUM(
            CASE
                WHEN requested_latitude IS NULL
                  OR requested_latitude NOT BETWEEN -90 AND 90
                THEN 1 ELSE 0
            END
        ) AS invalid_latitude,

        SUM(
            CASE
                WHEN requested_longitude IS NULL
                  OR requested_longitude NOT BETWEEN -180 AND 180
                THEN 1 ELSE 0
            END
        ) AS invalid_longitude,

        SUM(
            CASE
                WHEN requested_start_date IS NULL
                  OR requested_end_date IS NULL
                THEN 1 ELSE 0
            END
        ) AS missing_dates,

        SUM(
            CASE
                WHEN weather_model IS NULL
                  OR TRIM(weather_model) = ''
                THEN 1 ELSE 0
            END
        ) AS missing_weather_model,

        SUM(
            CASE
                WHEN hourly_time IS NULL
                  OR hourly_temperature_2m IS NULL
                  OR hourly_precipitation IS NULL
                  OR hourly_weather_code IS NULL
                THEN 1 ELSE 0
            END
        ) AS missing_arrays,

        SUM(
            CASE
                WHEN hourly_time IS NULL
                  OR hourly_temperature_2m IS NULL
                  OR hourly_precipitation IS NULL
                  OR hourly_weather_code IS NULL
                  OR size(hourly_time) <> size(hourly_temperature_2m)
                  OR size(hourly_time) <> size(hourly_precipitation)
                  OR size(hourly_time) <> size(hourly_weather_code)
                THEN 1 ELSE 0
            END
        ) AS misaligned_arrays,

        SUM(
            CASE
                WHEN requested_start_date IS NULL
                  OR requested_end_date IS NULL
                THEN 0
                WHEN hourly_time IS NULL
                THEN 1
                WHEN size(hourly_time) <>
                     datediff(
                         date_add(to_date(requested_end_date), 1),
                         to_date(requested_start_date)
                     ) * 24
                THEN 1
                ELSE 0
            END
        ) AS unexpected_hourly_volume,

        SUM(
            CASE
                WHEN source_system IS NULL
                  OR source_url IS NULL
                  OR source_file IS NULL
                  OR content_sha256 IS NULL
                  OR batch_id IS NULL
                  OR run_id IS NULL
                  OR ingested_at IS NULL
                THEN 1 ELSE 0
            END
        ) AS missing_provenance

    FROM bronze
),

checks AS (
    SELECT
        'bronze_row_count' AS check_name,
        'STRUCTURAL' AS check_type,
        CAST(CASE WHEN total_count >= 1 THEN 0 ELSE 1 END AS BIGINT) AS fail_count,
        'FAIL' AS severity,
        'Bronze should contain at least one Open-Meteo API response.' AS details
    FROM profile

    UNION ALL

    SELECT
        'bronze_response_key_unique',
        'STRUCTURAL',
        CAST(duplicate_response_rows AS BIGINT),
        'FAIL',
        'The combination of coordinate_id, requested_start_date, requested_end_date, and weather_model must be unique.'
    FROM duplicate_response_keys

    UNION ALL

    SELECT
        'requested_latitude',
        'DOMAIN',
        CAST(invalid_latitude AS BIGINT),
        'FAIL',
        'Requested latitude must be between -90 and 90.'
    FROM profile

    UNION ALL

    SELECT
        'requested_longitude',
        'DOMAIN',
        CAST(invalid_longitude AS BIGINT),
        'FAIL',
        'Requested longitude must be between -180 and 180.'
    FROM profile

    UNION ALL

    SELECT
        'requested_dates',
        'COMPLETENESS',
        CAST(missing_dates AS BIGINT),
        'FAIL',
        'Requested start and end dates must be populated.'
    FROM profile

    UNION ALL

    SELECT
        'weather_model_not_null',
        'COMPLETENESS',
        CAST(missing_weather_model AS BIGINT),
        'WARN',
        'Weather model should be populated; model pinning is a downstream decision.'
    FROM profile

    UNION ALL

    SELECT
        'hourly_arrays_not_null',
        'COMPLETENESS',
        CAST(missing_arrays AS BIGINT),
        'FAIL',
        'All hourly arrays must be populated.'
    FROM profile

    UNION ALL

    SELECT
        'hourly_array_alignment',
        'STRUCTURAL',
        CAST(misaligned_arrays AS BIGINT),
        'FAIL',
        'Hourly arrays must have matching lengths.'
    FROM profile

    UNION ALL

    SELECT
        'hourly_volume',
        'MEASUREMENT',
        CAST(unexpected_hourly_volume AS BIGINT),
        'FAIL',
        'The number of hourly observations must match the requested date range.'
    FROM profile
)

INSERT INTO `ftw-week-08`.`01-control`.open_meteo_weather_data_quality_results
SELECT
    r.run_id,
    r.executed_at,
    'Bronze',
    'open_meteo_weather',
    NULL,
    NULL,
    NULL,
    c.check_name,
    c.check_type,
    CASE
        WHEN c.fail_count = 0 THEN 'PASS'
        ELSE c.severity
    END AS status,
    c.severity,
    c.fail_count,
    p.total_count,
    CASE
        WHEN p.total_count = 0 THEN 100.0
        ELSE c.fail_count / p.total_count * 100.0
    END AS fail_pct,
    0.0,
    CAST(c.fail_count AS DOUBLE),
    'Data Engineering',
    c.details,
    NULL
FROM checks c
CROSS JOIN profile p
CROSS JOIN open_meteo_dq_run r;

-- COMMAND ----------

-- Flatten aligned hourly arrays for observation-level validation

CREATE OR REPLACE TEMP VIEW open_meteo_observations AS

SELECT
    t.coordinate_id,
    t.batch_id,
    t.source_response_version,
    p.pos,
    CAST(t.hourly_time[p.pos] AS TIMESTAMP) AS observation_timestamp,
    t.hourly_temperature_2m[p.pos] AS temperature_2m,
    t.hourly_precipitation[p.pos] AS precipitation,
    t.hourly_weather_code[p.pos] AS weather_code

FROM `ftw-week-08`.`02-bronze`.open_meteo_weather_raw t

LATERAL VIEW posexplode(t.hourly_time) p AS pos, hourly_timestamp;

-- COMMAND ----------

-- Run observation-level quality checks

WITH ordered AS (
    SELECT
        o.*,
        b.requested_start_date,
        b.requested_end_date,
        LAG(o.observation_timestamp) OVER (
            PARTITION BY o.coordinate_id, o.source_response_version
            ORDER BY o.pos
        ) AS previous_timestamp
    FROM open_meteo_observations o
    LEFT JOIN `ftw-week-08`.`02-bronze`.open_meteo_weather_raw b
        ON o.coordinate_id = b.coordinate_id
        AND o.source_response_version = b.source_response_version
),

profile AS (
    SELECT
        COUNT(*) AS total_count,

        SUM(CASE WHEN observation_timestamp IS NULL THEN 1 ELSE 0 END) AS timestamp_nulls,

        SUM(CASE WHEN temperature_2m IS NULL THEN 1 ELSE 0 END) AS temperature_nulls,

        SUM(CASE WHEN precipitation IS NULL THEN 1 ELSE 0 END) AS precipitation_nulls,

        SUM(CASE WHEN weather_code IS NULL THEN 1 ELSE 0 END) AS weather_code_nulls,

        COUNT(*) - COUNT(
    DISTINCT CONCAT(
        CAST(coordinate_id AS STRING),
        '|',
        CAST(source_response_version AS STRING),
        '|',
        CAST(observation_timestamp AS STRING)
    )
) AS duplicate_timestamps,

        SUM(
            CASE
                WHEN previous_timestamp IS NOT NULL
                 AND observation_timestamp < previous_timestamp
                THEN 1 ELSE 0
            END
        ) AS chronological_errors,

        SUM(
            CASE
                WHEN temperature_2m < -50
                  OR temperature_2m > 60
                THEN 1 ELSE 0
            END
        ) AS invalid_temperature,

        SUM(
            CASE
                WHEN precipitation < 0
                THEN 1 ELSE 0
            END
        ) AS negative_precipitation,

        SUM(
            CASE
                WHEN weather_code NOT IN (
                    0,1,2,3,
                    45,48,
                    51,53,55,56,57,
                    61,63,65,66,67,
                    71,73,75,77,
                    80,81,82,
                    85,86,
                    95,96,99
                )
                THEN 1 ELSE 0
            END
        ) AS invalid_weather_code,

        SUM(
    CASE
        WHEN observation_timestamp < CAST(requested_start_date AS TIMESTAMP)
          OR observation_timestamp >= CAST(
              date_add(to_date(requested_end_date), 1) AS TIMESTAMP
          )
        THEN 1 ELSE 0
    END
) AS outside_date_window,

        SUM(
            CASE
                WHEN previous_timestamp IS NOT NULL
                 AND observation_timestamp <> previous_timestamp + INTERVAL 1 HOUR
                THEN 1 ELSE 0
            END
        ) AS timestamp_gaps

    FROM ordered
)

INSERT INTO `ftw-week-08`.`01-control`.open_meteo_weather_data_quality_results

SELECT
    r.run_id,
    r.executed_at,
    'Bronze',
    'open_meteo_weather',
    NULL,
    NULL,
    NULL,
    check_name,
    check_type,
    CASE
        WHEN fail_count = 0 THEN 'PASS'
        ELSE severity
    END,
    severity,
    fail_count,
    total_count,
    CASE
        WHEN total_count = 0 THEN 100.0
        ELSE fail_count / total_count * 100.0
    END,
    0.0,
    CAST(fail_count AS DOUBLE),
    'Data Engineering',
    details,
    NULL

FROM profile p
CROSS JOIN open_meteo_dq_run r

LATERAL VIEW STACK(
    11,

    'timestamp_not_null',
    'COMPLETENESS',
    timestamp_nulls,
    'FAIL',
    'Observation timestamps must not be null.',

    'temperature_not_null',
    'COMPLETENESS',
    temperature_nulls,
    'FAIL',
    'Temperature observations must not be null.',

    'precipitation_not_null',
    'COMPLETENESS',
    precipitation_nulls,
    'FAIL',
    'Precipitation observations must not be null.',

    'weather_code_not_null',
    'COMPLETENESS',
    weather_code_nulls,
    'FAIL',
    'Weather code observations must not be null.',

    'duplicate_timestamps',
    'UNIQUENESS',
    duplicate_timestamps,
    'FAIL',
    'Observation timestamps must be unique.',

    'timestamp_chronological_order',
    'CONSISTENCY',
    chronological_errors,
    'FAIL',
    'Observation timestamps must be chronological.',

    'temperature_range',
    'DOMAIN',
    invalid_temperature,
    'WARN',
    'Temperature values outside the defined physical plausibility range require review.',

    'precipitation_non_negative',
    'DOMAIN',
    negative_precipitation,
    'FAIL',
    'Precipitation must not be negative.',

    'weather_code_domain',
    'DOMAIN',
    invalid_weather_code,
    'FAIL',
    'Weather codes must use the valid Open-Meteo/WMO code set.',

    'observation_date_window',
    'CONSISTENCY',
    outside_date_window,
    'FAIL',
    'Observations must fall within the requested date range.',

    'hourly_continuity',
    'CONSISTENCY',
    timestamp_gaps,
    'FAIL',
    'Hourly observations should be continuous with one-hour intervals.'
) s AS check_name, check_type, fail_count, severity, details;

-- COMMAND ----------

-- Review all DQ checks for the current validation run

SELECT
    check_name,
    check_type,
    status,
    severity,
    fail_count,
    total_count,
    fail_pct,
    details
FROM `ftw-week-08`.`01-control`.open_meteo_weather_data_quality_results
WHERE run_id = (SELECT run_id FROM open_meteo_dq_run)
ORDER BY
    CASE status
        WHEN 'FAIL' THEN 1
        WHEN 'WARN' THEN 2
        WHEN 'PASS' THEN 3
        ELSE 4
    END,
    check_name;

-- COMMAND ----------

-- Summarize the current DQ run

SELECT
    status,
    COUNT(*) AS check_count
FROM `ftw-week-08`.`01-control`.open_meteo_weather_data_quality_results
WHERE run_id = (SELECT run_id FROM open_meteo_dq_run)
GROUP BY status
ORDER BY
    CASE status
        WHEN 'FAIL' THEN 1
        WHEN 'WARN' THEN 2
        WHEN 'PASS' THEN 3
        ELSE 4
    END;

-- COMMAND ----------

-- Review checks requiring attention

SELECT
    check_name,
    status,
    severity,
    fail_count,
    total_count,
    fail_pct,
    details
FROM `ftw-week-08`.`01-control`.open_meteo_weather_data_quality_results
WHERE run_id = (SELECT run_id FROM open_meteo_dq_run)
  AND status IN ('WARN', 'FAIL')
ORDER BY
    CASE status
        WHEN 'FAIL' THEN 1
        WHEN 'WARN' THEN 2
    END,
    check_name;

-- COMMAND ----------

-- Determine whether the Bronze dataset can proceed to Silver

SELECT
    CASE
        WHEN SUM(
            CASE
                WHEN status = 'FAIL'
                 AND severity = 'FAIL'
                THEN 1
                ELSE 0
            END
        ) = 0
        THEN 'READY_FOR_SILVER'
        ELSE 'BLOCKED'
    END AS final_decision,

    SUM(
        CASE
            WHEN status = 'FAIL'
             AND severity = 'FAIL'
            THEN 1
            ELSE 0
        END
    ) AS blocking_fail_count,

    SUM(
        CASE
            WHEN status = 'WARN'
            THEN 1
            ELSE 0
        END
    ) AS warn_count

FROM `ftw-week-08`.`01-control`.open_meteo_weather_data_quality_results

WHERE run_id = (SELECT run_id FROM open_meteo_dq_run);

-- COMMAND ----------

-- Reconcile expected source characteristics with Bronze

SELECT
    requested_latitude,
    requested_longitude,
    requested_start_date,
    requested_end_date,
    returned_latitude,
    returned_longitude,
    utc_offset_seconds,
    timezone,
    size(hourly_time) AS bronze_hourly_count,
    size(hourly_temperature_2m) AS bronze_temperature_count,
    size(hourly_precipitation) AS bronze_precipitation_count,
    size(hourly_weather_code) AS bronze_weather_code_count
FROM `ftw-week-08`.`02-bronze`.open_meteo_weather_raw;