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
