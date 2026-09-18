-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Taxi Zones Bronze Quality Check
-- MAGIC
-- MAGIC ## Purpose
-- MAGIC
-- MAGIC This notebook validates the existing Bronze Taxi Zones reference table:
-- MAGIC
-- MAGIC `ftw-week-08`.`02-bronze`.taxi_zones_raw
-- MAGIC
-- MAGIC The validation covers:
-- MAGIC
-- MAGIC - Completeness
-- MAGIC - Uniqueness
-- MAGIC - Valid ranges
-- MAGIC - Accepted categorical values
-- MAGIC - Duplicate business records
-- MAGIC - Special-location consistency
-- MAGIC - EWR consistency
-- MAGIC - Bronze ingestion metadata
-- MAGIC - Source-to-Bronze reconciliation
-- MAGIC - DQ result status and exit-gate conditions
-- MAGIC
-- MAGIC ### Important
-- MAGIC
-- MAGIC This notebook is for **data quality validation only**.
-- MAGIC
-- MAGIC It does not create, replace, clean, transform, or delete the Bronze
-- MAGIC Taxi Zone table.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Validation Approach
-- MAGIC
-- MAGIC Each DQ check produces a standardized result.
-- MAGIC
-- MAGIC ### Status
-- MAGIC
-- MAGIC | Status | Meaning |
-- MAGIC |---|---|
-- MAGIC | PASS | Validation expectation is satisfied |
-- MAGIC | WARN | A non-critical or known source issue was detected and requires review |
-- MAGIC | FAIL | A critical validation expectation was broken |
-- MAGIC | INFO | Measurement only; does not affect the DQ pass rate |
-- MAGIC
-- MAGIC ### Severity
-- MAGIC
-- MAGIC | Severity | Meaning |
-- MAGIC |---|---|
-- MAGIC | FAIL | Critical issue that should block downstream processing |
-- MAGIC | WARN | Non-blocking issue requiring review |
-- MAGIC | INFO | Informational measurement |
-- MAGIC
-- MAGIC Checks are evaluated independently. A single record may contribute to more than
-- MAGIC one check, so fail counts must not be summed to determine the number of unique
-- MAGIC bad records.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Dataset and Source Context
-- MAGIC
-- MAGIC ### Source
-- MAGIC
-- MAGIC `taxi_zone_lookup.csv`
-- MAGIC
-- MAGIC ### Bronze Target
-- MAGIC
-- MAGIC `ftw-week-08`.`02-bronze`.taxi_zones_raw
-- MAGIC
-- MAGIC ### Business Columns
-- MAGIC
-- MAGIC - `location_id`
-- MAGIC - `borough`
-- MAGIC - `zone`
-- MAGIC - `service_zone`
-- MAGIC
-- MAGIC ### Source Characteristics
-- MAGIC
-- MAGIC The Taxi Zone Lookup is a reference dataset containing 265 records in the
-- MAGIC current source snapshot.
-- MAGIC
-- MAGIC `location_id` is the business identifier and should be unique and positive.
-- MAGIC
-- MAGIC The source contains special classifications such as:
-- MAGIC
-- MAGIC - `EWR`
-- MAGIC - `Unknown`
-- MAGIC - `Outside of NYC`
-- MAGIC
-- MAGIC These are handled through source-specific consistency checks rather than being
-- MAGIC automatically treated as data-quality failures.

-- COMMAND ----------

CREATE TABLE IF NOT EXISTS `ftw-week-08`.`02-bronze`.90_validate_taxi_zones (
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
)
USING DELTA;

-- COMMAND ----------

DECLARE OR REPLACE VARIABLE dq_run_id STRING;
SET VARIABLE dq_run_id = uuid();
SELECT
    dq_run_id AS run_id,
    current_timestamp() AS executed_at;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Bronze Profile
-- MAGIC
-- MAGIC The following query profiles the existing Bronze table before the formal DQ
-- MAGIC checks are evaluated.
-- MAGIC
-- MAGIC The profile is observational only and does not modify the Bronze table.

