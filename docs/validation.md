This document defines the evidence required to prove every pipeline layer is complete, repeatable, and trustworthy.

# Validation and proof

Status: no pipeline checks have been executed. Starter-file checks do not validate data.

## Layer gates

| Layer | Required evidence |
|---|---|
| Source/Bronze | Availability; source schema; file/response validity; raw counts vs landed counts; source version and provenance; dates and batch coverage |
| Silver | Typed-field validity; required nulls; duplicate disposition; accepted values; date/range anomalies; row and measure deltas |
| Gold/integration | Unique non-null PKs; nullable/non-null FK policy; unmatched counts; no unintended fan-out; grain and measure reconciliation |
| Analytics | Hand-calculated selected zone/date/hour spot checks; denominators and zero/missing coverage handling |
| Dashboard | Numbers match Analytics/Gold; last checked and data coverage are visible |

Reconcile raw rows = accepted rows + quarantined rows + removed duplicate occurrences with mutually exclusive accounting. Reconcile an important source measure across the same dispositions before comparing Silver and Gold. Define monetary precision/tolerance explicitly. A retained row can have an ineligible measure; document each metric's denominator.

Persist DQ results including run_id, batch_id/source_version_id, code_revision, dataset/layer, check_name/type, executed_at, status, fail_count, total_count, fail_pct, threshold, severity, owner and evidence location. Critical failures block publication; warnings require explanation. Thresholds are relative or schema/business invariants, not fixed current row totals. All checks need explicit empty-dataset behavior.

## Proof sequence

1. Load March; record source versions, target content, counts and measures.
2. Add April; confirm unaffected March content is unchanged.
3. Add May; confirm unaffected earlier content is unchanged.
4. Repeat May; compare business content in both directions, row multiplicities, key sets and reconciled measures. Counts alone are insufficient. Existing input metadata must not be reset on a retry; run/DQ logs may gain entries.
5. Force a failure before publication and after a data commit/before checkpoint update; retry without duplicates or manual deletion.
6. In an isolated test target, process a revised snapshot and late-arrival fixture; confirm affected data updates, unchanged data remains intact, and earlier event dates are not skipped.
7. Introduce a schema-breaking fixture and verify no apparently successful empty output.
8. Replay pinned raw inputs, code, configuration and dependencies in a fresh target; compare business output excluding genuinely run-specific audit records.

Capture immutable evidence under a run-specific directory with the exact source manifest, code revision, config version and runtime. Store large comparison results in R2; commit concise reviewed summaries under `evidence/`.

| Scenario | Run IDs | Source versions | Content comparison | Counts/measures | Result |
|---|---|---|---|---|---|
| March | Pending | Pending | Pending | Pending | Not run |
| + April | Pending | Pending | Pending | Pending | Not run |
| + May | Pending | Pending | Pending | Pending | Not run |
| Repeat May | Pending | Pending | Pending | Pending | Not run |
| Failure/revision/late/schema | Pending | Pending | Pending | Pending | Not run |
| Fresh replay | Pending | Pending | Pending | Pending | Not run |
