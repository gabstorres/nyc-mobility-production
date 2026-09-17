-- ============================================================
-- Validation queries for green_taxi_raw Bronze ingestion
--
-- Run these anytime to confirm ingestion is behaving correctly —
-- reusable checks, not one-off test code.
-- ============================================================


-- 1. Row counts per file, cross-checked against ingestion_batches.
--    Confirms Bronze row counts match what the control table recorded
--    as SUCCESS for the same batch.
SELECT
    b.source_file,
    b.batch_id,
    COUNT(*) AS bronze_row_count,
    ib.row_count AS logged_row_count,
    CASE WHEN COUNT(*) = ib.row_count THEN 'MATCH' ELSE 'MISMATCH' END AS reconciliation
FROM `ftw-week-08`.`02-bronze`.green_taxi_raw b
JOIN `ftw-week-08`.`01-control`.ingestion_batches ib
    ON b.batch_id = ib.batch_id
GROUP BY b.source_file, b.batch_id, ib.row_count
ORDER BY b.source_file;


-- 2. No duplicate rows per file after a rerun. Since green taxi trips have
--    no natural key, this checks whether the SAME batch_id appears more
--    than once (would indicate a rerun accidentally re-inserted the same
--    successful batch instead of skipping it).
SELECT
    batch_id,
    source_file,
    COUNT(*) AS row_count
FROM `ftw-week-08`.`02-bronze`.green_taxi_raw
GROUP BY batch_id, source_file
ORDER BY source_file;


-- 3. Every Bronze row must carry complete provenance. A null in any of
--    these means a row was written without going through the standard
--    ingestion path (e.g. inserted manually, bypassing batch_tracking.py).
SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN source_system IS NULL THEN 1 ELSE 0 END) AS null_source_system,
    SUM(CASE WHEN source_file IS NULL THEN 1 ELSE 0 END) AS null_source_file,
    SUM(CASE WHEN ingested_at IS NULL THEN 1 ELSE 0 END) AS null_ingested_at,
    SUM(CASE WHEN batch_id IS NULL THEN 1 ELSE 0 END) AS null_batch_id
FROM `ftw-week-08`.`02-bronze`.green_taxi_raw;


-- 4. Every SUCCESS batch in the control table should have a matching set
--    of rows in Bronze. Flags a batch marked SUCCESS with no corresponding
--    data — a sign the log and the table have drifted out of sync.
SELECT
    ib.batch_id,
    ib.source_object,
    ib.row_count AS logged_row_count,
    COUNT(b.batch_id) AS actual_bronze_rows
FROM `ftw-week-08`.`01-control`.ingestion_batches ib
LEFT JOIN `ftw-week-08`.`02-bronze`.green_taxi_raw b
    ON ib.batch_id = b.batch_id
WHERE ib.source_system = 'green_taxi'
  AND ib.status = 'SUCCESS'
GROUP BY ib.batch_id, ib.source_object, ib.row_count
HAVING COUNT(b.batch_id) != ib.row_count
ORDER BY ib.source_object;

-- 5. Confirm each month's row content is stable across subsequent loads.
--    Run this any time — if March's data ever changes after April/May load,
--    something is silently mutating already-committed rows.

SELECT
    source_file,
    COUNT(*) AS row_count,
    md5(
        concat_ws('|',
            sort_array(collect_list(
                concat_ws('~', CAST(VendorID AS STRING), CAST(lpep_pickup_datetime AS STRING),
                               CAST(lpep_dropoff_datetime AS STRING), CAST(fare_amount AS STRING))
            ))
        )
    ) AS content_fingerprint
FROM `ftw-week-08`.`02-bronze`.green_taxi_raw
GROUP BY source_file
ORDER BY source_file;
