# Source profile

Status: not yet executed. Listed source URLs are not proof of successful downloads or valid data.

## File inventory

For each taxi month and reference snapshot record source URL, filename, retrieval time, bytes, SHA-256, Parquet/CSV readability, row count, schema and observed event range. Compare March, April and May schemas before accepting a contract. Do not assume filenames guarantee event-date coverage.

| Source | Rows | Schema | Observed dates | Key nulls | Duplicate candidates | Other anomalies | Evidence |
|---|---|---|---|---|---|---|---|
| Taxi March 2026 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| Taxi April 2026 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| Taxi May 2026 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| Taxi zones | Pending | Pending | Snapshot | Pending | LocationID uniqueness pending | Pending | Pending |

Profile null rates for every column; full-row equality and candidate-key collisions; within/across-file duplicate candidates; unexpected codes; negative/zero measures; missing timestamps; durations; out-of-month events; and pickup/drop-off reference coverage. The public taxi schema does not establish a unique trip ID; do not treat VendorID as a vehicle/trip key.

## API profile

Record endpoint, full non-secret parameters, request window, status/headers, response checksum, structure, array lengths, units, location/grid metadata, timestamp coverage, duplicates, nulls, empty-response behavior, and error bodies. Inspect documented throttling and implement bounded retries; do not deliberately stress the service. Determine whether pagination applies rather than inventing it.

Generate expected hourly coverage from the requested interval and timezone; test DST. Document request/model selection and a historical revision policy.

## Exit gate

Owner and reviewer agree source schemas, dates, volume, identity limitations, anomalies and response contracts. Any unresolved issue affecting correctness blocks dependent transformations.
