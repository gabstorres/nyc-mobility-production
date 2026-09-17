# Databricks notebook source
# MAGIC %md
# MAGIC # Open-Meteo Bronze Data Quality Validation
# MAGIC
# MAGIC Validate the Open-Meteo Bronze dataset for structural integrity, metadata completeness, hourly array alignment, observation-level quality, provenance, and source-to-Bronze consistency before Silver transformation.

# COMMAND ----------

# MAGIC %md
# MAGIC ## Validation Approach
# MAGIC
# MAGIC Validation is performed in two stages:
# MAGIC
# MAGIC 1. **Bronze-level validation** checks the raw API response, metadata, provenance, and hourly arrays.
# MAGIC 2. **Observation-level validation** temporarily flattens the hourly arrays for timestamp, weather measurement, domain, duplicate, and continuity checks.
# MAGIC
# MAGIC The Bronze table is not modified during validation. DQ results are written to the dedicated Open-Meteo validation table.

# COMMAND ----------

# MAGIC %md
# MAGIC ## Dataset and Source Context
# MAGIC
# MAGIC **Source:** Open-Meteo Historical Weather API  
# MAGIC **Endpoint:** `https://archive-api.open-meteo.com/v1/archive`  
# MAGIC **Requested period:** 2026-03-01 to 2026-05-31  
# MAGIC **Requested coordinates:** 40.7128, -74.0060  
# MAGIC **Timezone:** UTC  
# MAGIC **Hourly variables:** temperature_2m, precipitation, weather_code  
# MAGIC **Expected observations:** 2,208 hourly records

# COMMAND ----------

# MAGIC %sql
# MAGIC -- Profile the current Bronze table
# MAGIC
# MAGIC SELECT
# MAGIC     COUNT(*) AS bronze_row_count,
# MAGIC     MIN(ingested_at) AS first_ingested_at,
# MAGIC     MAX(ingested_at) AS last_ingested_at,
# MAGIC     MAX(batch_id) AS batch_id,
# MAGIC     MAX(source_response_version) AS source_response_version
# MAGIC FROM `ftw-week-08`.`02-bronze`.open_meteo_weather_raw;

# COMMAND ----------

# MAGIC %sql
# MAGIC -- Inspect the current Open-Meteo Bronze response
# MAGIC
# MAGIC SELECT
# MAGIC     coordinate_id,
# MAGIC     requested_latitude,
# MAGIC     requested_longitude,
# MAGIC     requested_start_date,
# MAGIC     requested_end_date,
# MAGIC     weather_model,
# MAGIC     returned_latitude,
# MAGIC     returned_longitude,
# MAGIC     elevation_m,
# MAGIC     utc_offset_seconds,
# MAGIC     timezone,
# MAGIC     hourly_units_time,
# MAGIC     hourly_units_temperature_2m,
# MAGIC     hourly_units_precipitation,
# MAGIC     hourly_units_weather_code,
# MAGIC     source_system,
# MAGIC     source_url,
# MAGIC     source_file,
# MAGIC     content_sha256,
# MAGIC     source_response_version,
# MAGIC     run_id,
# MAGIC     batch_id,
# MAGIC     ingested_at
# MAGIC FROM `ftw-week-08`.`02-bronze`.open_meteo_weather_raw;

# COMMAND ----------

# MAGIC %sql
# MAGIC CREATE TABLE IF NOT EXISTS `ftw-week-08`.`01-control`.open_meteo_weather_data_quality_results (
# MAGIC     run_id STRING,
# MAGIC     executed_at TIMESTAMP,
# MAGIC     layer STRING,
# MAGIC     dataset STRING,
# MAGIC     batch_id STRING,
# MAGIC     source_version_id STRING,
# MAGIC     code_revision STRING,
# MAGIC     check_name STRING,
# MAGIC     check_type STRING,
# MAGIC     status STRING,
# MAGIC     severity STRING,
# MAGIC     fail_count BIGINT,
# MAGIC     total_count BIGINT,
# MAGIC     fail_pct DOUBLE,
# MAGIC     threshold_pct DOUBLE,
# MAGIC     metric_value DOUBLE,
# MAGIC     owner STRING,
# MAGIC     details STRING,
# MAGIC     evidence_location STRING
# MAGIC );

