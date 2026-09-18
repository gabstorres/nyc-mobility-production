-- Open-Meteo Weather -- Silver Layer Data Quality Validation
--
-- Purpose: Validate the Silver weather_hourly table after transformation
-- from Bronze.
--
-- Source:        `ftw-week-08`.`02-bronze`.open_meteo_weather_raw
-- Silver target: `ftw-week-08`.`03-silver`.weather_hourly
-- DQ results:    `ftw-week-08`.`01-control`.open_meteo_silver_dq_results
--
-- Validation areas: required fields; data types and column
-- transformations; weather observation key and duplicate handling;
-- UTC -> America/New_York timestamp conversion; hourly continuity; DST
-- handling; temperature, precipitation, and weather code ranges; WMO
-- weather-code classification; Bronze -> Silver row reconciliation;
-- metadata and lineage preservation.
--
-- Important Silver behavior: Bronze hourly arrays are exploded into one
-- row per observation hour. Local timestamps are derived from UTC using
-- the America/New_York timezone with DST-aware conversion. Weather codes
-- are retained for audit and mapped to a readable weather condition
-- category.
--
-- Status values: PASS = expectation met; WARN = known issue requiring
-- review; FAIL = blocking DQ issue; INFO = measurement only.
--
-- KNOWN OPEN ISSUES in this file, carried over unmodified from the
-- reviewed notebook (see PR discussion -- not fixed as part of this
-- move/rename):
--   1. The exit gate below uses raise_error() and will HALT the run on
--      any FAIL, including from issue 2 below.
--   2. The wmo_code_category_mapping check (further down) marks ANY
--      weather_code not in its hardcoded 28-code list as a FAIL, even
--      though the Silver transform correctly falls back to
--      'unknown_code' for exactly that case. A genuinely novel code the
--      pipeline is designed to absorb would incorrectly halt the run.

DECLARE OR REPLACE VARIABLE dq_run_id STRING;
SET VARIABLE dq_run_id = uuid();

SELECT
    dq_run_id AS run_id,
    current_timestamp() AS executed_at;

-- =====================================================================
-- DQ results table (create once)
-- =====================================================================
CREATE TABLE IF NOT EXISTS `ftw-week-08`.`01-control`.open_meteo_silver_dq_results (

    run_id STRING,
    executed_at TIMESTAMP,

    layer STRING,
    dataset STRING,

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
    details STRING
)

COMMENT 'Silver Open-Meteo weather data quality results. One row per check per validation run.';

-- ============================================================
-- Required fields
-- ============================================================

INSERT INTO `ftw-week-08`.`01-control`.open_meteo_silver_dq_results

WITH checks AS (

    SELECT
        'weather_observation_key_not_null' AS check_name,
        COUNT_IF(weather_observation_key IS NULL) AS fail_count,
        COUNT(*) AS total_count
    FROM `ftw-week-08`.`03-silver`.weather_hourly

    UNION ALL

    SELECT
        'coordinate_id_not_null',
        COUNT_IF(coordinate_id IS NULL),
        COUNT(*)
    FROM `ftw-week-08`.`03-silver`.weather_hourly

    UNION ALL

    SELECT
        'observation_timestamp_utc_not_null',
        COUNT_IF(observation_timestamp_utc IS NULL),
        COUNT(*)
    FROM `ftw-week-08`.`03-silver`.weather_hourly

    UNION ALL

    SELECT
        'weather_model_not_null',
        COUNT_IF(weather_model IS NULL),
        COUNT(*)
    FROM `ftw-week-08`.`03-silver`.weather_hourly

    UNION ALL

    SELECT
        'observation_timestamp_local_not_null',
        COUNT_IF(observation_timestamp_local IS NULL),
        COUNT(*)
    FROM `ftw-week-08`.`03-silver`.weather_hourly

    UNION ALL

    SELECT
        'weather_code_not_null',
        COUNT_IF(weather_code IS NULL),
        COUNT(*)
    FROM `ftw-week-08`.`03-silver`.weather_hourly

    UNION ALL

    SELECT
        'source_system_not_null',
        COUNT_IF(source_system IS NULL),
        COUNT(*)
    FROM `ftw-week-08`.`03-silver`.weather_hourly

    UNION ALL

    SELECT
        'source_file_not_null',
        COUNT_IF(source_file IS NULL),
        COUNT(*)
    FROM `ftw-week-08`.`03-silver`.weather_hourly

    UNION ALL

    SELECT
        'batch_id_not_null',
        COUNT_IF(batch_id IS NULL),
        COUNT(*)
    FROM `ftw-week-08`.`03-silver`.weather_hourly

    UNION ALL

    SELECT
        'ingested_at_not_null',
        COUNT_IF(ingested_at IS NULL),
        COUNT(*)
    FROM `ftw-week-08`.`03-silver`.weather_hourly
)