-- COMMAND ----------

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT location_id) AS distinct_location_ids,

    SUM(CASE WHEN location_id IS NULL THEN 1 ELSE 0 END) AS null_location_id,
    SUM(CASE WHEN borough IS NULL THEN 1 ELSE 0 END) AS null_borough,
    SUM(CASE WHEN zone IS NULL THEN 1 ELSE 0 END) AS null_zone,
    SUM(CASE WHEN service_zone IS NULL THEN 1 ELSE 0 END) AS null_service_zone,

    MIN(location_id) AS min_location_id,
    MAX(location_id) AS max_location_id,

    SUM(CASE WHEN source_file IS NULL THEN 1 ELSE 0 END) AS null_source_file,
    SUM(CASE WHEN source_file_version IS NULL THEN 1 ELSE 0 END) AS null_source_version,
    SUM(CASE WHEN batch_id IS NULL THEN 1 ELSE 0 END) AS null_batch_id,
    SUM(CASE WHEN ingested_at IS NULL THEN 1 ELSE 0 END) AS null_ingested_at

FROM `ftw-week-08`.`02-bronze`.taxi_zones_raw;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Taxi Zone DQ Checks
-- MAGIC
-- MAGIC The checks below validate:
-- MAGIC
-- MAGIC ### Business Data
-- MAGIC
-- MAGIC - Table is not empty
-- MAGIC - `location_id` is not null
-- MAGIC - `location_id` is unique
-- MAGIC - `location_id` is positive
-- MAGIC - Borough completeness
-- MAGIC - Zone completeness
-- MAGIC - Service-zone completeness
-- MAGIC - Borough domain
-- MAGIC - Service-zone domain
-- MAGIC - Duplicate business records
-- MAGIC - Special-location consistency
-- MAGIC - EWR consistency
-- MAGIC
-- MAGIC ### Bronze Metadata
-- MAGIC
-- MAGIC - Source file is present
-- MAGIC - Source version is present
-- MAGIC - Batch ID is present
-- MAGIC - Ingestion timestamp is present
-- MAGIC
-- MAGIC Known source-specific characteristics are reported as warnings where
-- MAGIC appropriate instead of automatically blocking the pipeline.

-- COMMAND ----------

DECLARE OR REPLACE VARIABLE dq_run_id STRING;

SET VARIABLE dq_run_id = uuid();

SELECT
    dq_run_id AS run_id,
    current_timestamp() AS executed_at;

-- COMMAND ----------

