# Databricks notebook source
# MAGIC %md
# MAGIC # 10 Load Green Taxi into Bronze
# MAGIC
# MAGIC Thin entry point. The load logic lives in `src/ingestion/green_taxi.py`.
# MAGIC
# MAGIC Prerequisites:
# MAGIC - `etl/01_control/00_create_control_tables.sql`
# MAGIC - `etl/02_bronze/00_create_bronze_tables.sql`
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

results = ingest_all(spark, dbutils)
for result in results:
    print(f"{result['file']}: {result['batch_id'] or 'skipped (already processed)'}")