# COMMAND ----------

# MAGIC %sql
# MAGIC -- DQ results are persisted; do not truncate previous validation runs.

# COMMAND ----------

# MAGIC %sql
# MAGIC -- Create one stable DQ run for the entire validation execution
# MAGIC
# MAGIC CREATE OR REPLACE TEMP TABLE open_meteo_dq_run AS
# MAGIC SELECT
# MAGIC     uuid() AS run_id,
# MAGIC     current_timestamp() AS executed_at;

# COMMAND ----------

# MAGIC %sql
# MAGIC SELECT *
# MAGIC FROM open_meteo_dq_run;

# COMMAND ----------

# MAGIC %sql
# MAGIC -- Run Bronze-level structural and metadata checks
# MAGIC
# MAGIC WITH bronze AS (
# MAGIC     SELECT *
# MAGIC     FROM `ftw-week-08`.`02-bronze`.open_meteo_weather_raw
# MAGIC ),
# MAGIC
# MAGIC response_key_counts AS (
# MAGIC     SELECT
# MAGIC         coordinate_id,
# MAGIC         requested_start_date,
# MAGIC         requested_end_date,
# MAGIC         weather_model,
# MAGIC         COUNT(*) AS row_count
# MAGIC     FROM bronze
# MAGIC     GROUP BY
# MAGIC         coordinate_id,
# MAGIC         requested_start_date,
# MAGIC         requested_end_date,
# MAGIC         weather_model
# MAGIC ),
# MAGIC
# MAGIC duplicate_response_keys AS (
# MAGIC     SELECT
# MAGIC         COALESCE(
# MAGIC             SUM(CASE WHEN row_count > 1 THEN row_count ELSE 0 END),
# MAGIC             0
# MAGIC         ) AS duplicate_response_rows
# MAGIC     FROM response_key_counts
# MAGIC ),
# MAGIC
# MAGIC profile AS (
# MAGIC     SELECT
# MAGIC         COUNT(*) AS total_count,
# MAGIC
# MAGIC         SUM(
# MAGIC             CASE
# MAGIC                 WHEN requested_latitude IS NULL
# MAGIC                   OR requested_latitude NOT BETWEEN -90 AND 90
# MAGIC                 THEN 1 ELSE 0
# MAGIC             END
# MAGIC         ) AS invalid_latitude,
# MAGIC
# MAGIC         SUM(
# MAGIC             CASE
# MAGIC                 WHEN requested_longitude IS NULL
# MAGIC                   OR requested_longitude NOT BETWEEN -180 AND 180
# MAGIC                 THEN 1 ELSE 0
# MAGIC             END
# MAGIC         ) AS invalid_longitude,
# MAGIC
# MAGIC         SUM(
# MAGIC             CASE
# MAGIC                 WHEN requested_start_date IS NULL
# MAGIC                   OR requested_end_date IS NULL
# MAGIC                 THEN 1 ELSE 0
# MAGIC             END
# MAGIC         ) AS missing_dates,
# MAGIC
# MAGIC         SUM(
# MAGIC             CASE
# MAGIC                 WHEN weather_model IS NULL
# MAGIC                   OR TRIM(weather_model) = ''
# MAGIC                 THEN 1 ELSE 0
# MAGIC             END
# MAGIC         ) AS missing_weather_model,
# MAGIC
# MAGIC         SUM(
# MAGIC             CASE
# MAGIC                 WHEN hourly_time IS NULL
# MAGIC                   OR hourly_temperature_2m IS NULL
# MAGIC                   OR hourly_precipitation IS NULL
# MAGIC                   OR hourly_weather_code IS NULL
# MAGIC                 THEN 1 ELSE 0
# MAGIC             END
# MAGIC         ) AS missing_arrays,
# MAGIC
# MAGIC         SUM(
# MAGIC             CASE
# MAGIC                 WHEN hourly_time IS NULL
# MAGIC                   OR hourly_temperature_2m IS NULL
# MAGIC                   OR hourly_precipitation IS NULL
# MAGIC                   OR hourly_weather_code IS NULL
# MAGIC                   OR size(hourly_time) <> size(hourly_temperature_2m)
# MAGIC                   OR size(hourly_time) <> size(hourly_precipitation)
# MAGIC                   OR size(hourly_time) <> size(hourly_weather_code)
# MAGIC                 THEN 1 ELSE 0
# MAGIC             END
# MAGIC         ) AS misaligned_arrays,
# MAGIC
# MAGIC         SUM(
# MAGIC             CASE
# MAGIC                 WHEN requested_start_date IS NULL
# MAGIC                   OR requested_end_date IS NULL
# MAGIC                 THEN 0
# MAGIC                 WHEN hourly_time IS NULL
# MAGIC                 THEN 1
# MAGIC                 WHEN size(hourly_time) <>
# MAGIC                      datediff(
# MAGIC                          date_add(to_date(requested_end_date), 1),
# MAGIC                          to_date(requested_start_date)
# MAGIC                      ) * 24
# MAGIC                 THEN 1
# MAGIC                 ELSE 0
# MAGIC             END
# MAGIC         ) AS unexpected_hourly_volume,
# MAGIC
# MAGIC         SUM(
# MAGIC             CASE
# MAGIC                 WHEN source_system IS NULL
# MAGIC                   OR source_url IS NULL
# MAGIC                   OR source_file IS NULL
# MAGIC                   OR content_sha256 IS NULL
# MAGIC                   OR batch_id IS NULL
# MAGIC                   OR run_id IS NULL
# MAGIC                   OR ingested_at IS NULL
# MAGIC                 THEN 1 ELSE 0
# MAGIC             END
# MAGIC         ) AS missing_provenance
# MAGIC
# MAGIC     FROM bronze
# MAGIC ),
# MAGIC
# MAGIC checks AS (
# MAGIC     SELECT
# MAGIC         'bronze_row_count' AS check_name,
# MAGIC         'STRUCTURAL' AS check_type,
# MAGIC         CAST(CASE WHEN total_count >= 1 THEN 0 ELSE 1 END AS BIGINT) AS fail_count,
# MAGIC         'FAIL' AS severity,
# MAGIC         'Bronze should contain at least one Open-Meteo API response.' AS details
# MAGIC     FROM profile
# MAGIC
# MAGIC     UNION ALL
# MAGIC
# MAGIC     SELECT
# MAGIC         'bronze_response_key_unique',
# MAGIC         'STRUCTURAL',
# MAGIC         CAST(duplicate_response_rows AS BIGINT),
# MAGIC         'FAIL',
# MAGIC         'The combination of coordinate_id, requested_start_date, requested_end_date, and weather_model must be unique.'
# MAGIC     FROM duplicate_response_keys
# MAGIC
# MAGIC     UNION ALL
# MAGIC
# MAGIC     SELECT
# MAGIC         'requested_latitude',
# MAGIC         'DOMAIN',
# MAGIC         CAST(invalid_latitude AS BIGINT),
# MAGIC         'FAIL',
# MAGIC         'Requested latitude must be between -90 and 90.'
# MAGIC     FROM profile
# MAGIC
# MAGIC     UNION ALL
# MAGIC
# MAGIC     SELECT
# MAGIC         'requested_longitude',
# MAGIC         'DOMAIN',
# MAGIC         CAST(invalid_longitude AS BIGINT),
# MAGIC         'FAIL',
# MAGIC         'Requested longitude must be between -180 and 180.'
# MAGIC     FROM profile
# MAGIC
# MAGIC     UNION ALL
# MAGIC
# MAGIC     SELECT
# MAGIC         'requested_dates',
# MAGIC         'COMPLETENESS',
# MAGIC         CAST(missing_dates AS BIGINT),
# MAGIC         'FAIL',
# MAGIC         'Requested start and end dates must be populated.'
# MAGIC     FROM profile
# MAGIC
# MAGIC     UNION ALL
# MAGIC
# MAGIC     SELECT
# MAGIC         'weather_model_not_null',
# MAGIC         'COMPLETENESS',
# MAGIC         CAST(missing_weather_model AS BIGINT),
# MAGIC         'WARN',
# MAGIC         'Weather model should be populated; model pinning is a downstream decision.'
# MAGIC     FROM profile
# MAGIC
# MAGIC     UNION ALL
# MAGIC
# MAGIC     SELECT
# MAGIC         'hourly_arrays_not_null',
# MAGIC         'COMPLETENESS',
# MAGIC         CAST(missing_arrays AS BIGINT),
# MAGIC         'FAIL',
# MAGIC         'All hourly arrays must be populated.'
# MAGIC     FROM profile
# MAGIC
# MAGIC     UNION ALL
# MAGIC
# MAGIC     SELECT
# MAGIC         'hourly_array_alignment',
# MAGIC         'STRUCTURAL',
# MAGIC         CAST(misaligned_arrays AS BIGINT),
# MAGIC         'FAIL',
# MAGIC         'Hourly arrays must have matching lengths.'
# MAGIC     FROM profile
# MAGIC
# MAGIC     UNION ALL
# MAGIC
# MAGIC     SELECT
# MAGIC         'hourly_volume',
# MAGIC         'MEASUREMENT',
# MAGIC         CAST(unexpected_hourly_volume AS BIGINT),
# MAGIC         'FAIL',
# MAGIC         'The number of hourly observations must match the requested date range.'
# MAGIC     FROM profile
# MAGIC )
# MAGIC
# MAGIC INSERT INTO `ftw-week-08`.`01-control`.open_meteo_weather_data_quality_results
# MAGIC SELECT
# MAGIC     r.run_id,
# MAGIC     r.executed_at,
# MAGIC     'Bronze',
# MAGIC     'open_meteo_weather',
# MAGIC     NULL,
# MAGIC     NULL,
# MAGIC     NULL,
# MAGIC     c.check_name,
# MAGIC     c.check_type,
# MAGIC     CASE
# MAGIC         WHEN c.fail_count = 0 THEN 'PASS'
# MAGIC         ELSE c.severity
# MAGIC     END AS status,
# MAGIC     c.severity,
# MAGIC     c.fail_count,
# MAGIC     p.total_count,
# MAGIC     CASE
# MAGIC         WHEN p.total_count = 0 THEN 100.0
# MAGIC         ELSE c.fail_count / p.total_count * 100.0
# MAGIC     END AS fail_pct,
# MAGIC     0.0,
# MAGIC     CAST(c.fail_count AS DOUBLE),
# MAGIC     'Data Engineering',
# MAGIC     c.details,
# MAGIC     NULL
# MAGIC FROM checks c
# MAGIC CROSS JOIN profile p
# MAGIC CROSS JOIN open_meteo_dq_run r;

