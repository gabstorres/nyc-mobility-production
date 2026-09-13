# Delivery plan

Status: all implementation work is pending. Convert these rows to GitHub issues after repository creation. Assign names rather than assuming a team size.

| Order | Work item | Dependencies | Completion evidence | Owner / reviewer |
|---|---|---|---|---|
| 01 | Set up shared repository and team access | None | Members can clone; PR workflow agreed | TBD / TBD |
| 02 | Confirm questions, grains, platform and storage | 01 | Model scope agreed; actual catalog, schemas, group prefix, and Volume path recorded | TBD / TBD |
| 03 | Acquire and profile taxi, weather, zones | 02 | Schemas, counts, date coverage, key candidates, anomalies, source versions recorded | TBD / TBD |
| 04 | Review field mapping and ingestion contracts | 03 | Incremental signals, duplicate policy, failure recovery, schema policy and mappings approved | TBD / TBD |
| 05 | Implement control state and March Bronze | 04 | Raw sources preserved; provenance and counts reconcile; retry safe | TBD / TBD |
| 06 | Build and validate March Silver | 05 passes | Explicit types, quality flags, duplicate disposition and explained row/measure deltas | TBD / TBD |
| 07 | Build dimensions and Gold integration | 06 passes | Grain, PKs, FKs, join cardinality and measures pass | TBD / TBD |
| 08 | Add April, then May, then rerun May | 07 passes | No unnecessary historical rebuild; identical business content after May rerun | TBD / TBD |
| 09 | Prove failure recovery, revisions and late arrivals | 08 | Isolated fixtures pass; shared demonstration data remains intact | TBD / TBD |
| 10 | Analytics and business/DQ dashboards | 08 and required DQ gates pass | Hand-calculated spot checks and dashboard reconciliation | TBD / TBD |
| 11 | Fresh-environment replay and handover | 09, 10 | Different teammate reproduces the pinned-input result using README | TBD / TBD |

## First working session

Create the repo; agree the five business questions; choose a storage prefix and actual Databricks namespace; assign source owners and reviewers; acquire the three official taxi files and zone CSV; preserve a historical-weather sample response; begin profiling. Do not write Silver/Gold SQL before the upstream design gates pass.

## Suggested workstreams

Taxi ingestion; weather/reference ingestion; model/SQL; validation/analytics. Combine roles for smaller teams. All workstreams own their documentation. Source profiling can proceed concurrently, but agree contracts before integrating code.

## Demonstration narrative

Explain sources and grain; show March; add April; add May; rerun May and show content comparison; show a failed check stopping publication; show recovery; trace one result back to raw sources; show both dashboards and the run instructions.