WITH base AS (
    SELECT
        location_id,
        borough,
        zone,
        service_zone,
        source_file,
        source_file_version,
        batch_id,
        ingested_at
    FROM `ftw-week-08`.`02-bronze`.taxi_zones_raw
),
total AS (
    SELECT COUNT(*) AS total_count
    FROM base
),
checks AS (
    -- 1. Table is not empty
    SELECT
        'row_count_not_empty' AS check_name,
        'VOLUME' AS check_type,
        CASE WHEN total_count = 0 THEN 1 ELSE 0 END AS fail_count,
        1 AS total_count,
        0.0 AS threshold_pct,
        CAST(total_count AS DOUBLE) AS metric_value,
        'FAIL' AS severity,
        'Bronze Taxi Zone table must contain at least one record.' AS details
    FROM total
    UNION ALL
    -- 2. Location ID not null
    SELECT
        'location_id_not_null',
        'NOT_NULL',
        SUM(CASE WHEN location_id IS NULL THEN 1 ELSE 0 END),
        COUNT(*),
        0.0,
        NULL,
        'FAIL',
        'Every Taxi Zone record must have a location_id.'
    FROM base
    UNION ALL
    -- 3. Location ID unique
    SELECT
        'location_id_unique',
        'UNIQUE',
        COALESCE(
            (
                SELECT SUM(cnt - 1)
                FROM (
                    SELECT
                        location_id,
                        COUNT(*) AS cnt
                    FROM base
                    WHERE location_id IS NOT NULL
                    GROUP BY location_id
                    HAVING COUNT(*) > 1
                )
            ),
            0
        ),
        COUNT(*),
        0.0,
        NULL,
        'FAIL',
        'Non-null location_id values must be unique.'
    FROM base
    UNION ALL
    -- 4. Location ID positive
    SELECT
        'location_id_positive',
        'RANGE',
        SUM(
            CASE
                WHEN location_id IS NOT NULL
                     AND location_id <= 0
                THEN 1
                ELSE 0
            END
        ),
        COUNT(*),
        0.0,
        NULL,
        'FAIL',
        'location_id must be a positive identifier.'
    FROM base
    UNION ALL
    -- 5. Borough completeness
    SELECT
        'borough_not_null',
        'NOT_NULL',
        SUM(CASE WHEN borough IS NULL THEN 1 ELSE 0 END),
        COUNT(*),
        0.0,
        NULL,
        'WARN',
        'Null borough values require review.'
    FROM base
    UNION ALL
    -- 6. Zone completeness
    SELECT
        'zone_not_null',
        'NOT_NULL',
        SUM(CASE WHEN zone IS NULL THEN 1 ELSE 0 END),
        COUNT(*),
        0.0,
        NULL,
        'WARN',
        'Null zone values require review.'
    FROM base
    UNION ALL
    -- 7. Service zone completeness
    SELECT
        'service_zone_not_null',
        'NOT_NULL',
        SUM(CASE WHEN service_zone IS NULL THEN 1 ELSE 0 END),
        COUNT(*),
        0.0,
        NULL,
        'WARN',
        'Null service_zone values require review.'
    FROM base
    UNION ALL
    -- 8. Borough domain
    SELECT
        'borough_domain',
        'DOMAIN',
        SUM(
            CASE
                WHEN borough IS NOT NULL
                 AND TRIM(borough) NOT IN (
                    'EWR',
                    'Queens',
                    'Bronx',
                    'Manhattan',
                    'Staten Island',
                    'Brooklyn',
                    'Unknown'
                 )
                THEN 1
                ELSE 0
            END
        ),
        COUNT(*),
        0.0,
        NULL,
        'WARN',
        'Borough must use an accepted Taxi Zone source classification.'
    FROM base
    UNION ALL
    -- 9. Service zone domain
    SELECT
        'service_zone_domain',
        'DOMAIN',
        SUM(
            CASE
                WHEN service_zone IS NOT NULL
                 AND TRIM(service_zone) NOT IN (
                    'EWR',
                    'Boro Zone',
                    'Yellow Zone',
                    'Airports'
                 )
                THEN 1
                ELSE 0
            END
        ),
        COUNT(*),
        0.0,
        NULL,
        'WARN',
        'service_zone must use an accepted Taxi Zone source classification.'
    FROM base
    UNION ALL
    -- 10. Duplicate business records
    SELECT
        'full_row_unique',
        'UNIQUE',
        COALESCE(
            (
                SELECT SUM(cnt - 1)
                FROM (
                    SELECT
                        location_id,
                        borough,
                        zone,
                        service_zone,
                        COUNT(*) AS cnt
                    FROM base
                    GROUP BY
                        location_id,
                        borough,
                        zone,
                        service_zone
                    HAVING COUNT(*) > 1
                )
            ),
            0
        ),
        COUNT(*),
        0.0,
        NULL,
        'WARN',
        'Duplicate business-content rows should be reviewed.'
    FROM base
    UNION ALL
    -- 11. Special-location consistency
    SELECT
        'special_location_consistency',
        'CONSISTENCY',
        SUM(
            CASE
                WHEN UPPER(TRIM(borough)) = 'UNKNOWN'
                     AND (
                         zone IS NOT NULL
                         OR service_zone IS NOT NULL
                     )
                THEN 1

                WHEN UPPER(TRIM(zone)) = 'OUTSIDE OF NYC'
                     AND (
                         borough IS NOT NULL
                         OR service_zone IS NOT NULL
                     )
                THEN 1

                ELSE 0
            END
        ),
        COUNT(*),
        0.0,
        NULL,
        'WARN',
        'Special Taxi Zone classifications should remain internally consistent.'
    FROM base
    UNION ALL
    -- 12. EWR consistency
    SELECT
        'ewr_consistency',
        'CONSISTENCY',
        SUM(
            CASE
                WHEN UPPER(TRIM(borough)) = 'EWR'
                     AND (
                         COALESCE(UPPER(TRIM(service_zone)), '') <> 'EWR'
                         OR COALESCE(UPPER(TRIM(zone)), '') <> 'NEWARK AIRPORT'
                     )
                THEN 1

                WHEN UPPER(TRIM(service_zone)) = 'EWR'
                     AND (
                         COALESCE(UPPER(TRIM(borough)), '') <> 'EWR'
                         OR COALESCE(UPPER(TRIM(zone)), '') <> 'NEWARK AIRPORT'
                     )
                THEN 1

                ELSE 0
            END
        ),
        COUNT(*),
        0.0,
        NULL,
        'WARN',
        'EWR records should consistently map to Newark Airport and EWR.'
    FROM base
    UNION ALL
    -- 13. Source file metadata
    SELECT
        'source_file_not_null',
        'NOT_NULL',
        SUM(CASE WHEN source_file IS NULL THEN 1 ELSE 0 END),
        COUNT(*),
        0.0,
        NULL,
        'FAIL',
        'Every Bronze record must retain source file metadata.'
    FROM base
    UNION ALL
    -- 14. Source version metadata
    SELECT
        'source_version_not_null',
        'NOT_NULL',
        SUM(CASE WHEN source_file_version IS NULL THEN 1 ELSE 0 END),
        COUNT(*),
        0.0,
        NULL,
        'FAIL',
        'Every Bronze record must retain source version metadata.'
    FROM base
    UNION ALL
    -- 15. Batch ID metadata
    SELECT
        'batch_id_not_null',
        'NOT_NULL',
        SUM(CASE WHEN batch_id IS NULL THEN 1 ELSE 0 END),
        COUNT(*),
        0.0,
        NULL,
        'FAIL',
        'Every Bronze record must retain batch metadata.'
    FROM base
    UNION ALL
    -- 16. Ingestion timestamp metadata
    SELECT
        'ingested_at_not_null',
        'NOT_NULL',
        SUM(CASE WHEN ingested_at IS NULL THEN 1 ELSE 0 END),
        COUNT(*),
        0.0,
        NULL,
        'FAIL',
        'Every Bronze record must have an ingestion timestamp.'
    FROM base
),
measurements AS (
    -- 17. Row count measurement
    SELECT
        'row_count_measurement' AS check_name,
        'MEASURE' AS check_type,
        0 AS fail_count,
        COUNT(*) AS total_count,
        0.0 AS threshold_pct,
        CAST(COUNT(*) AS DOUBLE) AS metric_value,
        'INFO' AS severity,
        'Current Bronze Taxi Zone row count.' AS details
    FROM base
    UNION ALL
    -- 18. Location ID range measurement
    SELECT
        'location_id_range_measurement',
        'MEASURE',
        0,
        COUNT(*),
        0.0,
        CAST(MAX(location_id) - MIN(location_id) + 1 AS DOUBLE),
        'INFO',
        CONCAT(
            'LocationID range: ',
            CAST(MIN(location_id) AS STRING),
            ' to ',
            CAST(MAX(location_id) AS STRING)
        )
    FROM base
    UNION ALL
    -- 19. Location ID coverage measurement
    SELECT
        'location_id_coverage_measurement',
        'MEASURE',
        0,
        COUNT(*),
        0.0,
        CAST(COUNT(DISTINCT location_id) AS DOUBLE),
        'INFO',
        'Number of distinct LocationIDs currently present.'
    FROM base
),
all_checks AS (
    SELECT * FROM checks
    UNION ALL
    SELECT * FROM measurements
)
INSERT INTO `ftw-week-08`.`02-bronze`.90_validate_taxi_zones
SELECT
    dq_run_id AS run_id,
    current_timestamp() AS executed_at,
    'BRONZE' AS layer,
    'taxi_zones_raw' AS dataset,
    MAX(b.batch_id) AS batch_id,
    MAX(b.source_file_version) AS source_version_id,
    NULL AS code_revision,
    c.check_name,
    c.check_type,
    CASE
        WHEN c.severity = 'INFO' THEN 'INFO'
        WHEN c.fail_count = 0 THEN 'PASS'
        WHEN c.total_count IS NULL OR c.total_count = 0 THEN c.severity
        WHEN c.fail_count / NULLIF(c.total_count, 0) <= c.threshold_pct
            THEN 'WARN'
        ELSE c.severity
    END AS status,
    c.severity,
    CAST(c.fail_count AS BIGINT),
    CAST(c.total_count AS BIGINT),
    CASE
        WHEN c.total_count IS NULL OR c.total_count = 0 THEN NULL
        ELSE ROUND(c.fail_count / c.total_count * 100, 2)
    END AS fail_pct,
    c.threshold_pct,
    c.metric_value,
    'Data Engineering Team' AS owner,
    c.details,
    NULL AS evidence_location
