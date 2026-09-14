# Source Profile

This document records each source's schema, volume, date coverage, nulls, duplicate candidates, keys, partitions, and anomalies.

## Status

Source profiling is currently in progress. Listed source URLs are not proof of successful downloads or valid data. Each source must be profiled and supported by recorded evidence before downstream transformations begin.

## File Inventory

For each taxi month and reference snapshot, record the source URL, filename, retrieval time, file size, SHA-256 checksum, file readability, row count, schema, and observed event range.

Compare the March, April, and May schemas before accepting a source contract. Do not assume that filenames guarantee event-date coverage.

| Source | Rows | Schema | Observed Dates | Key Nulls | Duplicate Candidates | Other Anomalies | Evidence |
|---|---:|---|---|---|---|---|---|
| Taxi March 2026 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| Taxi April 2026 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| Taxi May 2026 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| Taxi zones | 265 | `LocationID`, `Borough`, `Zone`, `service_zone` | Snapshot | 0 nulls across all columns | No duplicate `LocationID` values found | Sentinel records found at `LocationID` 264 and 265; special Borough values include `EWR`, `N/A`, and `Unknown` | `notebooks/profile_taxi_zones` |
| Weather (Open-Meteo) | 2,208 | `time`, `temperature_2m`, `precipitation`, `weather_code` | 2026-03-01T00:00 to 2026-05-31T23:00 (UTC), no gaps | 0 nulls across all columns | No duplicate `time` values found | 12 distinct `weather_code` values; 0 rows with negative precipitation or out-of-range temperature; requested coordinates snapped to a grid point ~3-4 km away (40.738136, -74.04254, elevation 32.0m) | `notebooks/profile_open_meteo.ipynb` |

Profile null rates for every column, full-row equality, candidate-key collisions, within-file and across-file duplicate candidates, unexpected codes, negative or zero measures, missing timestamps, durations, out-of-month events, and pickup and drop-off reference coverage.

The public taxi schema does not establish a unique trip ID. Do not treat `VendorID` as a vehicle or trip key.

## Taxi Zones Source Profile

### Source Details

- **Source file:** `taxi_zone_lookup.csv`
- **Source path:** `/Volumes/ftw-week-08/00-source/group_a_source/taxi_zones/taxi_zone_lookup.csv`
- **File format:** CSV
- **Dataset type:** Reference snapshot
- **Profiling notebook:** `notebooks/profile_taxi_zones`

### Dataset Schema

| Column | Description |
|---|---|
| `LocationID` | Identifier assigned to a taxi zone |
| `Borough` | Borough or special geographic classification |
| `Zone` | Taxi zone name |
| `service_zone` | Taxi service-zone classification |

### Row Count

The Taxi Zones CSV contains **265 rows**.

### Key Validation

`LocationID` was evaluated as the candidate key for the Taxi Zones reference dataset.

The uniqueness query returned no rows, which means:

- No duplicate `LocationID` values were detected.
- All 265 records have distinct `LocationID` values.
- `LocationID` is suitable as the candidate business key for downstream reference joins, subject to the documented sentinel-value policy.

### Null Analysis

| Column | Null Count |
|---|---:|
| `LocationID` | 0 |
| `Borough` | 0 |
| `Zone` | 0 |
| `service_zone` | 0 |

No SQL `NULL` values were found in the four source columns.

Values such as `N/A` and `Unknown` are not SQL nulls. They are explicit source values and must be handled separately during Silver-layer standardization.

### Distinct Borough Values

The following eight distinct `Borough` values were identified:

- `Bronx`
- `Brooklyn`
- `EWR`
- `Manhattan`
- `N/A`
- `Queens`
- `Staten Island`
- `Unknown`

The values `EWR`, `N/A`, and `Unknown` require explicit handling because they are not standard New York City borough names.

These values should not be silently removed or automatically converted to SQL `NULL` until the team agrees on the zone-standardization policy.

### Sentinel Records

Two sentinel or special reference records were identified:

| LocationID | Borough | Zone | service_zone |
|---:|---|---|---|
| 264 | `Unknown` | `N/A` | `N/A` |
| 265 | `N/A` | `Outside of NYC` | `N/A` |

These records represent special conditions rather than ordinary NYC taxi zones:

- `LocationID` 264 represents an unknown or unavailable zone.
- `LocationID` 265 represents a location outside New York City.

The sentinel records must remain identifiable during downstream transformations so unmatched, unknown, and outside-NYC trips are not silently dropped.

### Profiling Findings

