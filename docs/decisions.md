This document records important engineering decisions, their reasons, rejected alternatives, assumptions, and consequences.

# Decision log

Record problem, decision, reason, rejected alternative, assumption, consequence, status and reviewer. Priority: correctness > reliability > maintainability > scalability > observability > efficiency.

| ID | Decision | Reason / rejected alternative | Assumption / consequence | Status |
|---|---|---|---|---|
| D01 | Databricks + class R2; GitHub for code/docs | User selected course platform; avoid introducing a second platform | Actual access and paths must be confirmed | Platform confirmed; setup pending |
| D02 | Taxi, weather, zones first | Correctness before bonus scope; current advisories do not establish March-May closures | Traffic deferred until historical/spatial coverage exists | Proposed |
| D03 | Source-version manifest with per-layer checkpoints | Reliability before a simple filename-only skip list | Need safe commit/checkpoint reconciliation | Proposed |
| D04 | Replace a revised source batch contribution when complete | Correctness before efficiency; invented trip merge keys can retain stale rows | Must confirm replacement snapshot semantics | Proposed |
| D05 | Profile before finalizing taxi deduplication | Correctness before convenient DISTINCT/hash deduplication | Unique real-world trip identity may not be provable | Required design gate |
| D06 | One representative NYC weather location initially | Maintainability once business scope accepts city-level approximation | Cannot claim zone-specific observed weather | Proposed |
| D07 | No SCD Type 2 for zones initially | Maintainability; no agreed question requires historical zone labels | Pin raw snapshot for reproducibility | Proposed |
| D08 | One branch/work item and reviewer | Reliability and maintainability of shared changes | Separate developer outputs from integration targets | Proposed |

Whenever a decision changes, update the relevant canonical documents in the same PR and explicitly identify any remaining stale documents. This log explains choices; detailed implementation contracts live in ingestion/model/architecture documents.


## Databricks namespace and naming

Status: Proposed in Issue #3  
Decision date: `Sep 14 2026`

The project uses the `ftw-week-08` catalog and the existing R2-backed Volume at `ftw-week-08`.`00-source`.`group_a_source`.

Persisted processing layers use separate `control`, `bronze`, `silver`, `gold`, and `analytics` schemas. Table names do not include `group_a_` because the approved schemas are dedicated to the group.

A separate `control` schema was selected because pipeline runs, ingestion batches, and data-quality results have different grains and lifecycles from business records.

Gold and Analytics names remain pending Issue #17 and the approved business-question outputs.

Alternative rejected: storing operational state in Bronze. This would mix pipeline-control records with source-preserving business data.

Assumption: the processing schemas are dedicated to Group A. If other groups share them, the namespace strategy must be revised before tables are created.
