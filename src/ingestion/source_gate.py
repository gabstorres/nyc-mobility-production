import duckdb
import json
from pathlib import Path


def load_contract():
    contract_path = Path("config/source_contract.json")

    with open(contract_path, "r") as file:
        return json.load(file)


def check_row_count():
    query = """
    SELECT COUNT(*) AS row_count
    FROM read_parquet(
        'https://d37ci6vzurychx.cloudfront.net/trip-data/green_tripdata_2026-03.parquet'
    )
    """

    return duckdb.sql(query).fetchone()[0]


def get_columns():
    query = """
    DESCRIBE
    SELECT *
    FROM read_parquet(
        'https://d37ci6vzurychx.cloudfront.net/trip-data/green_tripdata_2026-03.parquet'
    )
    """

    results = duckdb.sql(query).fetchall()

    return [row[0] for row in results]


def main():
    contract = load_contract()

    print("Loaded contract:")
    print(contract.keys())

    green_taxi = contract["green_taxi"]

    print("\nRequired columns:")
    for column in green_taxi["required_columns"]:
        print(f"- {column}")

    print("\nRequired fields:")
    for field in green_taxi["required_fields"]:
        print(f"- {field}")

    print("\nRow count floor:")
    print(green_taxi["row_count_floor"])

    row_count = check_row_count()

    print("\nObserved row count:")
    print(row_count)

    if row_count >= green_taxi["row_count_floor"]:
        print("\nPASS: Row count validation passed.")
    else:
        print("\nFAIL: Row count validation failed.")

    columns = get_columns()

    print("\nColumns found:")
    for column in columns:
        print(f"- {column}")

    missing_columns = []

    for required_column in green_taxi["required_columns"]:
        if required_column not in columns:
            missing_columns.append(required_column)

    if missing_columns:
        print("\nFAIL: Missing required columns")
        print(missing_columns)
    else:
        print("\nPASS: All required columns exist.")


if __name__ == "__main__":
    main()