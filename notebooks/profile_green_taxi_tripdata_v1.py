# Databricks notebook source
# MAGIC %md
# MAGIC
# MAGIC # Green Taxi Trip Data Source Profiling
# MAGIC

# COMMAND ----------

# Setup — read each raw Parquet file individually (not the merged Delta table)

files = dbutils.fs.ls("/Volumes/ftw-week-08/00-source/group_a_source/green_taxi/")
file_paths = [f.path for f in files if f.name.endswith(".parquet")]

dfs = {f: spark.read.parquet(f) for f in file_paths}

# COMMAND ----------

# MAGIC %md 
# MAGIC ## A1 — File Inventory

# COMMAND ----------

# file count, row count per file

for f, df in dfs.items():
    print(f, df.count())

# COMMAND ----------

# MAGIC %md
# MAGIC ## A2 — Schema per File

# COMMAND ----------

# print schema per file

for f, df in dfs.items():
    print(f)
    df.printSchema()

# COMMAND ----------

# MAGIC %md
# MAGIC ## A3 — Date Range per File (+ out-of-month check)

# COMMAND ----------

from pyspark.sql import functions as F

for f, df in dfs.items():
    print(f"=== {f} ===")
    df.select(
        F.min("lpep_pickup_datetime").alias("min_pickup"),
        F.max("lpep_pickup_datetime").alias("max_pickup"),
        F.min("lpep_dropoff_datetime").alias("min_dropoff"),
        F.max("lpep_dropoff_datetime").alias("max_dropoff"),
    ).show(truncate=False)

    # Out-of-month check: extract expected year-month from filename, compare against actual trip months
    out_of_month = df.withColumn(
        "pickup_month", F.date_format("lpep_pickup_datetime", "yyyy-MM")
    ).groupBy("pickup_month").count().orderBy("pickup_month")

    print("Pickup month distribution (expect only 1 dominant month):")
    out_of_month.show()

# COMMAND ----------

# MAGIC %md
# MAGIC ## A4 — Null Rates per Column

# COMMAND ----------

def null_rates(df, label):
    total = df.count()
    null_counts = df.select([
        F.count(F.when(F.col(c).isNull(), c)).alias(c) for c in df.columns
    ]).collect()[0].asDict()

    print(f"=== {label} (total rows: {total}) ===")
    for col_name, null_count in sorted(null_counts.items(), key=lambda x: -x[1]):
        pct = (null_count / total * 100) if total > 0 else 0
        if null_count > 0:
            print(f"  {col_name}: {null_count} nulls ({pct:.2f}%)")

for f, df in dfs.items():
    null_rates(df, f)

# COMMAND ----------

# MAGIC %md
# MAGIC ## A5 — Duplicate Candidates

# COMMAND ----------

for f, df in dfs.items():
    total = df.count()
    distinct = df.distinct().count()
    dupes = total - distinct
    print(f"{f}: {total} total rows, {distinct} distinct rows, {dupes} exact duplicate rows")

# COMMAND ----------

# MAGIC %md
# MAGIC ## A6 — Cross-File Column Presence Matrix

# COMMAND ----------

import pandas as pd

all_columns = sorted(set().union(*[set(df.columns) for df in dfs.values()]))
file_names = list(dfs.keys())

matrix = pd.DataFrame(
    {f: [col in dfs[f].columns for col in all_columns] for f in file_names},
    index=all_columns
)

print(matrix)

# Flag mismatches explicitly
mismatches = matrix[matrix.nunique(axis=1) > 1]
if not mismatches.empty:
    print("\n⚠️ Columns NOT present in all files:")
    print(mismatches)
else:
    print("\n✅ All files share identical column sets.")

# COMMAND ----------

# MAGIC %md
# MAGIC #  Part B — Extended Checks

# COMMAND ----------

# MAGIC %md
# MAGIC ## B1 — Validity / Range Checks

# COMMAND ----------

for f, df in dfs.items():
    print(f"=== {f} ===")
    df.select(
        F.count(F.when(F.col("fare_amount") < 0, True)).alias("negative_fare"),
        F.count(F.when(F.col("trip_distance") < 0, True)).alias("negative_distance"),
        F.count(F.when(F.col("total_amount") < 0, True)).alias("negative_total"),
        F.count(F.when((F.col("passenger_count") < 0) | (F.col("passenger_count") > 8), True)).alias("passenger_count_out_of_range"),
        F.count(F.when((F.col("trip_distance") == 0) & (F.col("fare_amount") > 20), True)).alias("zero_distance_high_fare"),
    ).show(truncate=False)

# COMMAND ----------

# MAGIC %md
# MAGIC ## B2 — Logical Consistency

# COMMAND ----------

for f, df in dfs.items():
    bad_order = df.filter(F.col("lpep_dropoff_datetime") < F.col("lpep_pickup_datetime")).count()
    print(f"{f}: {bad_order} rows where dropoff is before pickup")

# COMMAND ----------

# MAGIC %md
# MAGIC ## B3 — Categorical Code Validity 

# COMMAND ----------

# Known valid value sets per NYC TLC data dictionary — adjust if your version differs
VALID_PAYMENT_TYPE = {1, 2, 3, 4, 5, 6}
VALID_RATECODE = {1, 2, 3, 4, 5, 6}
VALID_VENDOR = {1, 2}

for f, df in dfs.items():
    print(f"=== {f} ===")

    print("payment_type distinct values:")
    df.groupBy("payment_type").count().orderBy("payment_type").show()

    print("RatecodeID distinct values:")
    df.groupBy("RatecodeID").count().orderBy("RatecodeID").show()

    print("VendorID distinct values:")
    df.groupBy("VendorID").count().orderBy("VendorID").show()

    invalid_payment = df.filter(~F.col("payment_type").isin(VALID_PAYMENT_TYPE) & F.col("payment_type").isNotNull()).count()
    invalid_ratecode = df.filter(~F.col("RatecodeID").isin(VALID_RATECODE) & F.col("RatecodeID").isNotNull()).count()
    invalid_vendor = df.filter(~F.col("VendorID").isin(VALID_VENDOR) & F.col("VendorID").isNotNull()).count()

    print(f"Invalid payment_type rows: {invalid_payment}")
    print(f"Invalid RatecodeID rows: {invalid_ratecode}")
    print(f"Invalid VendorID rows: {invalid_vendor}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## B4 — Row Count Reconciliation

# COMMAND ----------

source_total = sum(df.count() for df in dfs.values())

table_total = spark.sql("""
    SELECT COUNT(*) as cnt
    FROM `ftw-week-08`.`dev_crystal`.`green_taxi_tripdata`
""").collect()[0]["cnt"]

print(f"Source Parquet total rows: {source_total}")
print(f"Delta table total rows:    {table_total}")
print("✅ Match" if source_total == table_total else "⚠️ MISMATCH — investigate")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Summary of Findings

# COMMAND ----------

print("="*60)
print("PROFILING SUMMARY — green_taxi_tripdata")
print("="*60)
print(f"Files profiled: {len(dfs)}")
for f, df in dfs.items():
    print(f"  - {f}: {df.count()} rows")
print()
print("Key flags to review before writing docs/source_profile.md:")
print("  - Check A3 output for any out-of-month pickup dates")
print("  - Check A4 output for high-null critical columns")
print("  - Check A5 output for unexpected duplicate counts")
print("  - Check A6 output for any column presence mismatches")
print("  - Check B1 output for negative fares/distances")
print("  - Check B2 output for dropoff-before-pickup rows")
print("  - Check B3 output for invalid categorical codes")
print("  - Check B4 output — should be an exact match")