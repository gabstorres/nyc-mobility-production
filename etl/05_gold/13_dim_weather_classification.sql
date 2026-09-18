-- Gold dimension: dim_weather_classification (issue #36). Grain: one row
-- per (weather_code, precipitation_band) combination.
--
-- Built as a COMPLETE static enumeration from source_to_target_mapping.md's
-- own WMO code table and precipitation-band rule -- NOT derived from live
-- Silver data. Deliberate, not an oversight: mapping doc row 94 requires
-- the fact-side FK to be non-null "because complete mapping includes
-- unknown_code," which only holds if every code the classification rule
-- can ever produce -- including codes no Bronze batch has landed yet --
-- already has a dimension row before that batch arrives. A data-driven
-- build (rows only for codes observed so far) cannot promise that.
--
-- Because of this, dim_weather_classification has NO dependency on
-- weather_hourly or on any currently-open weather DQ notebook issue --
-- those are bugs in the DQ *check* logic, not in the Silver transform's
-- WMO mapping (independently verified correct against this same code
-- list). This table is safe to build today, ahead of that fix.
--
-- FLAGGED AMBIGUITY (raised in chat, not silently resolved): the mapping
-- doc describes weather_code as a literal composite-key column ("Retained
-- WMO code; composite [key] part with precipitation band") but also implies
-- completeness via *category* ("non-null because complete mapping includes
-- unknown_code"). Both only hold together if the truly-unmapped case gets
-- its own dedicated row per band with weather_code = NULL, rather than
-- embedding an arbitrary future numeric code -- that's what this build
-- does. Confirm this reading before treating it as final.
--
-- SCD: Type 0 / full rebuild -- static reference data, no history.
CREATE OR REPLACE TABLE `ftw-week-08`.`05-gold`.dim_weather_classification AS
WITH known_codes AS (
    -- Must stay byte-for-byte in sync with the CASE statement in
    -- etl/03_silver/weather_hourly.sql. 90_validate cross-checks this
    -- against Silver's actual output.
    SELECT * FROM VALUES
        (0,  'clear_sky'),
        (1,  'mainly_clear'),
        (2,  'partly_cloudy'),
        (3,  'overcast'),
        (45, 'fog'), (48, 'fog'),
        (51, 'drizzle'), (53, 'drizzle'), (55, 'drizzle'),
        (56, 'freezing_drizzle'), (57, 'freezing_drizzle'),
        (61, 'rain'), (63, 'rain'), (65, 'rain'),
        (66, 'freezing_rain'), (67, 'freezing_rain'),
        (71, 'snow'), (73, 'snow'), (75, 'snow'),
        (77, 'snow_grains'),
        (80, 'rain_showers'), (81, 'rain_showers'), (82, 'rain_showers'),
        (85, 'snow_showers'), (86, 'snow_showers'),
        (95, 'thunderstorm'),
        (96, 'thunderstorm_with_hail'), (99, 'thunderstorm_with_hail')
    AS t(weather_code, weather_condition)
),
precipitation_bands AS (
    SELECT * FROM VALUES ('dry'), ('light'), ('moderate'), ('heavy') AS t(precipitation_band)
),
enumerated AS (
    SELECT weather_code, weather_condition, precipitation_band
    FROM known_codes
    CROSS JOIN precipitation_bands

    UNION ALL

    -- One catch-all row per band for any code the mapping doc's rule
    -- doesn't cover, matching Silver's ELSE 'unknown_code' fallback.
    SELECT CAST(NULL AS INT) AS weather_code, 'unknown_code' AS weather_condition, precipitation_band
    FROM precipitation_bands
)
SELECT
    sha2(to_json(named_struct(
        'weather_code', weather_code,
        'precipitation_band', precipitation_band
    )), 256) AS weather_classification_key,
    weather_code,
    weather_condition,
    precipitation_band
FROM enumerated;
