# SQL implementation

SQL is organized in pipeline order:

1. `00_source_profile/`
2. `01_ops/`
3. `02_bronze/`
4. `03_silver/`
5. `04_integration/`
6. `05_gold/`
7. `06_analytics/`

Validation SQL belongs beside the layer it validates so each layer has an explicit exit gate. Within a layer, use ordered filenames such as `00_create_tables.sql`, `10_transform.sql`, and `90_validate.sql`.

The numeric prefixes make navigation and review order clear. They do not replace explicit Databricks job dependencies. Resolve actual names from approved configuration and use fully qualified `catalog.schema.table` references.

Gold and Analytics remain placeholders until the star schema is approved. No transformation SQL is implemented or validated yet.
