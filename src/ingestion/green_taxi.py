from src.ingestion.batch_tracking import (
    hash_file,
    register_batch_discovered,
    mark_batch_started,
    mark_batch_success,
    mark_batch_failed,
)

LANDING_PATH = "/Volumes/ftw-week-08/00-source/group_a_source/green_taxi/"
BRONZE_TABLE = "`ftw-week-08`.`02-bronze`.green_taxi_raw"
SOURCE_SYSTEM = "green_taxi"


def discover_files(dbutils, landing_path=LANDING_PATH):
    """List all Parquet files in the landing location. No hardcoded filenames."""
    files = dbutils.fs.ls(landing_path)
    return [f.path for f in files if f.name.endswith(".parquet")]


def already_succeeded(spark, content_hash, source_system=SOURCE_SYSTEM):
    """
    Check ingestion_batches for a prior SUCCESS on this exact content —
    not just this filename, per the issue's requirement to use
    "source file identity plus content checksum."
    """
    result = spark.sql(f"""
        SELECT COUNT(*) AS cnt
        FROM `ftw-week-08`.`01-control`.ingestion_batches
        WHERE source_system = '{source_system}'
          AND content_sha256 = '{content_hash}'
          AND status = 'SUCCESS'
    """).collect()[0]["cnt"]
    return result > 0


def ingest_file(spark, dbutils, file_path, source_period, bronze_table=BRONZE_TABLE):
    """
    Ingest one file into Bronze, with full batch tracking.
    Skips (returns None) if this exact content was already successfully processed.
    """
    content_hash = hash_file(file_path)

    if already_succeeded(spark, content_hash):
        print(f"SKIP — already processed: {file_path}")
        return None

    batch_id = register_batch_discovered(
        spark, dbutils,
        file_path=file_path,
        source_system=SOURCE_SYSTEM,
        source_period=source_period,
    )
    mark_batch_started(spark, batch_id)

    try:
        spark.sql(f"""
            COPY INTO {bronze_table}
            FROM (
                SELECT *,
                       '{SOURCE_SYSTEM}' AS source_system,
                       _metadata.file_name AS source_file,
                       current_timestamp() AS ingested_at,
                       '{batch_id}' AS batch_id
                FROM '{file_path}'
            )
            FILEFORMAT = PARQUET
        """)

        source_rows = spark.read.parquet(file_path).count()
        loaded_rows = spark.sql(f"""
            SELECT COUNT(*) AS cnt FROM {bronze_table}
            WHERE batch_id = '{batch_id}'
        """).collect()[0]["cnt"]

        if loaded_rows != source_rows:
            raise Exception(f"Row count mismatch: source={source_rows}, loaded={loaded_rows}")

        mark_batch_success(spark, batch_id, row_count=loaded_rows)
        print(f"SUCCESS — {file_path}: {loaded_rows} rows")
        return batch_id

    except Exception as e:
        mark_batch_failed(spark, batch_id)
        print(f"FAILED — {file_path}: {e}")
        raise


def ingest_all(spark, dbutils, landing_path=LANDING_PATH):
    """Discover and ingest every file in the landing location, skipping already-processed ones."""
    file_paths = discover_files(dbutils, landing_path)
    results = []
    for file_path in file_paths:
        filename = file_path.split("/")[-1]
        source_period = filename.replace("green_tripdata_", "").replace(".parquet", "")

        batch_id = ingest_file(spark, dbutils, file_path, source_period)
        results.append({"file": file_path, "batch_id": batch_id})
    return results
