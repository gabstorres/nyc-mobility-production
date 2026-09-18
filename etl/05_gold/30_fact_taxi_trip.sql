-- ============================================================
-- Gold: fact_taxi_trip  (issue #38)
--
-- Stage:      05 Gold
-- Runs after: Silver green taxi gate, dim_date, dim_hour, dim_taxi_zone,
--             dim_weather_classification, and fact_weather_hourly
-- Target:     `ftw-week-08`.`05-gold`.fact_taxi_trip
-- Grain:      one row per accepted Green Taxi trip, after the D10 duplicate
--             policy has quarantined every collision group
-- Contract:   docs/data_dictionary.md (fact_taxi_trip), docs/data_model.md
-- Owner:      Ina
--
-- Keys
--   trip_key  SHA-256 of the D10 identity inputs, read from the Silver typed
--             values: vendor_id, pickup_datetime_local, dropoff_datetime_local,
--             pickup_location_id, dropoff_location_id, trip_distance_miles,
--             fare_amount_usd. Never includes batch_id, run_id or ingestion
--             time. Silver's own trip_hash is built from the raw Bronze strings,
--             so the two digests differ by design; both are deterministic, and
--             the guard below proves this one is unique at the declared grain.
--   Role-playing FKs: pickup and drop-off date, hour and zone keys.
--   pickup_weather_classification_key is nullable, explained by
--   weather_match_status.
--
-- Derived measure and flag formulas
--   trip_count                     1 for every published trip
--   trip_duration_seconds          carried from Silver (drop-off minus pickup)
--   pickup_timestamp_utc           to_utc_timestamp(pickup_datetime_local, 'America/New_York')   -- DST-aware, D09
--   dropoff_timestamp_utc          to_utc_timestamp(dropoff_datetime_local, 'America/New_York')
--   pickup_in_reporting_window_flag  pickup >= 2026-03-01 and < 2026-06-01, local
--   out_of_source_file_month_flag    pickup year-month differs from the month in source_file
--   negative_trip_distance_flag      trip_distance_miles < 0        (Silver: negative_distance_flag)
--   negative_fare_amount_flag        fare_amount_usd < 0            (Silver: negative_fare_flag)
--   negative_total_amount_flag       total_amount_usd < 0           (derived here)
--   zero_distance_high_fare_flag     distance = 0 and fare > 20 USD (derived here)
--   passenger_count_zero_flag        passenger_count = 0; null stays null
--   passenger_count_over_8_flag      passenger_count > 8; null stays null
--
-- Rows are never dropped. Quality flags travel with the row (D15) and every
-- nullable key carries a match status, so an unmatched zone or weather hour is
-- visible rather than silent.
--
-- Rerun behaviour: MERGE on trip_key. Unchanged trips are updated in place, new
-- trips inserted, and a trip that no longer exists in Silver is deleted, so a
-- revised source contribution cannot leave stale rows behind (D04).
-- Silver green_taxi_clean is rebuilt in full on each run, so the staged set is
-- the complete accepted population and NOT MATCHED BY SOURCE is safe. When
-- Silver becomes incremental, scope the staged view and this MERGE by
-- source_file.
-- ============================================================

CREATE TABLE IF NOT EXISTS `ftw-week-08`.`05-gold`.fact_taxi_trip (
    trip_key STRING NOT NULL,

    vendor_id INT,
    pickup_datetime_local TIMESTAMP,
    dropoff_datetime_local TIMESTAMP,
    pickup_timestamp_utc TIMESTAMP,
    dropoff_timestamp_utc TIMESTAMP,
    store_and_fwd_flag STRING,
    rate_code_id INT,
    pickup_location_id INT,
    dropoff_location_id INT,
    passenger_count DECIMAL(10,2),

    trip_distance_miles DECIMAL(18,3),
    fare_amount_usd DECIMAL(18,2),
    extra_amount_usd DECIMAL(18,2),
    mta_tax_amount_usd DECIMAL(18,2),
    tip_amount_usd DECIMAL(18,2),
    tolls_amount_usd DECIMAL(18,2),
    ehail_fee_amount_usd DECIMAL(18,2),
    improvement_surcharge_amount_usd DECIMAL(18,2),
    total_amount_usd DECIMAL(18,2),
    payment_type_id INT,
    trip_type_id INT,
    congestion_surcharge_amount_usd DECIMAL(18,2),
    cbd_congestion_fee_amount_usd DECIMAL(18,2),

    pickup_date_key INT,
    dropoff_date_key INT,
    pickup_hour_key INT,
    dropoff_hour_key INT,
    pickup_zone_key BIGINT,
    dropoff_zone_key BIGINT,
    pickup_weather_classification_key STRING,

    trip_duration_seconds BIGINT,
    trip_count INT,

    pickup_in_reporting_window_flag BOOLEAN,
    out_of_source_file_month_flag BOOLEAN,
    dropoff_before_pickup_flag BOOLEAN,
    negative_trip_distance_flag BOOLEAN,
    negative_fare_amount_flag BOOLEAN,
    negative_total_amount_flag BOOLEAN,
    zero_distance_high_fare_flag BOOLEAN,
    passenger_count_zero_flag BOOLEAN,
    passenger_count_over_8_flag BOOLEAN,

    pickup_zone_match_status STRING,
    dropoff_zone_match_status STRING,
    weather_match_status STRING,

    source_system STRING,
    source_file STRING,
    source_file_version STRING,
    batch_id STRING,
    run_id STRING,
    ingested_at TIMESTAMP,
    source_row_locator STRING,
    gold_processed_at TIMESTAMP
)
USING DELTA;


-- Pinned configuration, mirroring config/project.json. A view rather than
-- session variables, so the temp views below resolve the same way in a
-- notebook, a SQL file task and the SQL editor. run_id identifies this Gold
-- execution attempt; pipeline_runs is deferred (D14).
CREATE OR REPLACE TEMP VIEW gold_taxi_config AS
SELECT
    'nyc_approved_point' AS weather_coordinate_id,
    'era5' AS weather_model_pinned,
    TIMESTAMP '2026-03-01 00:00:00' AS reporting_window_start,
    TIMESTAMP '2026-06-01 00:00:00' AS reporting_window_end,
    uuid() AS gold_run_id;


-- Step 1 — trip identity, UTC timestamps and the documented flags.
CREATE OR REPLACE TEMP VIEW gold_trip_base AS
SELECT
    sha2(concat_ws('||',
        CAST(t.vendor_id AS STRING),
        CAST(t.pickup_datetime_local AS STRING),
        CAST(t.dropoff_datetime_local AS STRING),
        CAST(t.pickup_location_id AS STRING),
        CAST(t.dropoff_location_id AS STRING),
        CAST(t.trip_distance_miles AS STRING),
        CAST(t.fare_amount_usd AS STRING)
    ), 256) AS trip_key,

    t.vendor_id,
    t.pickup_datetime_local,
    t.dropoff_datetime_local,
    to_utc_timestamp(t.pickup_datetime_local, 'America/New_York') AS pickup_timestamp_utc,
    to_utc_timestamp(t.dropoff_datetime_local, 'America/New_York') AS dropoff_timestamp_utc,
    t.store_and_fwd_flag,
    t.rate_code_id,
    t.pickup_location_id,
    t.dropoff_location_id,
    CAST(t.passenger_count AS DECIMAL(10,2)) AS passenger_count,

    t.trip_distance_miles,
    t.fare_amount_usd,
    t.extra_amount_usd,
    t.mta_tax_amount_usd,
    t.tip_amount_usd,
    t.tolls_amount_usd,
    t.ehail_fee_amount_usd,
    t.improvement_surcharge_amount_usd,
    t.total_amount_usd,
    t.payment_type_id,
    t.trip_type_id,
    t.congestion_surcharge_amount_usd,
    t.cbd_congestion_fee_amount_usd,

    t.trip_duration_seconds,

    (t.pickup_datetime_local >= c.reporting_window_start
     AND t.pickup_datetime_local < c.reporting_window_end) AS pickup_in_reporting_window_flag,
    (date_format(t.pickup_datetime_local, 'yyyy-MM')
     <> regexp_extract(t.source_file, 'green_tripdata_([0-9]{4}-[0-9]{2})', 1)) AS out_of_source_file_month_flag,
    t.dropoff_before_pickup_flag,
    t.negative_distance_flag AS negative_trip_distance_flag,
    t.negative_fare_flag AS negative_fare_amount_flag,
    (t.total_amount_usd < 0) AS negative_total_amount_flag,
    (t.trip_distance_miles = 0 AND t.fare_amount_usd > 20) AS zero_distance_high_fare_flag,
    (t.passenger_count = 0) AS passenger_count_zero_flag,
    (t.passenger_count > 8) AS passenger_count_over_8_flag,

    t.source_system,
    t.source_file,
    t.batch_id,
    t.ingested_at,
    c.gold_run_id,
    c.weather_coordinate_id,
    c.weather_model_pinned
FROM `ftw-week-08`.`03-silver`.green_taxi_clean t
CROSS JOIN gold_taxi_config c;


-- Step 2 — both zone roles. 264 (unknown) and 265 (outside_nyc) are valid
-- members, so they are matched_special, not failures. An unmatched id keeps its
-- value and a null key.
CREATE OR REPLACE TEMP VIEW gold_trip_zones AS
SELECT
    b.*,
    pz.zone_key AS pickup_zone_key,
    dz.zone_key AS dropoff_zone_key,
    CASE
        WHEN b.pickup_location_id IS NULL THEN 'missing_source_id'
        WHEN pz.zone_key IS NULL THEN 'unmatched_location_id'
        WHEN b.pickup_location_id IN (264, 265) THEN 'matched_special'
        ELSE 'matched_regular'
    END AS pickup_zone_match_status,
    CASE
        WHEN b.dropoff_location_id IS NULL THEN 'missing_source_id'
        WHEN dz.zone_key IS NULL THEN 'unmatched_location_id'
        WHEN b.dropoff_location_id IN (264, 265) THEN 'matched_special'
        ELSE 'matched_regular'
    END AS dropoff_zone_match_status
FROM gold_trip_base b
LEFT JOIN `ftw-week-08`.`05-gold`.dim_taxi_zone pz
    ON b.pickup_location_id = pz.location_id
LEFT JOIN `ftw-week-08`.`05-gold`.dim_taxi_zone dz
    ON b.dropoff_location_id = dz.location_id;


-- Guard: dim_taxi_zone must be unique on location_id, or a trip would be
-- duplicated once per matching zone row.
SELECT CASE
         WHEN (SELECT COUNT(*) FROM gold_trip_zones) > (SELECT COUNT(*) FROM gold_trip_base)
         THEN raise_error('fact_taxi_trip: dim_taxi_zone is not unique on location_id; the zone join fans out')
       END;


-- Step 3 — weather classification for the pickup hour, matched in UTC on the
-- pinned coordinate and model (D09, D12). Only the classification key is
-- copied; temperature and precipitation stay in fact_weather_hourly. Reading
-- the weather fact keeps trip and weather classifications identical; it is a
-- build-time lookup, not a stored fact-to-fact foreign key.
CREATE OR REPLACE TEMP VIEW gold_trip_weather AS
SELECT
    z.*,
    w.weather_classification_key AS pickup_weather_classification_key,
    CASE
        WHEN z.pickup_datetime_local IS NULL THEN 'invalid_pickup_timestamp'
        WHEN w.weather_classification_key IS NOT NULL THEN 'matched_unique'
        ELSE 'no_match'
    END AS weather_match_status
FROM gold_trip_zones z
LEFT JOIN `ftw-week-08`.`05-gold`.fact_weather_hourly w
    ON w.coordinate_id = z.weather_coordinate_id
   AND w.weather_model = z.weather_model_pinned
   AND w.observation_timestamp_utc = date_trunc('hour', z.pickup_timestamp_utc);


-- Step 4 — guards that must hold before publishing.
-- A duplicate trip_key would break the declared grain. More than one weather
-- match per trip would fan out the fact; the dictionary calls that
-- ambiguous_match and it blocks publication (D12).
SELECT CASE
         WHEN COUNT(*) > 0
         THEN raise_error(concat('fact_taxi_trip: ', CAST(COUNT(*) AS STRING),
                                 ' duplicate trip_key values in the staged rows'))
       END
FROM (
    SELECT trip_key FROM gold_trip_weather GROUP BY trip_key HAVING COUNT(*) > 1
);

SELECT CASE
         WHEN (SELECT COUNT(*) FROM gold_trip_weather) > (SELECT COUNT(*) FROM gold_trip_zones)
         THEN raise_error('fact_taxi_trip: ambiguous_match — a trip matched more than one weather observation; check coordinate_id and weather_model')
       END;


-- Step 5 — the published shape. source_file_version comes from the control
-- table, so a Gold row can be traced to the exact source version that produced
-- it. source_row_locator has no stable source value yet (D18).
CREATE OR REPLACE TEMP VIEW gold_trip_final AS
SELECT
    w.trip_key,

    w.vendor_id,
    w.pickup_datetime_local,
    w.dropoff_datetime_local,
    w.pickup_timestamp_utc,
    w.dropoff_timestamp_utc,
    w.store_and_fwd_flag,
    w.rate_code_id,
    w.pickup_location_id,
    w.dropoff_location_id,
    w.passenger_count,

    w.trip_distance_miles,
    w.fare_amount_usd,
    w.extra_amount_usd,
    w.mta_tax_amount_usd,
    w.tip_amount_usd,
    w.tolls_amount_usd,
    w.ehail_fee_amount_usd,
    w.improvement_surcharge_amount_usd,
    w.total_amount_usd,
    w.payment_type_id,
    w.trip_type_id,
    w.congestion_surcharge_amount_usd,
    w.cbd_congestion_fee_amount_usd,

    CAST(date_format(w.pickup_datetime_local, 'yyyyMMdd') AS INT) AS pickup_date_key,
    CAST(date_format(w.dropoff_datetime_local, 'yyyyMMdd') AS INT) AS dropoff_date_key,
    HOUR(w.pickup_datetime_local) AS pickup_hour_key,
    HOUR(w.dropoff_datetime_local) AS dropoff_hour_key,
    w.pickup_zone_key,
    w.dropoff_zone_key,
    w.pickup_weather_classification_key,

    w.trip_duration_seconds,
    1 AS trip_count,

    w.pickup_in_reporting_window_flag,
    w.out_of_source_file_month_flag,
    w.dropoff_before_pickup_flag,
    w.negative_trip_distance_flag,
    w.negative_fare_amount_flag,
    w.negative_total_amount_flag,
    w.zero_distance_high_fare_flag,
    w.passenger_count_zero_flag,
    w.passenger_count_over_8_flag,

    w.pickup_zone_match_status,
    w.dropoff_zone_match_status,
    w.weather_match_status,

    w.source_system,
    w.source_file,
    b.source_version_id AS source_file_version,
    w.batch_id,
    w.gold_run_id AS run_id,
    w.ingested_at,
    CAST(NULL AS STRING) AS source_row_locator,
    current_timestamp() AS gold_processed_at
FROM gold_trip_weather w
LEFT JOIN `ftw-week-08`.`01-control`.ingestion_batches b
    ON w.batch_id = b.batch_id;


MERGE INTO `ftw-week-08`.`05-gold`.fact_taxi_trip AS target
USING gold_trip_final AS source
ON target.trip_key = source.trip_key
WHEN MATCHED THEN UPDATE SET *
WHEN NOT MATCHED THEN INSERT *
WHEN NOT MATCHED BY SOURCE THEN DELETE;


-- Step 6 — counts and one measure reconciled, for the run log. Blocking checks
-- live in 90_validate_gold.sql.
SELECT
    (SELECT COUNT(*) FROM `ftw-week-08`.`03-silver`.green_taxi_clean) AS silver_clean_rows,
    (SELECT SUM(trip_count) FROM `ftw-week-08`.`05-gold`.fact_taxi_trip) AS gold_trip_count,
    (SELECT ROUND(SUM(fare_amount_usd), 2) FROM `ftw-week-08`.`03-silver`.green_taxi_clean) AS silver_fare_total,
    (SELECT ROUND(SUM(fare_amount_usd), 2) FROM `ftw-week-08`.`05-gold`.fact_taxi_trip) AS gold_fare_total,
    (SELECT COUNT_IF(pickup_zone_key IS NULL) FROM `ftw-week-08`.`05-gold`.fact_taxi_trip) AS null_pickup_zone_keys,
    (SELECT COUNT_IF(weather_match_status = 'no_match') FROM `ftw-week-08`.`05-gold`.fact_taxi_trip) AS weather_no_match_rows;
