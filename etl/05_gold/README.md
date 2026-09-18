# 05 — Gold

Approved facts and dimensions, per `docs/data_model.md`. Dimensions are built before facts, and a fact resolves its foreign keys only against built dimensions, never against Silver.

| File | Target table | Status |
|---|---|---|
| `10_dim_date.sql` | `dim_date` | Placeholder |
| `11_dim_hour.sql` | `dim_hour` | Placeholder |
| `12_dim_taxi_zone.sql` | `dim_taxi_zone` | Placeholder |
| `13_dim_weather_classification.sql` | `dim_weather_classification` | Placeholder |
| `20_fact_weather_hourly.sql` | `fact_weather_hourly` | Implemented (#38), not yet run |
| `30_fact_taxi_trip.sql` | `fact_taxi_trip` | Implemented (#38), not yet run |
| `90_validate_gold.sql` | Gold gate: PKs, FKs, grain, measures | Placeholder |

Trip and weather measurements stay at their own grain. A trip carries only the weather classification key; temperature and precipitation stay in `fact_weather_hourly` (D12).

`30_fact_taxi_trip.sql` reads `fact_weather_hourly` to copy the pickup-hour
classification key, so the weather fact must be built first. That is a
build-time lookup, not a stored fact-to-fact foreign key (D12).
