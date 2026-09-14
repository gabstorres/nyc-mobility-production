# NYC Mobility Pipeline

Day 8 group project: build a repeatable NYC Green Taxi, historical weather, and taxi-zone pipeline in Databricks using class R2 storage.

**Status: planning starter. No ingestion or transformation pipeline is implemented or validated yet.**

## Start here

1. Read [the work plan](BACKLOG.md) and agree the questions in [the model](docs/data_model.md).
2. Confirm the actual Databricks catalog, permitted schemas, group R2 prefix, and mounted Volume path. Record non-secret values in a team configuration copied from `config/project.example.json`.
3. Use the verified source links in [ingestion](docs/ingestion.md). Acquire immutable source copies and record checksums. Profile all three taxi months but process March first in the proof sequence.
4. Complete [source profiling](docs/source_profile.md) and [field mapping](docs/data_dictionary.md). Review the source contracts before writing transformation SQL.
5. Implement ingestion and March Bronze, pass validation, and only then advance to Silver. Gold remains a placeholder until the star schema is approved.
6. Add April, add May, rerun May, and capture the proof in [validation](docs/validation.md).

There is no pipeline run command yet. Add the exact Databricks runtime, dependencies, configuration, job/notebook entry point, parameters, and rerun instructions when implementation is validated.

## Responsibilities

| Location | Purpose |
|---|---|
| `config/` | Non-secret configuration examples and official source registry |
| `src/ingestion/` | Python discovery, downloads, API requests, and ingestion orchestration |
| `sql/00_source_profile/` | Source profiling queries executed before transformation design is finalized |
| `sql/01_ops/` | Batch state, run history, checkpoints, schema observations, and DQ results |
| `sql/02_bronze/` | Bronze definitions, landing SQL, and Bronze validation |
| `sql/03_silver/` | Cleaning, standardization, duplicate handling, and Silver validation |
| `sql/04_integration/` | Taxi, zone, and weather joins plus join-coverage validation |
| `sql/05_gold/`, `sql/06_analytics/` | Structural placeholders until the dimensional model is approved |
| `notebooks/` | Thin Databricks entry points, avoiding duplicated business logic |
| `docs/` | Canonical architecture, model, dictionary, ingestion, decisions, validation |
| `evidence/`, `evidence/proof/` | Small reviewed run summaries and incremental/idempotency proof |
| `.github/` | Pull request and work-item templates |

GitHub stores code, configuration examples, documentation, and compact evidence. R2 stores raw files, raw JSON, and large outputs. Databricks hosts execution and persisted processing/DQ tables. Do not commit credentials, raw datasets, downloaded lecture PDFs, notebook outputs containing data, or local processing state.

## Collaboration

See [CONTRIBUTING.md](CONTRIBUTING.md). Use one shared repository, a branch per work item, and a teammate review before merging. Each owner documents and validates their changes.

## Scope and limitations

March-May 2026 Green Taxi records measure recorded activity, a proxy for demand. Weather comparisons are associations. Current traffic advisories are deferred unless suitable historical coverage is established. Definitions and modeling choices remain proposals until source profiling and team review are complete.
