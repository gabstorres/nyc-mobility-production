# 01 — Control

Contains SQL for ingestion batches, pipeline runs, processing checkpoints, schema observations, and data-quality results.

Persisted operational tables created here use the approved control schema.

Processing state must advance only after the corresponding load and required validation succeed.
