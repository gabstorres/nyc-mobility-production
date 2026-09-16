# NYC Mobility Pipeline

A Databricks lakehouse pipeline combining NYC Green Taxi trips, historical
Open-Meteo weather observations, and NYC Taxi Zone reference data.

```mermaid
flowchart TD
    A[Frame business questions, grain and naming] --> B[Profile all sources]
    B --> C[Design ingestion and processing state]
    C --> D[Draft and ratify star schema]
    D --> E[Ingest source data]
    E --> F[Bronze: preserve received data]
    F --> G{Bronze DQ gate}
    G -- Fail --> F
    G -- Pass --> H[Silver: clean and standardize]
    H --> I{Silver DQ gate}
    I -- Fail --> H
    I -- Pass --> J[Integration: taxi, zones and weather]
    J --> K{Integration DQ gate}
    K -- Fail --> J
    K -- Pass --> L[Gold dimensions]
    L --> M[Gold fact]
    M --> N{Gold DQ gate}
    N -- Fail --> L
    N -- Pass --> O[Analytics outputs]
    O --> P{Analytics DQ gate}
    P -- Fail --> O
    P -- Pass --> Q[Analytics Dashboard]

    G --> R[DQ results table]
    I --> R
    K --> R
    N --> R
    P --> R
    R --> S[DQ Dashboard]

    Q --> T[Incremental and rerun proof]
    S --> T
```

The pipeline is designed for traceable ingestion, explicit data-quality gates,
safe reruns, and reproducible analytical outputs.

> **Status:** Active development. Source profiling, architecture, ingestion
> contracts, and the Gold model are documented. The complete pipeline has not
> yet been orchestrated and validated end to end.

## Data sources

