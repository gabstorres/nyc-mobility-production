# 02 — Bronze

Contains Bronze table definitions, source-preserving landing code, and Bronze validation for each source.

Bronze must preserve received records and provenance without silently cleaning, deduplicating, or dropping them.

| File | Source | Purpose |
|---|---|---|
| `10_load_green_taxi.py` | Green Taxi | Creates `green_taxi_raw` if missing, then loads new monthly Parquet files via `src/ingestion/green_taxi.py` |
| `20_load_open_meteo.sql` | Open-Meteo | Creates `open_meteo_weather_raw` if missing, then merges the landed weather response |
| `30_load_taxi_zones.sql` | Taxi Zones | Creates `taxi_zones_raw` if missing, then full-refreshes from the zone lookup CSV |
| `90_validate_green_taxi.sql` | Green Taxi | Bronze gate: batch reconciliation, provenance, content stability |
| `90_validate_taxi_zones.sql` | Taxi Zones | Bronze gate (Databricks SQL notebook) |

Each load file creates its own table if it is missing, so it can run on its own. Run a source's load, then that source's `90_validate_<source>`. Each source has its own gate (see `docs/validation.md`).