# COMMAND ----------

# MAGIC %sql
# MAGIC -- Flatten aligned hourly arrays for observation-level validation
# MAGIC
# MAGIC CREATE OR REPLACE TEMP VIEW open_meteo_observations AS
# MAGIC
# MAGIC SELECT
# MAGIC     t.coordinate_id,
# MAGIC     t.batch_id,
# MAGIC     t.source_response_version,
# MAGIC     p.pos,
# MAGIC     CAST(t.hourly_time[p.pos] AS TIMESTAMP) AS observation_timestamp,
# MAGIC     t.hourly_temperature_2m[p.pos] AS temperature_2m,
# MAGIC     t.hourly_precipitation[p.pos] AS precipitation,
# MAGIC     t.hourly_weather_code[p.pos] AS weather_code
# MAGIC
# MAGIC FROM `ftw-week-08`.`02-bronze`.open_meteo_weather_raw t
# MAGIC
# MAGIC LATERAL VIEW posexplode(t.hourly_time) p AS pos, hourly_timestamp;

# COMMAND ----------

# MAGIC %sql
# MAGIC -- Run observation-level quality checks
# MAGIC
# MAGIC WITH ordered AS (
# MAGIC     SELECT
# MAGIC         o.*,
# MAGIC         b.requested_start_date,
# MAGIC         b.requested_end_date,
# MAGIC         LAG(o.observation_timestamp) OVER (
# MAGIC             PARTITION BY o.coordinate_id, o.source_response_version
# MAGIC             ORDER BY o.pos
# MAGIC         ) AS previous_timestamp
# MAGIC     FROM open_meteo_observations o
# MAGIC     LEFT JOIN `ftw-week-08`.`02-bronze`.open_meteo_weather_raw b
# MAGIC         ON o.coordinate_id = b.coordinate_id
# MAGIC         AND o.source_response_version = b.source_response_version
# MAGIC ),
# MAGIC
# MAGIC profile AS (
# MAGIC     SELECT
# MAGIC         COUNT(*) AS total_count,
# MAGIC
# MAGIC         SUM(CASE WHEN observation_timestamp IS NULL THEN 1 ELSE 0 END) AS timestamp_nulls,
# MAGIC
# MAGIC         SUM(CASE WHEN temperature_2m IS NULL THEN 1 ELSE 0 END) AS temperature_nulls,
# MAGIC
# MAGIC         SUM(CASE WHEN precipitation IS NULL THEN 1 ELSE 0 END) AS precipitation_nulls,
# MAGIC
# MAGIC         SUM(CASE WHEN weather_code IS NULL THEN 1 ELSE 0 END) AS weather_code_nulls,
# MAGIC
# MAGIC         COUNT(*) - COUNT(
# MAGIC     DISTINCT CONCAT(
# MAGIC         CAST(coordinate_id AS STRING),
# MAGIC         '|',
# MAGIC         CAST(source_response_version AS STRING),
# MAGIC         '|',
# MAGIC         CAST(observation_timestamp AS STRING)
# MAGIC     )
# MAGIC ) AS duplicate_timestamps,
# MAGIC
# MAGIC         SUM(
# MAGIC             CASE
# MAGIC                 WHEN previous_timestamp IS NOT NULL
# MAGIC                  AND observation_timestamp < previous_timestamp
# MAGIC                 THEN 1 ELSE 0
# MAGIC             END
# MAGIC         ) AS chronological_errors,
# MAGIC
# MAGIC         SUM(
# MAGIC             CASE
# MAGIC                 WHEN temperature_2m < -50
# MAGIC                   OR temperature_2m > 60
# MAGIC                 THEN 1 ELSE 0
# MAGIC             END
# MAGIC         ) AS invalid_temperature,
# MAGIC
# MAGIC         SUM(
# MAGIC             CASE
# MAGIC                 WHEN precipitation < 0
# MAGIC                 THEN 1 ELSE 0
# MAGIC             END
# MAGIC         ) AS negative_precipitation,
# MAGIC
# MAGIC         SUM(
# MAGIC             CASE
# MAGIC                 WHEN weather_code NOT IN (
# MAGIC                     0,1,2,3,
# MAGIC                     45,48,
# MAGIC                     51,53,55,56,57,
# MAGIC                     61,63,65,66,67,
# MAGIC                     71,73,75,77,
# MAGIC                     80,81,82,
# MAGIC                     85,86,
# MAGIC                     95,96,99
# MAGIC                 )
# MAGIC                 THEN 1 ELSE 0
# MAGIC             END
# MAGIC         ) AS invalid_weather_code,
# MAGIC
# MAGIC         SUM(
# MAGIC     CASE
# MAGIC         WHEN observation_timestamp < CAST(requested_start_date AS TIMESTAMP)
# MAGIC           OR observation_timestamp >= CAST(
# MAGIC               date_add(to_date(requested_end_date), 1) AS TIMESTAMP
# MAGIC           )
# MAGIC         THEN 1 ELSE 0
# MAGIC     END
# MAGIC ) AS outside_date_window,
# MAGIC
# MAGIC         SUM(
# MAGIC             CASE
# MAGIC                 WHEN previous_timestamp IS NOT NULL
# MAGIC                  AND observation_timestamp <> previous_timestamp + INTERVAL 1 HOUR
# MAGIC                 THEN 1 ELSE 0
# MAGIC             END
# MAGIC         ) AS timestamp_gaps
# MAGIC
# MAGIC     FROM ordered
# MAGIC )
# MAGIC
# MAGIC INSERT INTO `ftw-week-08`.`01-control`.open_meteo_weather_data_quality_results
# MAGIC
# MAGIC SELECT
# MAGIC     r.run_id,
# MAGIC     r.executed_at,
# MAGIC     'Bronze',
# MAGIC     'open_meteo_weather',
# MAGIC     NULL,
# MAGIC     NULL,
# MAGIC     NULL,
# MAGIC     check_name,
# MAGIC     check_type,
# MAGIC     CASE
# MAGIC         WHEN fail_count = 0 THEN 'PASS'
# MAGIC         ELSE severity
# MAGIC     END,
# MAGIC     severity,
# MAGIC     fail_count,
# MAGIC     total_count,
# MAGIC     CASE
# MAGIC         WHEN total_count = 0 THEN 100.0
# MAGIC         ELSE fail_count / total_count * 100.0
# MAGIC     END,
# MAGIC     0.0,
# MAGIC     CAST(fail_count AS DOUBLE),
# MAGIC     'Data Engineering',
# MAGIC     details,
# MAGIC     NULL
# MAGIC
# MAGIC FROM profile p
# MAGIC CROSS JOIN open_meteo_dq_run r
# MAGIC
# MAGIC LATERAL VIEW STACK(
# MAGIC     11,
# MAGIC
# MAGIC     'timestamp_not_null',
# MAGIC     'COMPLETENESS',
# MAGIC     timestamp_nulls,
# MAGIC     'FAIL',
# MAGIC     'Observation timestamps must not be null.',
# MAGIC
# MAGIC     'temperature_not_null',
# MAGIC     'COMPLETENESS',
# MAGIC     temperature_nulls,
# MAGIC     'FAIL',
# MAGIC     'Temperature observations must not be null.',
# MAGIC
# MAGIC     'precipitation_not_null',
# MAGIC     'COMPLETENESS',
# MAGIC     precipitation_nulls,
# MAGIC     'FAIL',
# MAGIC     'Precipitation observations must not be null.',
# MAGIC
# MAGIC     'weather_code_not_null',
# MAGIC     'COMPLETENESS',
# MAGIC     weather_code_nulls,
# MAGIC     'FAIL',
# MAGIC     'Weather code observations must not be null.',
# MAGIC
# MAGIC     'duplicate_timestamps',
# MAGIC     'UNIQUENESS',
# MAGIC     duplicate_timestamps,
# MAGIC     'FAIL',
# MAGIC     'Observation timestamps must be unique.',
# MAGIC
# MAGIC     'timestamp_chronological_order',
# MAGIC     'CONSISTENCY',
# MAGIC     chronological_errors,
# MAGIC     'FAIL',
# MAGIC     'Observation timestamps must be chronological.',
# MAGIC
# MAGIC     'temperature_range',
# MAGIC     'DOMAIN',
# MAGIC     invalid_temperature,
# MAGIC     'WARN',
# MAGIC     'Temperature values outside the defined physical plausibility range require review.',
# MAGIC
# MAGIC     'precipitation_non_negative',
# MAGIC     'DOMAIN',
# MAGIC     negative_precipitation,
# MAGIC     'FAIL',
# MAGIC     'Precipitation must not be negative.',
# MAGIC
# MAGIC     'weather_code_domain',
# MAGIC     'DOMAIN',
# MAGIC     invalid_weather_code,
# MAGIC     'FAIL',
# MAGIC     'Weather codes must use the valid Open-Meteo/WMO code set.',
# MAGIC
# MAGIC     'observation_date_window',
# MAGIC     'CONSISTENCY',
# MAGIC     outside_date_window,
# MAGIC     'FAIL',
# MAGIC     'Observations must fall within the requested date range.',
# MAGIC
# MAGIC     'hourly_continuity',
# MAGIC     'CONSISTENCY',
# MAGIC     timestamp_gaps,
# MAGIC     'FAIL',
# MAGIC     'Hourly observations should be continuous with one-hour intervals.'
# MAGIC ) s AS check_name, check_type, fail_count, severity, details;