SELECT
    dq_run_id,
    current_timestamp(),
    'silver',
    'open_meteo_weather_hourly',
    check_name,
    'completeness',

    CASE
        WHEN fail_count = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS status,

    'FAIL' AS severity,

    fail_count,
    total_count,

    CASE
        WHEN total_count = 0 THEN 0
        ELSE fail_count * 100.0 / total_count
    END AS fail_pct,

    0.0 AS threshold_pct,

    NULL AS metric_value,

    'data_engineering',
    CONCAT(
        'Required field check. Null rows: ',
        CAST(fail_count AS STRING)
    )

FROM checks;

-- ============================================================
-- Business key and duplicate check
-- ============================================================

INSERT INTO `ftw-week-08`.`01-control`.open_meteo_silver_dq_results

WITH duplicate_groups AS (

    SELECT
        coordinate_id,
        observation_timestamp_utc,
        weather_model,
        COUNT(*) AS row_count
    FROM `ftw-week-08`.`03-silver`.weather_hourly
    GROUP BY
        coordinate_id,
        observation_timestamp_utc,
        weather_model
    HAVING COUNT(*) > 1
),

key_checks AS (

    SELECT
        'business_key_unique' AS check_name,
        COUNT(*) AS fail_count,
        (SELECT COUNT(*) 
         FROM `ftw-week-08`.`03-silver`.weather_hourly) AS total_count
    FROM duplicate_groups

    UNION ALL

    SELECT
        'weather_observation_key_unique',
        COUNT(*) AS fail_count,
        (SELECT COUNT(*)
         FROM `ftw-week-08`.`03-silver`.weather_hourly) AS total_count
    FROM (
        SELECT
            weather_observation_key
        FROM `ftw-week-08`.`03-silver`.weather_hourly
        GROUP BY weather_observation_key
        HAVING COUNT(*) > 1
    )
)

SELECT
    dq_run_id,
    current_timestamp(),
    'silver',
    'open_meteo_weather_hourly',
    check_name,
    'uniqueness',

    CASE
        WHEN fail_count = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS status,

    'FAIL' AS severity,

    fail_count,
    total_count,

    CASE
        WHEN total_count = 0 THEN 0
        ELSE fail_count * 100.0 / total_count
    END AS fail_pct,

    0.0 AS threshold_pct,

    NULL AS metric_value,

    'data_engineering',

    CASE
        WHEN fail_count = 0
        THEN 'No duplicate observation keys found.'
        ELSE CONCAT(
            'Duplicate groups found: ',
            CAST(fail_count AS STRING)
        )
    END AS details

FROM key_checks;

-- ============================================================
-- Type and transformation checks
-- ============================================================

INSERT INTO `ftw-week-08`.`01-control`.open_meteo_silver_dq_results

WITH checks AS (

    SELECT
        'weather_observation_key_length' AS check_name,
        COUNT_IF(
            weather_observation_key IS NULL
            OR length(weather_observation_key) <> 64
        ) AS fail_count,
        COUNT(*) AS total_count
    FROM `ftw-week-08`.`03-silver`.weather_hourly

    UNION ALL

    SELECT
        'observation_hour_local_range',
        COUNT_IF(
            observation_hour_local IS NULL
            OR observation_hour_local < 0
            OR observation_hour_local > 23
        ),
        COUNT(*)
    FROM `ftw-week-08`.`03-silver`.weather_hourly

    UNION ALL

    SELECT
        'observation_date_matches_local_timestamp',
        COUNT_IF(
            observation_date_local <>
            CAST(observation_timestamp_local AS DATE)
        ),
        COUNT(*)
    FROM `ftw-week-08`.`03-silver`.weather_hourly

    UNION ALL

    SELECT
        'observation_hour_matches_local_timestamp',
        COUNT_IF(
            observation_hour_local <>
            HOUR(observation_timestamp_local)
        ),
        COUNT(*)
    FROM `ftw-week-08`.`03-silver`.weather_hourly

    UNION ALL

    SELECT
        'utc_timestamp_not_null_after_conversion',
        COUNT_IF(observation_timestamp_utc IS NULL),
        COUNT(*)
    FROM `ftw-week-08`.`03-silver`.weather_hourly

    UNION ALL

    SELECT
        'local_timestamp_not_null_after_conversion',
        COUNT_IF(observation_timestamp_local IS NULL),
        COUNT(*)
    FROM `ftw-week-08`.`03-silver`.weather_hourly
)

