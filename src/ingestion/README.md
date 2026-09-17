# Ingestion implementation

Source profiling is complete (`docs/source_profile.md`). Put Python file discovery, API acquisition, immutable raw capture and retry/checkpoint orchestration here. Follow `docs/ingestion.md`. Do not put SQL transformation logic in a second competing implementation.

| Module | Purpose |
|---|---|
| `common.py` | Shared helpers: file hashing, path handling, `ingestion_batches` status updates, schema fingerprint and schema drift report |
| `green_taxi.py` | Green Taxi file discovery and Bronze load |
| `weather.py` | Not yet implemented: Open-Meteo API request and raw capture |
| `taxi_zones.py` | Not yet implemented; Taxi Zones currently loads through `etl/02_bronze/30_load_taxi_zones.sql` |