| Source | Purpose | Format |
|---|---|---|
| [NYC TLC Green Taxi records](https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page) | Trip-level mobility activity | Parquet |
| [Open-Meteo Historical API](https://open-meteo.com/en/docs/historical-weather-api) | Hourly NYC weather observations | JSON |
| [NYC Taxi Zone lookup](https://d37ci6vzurychx.cloudfront.net/misc/taxi_zone_lookup.csv) | Pickup and drop-off zone reference | CSV |

The official source registry is maintained in
[`config/sources.json`](config/sources.json).

Raw source data is stored in the class R2-backed Databricks Volume. Raw datasets
and large outputs are not committed to GitHub.

## Platform configuration

| Setting | Value |
|---|---|
| Platform | Databricks |
| Catalog | `ftw-week-08` |
| Source schema | `00-source` |
| Source Volume | `group_a_source` |
| Volume path | `/Volumes/ftw-week-08/00-source/group_a_source/` |
| Reporting timezone | `America/New_York` |
| Proof period | March–May 2026 |
| Implementation languages | Python and SQL |

Expected source layout:

```text
/Volumes/ftw-week-08/00-source/group_a_source/
├── green_taxi/
├── taxi_zones/
├── weather/
└── traffic_advisory/
```

Traffic advisories are optional and are not part of the required pipeline.

## Repository structure

```text
nyc-mobility-pipeline/
├── README.md
├── CONTRIBUTING.md
├── .gitignore
│
├── .github/
│   ├── ISSUE_TEMPLATE/
│   │   └── work_item.md
│   └── pull_request_template.md
│
├── config/
│   ├── project.json
│   ├── naming.yml
│   └── sources.json
│
├── src/
│   └── ingestion/
│       ├── __init__.py
│       ├── common.py
│       ├── green_taxi.py
│       ├── weather.py
│       └── taxi_zones.py
│
├── etl/
│   ├── README.md
│   │
│   ├── 01_control/
│   │   ├── 00_create_control_tables.sql
│   │   └── 90_validate_control.sql
│   │
│   ├── 02_bronze/
│   │   ├── 10_load_green_taxi.py
│   │   ├── 20_load_open_meteo.py
│   │   ├── 30_load_taxi_zones.sql
│   │   └── 90_validate_bronze.sql
│   │
│   ├── 03_silver/
│   │   ├── 10_clean_green_taxi.sql
│   │   ├── 20_clean_weather_hourly.sql
│   │   ├── 30_clean_taxi_zones.sql
│   │   └── 90_validate_silver.sql
│   │
│   ├── 04_integration/
│   │   ├── 10_resolve_trip_zones.sql
│   │   ├── 20_resolve_trip_weather.sql
│   │   └── 90_validate_integration.sql
│   │
│   ├── 05_gold/
│   │   ├── 10_dim_date.sql
│   │   ├── 11_dim_hour.sql
│   │   ├── 12_dim_taxi_zone.sql
│   │   ├── 13_dim_weather_classification.sql
│   │   ├── 20_fact_weather_hourly.sql
│   │   ├── 30_fact_taxi_trip.sql
│   │   └── 90_validate_gold.sql
│   │
│   └── 06_analytics/
│       ├── 10_activity_by_time_and_zone.sql
│       ├── 20_trip_behavior_by_weather.sql
│       ├── 30_mobility_patterns_by_zone.sql
│       └── 90_validate_analytics.sql
│
├── notebooks/
│   ├── profile_green_taxi.ipynb
│   └── profile_weather.ipynb
│
├── tests/
│   ├── test_green_taxi_duplicate_policy.py
│   └── test_notebook_source_format.py
│
├── docs/
│   ├── architecture.md
│   ├── naming_conventions.md
│   ├── data_model.md
│   ├── data_dictionary.md
│   ├── source_profile.md
│   ├── source_to_target_mapping.md
│   ├── ingestion.md
│   ├── validation.md
│   ├── decisions.md
│   └── model/
│       ├── nyc_mobility_star_schema.dbml
│       └── nyc_mobility_star_schema.png
│
└── evidence/
    ├── README.md
    └── proof/
```

### Directory responsibilities

| Location | Responsibility |
|---|---|
| `config/` | Approved non-secret project, naming, and source configuration |
| `src/ingestion/` | Reusable Python for discovery, acquisition, metadata, and checkpoints |
| `etl/` | Ordered executable Python and SQL tasks |
| `notebooks/` | Source profiling and limited investigation |
| `tests/` | Policy, source-format, and reusable-code tests |
| `docs/` | Canonical architecture, model, mapping, ingestion, and validation decisions |
| `evidence/proof/` | Reviewed run, reconciliation, and rerun evidence |

Reusable Python belongs in `src/ingestion/`. Files under `etl/` should be small
runnable entry points or clearly scoped SQL transformations. Business logic
must not be duplicated between `src/`, `etl/`, and notebooks.

## Architecture and tables

| Stage | Purpose | Code | Destination |
|---|---|---|---|
| 00 Source | Immutable source files | R2-backed Volume | No project tables |
| 01 Control | Runs, batches, checkpoints, and DQ results | `etl/01_control/` | `01-control` |
| 02 Bronze | Source-preserving records with provenance | `etl/02_bronze/` | `02-bronze` |
| 03 Silver | Typed, standardized, and quality-reviewed records | `etl/03_silver/` | `03-silver` |
| 04 Integration | Resolve trips to zones and weather | `etl/04_integration/` | Published through Gold |
| 05 Gold | Approved facts and dimensions | `etl/05_gold/` | `05-gold` |
| 06 Analytics | Business-question datasets | `etl/06_analytics/` | `06-analytics` |

Stage numbers describe execution order. Stage 00 creates no project tables.
Stage 04 does not have its own schema because integration enriches trips without
introducing a separate analytical grain.

## Gold model

The approved model contains two facts and four shared dimensions:

| Table | Grain |
|---|---|
| `fact_taxi_trip` | One row per accepted Green Taxi trip |
| `fact_weather_hourly` | One row per coordinate, UTC observation hour, and weather model |
| `dim_date` | One row per NYC-local calendar date |
| `dim_hour` | One row per hour from 0 through 23 |
| `dim_taxi_zone` | One row per Taxi Zone `LocationID` |
| `dim_weather_classification` | One row per weather-code and precipitation-band combination |

Taxi and weather facts do not join directly. A trip receives the weather
classification associated with its pickup hour. Temperature and precipitation
remain in `fact_weather_hourly`, preventing those measurements from being
multiplied across trip rows.

See [`docs/data_model.md`](docs/data_model.md) for keys, measures, nullable
relationships, classifications, and business-question mappings.

## Quick start

### 1. Prerequisites

You need:

- Git and access to this repository.
- Access to the team Databricks workspace.
- Permission to use the `ftw-week-08` catalog.
- Read access to the `group_a_source` Volume.
- A personal Databricks Git folder.
- An assigned GitHub issue and reviewer.

The full pipeline cannot currently run locally because it depends on Spark,
Unity Catalog, Databricks Volumes, and `dbutils`.

### 2. Clone the repository

```bash
git clone https://github.com/hyenalouise/nyc-mobility-pipeline.git
cd nyc-mobility-pipeline
git switch main
git pull --ff-only
```

Create one branch for one issue:

```bash
git switch -c <type>/issue-<number>-<short-description>
```

Example:

```bash
git switch -c ingestion/issue-20-taxi-files
```

### 3. Review configuration

The tracked non-secret configuration files are:

```text
config/project.json
config/naming.yml
config/sources.json
```

For temporary personal overrides:

```bash
cp config/project.json config/project.local.json
```

`config/project.local.json` is ignored by Git.

Never store Databricks tokens, R2 credentials, passwords, or other secrets in
project configuration.

### 4. Create a Databricks Git folder

In Databricks:

1. Create a personal Git folder using this repository URL.
2. Authenticate using your GitHub account.
3. Check out your assigned branch.
4. Attach approved class compute.
5. Confirm access to the catalog and source Volume.

Do not share Databricks Git folders between developers.

### 5. Verify access

Run in a Databricks SQL cell:

```sql
SHOW SCHEMAS IN `ftw-week-08`;
```

Run in a Python cell:

```python
display(
    dbutils.fs.ls(
        "/Volumes/ftw-week-08/00-source/group_a_source/"
    )
)
```

Expected folders include:

```text
green_taxi
taxi_zones
weather
```

If access fails, stop and request access. Do not replace approved shared paths
with personal paths in committed code.

## Execution order

Run approved entry points in this order:

```text
01 Control
→ 02 Bronze
→ Bronze validation
→ 03 Silver
→ Silver validation
→ 04 Integration
→ Integration validation
→ 05 Gold dimensions
→ 05 Gold facts
→ Gold validation
→ 06 Analytics
→ Analytics validation
```

Within a stage:

```text
00  Setup or table creation
10  First task
20  Next task
30  Next task
90  Validation gate
```

Do not run a downstream trusted stage while an upstream critical validation is
failing.

## Naming rules

All persisted tables must use fully qualified references:

```sql
SELECT *
FROM `ftw-week-08`.`02-bronze`.`green_taxi_raw`;
```

Catalog and schema names require backticks because they contain hyphens and
begin with numbers.

Do not depend on a previous `USE CATALOG` or `USE SCHEMA` command.

Outside source-preserving Bronze fields:

- Use lowercase `snake_case`.
- Use `_id` for identifiers.
- Use `_at` for timestamps.
- Use `_date` for dates.
- Use `_count` for counts.
- Use `_amount` for currency.
- Use `_flag` for Boolean indicators.

## Validation requirements

Every data-affecting pull request must include:

- Source version, checksum, or request window.
- Databricks Runtime used.
- Source and target row counts.
- Accepted, rejected, and quarantined counts.
- Duplicate and key-uniqueness checks.
- Null and required-field checks.
- Measure reconciliation where applicable.
- Evidence that records were not silently dropped.
- Rerun or idempotency evidence where applicable.
- Anything not yet validated.

An identical-input rerun must preserve business content and must not create
duplicates. Equal row counts alone do not prove idempotency.

Commit small reviewed evidence under:

```text
evidence/proof/
```

Do not commit raw datasets, full table exports, notebook result data, or large
execution logs.

## Local checks

Local development currently supports Git, documentation, and static Python
checks:

```bash
git status --short
git diff --check
python -m compileall src etl tests
```

The repository does not yet have a pinned local Python environment or complete
automated test runner. Those instructions must be added when reusable Python
dependencies are introduced.

## Development workflow

Start from current `main`:

```bash
git switch main
git pull --ff-only
git switch -c <type>/issue-<number>-<short-description>
```

Review changes before committing:

```bash
git status
git diff
git diff --check
```

Commit only intended files:

```bash
git add <specific-paths>
git commit -m "<clear description>"
git push -u origin <branch-name>
```

Every pull request must:

- Include `Closes #<issue-number>`.
- Explain what changed and why.
- Explain what was run or checked.
- Include counts or evidence when data is affected.
- Identify anything not yet validated.
- Receive the assigned teammate’s review.

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for ownership, branch naming, and
review rules.

## Documentation map

| Document | Purpose |
|---|---|
| [`docs/architecture.md`](docs/architecture.md) | Stage-by-stage data flow |
| [`docs/naming_conventions.md`](docs/naming_conventions.md) | Catalog, schemas, tables, columns, and paths |
| [`docs/data_model.md`](docs/data_model.md) | Facts, dimensions, grains, keys, and measures |
| [`docs/data_dictionary.md`](docs/data_dictionary.md) | Target fields, types, and business meanings |
| [`docs/source_profile.md`](docs/source_profile.md) | Observed source structure and quality |
| [`docs/source_to_target_mapping.md`](docs/source_to_target_mapping.md) | Source-to-target transformations |
| [`docs/ingestion.md`](docs/ingestion.md) | Batch identity, reruns, and recovery |
| [`docs/validation.md`](docs/validation.md) | Required checks and acceptance evidence |
| [`docs/decisions.md`](docs/decisions.md) | Accepted decisions and rejected alternatives |

If documentation and implementation disagree, stop and resolve the discrepancy
through the relevant issue. Do not silently choose one.

## Security and repository hygiene

Never commit:

- Databricks tokens.
- R2 credentials.
- Passwords or secret values.
- `.databrickscfg`.
- Raw Parquet, CSV, or JSON datasets.
- Local processing state.
- Notebook outputs containing data or configuration.
- Large generated evidence.

GitHub stores code, documentation, non-secret configuration, and compact
reviewed evidence. R2 and Databricks store source data and persisted tables.

## Remaining handoff requirements

Before claiming a reproducible end-to-end pipeline, the project must:

- Pin the supported Databricks Runtime.
- Pin external Python dependencies, if any.
- Implement all required ETL files.
- Provide one orchestration job or exact manual runbook.
- Run March, April, and May in order.
- Prove identical-input rerun safety.
- Demonstrate recovery after a controlled failure.
- Reconcile final Bronze, Silver, Gold, and Analytics outputs.

Progress and ownership are tracked through the
[GitHub Project board](https://github.com/users/hyenalouise/projects/3) and
[repository issues](https://github.com/hyenalouise/nyc-mobility-pipeline/issues).
