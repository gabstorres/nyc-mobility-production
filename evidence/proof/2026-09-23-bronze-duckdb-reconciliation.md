# Proof: Bronze reconciliation against an independent DuckDB engine

Issue #123  
Captured: 2026-09-23  
Status: Resolved

## Objective

This evidence verifies that the Green Taxi Bronze table contains the same records and financial totals as an independent DuckDB read of the original source parquet files.

The reconciliation compares three execution paths:

| Reconciliation side | Engine | Input |
|---|---|---|
| Bronze reconciliation | Databricks SQL | `ftw-week-08`.`02-bronze`.green_taxi_raw |
| Direct source verification | Databricks SQL `read_files()` | Original parquet files in the Unity Catalog Volume |
| Independent engine verification | DuckDB 1.1.3 | Original parquet files read directly with `read_parquet()` |

The DuckDB query does not read the Bronze table. DuckDB reads the original Green Taxi parquet files directly, providing a separate engine and query implementation.

## Source files reconciled

| Source month | Source file |
|---|---|
| March 2026 | `green_tripdata_2026-03.parquet` |
| April 2026 | `green_tripdata_2026-04.parquet` |
| May 2026 | `green_tripdata_2026-05.parquet` |

Source location:

```text
/Volumes/ftw-week-08/00-source/group_a_source/green_taxi/
```

Total source files reconciled:

```text
3
```

## Bronze results

The Bronze table returned the following combined results:

| Metric | Bronze result |
|---|---:|
| Row count | 133,367 |
| `SUM(fare_amount)` | 2,248,450.30 |
| `SUM(total_amount)` | 3,389,530.89 |
| Distinct source files | 3 |

### Bronze reproduction query

```sql
SELECT
    COUNT(*) AS row_count,
    ROUND(SUM(fare_amount), 2) AS fare_amount_sum,
    ROUND(SUM(total_amount), 2) AS total_amount_sum,
    COUNT(DISTINCT source_file) AS distinct_files
FROM `ftw-week-08`.`02-bronze`.green_taxi_raw;
```

## Direct source verification using Databricks

The original parquet files were also queried directly through Databricks `read_files()`.

This query bypasses the Bronze table and reads the source files from the Unity Catalog Volume.

| Metric | Direct source result |
|---|---:|
| Row count | 133,367 |
| `SUM(fare_amount)` | 2,248,450.30 |
| `SUM(total_amount)` | 3,389,530.89 |
| Source files | 3 |

### Direct-source reproduction query

```sql
SELECT
    COUNT(*) AS row_count,
    ROUND(SUM(fare_amount), 2) AS fare_amount_sum,
    ROUND(SUM(total_amount), 2) AS total_amount_sum
FROM read_files(
    '/Volumes/ftw-week-08/00-source/group_a_source/green_taxi/*.parquet',
    format => 'parquet'
);
```

This direct-source query supplies additional supporting evidence that the Bronze metrics agree with the original parquet contents.

## Independent DuckDB results

DuckDB 1.1.3 was installed and executed in a Databricks Python notebook.

DuckDB read the original Green Taxi parquet files directly from the Unity Catalog Volume by using `read_parquet()`.

DuckDB did not query the Bronze Delta table.

### Combined DuckDB result

| Metric | DuckDB result |
|---|---:|
| Row count | 133,367 |
| `SUM(fare_amount)` | 2,248,450.30 |
| `SUM(total_amount)` | 3,389,530.89 |
| Distinct files | 3 |

### Observed DuckDB output

```text
row_count          133367
fare_amount_sum    2248450.30
total_amount_sum   3389530.89
distinct_files     3
```

### DuckDB installation command

```python
%pip install duckdb==1.1.3
```

### DuckDB version verification

```python
import duckdb

print("DuckDB version:", duckdb.__version__)
```

Observed version:

```text
DuckDB version: 1.1.3
```

### DuckDB combined reconciliation command

