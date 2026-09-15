# NYC Mobility Pipeline

Day 8 group project: build a repeatable NYC Green Taxi, historical weather, and taxi-zone pipeline in Databricks using class R2 storage.

**Status: planning starter. No ingestion or transformation pipeline is implemented or validated yet.**

## Start here

1. Review the [GitHub Project board](https://github.com/users/hyenalouise/projects/3) and the [repository issues](https://github.com/hyenalouise/nyc-mobility-pipeline/issues). Select an issue whose prerequisites are complete before starting work.
2. Confirm the actual Databricks catalog, permitted schemas, group R2 prefix, and mounted Volume path. Record non-secret values in a team configuration copied from `config/project.example.json`.
3. Use the verified source links in [ingestion](docs/ingestion.md). Acquire immutable source copies and record checksums. Profile all three taxi months but process March first in the proof sequence.
4. Complete [source profiling](docs/source_profile.md) and [field mapping](docs/data_dictionary.md). Review the source contracts before writing transformation SQL.
5. Implement ingestion and March Bronze, pass validation, and only then advance to Silver. Gold remains a placeholder until the star schema is approved.
6. Add April, add May, rerun May, and capture the proof in [validation](docs/validation.md).

There is no pipeline run command yet. Add the exact Databricks runtime, dependencies, configuration, job/notebook entry point, parameters, and rerun instructions when implementation is validated.

## Project management

GitHub Issues define the scope, prerequisites, ownership, and acceptance evidence for each work item.
The GitHub Project board is the canonical view of project status.

## Repository structure

```text
nyc-mobility-pipeline/
├── README.md                      What this is, how to start, what is not built yet
├── CONTRIBUTING.md                Branching, review, namespaces, approved table names
├── config/
│   ├── project.example.json       Non-secret catalog, schema and path values to copy
│   ├── naming.example.yml         Approved naming values in YAML form
│   └── sources.json               Official source registry
├── src/
│   └── ingestion/                 Python discovery, downloads, API requests, orchestration
├── sql/
│   ├── 00_source_profile/         Profiling queries; creates no tables
│   ├── 01_control/                Run history, ingestion batches, DQ results -> 01-control
│   ├── 02_bronze/                 Landing SQL and Bronze validation -> 02-bronze
│   ├── 03_silver/                 Cleaning, dedup and Silver validation -> 03-silver
│   ├── 04_integration/            Zone and weather joins, join coverage; output -> 05-gold
│   ├── 05_gold/                   Dimensions and facts -> 05-gold
│   └── 06_analytics/              One dataset per business question -> 06-analytics
├── notebooks/                     Thin Databricks entry points, no business logic
├── docs/
│   ├── architecture.md            How data moves, stage by stage
│   ├── naming_conventions.md      Approved catalog, schema, table and column names
│   ├── data_model.md              Business questions, grain, keys, facts, dimensions
│   ├── data_dictionary.md         Field meaning and source-to-target mapping
│   ├── ingestion.md               Sources, incremental signals, provenance, rerun behavior
│   ├── validation.md              Evidence required to prove each layer
│   └── decisions.md               Decisions, rejected alternatives, consequences
├── evidence/
│   └── proof/                     Incremental and idempotency run evidence
└── .github/                       Pull request and work-item templates
```

A folder number is a pipeline stage, not a schema. `00_source_profile/` and
`04_integration/` create no tables of their own; see
[naming_conventions.md](docs/naming_conventions.md).

## Responsibilities

| Location | Purpose |
|---|---|
| `config/` | Non-secret configuration examples and official source registry |
| `src/ingestion/` | Python discovery, downloads, API requests, and ingestion orchestration |
| `sql/00_source_profile/` | Source profiling queries executed before transformation design is finalized |
| `sql/01_control/` | Batch state, run history, checkpoints, schema observations, and DQ results, written to `01-control` |
| `sql/02_bronze/` | Bronze definitions, landing SQL, and Bronze validation |
| `sql/03_silver/` | Cleaning, standardization, duplicate handling, and Silver validation |
| `sql/04_integration/` | Taxi, zone, and weather joins plus join-coverage validation; output is written by the Gold build, not a schema of its own |
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
