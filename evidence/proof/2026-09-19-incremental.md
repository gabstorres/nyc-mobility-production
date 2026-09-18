# Proof: March, then April, then May

Issue #45 · **TEMPLATE — not yet run.** Delete this line once filled in.

## What to demonstrate

March loads first. April is added without reprocessing March. May is added
without reprocessing either. The evidence is **not** that the totals grow — it is
that the earlier months' batch records are byte-identical across runs.

## Reset

```sql
DROP TABLE IF EXISTS `ftw-week-08`.`02-bronze`.green_taxi_raw;
DELETE FROM `ftw-week-08`.`01-control`.ingestion_batches WHERE source_system = 'green_taxi';
```

Then move `green_tripdata_2026-04.parquet` and `green_tripdata_2026-05.parquet`
**out** of the landing folder, leaving only March.

The loader treats the folder as the source, so staging arrivals means moving
files. The path is a literal inside `read_files` and cannot be parameterised,
which is a known limitation of the SQL loader.

## Procedure

| Run | Before running | Then |
|---|---|---|
| 1 | March only in the folder | run the job, capture the snapshot |
| 2 | move April back | run the job, capture the snapshot |
| 3 | move May back | run the job, capture the snapshot |

Snapshot queries are the two in `2026-09-19-idempotency.md`.

## Expected counts

| After run | Bronze | Silver clean | Silver quarantine | Gold fact |
|---|---:|---:|---:|---:|
| 1 — March | 44,208 | | | |
| 2 — + April | 88,446 | | | |
| 3 — + May | 133,367 | 133,353 | 14 | 133,353 |

Clean and quarantine for runs 1 and 2 are left blank deliberately: the collision
groups are known to fall inside single files (2 in March, 2 in April, 3 in May),
so fill these in from the run rather than predicting them.

## The evidence that matters

After each run, record the full `ingestion_batches` rows for `green_taxi`:

```sql
SELECT source_object, source_period, batch_id, status, row_count,
       SUBSTRING(content_sha256, 1, 12) AS sha, started_at, completed_at
FROM `ftw-week-08`.`01-control`.ingestion_batches
WHERE source_system = 'green_taxi' ORDER BY source_object;
```

**March's row must be byte-identical in all three snapshots** — same `batch_id`,
same `row_count`, same `started_at`, same `completed_at`. April's must be
identical between runs 2 and 3. That is what "added without rebuilding" means as
evidence rather than as a claim.

Also confirm from each run's task output that `10_load_green_taxi` reported
**only the newly arrived file**, not all files present.

### Run 1 — March

_Paste snapshot + batch table._

### Run 2 — + April

_Paste snapshot + batch table. Confirm March's row is unchanged from run 1._

### Run 3 — + May

_Paste snapshot + batch table. Confirm March's and April's rows are unchanged._

## Scope: what this proves and what it does not

Incremental loading is demonstrated **at Bronze**. Silver, Integration, Gold and
Analytics are rebuilt in full on every run, which is a recorded decision (D22)
rather than an omission. The reasons are in that entry: late-arriving rows mean
the May file carries 8 April pickups, so rebuilding only the arriving month would
leave April wrong; and the duplicate rule partitions over the whole population.

State this in any walkthrough. "We rebuild above Bronze on purpose, here is why"
is a stronger position than letting a reader discover it.