- The source file is readable as CSV.
- The file contains 265 rows.
- `LocationID` contains no null values.
- No duplicate `LocationID` values were detected.
- No SQL null values were detected in `LocationID`, `Borough`, `Zone`, or `service_zone`.
- Eight distinct Borough values were identified.
- `EWR`, `N/A`, and `Unknown` are special Borough values requiring a documented standardization rule.
- `LocationID` 264 and 265 are sentinel records.
- Sentinel records must be preserved or intentionally mapped based on the team's approved Silver-layer policy.
- Downstream joins should measure how many taxi records match regular zones, sentinel zones, and no zone record.

### Profiling Conclusion

The Taxi Zones CSV is suitable for use as a reference source for downstream processing.

`LocationID` is unique and has complete coverage within the reference file. However, the dataset contains special values that require documented treatment during Silver-layer cleaning and standardization.

The profiling task does not clean, replace, or remove these values. It records the source behavior so the team can define the transformation policy before building downstream tables.

### Recommended Downstream Rules

The following items require team agreement before Silver processing:

1. Define whether `EWR` will remain a separate geographic classification.
2. Define how `Borough = 'Unknown'` will be standardized.
3. Define how `Borough = 'N/A'` will be represented.
4. Preserve the distinction between `LocationID` 264 and 265.
5. Measure pickup and drop-off join coverage against the Taxi Zones reference.
6. Do not use an inner join if doing so silently removes unknown or unmatched trip locations.
7. Record row counts for matched zones, sentinel zones, and unmatched zone IDs.

## Open-Meteo Weather Source Profile

### Source Details

- **Endpoint:** `https://archive-api.open-meteo.com/v1/archive`
- **Requested coordinates:** 40.7128, -74.0060 — proposed city-level representative point, not zone-specific
- **Returned (grid-snapped) coordinates:** 40.738136, -74.04254, elevation 32.0m — Open-Meteo snaps the request to its nearest grid cell rather than the exact point requested, roughly 3-4 km from the requested coordinate; this reinforces decision D06's caveat that this is a city-level approximation, not zone-level weather
- **Requested variables:** `temperature_2m`, `precipitation`, `weather_code`
- **Requested timezone:** `UTC` (explicit); response confirms `utc_offset_seconds: 0`, `timezone`/`timezone_abbreviation`: `GMT`/`GMT`
- **Request window profiled:** 2026-03-01 through 2026-05-31 (the full three-month window, not just a sample)
- **Dataset type:** External REST API, hourly time series (not a static file)
- **Model:** not specified in the request; the default model was used and is not yet pinned (see Recommended Downstream Rules)
- **Profiling notebook:** `notebooks/profile_open_meteo.ipynb`
- **Sample response evidence:** saved to `/Volumes/ftw-week-08/00-source/group_a_source/weather/open_meteo_mar_may_2026_sample.json`, SHA-256 `4e6c8d0b238f1329245af1e06081cc0d43c0f46501a38d846605065fb4e87e96`

### Response Schema

Top-level response keys: `latitude`, `longitude`, `generationtime_ms`, `utc_offset_seconds`, `timezone`, `timezone_abbreviation`, `elevation`, `hourly_units`, `hourly`.

| Field | Description | Unit (`hourly_units`) |
|---|---|---|
| `hourly.time` | Hour timestamp | `iso8601` |
| `hourly.temperature_2m` | Air temperature at 2m | `°C` |
| `hourly.precipitation` | Hourly precipitation | `mm` |
| `hourly.weather_code` | WMO weather interpretation code | `wmo code` |

`generationtime_ms` for the full March–May request was ~1.2ms — response generation is fast and not a practical ingestion bottleneck.

### Row Count / Coverage

Expected hourly rows for 2026-03-01 through 2026-05-31: **2,208** (92 days × 24 hours).

Actual hourly rows returned: **2,208**. Gap: **0**. Full hourly coverage confirmed for the entire March–May 2026 window with no missing hours.

### Key Validation

`time` was evaluated as the candidate key for the hourly weather series.

The duplicate-timestamp query (`GROUP BY time HAVING COUNT(*) > 1`) returned **0 rows**:

- No duplicate `time` values were detected across the 2,208-row window.
- `time` is suitable as the key for the `fact_weather_hourly` grain (per `docs/data_model.md`).

### Null Analysis

| Column | Null Count |
|---|---:|
| `time` | 0 |
| `temperature_2m` | 0 |
| `precipitation` | 0 |
| `weather_code` | 0 |

No nulls were found in any of the four fields across the full profiled window.

### Distinct Weather Code Values

**12 distinct `weather_code` values** were returned: `0`, `1`, `2`, `3`, `51`, `53`, `55`, `61`, `63`, `71`, `73`, `75`.

Mapped against Open-Meteo's published WMO code table, these correspond to: 0 = clear sky, 1 = mainly clear, 2 = partly cloudy, 3 = overcast, 51/53/55 = light/moderate/dense drizzle, 61/63 = slight/moderate rain, 71/73/75 = slight/moderate/heavy snowfall.