# COMMAND ----------

# MAGIC %sql
# MAGIC -- Review all DQ checks for the current validation run
# MAGIC
# MAGIC SELECT
# MAGIC     check_name,
# MAGIC     check_type,
# MAGIC     status,
# MAGIC     severity,
# MAGIC     fail_count,
# MAGIC     total_count,
# MAGIC     fail_pct,
# MAGIC     details
# MAGIC FROM `ftw-week-08`.`01-control`.open_meteo_weather_data_quality_results
# MAGIC WHERE run_id = (SELECT run_id FROM open_meteo_dq_run)
# MAGIC ORDER BY
# MAGIC     CASE status
# MAGIC         WHEN 'FAIL' THEN 1
# MAGIC         WHEN 'WARN' THEN 2
# MAGIC         WHEN 'PASS' THEN 3
# MAGIC         ELSE 4
# MAGIC     END,
# MAGIC     check_name;

# COMMAND ----------

# MAGIC %sql
# MAGIC -- Summarize the current DQ run
# MAGIC
# MAGIC SELECT
# MAGIC     status,
# MAGIC     COUNT(*) AS check_count
# MAGIC FROM `ftw-week-08`.`01-control`.open_meteo_weather_data_quality_results
# MAGIC WHERE run_id = (SELECT run_id FROM open_meteo_dq_run)
# MAGIC GROUP BY status
# MAGIC ORDER BY
# MAGIC     CASE status
# MAGIC         WHEN 'FAIL' THEN 1
# MAGIC         WHEN 'WARN' THEN 2
# MAGIC         WHEN 'PASS' THEN 3
# MAGIC         ELSE 4
# MAGIC     END;