```python
import duckdb

source_glob = (
    "/Volumes/ftw-week-08/00-source/"
    "group_a_source/green_taxi/*.parquet"
)

connection = duckdb.connect()

duckdb_summary = connection.execute(
    """
    SELECT
        COUNT(*) AS row_count,
        ROUND(SUM(fare_amount), 2) AS fare_amount_sum,
        ROUND(SUM(total_amount), 2) AS total_amount_sum,
        COUNT(DISTINCT filename) AS distinct_files
    FROM read_parquet(
        ?,
        union_by_name = true,
        filename = true
    )
    """,
    [source_glob],
).fetchdf()

display(duckdb_summary)
```

## DuckDB per-file reconciliation

DuckDB independently calculated the row count for each parquet file.

| Source file | DuckDB row count |
|---|---:|
| `green_tripdata_2026-03.parquet` | 44,208 |
| `green_tripdata_2026-04.parquet` | 44,238 |
| `green_tripdata_2026-05.parquet` | 44,921 |
| Total | 133,367 |

The per-file counts reconcile to the combined DuckDB result:

```text
44,208 + 44,238 + 44,921 = 133,367
```

### DuckDB per-file reproduction command

```python
duckdb_per_file = connection.execute(
    """
    SELECT
        regexp_extract(
            filename,
            '[^/]+$',
            0
        ) AS source_file,
        COUNT(*) AS row_count,
        ROUND(SUM(fare_amount), 2) AS fare_amount_sum,
        ROUND(SUM(total_amount), 2) AS total_amount_sum
    FROM read_parquet(
        ?,
        union_by_name = true,
        filename = true
    )
    GROUP BY filename
    ORDER BY source_file
    """,
    [source_glob],
).fetchdf()

display(duckdb_per_file)
```

## Source file checksums

The Bronze lineage records a SHA-256 content checksum for every Green Taxi source-file version.

Replace the placeholders below with the complete 64-character values returned by the checksum query before committing this evidence.

| Source file | `content_sha256` |
|---|---|
| `green_tripdata_2026-03.parquet` | `bb1c81eed6776c1417bbb38aada82767f5369d14674ab5d6e541a3c192d85a10` |
| `green_tripdata_2026-04.parquet` | `bcf3369ddb968a3212d9119aac726d88633ad521ed58cc777f7f2a33308f88fa` |
| `green_tripdata_2026-05.parquet` | `0528deb8a4eb3e71b57f2d7b632534ea3071f938650143efbfb06e56a4fcafc7` |

### Checksum extraction query

```sql
SELECT
    source_file,
    content_sha256
FROM `ftw-week-08`.`02-bronze`.green_taxi_raw
GROUP BY
    source_file,
    content_sha256
ORDER BY
    source_file;
```

### File-version count query

```sql
SELECT
    COUNT(DISTINCT source_file) AS distinct_source_files,
    COUNT(DISTINCT content_sha256) AS distinct_file_versions
FROM `ftw-week-08`.`02-bronze`.green_taxi_raw;
```

The expected result is one distinct checksum for each of the three source files.

## Optional independent checksum reproduction

The source-file checksums can also be recalculated directly from the physical parquet files in the Databricks Python notebook.

```python
import glob
import hashlib
import os
import pandas as pd


def sha256_file(file_path):
    digest = hashlib.sha256()

    with open(file_path, "rb") as source_file:
        for chunk in iter(
            lambda: source_file.read(1024 * 1024),
            b"",
        ):
            digest.update(chunk)

    return digest.hexdigest()


source_files = sorted(glob.glob(source_glob))

checksum_results = pd.DataFrame(
    [
        {
            "source_file": os.path.basename(file_path),
            "content_sha256": sha256_file(file_path),
        }
        for file_path in source_files
    ]
)

display(checksum_results)
```

The independently calculated hashes should match the corresponding `content_sha256` values recorded in Bronze.

## Final comparison

| Metric | Bronze | Direct source read | DuckDB | Result |
|---|---:|---:|---:|---|
| Row count | 133,367 | 133,367 | 133,367 | Match |
| `SUM(fare_amount)` | 2,248,450.30 | 2,248,450.30 | 2,248,450.30 | Match |
| `SUM(total_amount)` | 3,389,530.89 | 3,389,530.89 | 3,389,530.89 | Match |
| Distinct files | 3 | 3 | 3 | Match |

