# Green Taxi Validation Checks

1. source_readable
2. row_count_not_empty
3. row_count_floor
4. required_columns
5. pickup_timestamp_not_null
6. dropoff_timestamp_not_null
7. trip_distance_non_negative
8. dropoff_after_pickup
9. expected_month_coverage
10. passenger_count_gt_8
11. vendor_id_domain
12. payment_type_domain
13. ratecode_id_domain
14. location_id_range
15. full_source_row_duplicate

The source gate validates local parquet inputs supplied through the --input parameter.

The validation suite does not download source files and does not require network connectivity or credentials.