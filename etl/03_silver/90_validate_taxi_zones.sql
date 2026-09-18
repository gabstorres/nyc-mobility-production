-- ==========================================
-- SILVER VALIDATION: TAXI ZONES
-- ==========================================

-- Check 1: location_id must not be NULL

SELECT *
FROM `ftw-week-08`.`03-silver`.taxi_zones_clean
WHERE location_id IS NULL;

-- Expected: 0 rows


-- ==========================================
-- Check 2: location_id must be unique
-- ==========================================

SELECT
    location_id,
    COUNT(*) AS duplicate_count
FROM `ftw-week-08`.`03-silver`.taxi_zones_clean
GROUP BY location_id
HAVING COUNT(*) > 1;

-- Expected: 0 rows


-- ==========================================
-- Check 3: Bronze -> Silver reconciliation
-- ==========================================

SELECT
    (SELECT COUNT(*)
     FROM `ftw-week-08`.`02-bronze`.taxi_zones_raw) AS bronze_count,

    (SELECT COUNT(*)
     FROM `ftw-week-08`.`03-silver`.taxi_zones_clean) AS silver_count;

-- Expected:
-- bronze_count = 265
-- silver_count = 265


-- ==========================================
-- Check 4: Sentinel records preserved
-- ==========================================

SELECT
    location_id,
    borough,
    zone_name,
    zone_classification
FROM `ftw-week-08`.`03-silver`.taxi_zones_clean
WHERE location_id IN (264, 265);

-- Expected:
-- 264 = unknown
-- 265 = outside_nyc


-- ==========================================
-- Check 5: Standardized borough values
-- ==========================================

SELECT DISTINCT borough
FROM `ftw-week-08`.`03-silver`.taxi_zones_clean
ORDER BY borough;

-- Expected values include:
-- bronx
-- brooklyn
-- manhattan
-- queens
-- staten island
-- ewr
-- na
-- unknown


-- ==========================================
-- Check 6: Standardized service_zone values
-- ==========================================

SELECT DISTINCT service_zone
FROM `ftw-week-08`.`03-silver`.taxi_zones_clean
ORDER BY service_zone;

-- Review for consistency and lowercase formatting


-- ==========================================
-- Check 7: Zone classifications summary
-- ==========================================

SELECT
    zone_classification,
    COUNT(*) AS row_count
FROM `ftw-week-08`.`03-silver`.taxi_zones_clean
GROUP BY zone_classification
ORDER BY zone_classification;

-- Expected classifications:
-- nyc_borough
-- ewr
-- unknown
-- outside_nyc

-- ==========================================
-- Check 8: Source metadata must not be NULL
-- ==========================================

SELECT *
FROM `ftw-week-08`.`03-silver`.taxi_zones_clean
WHERE source_system IS NULL
   OR source_file IS NULL
   OR source_file_version IS NULL
   OR batch_id IS NULL
   OR ingested_at IS NULL;

-- Expected: 0 rows


-- ==========================================
-- Check 9: source_system uses approved value
-- ==========================================

SELECT DISTINCT source_system
FROM `ftw-week-08`.`03-silver`.taxi_zones_clean;

-- Expected:
-- nyc_tlc_taxi_zones


-- ==========================================
-- Check 10: source_file_version populated
-- ==========================================

SELECT DISTINCT source_file_version
FROM `ftw-week-08`.`03-silver`.taxi_zones_clean;

-- Expected:
-- snapshot_v1
-- (or approved source version value)


-- ==========================================
-- Check 11: Borough values match Bronze source
-- ==========================================

SELECT
    COUNT(*) AS borough_value_mismatch
FROM `ftw-week-08`.`03-silver`.taxi_zones_clean s
WHERE s.borough NOT IN (
    SELECT DISTINCT borough
    FROM `ftw-week-08`.`02-bronze`.taxi_zones_raw
);

-- Expected: 0
