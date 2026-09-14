# 00 — Source profile

Contains SQL used to inspect source schemas, volumes, date coverage, nulls, duplicate candidates, keys, and unexpected values.

These queries read from source or landing data. They do not write to the control schema by default. Reviewed results are recorded in `docs/source_profile.md` and `evidence/`.

If profile results are later persisted, the target table must be explicitly approved and added to the naming configuration.