FROM all_checks c
CROSS JOIN (
    SELECT
        MAX(batch_id) AS batch_id,
        MAX(source_file_version) AS source_file_version
    FROM base
) b
GROUP BY
    c.check_name,
    c.check_type,
    c.severity,
    c.fail_count,
    c.total_count,
    c.threshold_pct,
    c.metric_value,
    c.details;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review Current DQ Run
-- MAGIC
-- MAGIC The following query displays all validation results generated for the current
-- MAGIC run.
-- MAGIC
-- MAGIC INFO measurements are retained for observability but are excluded from the
-- MAGIC pass/fail evaluation.

-- COMMAND ----------

SELECT
    check_name,
    check_type,
    status,
    severity,
    fail_count,
    total_count,
    fail_pct,
    threshold_pct,
    metric_value,
    details
FROM `ftw-week-08`.`02-bronze`.90_validate_taxi_zones
WHERE run_id = dq_run_id
ORDER BY
    CASE status
        WHEN 'FAIL' THEN 1
        WHEN 'WARN' THEN 2
        WHEN 'PASS' THEN 3
        WHEN 'INFO' THEN 4
    END,
    check_name;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## DQ Summary
-- MAGIC
-- MAGIC The summary provides the number of checks in each status and the overall
-- MAGIC pass rate.
-- MAGIC
-- MAGIC INFO measurements are excluded from the pass-rate calculation.