SELECT
    dq_run_id,
    current_timestamp(),
    'silver',
    'open_meteo_weather_hourly',
    check_name,
    'transformation',

    CASE
        WHEN fail_count = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS status,

    'FAIL' AS severity,

    fail_count,
    total_count,

    CASE
        WHEN total_count = 0 THEN 0
        ELSE fail_count * 100.0 / total_count
    END AS fail_pct,

    0.0 AS threshold_pct,

    NULL AS metric_value,

    'data_engineering',

    CASE
        WHEN fail_count = 0
        THEN 'Transformation check passed.'
        ELSE CONCAT(
            'Transformation check found ',
            CAST(fail_count AS STRING),
            ' invalid rows.'
        )
    END AS details

FROM checks;

-- ============================================================
-- Timestamp, DST, and hourly continuity
-- ============================================================

WITH ordered AS (
    SELECT
        coordinate_id,
        weather_model,
        observation_timestamp_utc,
        observation_timestamp_local,

        LAG(observation_timestamp_utc) OVER (
            PARTITION BY coordinate_id, weather_model
            ORDER BY observation_timestamp_utc
        ) AS previous_timestamp_utc,

        LAG(observation_timestamp_local) OVER (
            PARTITION BY coordinate_id, weather_model
            ORDER BY observation_timestamp_utc
        ) AS previous_timestamp_local

    FROM `ftw-week-08`.`03-silver`.weather_hourly
),

continuity_checks AS (

    SELECT
        'hourly_utc_continuity' AS check_name,
        COUNT_IF(
            previous_timestamp_utc IS NOT NULL
            AND (
                unix_timestamp(observation_timestamp_utc)
                - unix_timestamp(previous_timestamp_utc)
            ) <> 3600
        ) AS fail_count,
        COUNT(*) AS total_count
    FROM ordered

    UNION ALL

    SELECT
        'local_timestamp_non_decreasing',
        COUNT_IF(
            previous_timestamp_local IS NOT NULL
            AND observation_timestamp_local < previous_timestamp_local
        ),
        COUNT(*)
    FROM ordered

    UNION ALL

    SELECT
        'dst_2026_03_08_no_duplicate_02_hour',
        COUNT(*),
        1
    FROM (
        SELECT
            coordinate_id,
            weather_model,
            observation_date_local,
            observation_hour_local
        FROM `ftw-week-08`.`03-silver`.weather_hourly
        WHERE observation_date_local = DATE '2026-03-08'
          AND observation_hour_local = 2
        GROUP BY
            coordinate_id,
            weather_model,
            observation_date_local,
            observation_hour_local
        HAVING COUNT(*) > 1
    ) duplicates

    UNION ALL

    SELECT
        'dst_2026_03_08_expected_23_hours',
        COUNT_IF(hour_count <> 23),
        COUNT(*)
    FROM (
        SELECT
            coordinate_id,
            weather_model,
            COUNT(DISTINCT observation_timestamp_local) AS hour_count
        FROM `ftw-week-08`.`03-silver`.weather_hourly
        WHERE observation_date_local = DATE '2026-03-08'
        GROUP BY
            coordinate_id,
            weather_model
    ) dst_days
)

INSERT INTO `ftw-week-08`.`01-control`.open_meteo_silver_dq_results
SELECT
    dq_run_id,
    current_timestamp(),
    'silver',
    'open_meteo_weather_hourly',
    check_name,
    'timestamp_continuity',

    CASE
        WHEN fail_count = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS status,

    'FAIL' AS severity,

    fail_count,
    total_count,

    CASE
        WHEN total_count = 0 THEN 0
        ELSE fail_count * 100.0 / total_count
    END AS fail_pct,

    0.0 AS threshold_pct,

    NULL AS metric_value,

    'data_engineering',

    CASE
        WHEN fail_count = 0 THEN
            'Timestamp and continuity check passed.'
        ELSE
            CONCAT(
                'Timestamp validation found ',
                CAST(fail_count AS STRING),
                ' issue(s).'
            )
    END AS details

FROM continuity_checks;

-- ============================================================
-- Weather measure and code range checks
-- ============================================================

INSERT INTO `ftw-week-08`.`01-control`.open_meteo_silver_dq_results

