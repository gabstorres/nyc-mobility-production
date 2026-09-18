-- Green Taxi Silver Layer Data Quality Validation
--
-- Purpose: Validate the Silver Green Taxi table after transformation from
-- Bronze.
--
-- Source:            `ftw-week-08`.`02-bronze`.green_taxi_raw
-- Clean target:      `ftw-week-08`.`03-silver`.green_taxi_clean
-- Quarantine target: `ftw-week-08`.`03-silver`.green_taxi_quarantine
-- DQ results:        `ftw-week-08`.`01-control`.green_taxi_silver_dq_results
--
-- Validation areas: required fields; data types and column
-- transformations; trip hash and duplicate handling; timestamp and
-- duration validation; passenger count and trip distance flags; fare and
-- monetary value handling; Bronze -> Silver reconciliation; clean +
-- quarantine reconciliation; metadata preservation.
--
-- Important Silver behavior: only duplicate trip_hash collisions are
-- quarantined. Negative fares, negative distances, invalid durations,
-- dropoff-before-pickup, and implausible passenger counts remain in the
-- clean table with quality flags -- they are NOT quarantined.
--
-- Status values: PASS = expectation met; WARN = known issue requiring
-- review; FAIL = blocking DQ issue; INFO = measurement only.

DECLARE OR REPLACE VARIABLE dq_run_id STRING;

SET VARIABLE dq_run_id = uuid();

SELECT
    dq_run_id AS run_id,
    current_timestamp() AS executed_at;

