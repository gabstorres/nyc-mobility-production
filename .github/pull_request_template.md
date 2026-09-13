## Problem and resulting behavior

Describe the final change and link the work item.

## Validation

State what was executed, the run/batch IDs and code revision, and link evidence. Label unexecuted checks as not yet validated.

## Engineering review

- [ ] Grain, keys, and join cardinality are preserved or explicitly changed.
- [ ] Row/measure deltas are explained; critical upstream gates pass.
- [ ] Incremental behavior, unchanged reruns, revisions, and recovery are addressed where relevant.
- [ ] Provenance remains traceable; no data or secrets were accidentally committed.
- [ ] Canonical documentation is updated; any remaining stale document is identified.

## Assumptions or limitations

Record unresolved issues and any justified N/A checklist items.
