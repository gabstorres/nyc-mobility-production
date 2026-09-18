# Proof: repeated ingestion leaves the dataset unchanged

Issue #46 · **TEMPLATE — not yet run.** Delete this line once filled in.

## What to demonstrate

Running the identical ingestion a second time changes nothing: no new rows, no
new batches, no changed measures.

## Procedure

1. Run the snapshot query below. Paste the output under **Before**.
2. Run the whole job again. Change nothing in the Volume.
3. Run the snapshot query again. Paste the output under **After**.

Nothing needs moving or dropping. The point is that a plain rerun is a no-op.

## Snapshot query

```sql
SELECT 'bronze_green_taxi'    AS object, COUNT(*) AS value FROM `ftw-week-08`.`02-bronze`.green_taxi_raw
UNION ALL SELECT 'bronze_weather_responses', COUNT(*) FROM `ftw-week-08`.`02-bronze`.open_meteo_weather_raw
UNION ALL SELECT 'bronze_taxi_zones',        COUNT(*) FROM `ftw-week-08`.`02-bronze`.taxi_zones_raw
UNION ALL SELECT 'silver_clean',             COUNT(*) FROM `ftw-week-08`.`03-silver`.green_taxi_clean
UNION ALL SELECT 'silver_quarantine',        COUNT(*) FROM `ftw-week-08`.`03-silver`.green_taxi_quarantine
UNION ALL SELECT 'silver_weather_hourly',    COUNT(*) FROM `ftw-week-08`.`03-silver`.weather_hourly
UNION ALL SELECT 'integration_zone_map',     COUNT(*) FROM `ftw-week-08`.`04-integration`.trip_zone_map
UNION ALL SELECT 'integration_weather_map',  COUNT(*) FROM `ftw-week-08`.`04-integration`.trip_weather_map
UNION ALL SELECT 'gold_fact_taxi_trip',      COUNT(*) FROM `ftw-week-08`.`05-gold`.fact_taxi_trip
UNION ALL SELECT 'gold_fact_weather_hourly', COUNT(*) FROM `ftw-week-08`.`05-gold`.fact_weather_hourly
UNION ALL SELECT 'analytics_q1_rows',        COUNT(*) FROM `ftw-week-08`.`06-analytics`.activity_by_time_and_zone
UNION ALL SELECT 'fare_total_cents',
       CAST(ROUND(SUM(fare_amount_usd), 2) * 100 AS BIGINT) FROM `ftw-week-08`.`05-gold`.fact_taxi_trip;
```

```sql
SELECT source_system, source_object, batch_id, status, row_count,
       SUBSTRING(content_sha256, 1, 12) AS sha, completed_at
FROM `ftw-week-08`.`01-control`.ingestion_batches
ORDER BY source_system, source_object;
```

## Before

_Paste both result tables._

## After

_Paste both result tables._

## What must hold

| Check | Expected |
|---|---|
| Every row of the first snapshot | identical before and after |
| `fare_total_cents` | identical — measures unchanged, not just counts |
| `ingestion_batches` | same rows, same `batch_id`s, same `completed_at` |
| New `SUCCESS` batches | none |
| `content_sha256` per source | unchanged, which is *why* the loaders skipped |
| `10_load_green_taxi` task output | zero rows returned — no file was new |

Counts alone are not sufficient, which is why the fare total is in the snapshot:
a rebuild that dropped and re-inserted the same number of rows with different
values would pass a count comparison and fail this one.

## Why it holds

Green Taxi skips a file whose content hash already has a `SUCCESS` batch. Weather
and Taxi Zones merge on a business key and only write when content or lineage
changed. Everything above Bronze is a deterministic full rebuild from Bronze
(D22), so identical Bronze produces identical Silver, Gold and Analytics.

`ingested_at` is expected to stay unchanged too, because no row is rewritten. A
loader that reran with `CREATE OR REPLACE` would reset it on every row, which is
the behaviour D11's implementation note rejected.