-- COMMAND ----------

SELECT
    COUNT(CASE WHEN status = 'PASS' THEN 1 END) AS passed_checks,
    COUNT(CASE WHEN status = 'WARN' THEN 1 END) AS warning_checks,
    COUNT(CASE WHEN status = 'FAIL' THEN 1 END) AS failed_checks,
    COUNT(CASE WHEN status = 'INFO' THEN 1 END) AS informational_checks,
    COUNT(
        CASE
            WHEN status IN ('PASS', 'WARN', 'FAIL')
            THEN 1
        END
    ) AS evaluated_checks,
    ROUND(
        100.0 * COUNT(CASE WHEN status = 'PASS' THEN 1 END)
        /
        NULLIF(
            COUNT(
                CASE
                    WHEN status IN ('PASS', 'WARN', 'FAIL')
                    THEN 1
                END
            ),
            0
        ),
        2
    ) AS pass_rate_pct
FROM `ftw-week-08`.`02-bronze`.90_validate_taxi_zones
WHERE run_id = dq_run_id;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Bronze DQ Exit Gate
-- MAGIC
-- MAGIC ### Gate Rule
-- MAGIC
-- MAGIC - Any `FAIL` result → Bronze validation is **BLOCKED**
-- MAGIC - `WARN` results → validation may continue, but warnings must be reviewed
-- MAGIC - `INFO` results → informational only
-- MAGIC
-- MAGIC The gate is a validation decision and does not modify the Bronze table.

-- COMMAND ----------

SELECT
    CASE
        WHEN COUNT(CASE WHEN status = 'FAIL' THEN 1 END) > 0
            THEN 'BLOCKED'
        ELSE 'PASSED'
    END AS bronze_dq_gate,

    COUNT(CASE WHEN status = 'FAIL' THEN 1 END) AS fail_count,
    COUNT(CASE WHEN status = 'WARN' THEN 1 END) AS warn_count,
    COUNT(CASE WHEN status = 'PASS' THEN 1 END) AS pass_count,
    COUNT(CASE WHEN status = 'INFO' THEN 1 END) AS info_count
FROM `ftw-week-08`.`02-bronze`.90_validate_taxi_zones
WHERE run_id = dq_run_id;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Source → Bronze Reconciliation
-- MAGIC
-- MAGIC Taxi Zone Lookup is a reference snapshot. The Bronze table should represent
-- MAGIC the source snapshot without unintended loss, duplication, or modification.
-- MAGIC
-- MAGIC The reconciliation checks:
-- MAGIC
-- MAGIC 1. Source row count vs Bronze row count
-- MAGIC 2. Source distinct LocationIDs vs Bronze distinct LocationIDs
-- MAGIC 3. Source business records missing from Bronze
-- MAGIC 4. Bronze business records not present in the source
-- MAGIC
-- MAGIC The comparison uses the business columns:
-- MAGIC
-- MAGIC - `location_id`
-- MAGIC - `borough`
-- MAGIC - `zone`
-- MAGIC - `service_zone`
-- MAGIC
-- MAGIC This is a validation-only operation.