# COMMAND ----------

# MAGIC %sql
# MAGIC -- Review checks requiring attention
# MAGIC
# MAGIC SELECT
# MAGIC     check_name,
# MAGIC     status,
# MAGIC     severity,
# MAGIC     fail_count,
# MAGIC     total_count,
# MAGIC     fail_pct,
# MAGIC     details
# MAGIC FROM `ftw-week-08`.`01-control`.open_meteo_weather_data_quality_results
# MAGIC WHERE run_id = (SELECT run_id FROM open_meteo_dq_run)
# MAGIC   AND status IN ('WARN', 'FAIL')
# MAGIC ORDER BY
# MAGIC     CASE status
# MAGIC         WHEN 'FAIL' THEN 1
# MAGIC         WHEN 'WARN' THEN 2
# MAGIC     END,
# MAGIC     check_name;

# COMMAND ----------

# MAGIC %sql
# MAGIC -- Determine whether the Bronze dataset can proceed to Silver
# MAGIC
# MAGIC SELECT
# MAGIC     CASE
# MAGIC         WHEN SUM(
# MAGIC             CASE
# MAGIC                 WHEN status = 'FAIL'
# MAGIC                  AND severity = 'FAIL'
# MAGIC                 THEN 1
# MAGIC                 ELSE 0
# MAGIC             END
# MAGIC         ) = 0
# MAGIC         THEN 'READY_FOR_SILVER'
# MAGIC         ELSE 'BLOCKED'
# MAGIC     END AS final_decision,
# MAGIC
# MAGIC     SUM(
# MAGIC         CASE
# MAGIC             WHEN status = 'FAIL'
# MAGIC              AND severity = 'FAIL'
# MAGIC             THEN 1
# MAGIC             ELSE 0
# MAGIC         END
# MAGIC     ) AS blocking_fail_count,
# MAGIC
# MAGIC     SUM(
# MAGIC         CASE
# MAGIC             WHEN status = 'WARN'
# MAGIC             THEN 1
# MAGIC             ELSE 0
# MAGIC         END
# MAGIC     ) AS warn_count
# MAGIC
# MAGIC FROM `ftw-week-08`.`01-control`.open_meteo_weather_data_quality_results
# MAGIC
# MAGIC WHERE run_id = (SELECT run_id FROM open_meteo_dq_run);

# COMMAND ----------

# MAGIC %sql
# MAGIC -- Reconcile expected source characteristics with Bronze
# MAGIC
# MAGIC SELECT
# MAGIC     requested_latitude,
# MAGIC     requested_longitude,
# MAGIC     requested_start_date,
# MAGIC     requested_end_date,
# MAGIC     returned_latitude,
# MAGIC     returned_longitude,
# MAGIC     utc_offset_seconds,
# MAGIC     timezone,
# MAGIC     size(hourly_time) AS bronze_hourly_count,
# MAGIC     size(hourly_temperature_2m) AS bronze_temperature_count,
# MAGIC     size(hourly_precipitation) AS bronze_precipitation_count,
# MAGIC     size(hourly_weather_code) AS bronze_weather_code_count
# MAGIC FROM `ftw-week-08`.`02-bronze`.open_meteo_weather_raw;