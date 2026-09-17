-- ============================================================
-- Validation queries for green_taxi_clean / green_taxi_quarantine
-- ============================================================

-- 1. Row count reconciliation: Bronze in = Silver clean + quarantined (duplicates only)
SELECT
    (SELECT COUNT(*) FROM `ftw-week-08`.`02-bronze`.green_taxi_raw) AS bronze_rows,
    (SELECT COUNT(*) FROM `ftw-week-08`.`03-silver`.green_taxi_clean) AS clean_rows,
    (SELECT COUNT(*) FROM `ftw-week-08`.`03-silver`.green_taxi_quarantine) AS quarantined_rows,
    (SELECT COUNT(*) FROM `ftw-week-08`.`03-silver`.green_taxi_clean)
      + (SELECT COUNT(*) FROM `ftw-week-08`.`03-silver`.green_taxi_quarantine) AS total_check;


-- 2. Quarantine reasons breakdown (duplicates only, per D10)
SELECT reason, COUNT(*) AS row_count
FROM `ftw-week-08`.`03-silver`.green_taxi_quarantine
LATERAL VIEW explode(quarantine_reasons) AS reason
GROUP BY reason
ORDER BY row_count DESC;


-- 3. Quality flag counts on the CLEAN table — proves invalid values
--    are retained and quantified, not silently dropped.
SELECT
    SUM(CASE WHEN negative_fare_flag THEN 1 ELSE 0 END) AS negative_fare_count,
    SUM(CASE WHEN negative_distance_flag THEN 1 ELSE 0 END) AS negative_distance_count,
    SUM(CASE WHEN dropoff_before_pickup_flag THEN 1 ELSE 0 END) AS dropoff_before_pickup_count,
    SUM(CASE WHEN implausible_duration_flag THEN 1 ELSE 0 END) AS implausible_duration_count,
    SUM(CASE WHEN implausible_passenger_count_flag THEN 1 ELSE 0 END) AS implausible_passenger_count_count,
    COUNT(*) AS total_clean_rows
FROM `ftw-week-08`.`03-silver`.green_taxi_clean;