No fog (45/48), freezing-rain (56/57/66/67), shower (80-86), or thunderstorm (95/96/99) codes appeared in this March-May 2026 window. This is an observation about this specific window, not a guarantee those codes can't appear in other periods — the weather-code mapping table (see Recommended Downstream Rules) should still cover the full WMO code set, not just the 12 observed here.

### Anomalies

The anomaly query (`precipitation < 0 OR temperature_2m < -50 OR temperature_2m > 60`) returned **0 rows**. No negative precipitation values or out-of-range temperatures were found in the profiled window.

### HTTP Status and Empty-Response Behavior

- Successful request status code: **200**
- Out-of-range request (2099-01-01 to 2099-01-02) status code: **400**, with JSON error body `{"error":true,"reason":"Bad Request"}`

The API returns an explicit 4xx error with a JSON error body for an invalid/out-of-range date window — it does not return a 200 with empty `hourly` arrays. Ingestion code must treat a non-200 status as a hard failure, not interpret it as "no data for this period."

### Repeated-Request Determinism

Two identical requests for the same window were compared with `generationtime_ms` excluded (since that field is expected to vary per call): **content was identical** (`same content on repeat: True`, both returned status 200). The API is deterministic for a fixed historical window, aside from that one volatile metadata field.

### Rate-Limit Behavior

No per-request rate-limit headers were present in the response (observed headers: `Date`, `Content-Type`, `Transfer-Encoding`, `Connection`, `Content-Encoding` — no `X-RateLimit-*` or similar). No API key is required for non-commercial use.

Open-Meteo's published free-tier fair-usage limits (from their pricing page, not the archive-API docs page, which doesn't state numeric quotas itself): **600 calls/minute, 5,000/hour, 10,000/day, 300,000/month**, rate-limited on a fair-usage basis with no uptime guarantee for the free tier. The bounded retry (429/5xx + backoff) implemented in the notebook is the intended safeguard for real ingestion runs; this profiling exercise made only a handful of calls and did not test the throttling threshold itself, per the "do not deliberately stress the service" guidance.

### Profiling Findings

- The endpoint is reachable and returns valid JSON with status 200 for a well-formed request.
- The full March–May 2026 window returns exactly the expected 2,208 hourly rows with zero gaps.
- No duplicate `time` values and no nulls were found in any of the four fields.
- 12 distinct `weather_code` values were observed; none indicate malformed data.
- No negative precipitation or implausible temperature values were found.
- Requested coordinates are silently snapped to the nearest model grid cell (~3-4 km away here) rather than matched exactly — record the returned coordinates and elevation as part of any reproducible run, not just the requested ones.
- Invalid/out-of-range windows return HTTP 400 with a JSON error body, not an empty 200.
- Repeated identical requests return identical content (aside from `generationtime_ms`).
- No rate-limit headers are returned per-request; documented limits are published separately as fair-usage quotas.

### Profiling Conclusion

The Open-Meteo historical archive API is confirmed suitable as the weather source for the documented March–May 2026 coverage: it returns complete, duplicate-free, null-free hourly data for the full window, behaves deterministically on repeat calls, and fails loudly (HTTP 400) rather than silently on bad requests.

Remaining caveats that do not block this profiling task but should be resolved before Silver: the single representative coordinate is a city-level approximation (confirmed here to be ~3-4 km from the exact requested point), the model parameter is not yet pinned, and the weather-code-to-condition / precipitation-band mappings referenced in the business questions are not yet defined.

### Recommended Downstream Rules

The following items require team agreement before Silver processing:

1. Pin the `model` parameter explicitly once variable support across candidate models is confirmed, rather than relying on the API default used here.
2. Define and document the weather-code-to-condition and precipitation-band mappings referenced in the business questions, covering the full WMO code table rather than only the 12 codes observed in this window.
3. Confirm whether Open-Meteo revises historical hourly values after initial publication, and if so, define a re-fetch/reconciliation policy.
4. Confirm the single representative NYC coordinate (decision D06) is acceptable for all three business questions before finalizing the weather fact grain, given the confirmed ~3-4 km grid-snap offset from the requested point.
5. Confirm weather is attributed to trips using the pickup hour, per the documented assumption, and that this is implemented correctly at Silver.
6. Record the actual free-tier quota (600/min, 5,000/hour, 10,000/day, 300,000/month) in ingestion runbooks so batch/backfill jobs stay within fair-usage limits.

## Exit Gate

The source-profile exit gate passes only when the owner and reviewer agree on:

- Source schemas
- Date coverage
- Source volume
- Candidate keys and identity limitations
- Null and duplicate findings
- Special and sentinel values
- Documented anomalies
- Response contracts
- Evidence locations

Any unresolved issue affecting correctness blocks dependent transformations.