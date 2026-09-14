This document defines approved catalog, schema, table, column, and file naming conventions.

# Naming conventions

Status: **Placeholder — pending Issue #3 approval.**

## Fully qualified references

Every persisted table must be referenced as:

```text
<catalog>.<schema>.<table>
```

## Namespace placeholders

| Layer | Placeholder |
|---|---|
| Control | `<TODO_CATALOG_NAME>.<TODO_CONTROL_SCHEMA>` |
| Bronze | `<TODO_CATALOG_NAME>.<TODO_BRONZE_SCHEMA>` |
| Silver | `<TODO_CATALOG_NAME>.<TODO_SILVER_SCHEMA>` |
| Gold | `<TODO_CATALOG_NAME>.<TODO_GOLD_SCHEMA>` |
| Analytics | `<TODO_CATALOG_NAME>.<TODO_ANALYTICS_SCHEMA>` |

## Proposed table patterns

These patterns require team approval in Issue #3.

| Layer | Proposed pattern |
|---|---|
| Bronze | `<source>_raw` |
| Silver | `<business_entity>` |
| Gold fact | `fact_<business_process>` |
| Gold dimension | `dim_<business_entity>` |
| Analytics | `<measure>_by_<dimension>` |
| Control | `<operational_purpose>` |

## Column conventions

- Use lowercase `snake_case` outside source-preserving Bronze columns.
- Use `_id` for identifiers, `_at` for timestamps, and `_date` for dates.
- Use `_count` for counts, `_amount` for currency, and `_flag` for Boolean indicators.
- Preserve source column names in Bronze where practical.
- Document every rename, type change, derived field, semantic change, and dropped field.

## Approval

- [ ] Team approved the catalog.
- [ ] Team approved the schemas.
- [ ] Team approved table patterns and names.
- [ ] `config/project.example.json` was updated with the approved non-secret values.

Approval date: `<TODO_APPROVAL_DATE>`
