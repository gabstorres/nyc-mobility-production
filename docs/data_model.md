This document defines business questions, table grains, keys, facts, dimensions, relationships, and required measures.

# Data model and business questions

Status: proposed. Final keys require source profiling.

| Question | Measure + by |
|---|---|
| When is activity highest? | Trip count by pickup date, weekday, hour |
| Where is activity highest? | Pickup/drop-off counts by respective zone and event month |
| How does volume vary with weather? | Average trips per covered hour by weather, weekday, hour |
| How does behavior vary with weather? | Average duration, distance, metered fare by pickup-time weather |
| Which zones remain busy? | Average daily pickups and monthly rank by pickup zone |

Recorded activity is a demand proxy. Associations with weather do not establish causation. Count zero-trip hours/days only when source coverage is confirmed; missing data is not zero.

| Proposed Gold table | Grain | Key / relationships |
|---|---|---|
| fact_taxi_trip | One row per accepted Green Taxi trip record under the documented identity policy | Non-null unique technical trip key pending profiling; date/hour FKs; nullable pickup/drop-off zone FKs with explicit unknown handling |
| dim_taxi_zone | One row per taxi-zone identifier in the selected validated snapshot | Unique non-null zone key; source LocationID mapping |
| dim_date | One row per calendar date | Unique non-null date key |
| dim_hour | One row per hour of day | Unique non-null hour key 0-23 |
| fact_weather_hourly | One row per configured weather location per UTC hour for the selected dataset/model | Unique location/hour key; date/hour context; source-version lineage |
| agg_pickup_zone_hourly | One row per pickup zone per covered UTC hour | Unique zone/hour key; aggregate trips before integrating unique hourly weather |

Store pickup/drop-off timestamps, trip distance (miles), duration (seconds), metered fare (USD), total amount (USD), quality flags, and lineage in the trip model. Pin reporting timezone to America/New_York after confirming source semantics. Define eligible records and denominators separately for each metric.

Keep weather measurements at their own grain. Do not sum repeated precipitation values after joining weather to trips. Use a documented city-level representative weather location initially; it does not imply zone-level weather accuracy.

Validate unmatched keys and fan-out before integration. Nullable relationships preserve trips and retain their original source IDs for investigation. No SCD Type 2 until a business question requires historical dimension descriptions. Weather-history modeling is not a reason to force SCD Type 2 on zones.