## Variance analysis

| Metric | Bronze minus DuckDB |
|---|---:|
| Row-count variance | 0 |
| `fare_amount` variance | 0.00 |
| `total_amount` variance | 0.00 |
| File-count variance | 0 |

No reconciliation variance was detected.

## Relationship to Issue #115

Issue #115 introduced the DuckDB-based pre-ingestion source gate located at:

```text
src/ingestion/source_gate.py
```

The source gate reads parquet files through DuckDB using `read_parquet()`.

Machine-readable source-validation evidence is stored at:

```text
evidence/proof/source-validation/results.json
```

The Issue #115 evidence recorded:

| Field | Result |
|---|---|
| Source | `green_taxi` |
| Source rows | 133,367 |
| Input files | 3 |
| Gate result | `ACCEPTED` |
| Exit code | 0 |
| Checks executed | 15 |

Issue #123 builds on the independent DuckDB source-reading capability from Issue #115 by explicitly reconciling Bronze row counts, financial measures, and file counts against the original source files.

## Independence of the reconciliation

The Bronze and DuckDB calculations use separate execution paths.

### Bronze path

```text
Bronze Delta table
→ Databricks SQL aggregation
→ Bronze reconciliation figures
```

### DuckDB path

```text
Original source parquet files
→ DuckDB read_parquet()
→ Independent DuckDB aggregation
→ DuckDB reconciliation figures
```

DuckDB does not read:

```text
`ftw-week-08`.`02-bronze`.green_taxi_raw
```

Therefore, a defect in the Bronze Delta table would not automatically reproduce itself in the DuckDB output.

The two paths share only the intended original source-file set.

## Acceptance criteria mapping

| Issue #123 requirement | Evidence | Status |
|---|---|---|
| Reconcile Bronze against a second engine | Databricks Bronze compared with DuckDB 1.1.3 | Satisfied |
| Use the same source files | Both paths represent the March, April, and May 2026 Green Taxi files | Satisfied |
| Compare row count per file | DuckDB returned 44,208, 44,238, and 44,921 rows | Satisfied |
| Compare combined row count | Bronze and DuckDB both returned 133,367 | Satisfied |
| Compare `SUM(fare_amount)` | Bronze and DuckDB both returned 2,248,450.30 | Satisfied |
| Compare `SUM(total_amount)` | Bronze and DuckDB both returned 3,389,530.89 | Satisfied |
| Compare file versions | Bronze and DuckDB both identified 3 source files | Satisfied |
| Record source-file checksums | Query and checksum table are included | Pending placeholder replacement |
| Include reproduction commands | Databricks SQL and DuckDB commands are included | Satisfied |
| Save proof under `evidence/proof/` | This evidence file | Satisfied |

## Final verification before commit

Complete these checks before committing the evidence:

1. Replace all three checksum placeholders with the complete SHA-256 values.
2. Search this file for `PASTE_`.
3. Confirm the search returns zero results.
4. Confirm each checksum contains 64 hexadecimal characters.
5. Confirm the Bronze figures still match the recorded query results.
6. Confirm the DuckDB figures still match the recorded notebook output.
7. Change the status at the top from:

```text
Status: Reconciliation complete; checksum transcription pending
```

to:

```text
Status: Resolved
```

## Conclusion

The Green Taxi Bronze table was successfully reconciled against an independent DuckDB read of the original source parquet files.

The following values matched exactly:

```text
Row count:          133,367
SUM(fare_amount):   2,248,450.30
SUM(total_amount):  3,389,530.89
Distinct files:     3
```

The per-file DuckDB row counts also reconciled to the combined total:

```text
March 2026: 44,208
April 2026: 44,238
May 2026:   44,921
Total:      133,367
```

The zero variances provide evidence that Bronze ingestion loaded the expected Green Taxi source records without measurable row loss, duplication, source-file omission, or financial-measure drift.

Issue #123 is ready to close after the three checksum placeholders are replaced with the full values returned by the checksum query.