-- =====================================================================
-- DQ results table (create once)
-- =====================================================================
CREATE TABLE IF NOT EXISTS `ftw-week-08`.`01-control`.green_taxi_silver_dq_results (

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

COMMENT 'Silver Green Taxi data quality results. One row per check per validation run.';

-- =====================================================================
-- Required fields
-- =====================================================================
INSERT INTO `ftw-week-08`.`01-control`.green_taxi_silver_dq_results

WITH checks AS (

    SELECT
        COUNT(*) AS total_count,

        COUNT_IF(vendor_id IS NULL) AS vendor_id_nulls,

        COUNT_IF(pickup_datetime_local IS NULL) AS pickup_datetime_nulls,

        COUNT_IF(dropoff_datetime_local IS NULL) AS dropoff_datetime_nulls,

        COUNT_IF(pickup_location_id IS NULL) AS pickup_location_nulls,

        COUNT_IF(dropoff_location_id IS NULL) AS dropoff_location_nulls,

        COUNT_IF(source_system IS NULL OR trim(source_system) = '') AS source_system_nulls,

        COUNT_IF(source_file IS NULL OR trim(source_file) = '') AS source_file_nulls,

        COUNT_IF(batch_id IS NULL OR trim(batch_id) = '') AS batch_id_nulls,

        COUNT_IF(ingested_at IS NULL) AS ingested_at_nulls

    FROM `ftw-week-08`.`03-silver`.green_taxi_clean
),

results AS (

    SELECT
        'vendor_id_not_null' AS check_name,
        'NOT_NULL' AS check_type,
        vendor_id_nulls AS fail_count,
        total_count,
        'HIGH' AS severity,
        'vendor_id must not be NULL.' AS details
    FROM checks

    UNION ALL

    SELECT
        'pickup_datetime_not_null',
        'NOT_NULL',
        pickup_datetime_nulls,
        total_count,
        'HIGH',
        'pickup_datetime_local must not be NULL.'
    FROM checks

    UNION ALL

    SELECT
        'dropoff_datetime_not_null',
        'NOT_NULL',
        dropoff_datetime_nulls,
        total_count,
        'HIGH',
        'dropoff_datetime_local must not be NULL.'
    FROM checks

    UNION ALL

    SELECT
        'pickup_location_not_null',
        'NOT_NULL',
        pickup_location_nulls,
        total_count,
        'HIGH',
        'pickup_location_id must not be NULL.'
    FROM checks

    UNION ALL

    SELECT
        'dropoff_location_not_null',
        'NOT_NULL',
        dropoff_location_nulls,
        total_count,
        'HIGH',
        'dropoff_location_id must not be NULL.'
    FROM checks

    UNION ALL

    SELECT
        'source_system_not_null',
        'NOT_NULL',
        source_system_nulls,
        total_count,
        'HIGH',
        'source_system must not be NULL or blank.'
    FROM checks

    UNION ALL

    SELECT
        'source_file_not_null',
        'NOT_NULL',
        source_file_nulls,
        total_count,
        'HIGH',
        'source_file must not be NULL or blank.'
    FROM checks

    UNION ALL

    SELECT
        'batch_id_not_null',
        'NOT_NULL',
        batch_id_nulls,
        total_count,
        'HIGH',
        'batch_id must not be NULL or blank.'
    FROM checks

    UNION ALL

    SELECT
        'ingested_at_not_null',
        'NOT_NULL',
        ingested_at_nulls,
        total_count,
        'HIGH',
        'ingested_at must not be NULL.'
    FROM checks
)

SELECT

    dq_run_id AS run_id,
    current_timestamp() AS executed_at,

    '03-silver' AS layer,
    'green_taxi' AS dataset,

    check_name,
    check_type,

    CASE
        WHEN fail_count = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS status,

    severity,

    fail_count,
    total_count,

    ROUND(
        100.0 * fail_count / NULLIF(total_count, 0),
        2
    ) AS fail_pct,

    0.0 AS threshold_pct,

    CAST(fail_count AS DOUBLE) AS metric_value,

    'Data Engineering' AS owner,

    details

FROM results;

-- =====================================================================
-- Trip hash and duplicate handling (quarantine reconciliation)
-- =====================================================================
INSERT INTO `ftw-week-08`.`01-control`.green_taxi_silver_dq_results

WITH bronze_hashes AS (

    SELECT
        sha2(
            concat_ws('||',
                CAST(VendorID AS STRING),
                CAST(lpep_pickup_datetime AS STRING),
                CAST(lpep_dropoff_datetime AS STRING),
                CAST(PULocationID AS STRING),
                CAST(DOLocationID AS STRING),
                CAST(trip_distance AS STRING),
                CAST(fare_amount AS STRING)
            ),
            256
        ) AS trip_hash

    FROM `ftw-week-08`.`02-bronze`.green_taxi_raw
),

duplicate_hashes AS (

    SELECT
        trip_hash,
        COUNT(*) AS hash_count
    FROM bronze_hashes
    GROUP BY trip_hash
    HAVING COUNT(*) > 1
),

quarantine_checks AS (

    SELECT
        COUNT(*) AS quarantine_rows,

        COUNT_IF(
            quarantine_reasons IS NULL
            OR NOT array_contains(
                quarantine_reasons,
                'duplicate_hash_collision'
            )
        ) AS invalid_quarantine_reason_rows

    FROM `ftw-week-08`.`03-silver`.green_taxi_quarantine
),

duplicate_counts AS (

    SELECT
        COALESCE(SUM(hash_count), 0) AS expected_quarantine_rows
    FROM duplicate_hashes
),

clean_count AS (

    SELECT COUNT(*) AS clean_rows
    FROM `ftw-week-08`.`03-silver`.green_taxi_clean
),

bronze_count AS (

    SELECT COUNT(*) AS bronze_rows
    FROM `ftw-week-08`.`02-bronze`.green_taxi_raw
),

results AS (

    SELECT
        'duplicate_rows_quarantined' AS check_name,
        'DUPLICATE_HANDLING' AS check_type,

        ABS(
            quarantine_rows - expected_quarantine_rows
        ) AS fail_count,

        expected_quarantine_rows AS total_count,

        'HIGH' AS severity,

        'All Bronze trip_hash collision rows must be present in quarantine.' AS details

    FROM quarantine_checks
    CROSS JOIN duplicate_counts

    UNION ALL

    SELECT
        'quarantine_reason_correct',
        'DUPLICATE_HANDLING',

        invalid_quarantine_reason_rows,
        quarantine_rows,

        'HIGH',

        'Every quarantined row must have duplicate_hash_collision as its quarantine reason.'

    FROM quarantine_checks

    UNION ALL

    SELECT
        'bronze_clean_quarantine_reconciliation',
        'RECONCILIATION',

        ABS(
            bronze_rows - clean_rows - quarantine_rows
        ),
        bronze_rows,

        'HIGH',

        'Bronze row count must equal clean rows plus quarantine rows.'

    FROM bronze_count
    CROSS JOIN clean_count
    CROSS JOIN quarantine_checks
)

SELECT

    dq_run_id AS run_id,
    current_timestamp() AS executed_at,

    '03-silver' AS layer,
    'green_taxi' AS dataset,

    check_name,
    check_type,

    CASE
        WHEN fail_count = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS status,

    severity,

    fail_count,
    total_count,

    ROUND(
        100.0 * fail_count / NULLIF(total_count, 0),
        2
    ) AS fail_pct,

    0.0 AS threshold_pct,

    CAST(fail_count AS DOUBLE) AS metric_value,

    'Data Engineering' AS owner,

    details

FROM results;

-- =====================================================================
-- Data types and column transformations
-- =====================================================================
INSERT INTO `ftw-week-08`.`01-control`.green_taxi_silver_dq_results

WITH checks AS (

    SELECT

        COUNT(*) AS total_count,

        COUNT_IF(
            typeof(vendor_id) <> 'int'
        ) AS vendor_id_type_fail,

        COUNT_IF(
            typeof(rate_code_id) <> 'int'
        ) AS rate_code_id_type_fail,

        COUNT_IF(
            typeof(pickup_location_id) <> 'int'
        ) AS pickup_location_id_type_fail,

        COUNT_IF(
            typeof(dropoff_location_id) <> 'int'
        ) AS dropoff_location_id_type_fail,

        COUNT_IF(
            typeof(passenger_count) <> 'int'
        ) AS passenger_count_type_fail,

        COUNT_IF(
            typeof(payment_type_id) <> 'int'
        ) AS payment_type_id_type_fail,

        COUNT_IF(
            typeof(trip_type_id) <> 'int'
        ) AS trip_type_id_type_fail,

        COUNT_IF(
            typeof(trip_distance_miles) <> 'decimal(18,3)'
        ) AS trip_distance_type_fail,

        COUNT_IF(
            typeof(fare_amount_usd) <> 'decimal(18,2)'
        ) AS fare_amount_type_fail,

        COUNT_IF(
            typeof(total_amount_usd) <> 'decimal(18,2)'
        ) AS total_amount_type_fail,

        COUNT_IF(
            trip_duration_seconds IS NULL
            AND pickup_datetime_local IS NOT NULL
            AND dropoff_datetime_local IS NOT NULL
        ) AS duration_calculation_fail

    FROM `ftw-week-08`.`03-silver`.green_taxi_clean
),

results AS (

    SELECT
        'vendor_id_type' AS check_name,
        'DATA_TYPE' AS check_type,
        vendor_id_type_fail AS fail_count,
        total_count,
        'HIGH' AS severity,
        'vendor_id must be INT.' AS details
    FROM checks

    UNION ALL

    SELECT
        'rate_code_id_type',
        'DATA_TYPE',
        rate_code_id_type_fail,
        total_count,
        'MEDIUM',
        'rate_code_id must be INT.'
    FROM checks

    UNION ALL

    SELECT
        'pickup_location_id_type',
        'DATA_TYPE',
        pickup_location_id_type_fail,
        total_count,
        'HIGH',
        'pickup_location_id must be INT.'
    FROM checks

    UNION ALL

    SELECT
        'dropoff_location_id_type',
        'DATA_TYPE',
        dropoff_location_id_type_fail,
        total_count,
        'HIGH',
        'dropoff_location_id must be INT.'
    FROM checks

    UNION ALL

    SELECT
        'passenger_count_type',
        'DATA_TYPE',
        passenger_count_type_fail,
        total_count,
        'MEDIUM',
        'passenger_count must be INT.'
    FROM checks

    UNION ALL

    SELECT
        'payment_type_id_type',
        'DATA_TYPE',
        payment_type_id_type_fail,
        total_count,
        'MEDIUM',
        'payment_type_id must be INT.'
    FROM checks

    UNION ALL

    SELECT
        'trip_type_id_type',
        'DATA_TYPE',
        trip_type_id_type_fail,
        total_count,
        'MEDIUM',
        'trip_type_id must be INT.'
    FROM checks

    UNION ALL

    SELECT
        'trip_distance_miles_type',
        'DATA_TYPE',
        trip_distance_type_fail,
        total_count,
        'HIGH',
        'trip_distance_miles must be DECIMAL(18,3).'
    FROM checks

    UNION ALL

    SELECT
        'fare_amount_usd_type',
        'DATA_TYPE',
        fare_amount_type_fail,
        total_count,
        'HIGH',
        'fare_amount_usd must be DECIMAL(18,2).'
    FROM checks

    UNION ALL

    SELECT
        'total_amount_usd_type',
        'DATA_TYPE',
        total_amount_type_fail,
        total_count,
        'HIGH',
        'total_amount_usd must be DECIMAL(18,2).'
    FROM checks

    UNION ALL

    SELECT
        'trip_duration_calculation',
        'TRANSFORMATION',
        duration_calculation_fail,
        total_count,
        'HIGH',
        'trip_duration_seconds must be calculated when both timestamps are present.'
    FROM checks
)

SELECT

    dq_run_id AS run_id,
    current_timestamp() AS executed_at,

    '03-silver' AS layer,
    'green_taxi' AS dataset,

    check_name,
    check_type,

    CASE
        WHEN fail_count = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS status,

    severity,

    fail_count,
    total_count,

    ROUND(
        100.0 * fail_count / NULLIF(total_count, 0),
        2
    ) AS fail_pct,

    0.0 AS threshold_pct,

    CAST(fail_count AS DOUBLE) AS metric_value,

    'Data Engineering' AS owner,

    details

FROM results;

-- =====================================================================
-- Timestamp and duration validation (flag logic)
-- =====================================================================
INSERT INTO `ftw-week-08`.`01-control`.green_taxi_silver_dq_results

WITH checks AS (

    SELECT

        COUNT(*) AS total_count,

        COUNT_IF(
            dropoff_before_pickup_flag IS NULL
        ) AS dropoff_before_pickup_flag_nulls,

        COUNT_IF(
            implausible_duration_flag IS NULL
        ) AS implausible_duration_flag_nulls,

        COUNT_IF(
            trip_duration_seconds IS NULL
            AND pickup_datetime_local IS NOT NULL
            AND dropoff_datetime_local IS NOT NULL
        ) AS duration_nulls,

        COUNT_IF(
            dropoff_datetime_local < pickup_datetime_local
            AND dropoff_before_pickup_flag <> TRUE
        ) AS incorrect_dropoff_flag,

        COUNT_IF(
            (
                trip_duration_seconds <= 0
                OR trip_duration_seconds > 86400
            )
            AND implausible_duration_flag <> TRUE
        ) AS incorrect_duration_flag

    FROM `ftw-week-08`.`03-silver`.green_taxi_clean
),

results AS (

    SELECT
        'dropoff_before_pickup_flag_not_null' AS check_name,
        'FLAG_VALIDATION' AS check_type,
        dropoff_before_pickup_flag_nulls AS fail_count,
        total_count,
        'HIGH' AS severity,
        'dropoff_before_pickup_flag must be populated for every clean row.' AS details
    FROM checks

    UNION ALL

    SELECT
        'implausible_duration_flag_not_null',
        'FLAG_VALIDATION',
        implausible_duration_flag_nulls,
        total_count,
        'HIGH',
        'implausible_duration_flag must be populated for every clean row.'
    FROM checks

    UNION ALL

    SELECT
        'trip_duration_not_null_when_timestamps_present',
        'TRANSFORMATION',
        duration_nulls,
        total_count,
        'HIGH',
        'trip_duration_seconds must be calculated when both timestamps are present.'
    FROM checks

    UNION ALL

    SELECT
        'dropoff_before_pickup_flag_logic',
        'FLAG_VALIDATION',
        incorrect_dropoff_flag,
        total_count,
        'HIGH',
        'Rows with dropoff before pickup must have dropoff_before_pickup_flag = TRUE.'
    FROM checks

    UNION ALL

    SELECT
        'implausible_duration_flag_logic',
        'FLAG_VALIDATION',
        incorrect_duration_flag,
        total_count,
        'HIGH',
        'Rows with duration <= 0 or > 86400 seconds must have implausible_duration_flag = TRUE.'
    FROM checks
)

SELECT

    dq_run_id AS run_id,
    current_timestamp() AS executed_at,

    '03-silver' AS layer,
    'green_taxi' AS dataset,

    check_name,
    check_type,

    CASE
        WHEN fail_count = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS status,

    severity,

    fail_count,
    total_count,

    ROUND(
        100.0 * fail_count / NULLIF(total_count, 0),
        2
    ) AS fail_pct,

    0.0 AS threshold_pct,

    CAST(fail_count AS DOUBLE) AS metric_value,

    'Data Engineering' AS owner,

    details

FROM results;

-- =====================================================================
-- Passenger count and trip distance flags
-- =====================================================================
INSERT INTO `ftw-week-08`.`01-control`.green_taxi_silver_dq_results

WITH checks AS (

    SELECT

        COUNT(*) AS total_count,

        COUNT_IF(
            passenger_count IS NOT NULL
            AND passenger_count < 0
            AND implausible_passenger_count_flag <> TRUE
        ) AS incorrect_passenger_flag,

        COUNT_IF(
            passenger_count IS NOT NULL
            AND passenger_count > 8
            AND implausible_passenger_count_flag <> TRUE
        ) AS incorrect_high_passenger_flag,

        COUNT_IF(
            trip_distance_miles IS NOT NULL
            AND trip_distance_miles < 0
            AND negative_distance_flag <> TRUE
        ) AS incorrect_negative_distance_flag,

        COUNT_IF(
            passenger_count IS NOT NULL
            AND implausible_passenger_count_flag IS NULL
        ) AS passenger_flag_nulls,

        COUNT_IF(
            negative_distance_flag IS NULL
        ) AS distance_flag_nulls

    FROM `ftw-week-08`.`03-silver`.green_taxi_clean
),

results AS (

    SELECT
        'negative_distance_flag_logic' AS check_name,
        'FLAG_VALIDATION' AS check_type,
        incorrect_negative_distance_flag AS fail_count,
        total_count,
        'HIGH' AS severity,
        'Negative trip distances must have negative_distance_flag = TRUE.'
            AS details
    FROM checks

    UNION ALL

    SELECT
        'implausible_passenger_count_negative_logic',
        'FLAG_VALIDATION',
        incorrect_passenger_flag,
        total_count,
        'HIGH',
        'Negative passenger counts must have implausible_passenger_count_flag = TRUE.'
    FROM checks

    UNION ALL

    SELECT
        'implausible_passenger_count_high_logic',
        'FLAG_VALIDATION',
        incorrect_high_passenger_flag,
        total_count,
        'HIGH',
        'Passenger counts greater than 8 must have implausible_passenger_count_flag = TRUE.'
    FROM checks

    UNION ALL

    SELECT
        'implausible_passenger_count_flag_not_null',
        'FLAG_VALIDATION',
        passenger_flag_nulls,
        total_count,
        'MEDIUM',
        'implausible_passenger_count_flag must be populated when passenger_count is present.'
    FROM checks

    UNION ALL

    SELECT
        'negative_distance_flag_not_null',
        'FLAG_VALIDATION',
        distance_flag_nulls,
        total_count,
        'MEDIUM',
        'negative_distance_flag must be populated for every clean row.'
    FROM checks
)

SELECT

    dq_run_id AS run_id,
    current_timestamp() AS executed_at,

    '03-silver' AS layer,
    'green_taxi' AS dataset,

    check_name,
    check_type,

    CASE
        WHEN fail_count = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS status,

    severity,

    fail_count,
    total_count,

    ROUND(
        100.0 * fail_count / NULLIF(total_count, 0),
        2
    ) AS fail_pct,

    0.0 AS threshold_pct,

    CAST(fail_count AS DOUBLE) AS metric_value,

    'Data Engineering' AS owner,

    details

FROM results;

-- =====================================================================
-- Fare and monetary value handling
-- =====================================================================
INSERT INTO `ftw-week-08`.`01-control`.green_taxi_silver_dq_results

WITH checks AS (

    SELECT

        COUNT(*) AS total_count,

        COUNT_IF(
            fare_amount_usd IS NOT NULL
            AND fare_amount_usd < 0
            AND negative_fare_flag <> TRUE
        ) AS incorrect_negative_fare_flag,

        COUNT_IF(
            negative_fare_flag IS NULL
        ) AS negative_fare_flag_nulls,

        COUNT_IF(
            typeof(extra_amount_usd) <> 'decimal(18,2)'
        ) AS extra_type_fail,

        COUNT_IF(
            typeof(mta_tax_amount_usd) <> 'decimal(18,2)'
        ) AS mta_tax_type_fail,

        COUNT_IF(
            typeof(tip_amount_usd) <> 'decimal(18,2)'
        ) AS tip_type_fail,

        COUNT_IF(
            typeof(tolls_amount_usd) <> 'decimal(18,2)'
        ) AS tolls_type_fail,

        COUNT_IF(
            typeof(ehail_fee_amount_usd) <> 'decimal(18,2)'
        ) AS ehail_type_fail,

        COUNT_IF(
            typeof(improvement_surcharge_amount_usd) <> 'decimal(18,2)'
        ) AS improvement_surcharge_type_fail,

        COUNT_IF(
            typeof(congestion_surcharge_amount_usd) <> 'decimal(18,2)'
        ) AS congestion_surcharge_type_fail,

        COUNT_IF(
            typeof(cbd_congestion_fee_amount_usd) <> 'decimal(18,2)'
        ) AS cbd_congestion_fee_type_fail

    FROM `ftw-week-08`.`03-silver`.green_taxi_clean
),

results AS (

    SELECT
        'negative_fare_flag_logic' AS check_name,
        'FLAG_VALIDATION' AS check_type,
        incorrect_negative_fare_flag AS fail_count,
        total_count,
        'HIGH' AS severity,
        'Negative fare_amount_usd values must have negative_fare_flag = TRUE.'
            AS details
    FROM checks

    UNION ALL

    SELECT
        'negative_fare_flag_not_null',
        'FLAG_VALIDATION',
        negative_fare_flag_nulls,
        total_count,
        'MEDIUM',
        'negative_fare_flag must be populated for every clean row.'
    FROM checks

    UNION ALL

    SELECT
        'extra_amount_usd_type',
        'DATA_TYPE',
        extra_type_fail,
        total_count,
        'MEDIUM',
        'extra_amount_usd must be DECIMAL(18,2).'
    FROM checks

    UNION ALL

    SELECT
        'mta_tax_amount_usd_type',
        'DATA_TYPE',
        mta_tax_type_fail,
        total_count,
        'MEDIUM',
        'mta_tax_amount_usd must be DECIMAL(18,2).'
    FROM checks

    UNION ALL

    SELECT
        'tip_amount_usd_type',
        'DATA_TYPE',
        tip_type_fail,
        total_count,
        'MEDIUM',
        'tip_amount_usd must be DECIMAL(18,2).'
    FROM checks

    UNION ALL

    SELECT
        'tolls_amount_usd_type',
        'DATA_TYPE',
        tolls_type_fail,
        total_count,
        'MEDIUM',
        'tolls_amount_usd must be DECIMAL(18,2).'
    FROM checks

    UNION ALL

    SELECT
        'ehail_fee_amount_usd_type',
        'DATA_TYPE',
        ehail_type_fail,
        total_count,
        'MEDIUM',
        'ehail_fee_amount_usd must be DECIMAL(18,2).'
    FROM checks

    UNION ALL

    SELECT
        'improvement_surcharge_amount_usd_type',
        'DATA_TYPE',
        improvement_surcharge_type_fail,
        total_count,
        'MEDIUM',
        'improvement_surcharge_amount_usd must be DECIMAL(18,2).'
    FROM checks

    UNION ALL

    SELECT
        'congestion_surcharge_amount_usd_type',
        'DATA_TYPE',
        congestion_surcharge_type_fail,
        total_count,
        'MEDIUM',
        'congestion_surcharge_amount_usd must be DECIMAL(18,2).'
    FROM checks

    UNION ALL

    SELECT
        'cbd_congestion_fee_amount_usd_type',
        'DATA_TYPE',
        cbd_congestion_fee_type_fail,
        total_count,
        'MEDIUM',
        'cbd_congestion_fee_amount_usd must be DECIMAL(18,2).'
    FROM checks
)

SELECT

    dq_run_id AS run_id,
    current_timestamp() AS executed_at,

    '03-silver' AS layer,
    'green_taxi' AS dataset,

    check_name,
    check_type,

    CASE
        WHEN fail_count = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS status,

    severity,

    fail_count,
    total_count,

    ROUND(
        100.0 * fail_count / NULLIF(total_count, 0),
        2
    ) AS fail_pct,

    0.0 AS threshold_pct,

    CAST(fail_count AS DOUBLE) AS metric_value,

    'Data Engineering' AS owner,

    details

FROM results;

-- =====================================================================
-- Bronze -> Silver reconciliation
-- =====================================================================
INSERT INTO `ftw-week-08`.`01-control`.green_taxi_silver_dq_results

WITH counts AS (

    SELECT
        (SELECT COUNT(*)
         FROM `ftw-week-08`.`02-bronze`.green_taxi_raw) AS bronze_count,

        (SELECT COUNT(*)
         FROM `ftw-week-08`.`03-silver`.green_taxi_clean) AS clean_count,

        (SELECT COUNT(*)
         FROM `ftw-week-08`.`03-silver`.green_taxi_quarantine) AS quarantine_count

),

checks AS (

    SELECT

        bronze_count,
        clean_count,
        quarantine_count,

        bronze_count - (clean_count + quarantine_count)
            AS reconciliation_difference

    FROM counts
),

results AS (

    SELECT
        'bronze_silver_row_reconciliation' AS check_name,
        'RECONCILIATION' AS check_type,

        CASE
            WHEN reconciliation_difference = 0 THEN 0
            ELSE ABS(reconciliation_difference)
        END AS fail_count,

        bronze_count AS total_count,

        'HIGH' AS severity,

        CONCAT(
            'Bronze rows = ', bronze_count,
            '; Clean rows = ', clean_count,
            '; Quarantine rows = ', quarantine_count,
            '; Difference = ', reconciliation_difference
        ) AS details

    FROM checks

    UNION ALL

    SELECT
        'clean_plus_quarantine_equals_bronze',
        'RECONCILIATION',

        CASE
            WHEN clean_count + quarantine_count = bronze_count THEN 0
            ELSE ABS((clean_count + quarantine_count) - bronze_count)
        END,

        bronze_count,

        'HIGH',

        'All Bronze rows must be accounted for in either Silver clean or quarantine.'
    FROM checks
)

SELECT

    dq_run_id AS run_id,
    current_timestamp() AS executed_at,

    '03-silver' AS layer,
    'green_taxi' AS dataset,

    check_name,
    check_type,

    CASE
        WHEN fail_count = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS status,

    severity,

    fail_count,
    total_count,

    ROUND(
        100.0 * fail_count / NULLIF(total_count, 0),
        2
    ) AS fail_pct,

    0.0 AS threshold_pct,

    CAST(fail_count AS DOUBLE) AS metric_value,

    'Data Engineering' AS owner,

    details

FROM results;

-- =====================================================================
-- Summary by status
-- =====================================================================
SELECT
    status,
    COUNT(*) AS check_count
FROM `ftw-week-08`.`01-control`.green_taxi_silver_dq_results
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

-- =====================================================================
-- Exit gate (soft -- returns a status string, does not raise_error)
-- =====================================================================
SELECT
    CASE
        WHEN COUNT_IF(status = 'FAIL') = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END AS exit_gate_status,

    COUNT(*) AS total_checks,

    COUNT_IF(status = 'PASS') AS pass_count,

    COUNT_IF(status = 'WARN') AS warn_count,

    COUNT_IF(status = 'FAIL') AS fail_count

FROM `ftw-week-08`.`01-control`.green_taxi_silver_dq_results
WHERE run_id = dq_run_id;
