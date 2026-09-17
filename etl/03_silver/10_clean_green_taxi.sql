-- ============================================================
-- Silver: Green Taxi trips
-- typed, validated, deduplicated at the declared grain
--
-- trip_hash is computed from raw Bronze values BEFORE any casting,
-- so rounding during typing (e.g. trip_distance, fare_amount to
-- DECIMAL) can never change the hash and silently create false
-- collisions or diverge from the hash tested in Issue #14.
--
-- Quarantine policy (D10 + D15): only duplicate hash collisions are
-- quarantined. Negative fares/distances, dropoff-before-pickup,
-- implausible durations, and implausible passenger counts stay in
-- the clean table, tagged with flag columns instead — an ineligible
-- value for one measure must not exclude the row from unrelated
-- measures.
-- ============================================================

CREATE OR REPLACE TEMP VIEW silver_typed AS
SELECT
    sha2(concat_ws('||',
        CAST(VendorID AS STRING),
        CAST(lpep_pickup_datetime AS STRING),
        CAST(lpep_dropoff_datetime AS STRING),
        CAST(PULocationID AS STRING),
        CAST(DOLocationID AS STRING),
        CAST(trip_distance AS STRING),
        CAST(fare_amount AS STRING)
    ), 256) AS trip_hash,

    CAST(VendorID AS INT) AS vendor_id,
    lpep_pickup_datetime AS pickup_datetime_local,
    lpep_dropoff_datetime AS dropoff_datetime_local,
    unix_timestamp(lpep_dropoff_datetime) - unix_timestamp(lpep_pickup_datetime) AS trip_duration_seconds,
    store_and_fwd_flag,
    CAST(RatecodeID AS INT) AS rate_code_id,
    CAST(PULocationID AS INT) AS pickup_location_id,
    CAST(DOLocationID AS INT) AS dropoff_location_id,
    CAST(passenger_count AS INT) AS passenger_count,
    CAST(trip_distance AS DECIMAL(18,3)) AS trip_distance_miles,
    CAST(fare_amount AS DECIMAL(18,2)) AS fare_amount_usd,
    CAST(extra AS DECIMAL(18,2)) AS extra_amount_usd,
    CAST(mta_tax AS DECIMAL(18,2)) AS mta_tax_amount_usd,
    CAST(tip_amount AS DECIMAL(18,2)) AS tip_amount_usd,
    CAST(tolls_amount AS DECIMAL(18,2)) AS tolls_amount_usd,
    CAST(ehail_fee AS DECIMAL(18,2)) AS ehail_fee_amount_usd,
    CAST(improvement_surcharge AS DECIMAL(18,2)) AS improvement_surcharge_amount_usd,
    CAST(total_amount AS DECIMAL(18,2)) AS total_amount_usd,
    CAST(payment_type AS INT) AS payment_type_id,
    CAST(trip_type AS INT) AS trip_type_id,
    CAST(congestion_surcharge AS DECIMAL(18,2)) AS congestion_surcharge_amount_usd,
    CAST(cbd_congestion_fee AS DECIMAL(18,2)) AS cbd_congestion_fee_amount_usd,
    source_system, source_file, ingested_at, batch_id
FROM `ftw-week-08`.`02-bronze`.green_taxi_raw;


-- Step 2: quality flags + collision count (trip_hash computed above, untouched)
CREATE OR REPLACE TEMP VIEW silver_decided AS
SELECT *,
    COUNT(*) OVER (PARTITION BY trip_hash) AS collision_count,
    (fare_amount_usd < 0) AS negative_fare_flag,
    (trip_distance_miles < 0) AS negative_distance_flag,
    (dropoff_datetime_local < pickup_datetime_local) AS dropoff_before_pickup_flag,
    (trip_duration_seconds <= 0 OR trip_duration_seconds > 86400) AS implausible_duration_flag,
    (passenger_count < 0 OR passenger_count > 8) AS implausible_passenger_count_flag
FROM silver_typed;


-- Step 3: split by DUPLICATE STATUS ONLY (per D10/D15).
-- All quality flags above stay on green_taxi_clean regardless of value —
-- they inform downstream measure eligibility, they don't exclude the row.
CREATE OR REPLACE TABLE `ftw-week-08`.`03-silver`.green_taxi_clean AS
SELECT * EXCEPT (trip_hash, collision_count)
FROM silver_decided
WHERE collision_count = 1;

CREATE OR REPLACE TABLE `ftw-week-08`.`03-silver`.green_taxi_quarantine AS
SELECT *,
    array('duplicate_hash_collision') AS quarantine_reasons
FROM silver_decided
WHERE collision_count > 1;