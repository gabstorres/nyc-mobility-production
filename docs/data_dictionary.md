# Field dictionary and source-to-target mapping

Status: mapping template. Confirm actual input and upstream table names before SQL. Use snake_case and fully qualified `catalog.schema.table` references. No silent renames or drops.

| Source field | Bronze field | Proposed Silver field | Proposed Gold use | Change / meaning / validation |
|---|---|---|---|---|
| lpep_pickup_datetime | lpep_pickup_datetime | pickup_datetime_local | Pickup time; date/hour keys | Rename; source timezone semantics pending; preserve raw value |
| lpep_dropoff_datetime | lpep_dropoff_datetime | dropoff_datetime_local | Drop-off time | Rename; validate duration and DST handling |
| PULocationID | PULocationID | pickup_location_id | pickup_zone_key via built dimension | Rename and FK lookup; count unmatched |
| DOLocationID | DOLocationID | dropoff_location_id | dropoff_zone_key via built dimension | Rename and FK lookup; count unmatched |
| trip_distance | trip_distance | trip_distance_miles | trip_distance_miles | Explicit units; profile zero/negative values |
| fare_amount | fare_amount | fare_amount_usd | fare_amount_usd | Metered fare, not total charge; numeric precision pending |
| total_amount | total_amount | total_amount_usd | total_amount_usd | Total charged as defined by TLC; distinguish from fare |
| hourly.time | Raw JSON path retained | weather_hour_utc | Weather hour key | Parse using explicit request timezone; unique per location/hour |
| LocationID | LocationID | location_id | Zone source identifier | Reference uniqueness/non-null gate |
| Pickup/drop-off timestamps | Original values retained | trip_duration_seconds | trip_duration_seconds | Derived; timezone and invalid-duration policy pending |

Expand to EVERY discovered source field, including optional fields and fees. Record retained/dropped status, rationale, data types before/after, nullability, units, accepted values, derivation and affected metric. Preserve unknown/new fields in raw storage and surface schema changes for review.

Metadata dictionary must include source_system, source_file/source_url, source_version_id, source checksum, source period/request window, ingested_at (UTC), batch_id and source-row locator where practical. Separate run_id from batch_id. Define deterministic row serialization and identity only after duplicate profiling.