-- COMMAND ----------

CREATE OR REPLACE TEMP VIEW taxi_zone_source_validation AS
SELECT
    CAST(LocationID AS INT) AS location_id,
    Borough AS borough,
    Zone AS zone,
    service_zone
FROM read_files(
    '/Volumes/ftw-week-08/00-source/group_a_source/taxi_zones/taxi_zone_lookup.csv',
    format => 'csv',
    header => true
);

-- COMMAND ----------

SELECT
    source_count,
    bronze_count,
    source_distinct_location_ids,
    bronze_distinct_location_ids,
    source_count - bronze_count AS row_count_difference,
    source_distinct_location_ids
        - bronze_distinct_location_ids AS distinct_id_difference
FROM (
    SELECT
        (
            SELECT COUNT(*)
            FROM taxi_zone_source_validation
        ) AS source_count,
        (
            SELECT COUNT(*)
            FROM `ftw-week-08`.`02-bronze`.taxi_zones_raw
        ) AS bronze_count,
        (
            SELECT COUNT(DISTINCT location_id)
            FROM taxi_zone_source_validation
        ) AS source_distinct_location_ids,
        (
            SELECT COUNT(DISTINCT location_id)
            FROM `ftw-week-08`.`02-bronze`.taxi_zones_raw
        ) AS bronze_distinct_location_ids
);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Business-Content Reconciliation
-- MAGIC
-- MAGIC Row counts alone are not sufficient to prove that the Bronze table matches the
-- MAGIC source.
-- MAGIC
-- MAGIC Two-way anti-joins are used to identify:
-- MAGIC
-- MAGIC - Records present in the source but missing from Bronze
-- MAGIC - Records present in Bronze but absent from the source
-- MAGIC
-- MAGIC Expected result for an unchanged full-refresh snapshot:
-- MAGIC
-- MAGIC **0 rows in both directions.**

-- COMMAND ----------

SELECT
    s.*
FROM taxi_zone_source_validation s
LEFT ANTI JOIN `ftw-week-08`.`02-bronze`.taxi_zones_raw b
    ON s.location_id <=> b.location_id
   AND s.borough <=> b.borough
   AND s.zone <=> b.zone
   AND s.service_zone <=> b.service_zone
ORDER BY s.location_id;

-- COMMAND ----------

SELECT
    b.location_id,
    b.borough,
    b.zone,
    b.service_zone
FROM `ftw-week-08`.`02-bronze`.taxi_zones_raw b
LEFT ANTI JOIN taxi_zone_source_validation s
    ON b.location_id <=> s.location_id
   AND b.borough <=> s.borough
   AND b.zone <=> s.zone
   AND b.service_zone <=> s.service_zone
ORDER BY b.location_id;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## WARN / FAIL Investigation
-- MAGIC
-- MAGIC A non-zero DQ result should be investigated at record level before being
-- MAGIC classified as a true defect.
-- MAGIC
-- MAGIC This is especially important for the Taxi Zone source because it contains
-- MAGIC special classifications such as:
-- MAGIC
-- MAGIC - `Unknown`
-- MAGIC - `Outside of NYC`
-- MAGIC - `EWR`
-- MAGIC
-- MAGIC The following query exposes those records for review.

-- COMMAND ----------

SELECT
    location_id,
    borough,
    zone,
    service_zone
FROM `ftw-week-08`.`02-bronze`.taxi_zones_raw
WHERE
       UPPER(TRIM(borough)) = 'UNKNOWN'
    OR UPPER(TRIM(zone)) = 'OUTSIDE OF NYC'
    OR UPPER(TRIM(borough)) = 'EWR'
    OR UPPER(TRIM(service_zone)) = 'EWR'
ORDER BY location_id;

-- COMMAND ----------

SELECT
    check_name,
    check_type,
    status,
    severity,
    fail_count,
    total_count,
    fail_pct,
    details
FROM `ftw-week-08`.`02-bronze`.90_validate_taxi_zones
WHERE run_id = dq_run_id
  AND status IN ('FAIL', 'WARN')
ORDER BY
    CASE status
        WHEN 'FAIL' THEN 1
        WHEN 'WARN' THEN 2
    END,
    check_name;