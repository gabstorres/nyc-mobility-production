-- ============================================================
-- Validation queries for ingestion_batches
--
-- Run these anytime to confirm the control table is behaving
-- correctly — not one-off test code, meant to be reusable.
--
-- Scope note: this validates the control table only. It does not
-- check any Bronze data table, since Bronze ingestion (Issue #20)
-- is a separate, later issue. Any ingestion into dev/sandbox
-- schemas prior to this point was exploratory profiling work, not
-- official Bronze ingestion.
-- ============================================================


-- 1. Basic sanity: table is populated and every batch has a status.
--    Run this first to get a quick shape of what's in the table.
SELECT
    status,
    COUNT(*) AS batch_count
FROM `ftw-week-08`.`01-control`.ingestion_batches
GROUP BY status
ORDER BY status;


-- 2. Stuck batches: no batch should remain DISCOVERED or STARTED
--    indefinitely. A healthy pipeline resolves every batch to
--    SUCCESS or FAILED. This flags anything that looks abandoned
--    (e.g. a crash that didn't even reach the FAILED update).
SELECT
    batch_id,
    source_system,
    source_object,
    status,
    discovered_at,
    started_at
FROM `ftw-week-08`.`01-control`.ingestion_batches
WHERE status IN ('DISCOVERED', 'STARTED')
  AND discovered_at < current_timestamp() - INTERVAL 1 DAY;


-- 3. Retry history: confirms a retry after failure creates a NEW
--    row rather than overwriting or losing the failed attempt.
--    Same content_sha256 with multiple batch_ids is expected and
--    healthy (failed attempt + successful retry). Same
--    content_sha256 appearing more than once with status = SUCCESS
--    is worth investigating (possible duplicate processing).
SELECT
    source_object,
    content_sha256,
    COUNT(*) AS attempt_count,
    SUM(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END) AS success_count,
    SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) AS failed_count
FROM `ftw-week-08`.`01-control`.ingestion_batches
GROUP BY source_object, content_sha256
HAVING COUNT(*) > 1
ORDER BY source_object;