WITH checks AS (

    -- Temperature should be within the documented physical range.
    SELECT
        'temperature_2m_range' AS check_name,
        COUNT_IF(
            temperature_2m_c IS NULL
            OR temperature_2m_c < -90
            OR temperature_2m_c > 60
        ) AS fail_count,
        COUNT(*) AS total_count
    FROM `ftw-week-08`.`03-silver`.weather_hourly

    UNION ALL

    -- Precipitation cannot be negative.
    SELECT
        'precipitation_non_negative',
        COUNT_IF(
            precipitation_mm IS NULL
            OR precipitation_mm < 0
        ),
        COUNT(*)
    FROM `ftw-week-08`.`03-silver`.weather_hourly

    UNION ALL

    -- Validate that weather codes belong to the supported WMO
    -- codes handled by the Silver transformation.
    SELECT
        'weather_code_valid_wmo',
        COUNT_IF(
            weather_code IS NULL
            OR weather_code NOT IN (
                0, 1, 2, 3,
                45, 48,
                51, 53, 55,
                56, 57,
                61, 63, 65,
                66, 67,
                71, 73, 75,
                77,
                80, 81, 82,
                85, 86,
                95,
                96, 99
            )
        ),
        COUNT(*)
    FROM `ftw-week-08`.`03-silver`.weather_hourly

    UNION ALL

    -- Every supported weather code must have a category.
    SELECT
        'weather_code_category_not_null',
        COUNT_IF(
            weather_code IS NOT NULL
            AND weather_condition_category IS NULL
        ),
        COUNT(*)
    FROM `ftw-week-08`.`03-silver`.weather_hourly

    UNION ALL

    -- No supported WMO code should incorrectly be classified
    -- as unknown_code.
    SELECT
        'known_weather_code_not_unknown',
        COUNT_IF(
            weather_code IN (
                0, 1, 2, 3,
                45, 48,
                51, 53, 55,
                56, 57,
                61, 63, 65,
                66, 67,
                71, 73, 75,
                77,
                80, 81, 82,
                85, 86,
                95,
                96, 99
            )
            AND weather_condition_category = 'unknown_code'
        ),
        COUNT(*)
    FROM `ftw-week-08`.`03-silver`.weather_hourly
)

SELECT
    dq_run_id,
    current_timestamp(),
    'silver',
    'open_meteo_weather_hourly',
    check_name,
    'validity',

    CASE
        WHEN fail_count = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS status,

    'FAIL' AS severity,

    fail_count,
    total_count,

    CASE
        WHEN total_count = 0 THEN 0
        ELSE fail_count * 100.0 / total_count
    END AS fail_pct,

    0.0 AS threshold_pct,

    NULL AS metric_value,

    'data_engineering',

    CASE
        WHEN fail_count = 0 THEN
            'Weather measure and WMO validation passed.'
        ELSE
            CONCAT(
                'Validation found ',
                CAST(fail_count AS STRING),
                ' issue(s).'
            )
    END AS details

FROM checks;

-- ============================================================
-- WMO weather code -> category mapping
--
-- KNOWN ISSUE (not fixed here -- see file header): any weather_code not
-- in the VALUES list below is treated as a FAIL via
-- "e.expected_category IS NULL", even when Silver correctly classifies
-- it as 'unknown_code'. Suggested fix: replace that branch with
-- "(e.expected_category IS NULL AND s.weather_condition_category <>
-- 'unknown_code')" so a genuinely novel code is only flagged if Silver
-- did NOT fall back to unknown_code for it.
-- ============================================================

WITH expected_mapping AS (
    SELECT * FROM VALUES
        (0,  'clear_sky'),
        (1,  'mainly_clear'),
        (2,  'partly_cloudy'),
        (3,  'overcast'),
        (45, 'fog'),
        (48, 'fog'),
        (51, 'drizzle'),
        (53, 'drizzle'),
        (55, 'drizzle'),
        (56, 'freezing_drizzle'),
        (57, 'freezing_drizzle'),
        (61, 'rain'),
        (63, 'rain'),
        (65, 'rain'),
        (66, 'freezing_rain'),
        (67, 'freezing_rain'),
        (71, 'snow'),
        (73, 'snow'),
        (75, 'snow'),
        (77, 'snow_grains'),
        (80, 'rain_showers'),
        (81, 'rain_showers'),
        (82, 'rain_showers'),
        (85, 'snow_showers'),
        (86, 'snow_showers'),
        (95, 'thunderstorm'),
        (96, 'thunderstorm_with_hail'),
        (99, 'thunderstorm_with_hail')
    AS expected(weather_code, expected_category)
),

mapping_check AS (
    SELECT
        COUNT_IF(
            s.weather_code IS NOT NULL
            AND (
                e.expected_category IS NULL
                OR s.weather_condition_category <> e.expected_category
            )
        ) AS fail_count,
        COUNT(*) AS total_count
    FROM `ftw-week-08`.`03-silver`.weather_hourly s
    LEFT JOIN expected_mapping e
        ON s.weather_code = e.weather_code
)

