-- Gold dimension: dim_taxi_zone (issue #36). Sourced from Silver's
-- taxi_zones_clean (PR #81). Full rebuild (CREATE OR REPLACE): the TLC zone
-- lookup is a versioned reference snapshot, not something Silver appends
-- to, so a deterministic recompute matches its lifecycle (no SCD Type 2 --
-- no approved business question needs historical zone labels, per decision
-- D07's "no SCD Type 2 for zones initially").
--
-- Grain: one row per taxi zone (location_id) -- 265 rows.
--
-- KNOWN ISSUE (do not "fix" here -- fix upstream in Silver, then just
-- rerun this file, no code change needed):
-- PR #81's taxi_zones_clean lowercases every borough value, including the
-- sentinel values 'EWR' / 'N/A' / 'Unknown', which contradicts
-- source_to_target_mapping.md row 41 ("remain explicit source values").
-- This build passes `borough` straight through from Silver unmodified --
-- it does NOT attempt to reverse the casing here, since that would
-- duplicate a fix that belongs in Silver and would need reverting once PR
-- #81 is corrected. 90_validate_dim_taxi_zone.sql check 5 will FAIL loudly
-- against today's Silver data as a visible reminder rather than silently
-- passing bad data through.
--
-- zone_classification, by contrast, IS recomputed here rather than trusted
-- from Silver: source_to_target_mapping.md's own mapping register (row 96)
-- places this derivation at the Gold dimension, not at Silver, and PR
-- #81's Silver-side version of the same logic is missing the
-- `other_special` catch-all branch (the mapping doc's 5th rule).
-- Recomputing it here from raw location_id/borough means this column is
-- correct today regardless of whether/when that Silver gap gets fixed.
-- UPPER() is used so the classification is correct whether borough is
-- properly cased or (as today) lowercased by the PR #81 bug -- this one
-- column doesn't need a rerun once that upstream fix lands.
CREATE OR REPLACE TABLE `ftw-week-08`.`05-gold`.dim_taxi_zone AS
SELECT
    CAST(location_id AS BIGINT) AS zone_key, -- surrogate PK; location_id is already a dense unique 1-265 business key, so a direct cast is the simplest deterministic surrogate
    location_id,
    borough, -- passthrough from Silver as-is; see KNOWN ISSUE above
    zone_name,
    service_zone,
    CASE
        WHEN location_id = 264 THEN 'unknown'
        WHEN location_id = 265 THEN 'outside_nyc'
        WHEN UPPER(borough) = 'EWR' THEN 'ewr'
        WHEN UPPER(borough) IN ('MANHATTAN', 'BROOKLYN', 'QUEENS', 'BRONX', 'STATEN ISLAND') THEN 'nyc_borough'
        ELSE 'other_special'
    END AS zone_classification
FROM `ftw-week-08`.`03-silver`.taxi_zones_clean;
