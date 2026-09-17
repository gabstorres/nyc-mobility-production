# 02 — Bronze

Contains Bronze table definitions, source-preserving landing code, and Bronze validation for each source.

Bronze must preserve received records and provenance without silently cleaning, deduplicating, or dropping them.

| File | Source | Purpose |
|---|---|---|
| `00_create_bronze_tables.sql` | All | Creates `green_taxi_raw`, `open_meteo_weather_raw` and `taxi_zones_raw` |
| `10_load_green_taxi.py` | Green Taxi | Runs `src/ingestion/green_taxi.py` to load new monthly Parquet files |
| `20_load_open_meteo.sql` | Open-Meteo | Merges the landed weather response into Bronze |
| `30_load_taxi_zones.sql` | Taxi Zones | Full refresh from the zone lookup CSV |
| `90_validate_green_taxi.sql` | Green Taxi | Bronze gate: batch reconciliation, provenance, content stability |
| `90_validate_taxi_zones.sql` | Taxi Zones | Bronze gate (Databricks SQL notebook) |

Run order: `00`, then the load for a source, then that source's `90_validate_<source>`. Each source has its own gate (see `docs/validation.md`).
