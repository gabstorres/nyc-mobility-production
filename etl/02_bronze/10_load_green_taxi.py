# Databricks notebook source
# MAGIC %md
# MAGIC # 10 Load Green Taxi into Bronze
# MAGIC
# MAGIC Thin entry point. The load logic lives in `src/ingestion/green_taxi.py`.
# MAGIC
# MAGIC Prerequisites:
# MAGIC - `etl/01_control/00_create_control_tables.sql`
# MAGIC
# MAGIC Next: `etl/02_bronze/90_validate_green_taxi.sql`

# COMMAND ----------

import os
import sys
from pathlib import Path


def find_repo_root(start):
    """Walk up from the notebook's directory to the folder that contains src/ingestion."""
    for path in [start, *start.parents]:
        if (path / "src" / "ingestion").is_dir():
            return path
    raise RuntimeError(f"Could not find the repository root above {start}")


repo_root = str(find_repo_root(Path(os.getcwd()).resolve()))
if repo_root not in sys.path:
    sys.path.insert(0, repo_root)

# COMMAND ----------

from src.ingestion.green_taxi import ingest_all

# COMMAND ----------

# Table definition lives here so this file runs on its own. Safe to rerun.
spark.sql("""
CREATE TABLE IF NOT EXISTS `ftw-week-08`.`02-bronze`.green_taxi_raw (
    VendorID INT,
    lpep_pickup_datetime TIMESTAMP_NTZ,
    lpep_dropoff_datetime TIMESTAMP_NTZ,
    store_and_fwd_flag STRING,
    RatecodeID BIGINT,
    PULocationID INT,
    DOLocationID INT,
    passenger_count BIGINT,
    trip_distance DOUBLE,
    fare_amount DOUBLE,
    extra DOUBLE,
    mta_tax DOUBLE,
    tip_amount DOUBLE,
    tolls_amount DOUBLE,
    ehail_fee DOUBLE,
    improvement_surcharge DOUBLE,
    total_amount DOUBLE,
    payment_type BIGINT,
    trip_type BIGINT,
    congestion_surcharge DOUBLE,
    cbd_congestion_fee DOUBLE,

    -- provenance columns, per this issue's acceptance evidence
    source_system STRING,
    source_file STRING,
    ingested_at TIMESTAMP,
    batch_id STRING
)
USING DELTA
""")

# COMMAND ----------

results = ingest_all(spark, dbutils)
for result in results:
    print(f"{result['file']}: {result['batch_id'] or 'skipped (already processed)'}")
