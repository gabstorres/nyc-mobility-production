# Architecture

Status: proposed, not deployed. Platform: Databricks + class R2.

External files/API -> immutable raw copies in R2 -> Bronze -> Bronze validation -> Silver -> Silver validation -> built Gold dimensions and facts -> Gold validation -> Analytics -> business dashboard.

Ingestion manifests, per-layer checkpoints and DQ results support the whole pipeline; DQ results also feed a DQ dashboard.

## Storage boundaries

Suggested group prefix from the lecture: `groups/week09/<group-name>/` inside the class `ftw-b12-r2` storage. Confirm the actual bucket/prefix and Databricks Volume mapping with the class setup; this is not a verified mounted filesystem path.

Within the approved prefix, propose `landing/green_taxi/`, `landing/weather/`, `landing/taxi_zones/`, and `evidence/`. Store source versions immutably using a content checksum. Keep requested windows/source months separate from observed event dates.

Bronze preserves source representation and ingestion metadata. Silver owns explicit standardization and quality disposition. Gold owns the approved business model. Analytics queries Gold. The dashboard consumes validated Analytics/Gold.

Dimensions are built before fact FK resolution. No Gold fact may bypass built dimensions by joining directly back to Silver for dimension lookup.

Use Python for external interactions and orchestration, SQL for relational profiling, transformations, modeling and DQ. Keep notebooks thin. Pin code/configuration/source versions for replay; record runtime and dependencies after the platform is inspected.

Shared integration tables have one coordinated writer. Each developer uses isolated approved development targets. Physical table format, job orchestration, transaction boundaries and checkpoint implementation remain pending platform validation.
