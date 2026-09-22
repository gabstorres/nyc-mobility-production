# DuckDB Pre-Ingestion Source Gate

Purpose:
Validate Green Taxi source files locally before Bronze ingestion.

Flow:

Source Files
    ↓
DuckDB Source Gate
    ↓
ACCEPTED / BLOCKED
    ↓
Bronze Ingestion

Exit Codes

0 = ACCEPTED
1 = BLOCKED
2 = MISSING_INPUT