INSERT INTO `ftw-week-08`.`01-control`.open_meteo_silver_dq_results
SELECT
    dq_run_id,
    current_timestamp(),
    'silver',
    'open_meteo_weather_hourly',
    'wmo_code_category_mapping',
    'transformation',

    CASE
        WHEN fail_count = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS status,

    'FAIL' AS severity,

    fail_count,
    total_count,

    CASE
        WHEN total_count = 0 THEN 0
        ELSE fail_count * 100.0 / total_count
    END AS fail_pct,

    0.0 AS threshold_pct,

    NULL AS metric_value,

    'data_engineering',

    CASE
        WHEN fail_count = 0 THEN
            'All supported WMO weather codes map to the expected Silver category.'
        ELSE
            CONCAT(
                'Found ',
                CAST(fail_count AS STRING),
                ' weather code/category mapping issue(s).'
            )
    END AS details

FROM mapping_check;

-- ============================================================
-- Bronze -> Silver reconciliation
-- ============================================================

WITH bronze_expected AS (
    SELECT DISTINCT
        b.coordinate_id,
        to_timestamp(hourly_row.hourly_time) AS observation_timestamp_utc,
        b.weather_model
    FROM `ftw-week-08`.`02-bronze`.open_meteo_weather_raw AS b
    LATERAL VIEW explode(
        arrays_zip(
            b.hourly_time,
            b.hourly_temperature_2m,
            b.hourly_precipitation,
            b.hourly_weather_code
        )
    ) exploded_table AS hourly_row
),

bronze_expected_count AS (
    SELECT COUNT(*) AS expected_silver_rows
    FROM bronze_expected
),

silver_count AS (
    SELECT COUNT(*) AS actual_silver_rows
    FROM `ftw-week-08`.`03-silver`.weather_hourly
),

reconciliation AS (
    SELECT
        b.expected_silver_rows,
        s.actual_silver_rows,
        b.expected_silver_rows - s.actual_silver_rows AS difference
    FROM bronze_expected_count b
    CROSS JOIN silver_count s
)

INSERT INTO `ftw-week-08`.`01-control`.open_meteo_silver_dq_results
SELECT
    dq_run_id,
    current_timestamp(),
    'silver',
    'open_meteo_weather_hourly',
    'bronze_silver_row_reconciliation',
    'reconciliation',

    CASE
        WHEN difference = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS status,

    'FAIL' AS severity,

    ABS(difference) AS fail_count,
    expected_silver_rows AS total_count,

    CASE
        WHEN expected_silver_rows = 0 THEN 0
        ELSE ABS(difference) * 100.0 / expected_silver_rows
    END AS fail_pct,

    0.0 AS threshold_pct,

    actual_silver_rows AS metric_value,

    'data_engineering',

    CONCAT(
        'Expected unique hourly observations from Bronze: ',
        CAST(expected_silver_rows AS STRING),
        '; actual Silver rows: ',
        CAST(actual_silver_rows AS STRING),
        '; difference: ',
        CAST(difference AS STRING)
    ) AS details

FROM reconciliation;

-- ============================================================
-- DQ summary
-- ============================================================

SELECT
    status,
    COUNT(*) AS check_count
FROM `ftw-week-08`.`01-control`.open_meteo_silver_dq_results
WHERE run_id = dq_run_id
GROUP BY status
ORDER BY
    CASE status
        WHEN 'FAIL' THEN 1
        WHEN 'WARN' THEN 2
        WHEN 'PASS' THEN 3
        WHEN 'INFO' THEN 4
        ELSE 5
    END;

-- ============================================================
-- Full detail, one row per check
-- ============================================================

SELECT
    check_name,
    status,
    severity,
    fail_count,
    total_count,
    ROUND(fail_pct, 4) AS fail_pct,
    details
FROM `ftw-week-08`.`01-control`.open_meteo_silver_dq_results
WHERE run_id = dq_run_id
ORDER BY check_name;

-- ============================================================
-- Silver DQ exit gate (HARD gate -- raises and halts on any FAIL; see
-- KNOWN OPEN ISSUES in the file header)
-- ============================================================

SELECT
    CASE
        WHEN COUNT_IF(status = 'FAIL') > 0
        THEN raise_error(
            CONCAT(
                'Silver weather_hourly gate BLOCKED: ',
                CAST(COUNT_IF(status = 'FAIL') AS STRING),
                ' failed check(s).'
            )
        )
        ELSE 'Silver weather_hourly gate PASSED'
    END AS gate_result
FROM `ftw-week-08`.`01-control`.open_meteo_silver_dq_results
WHERE run_id = dq_run_id;
