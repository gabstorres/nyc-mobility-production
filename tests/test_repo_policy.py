"""
Repository policy checks. Run locally with:

    python -m pytest tests

The same command runs in CI (.github/workflows/ci.yml).
"""
import ast
import json
import re
import subprocess
from pathlib import Path

import pytest
import yaml

REPO_ROOT = Path(__file__).resolve().parents[1]

ETL_LAYERS = {
    "01_control",
    "02_bronze",
    "03_silver",
    "04_integration",
    "05_gold",
    "06_analytics",
}
ETL_FILE_NAME = re.compile(r"^\d{2}_[a-z0-9_]+\.(sql|py)$")
PROJECT_SCHEMA = r"`0[1-6]-[a-z]+`"
CATALOG = "`ftw-week-08`"

# Known violations that already exist on main. Each entry must name the fix.
# Remove an entry as soon as the fix merges; the test fails if an entry is stale.
KNOWN_DIGIT_TABLE_NAMES = {
    # PR #70 results table; to move to `01-control`.data_quality_results (D16)
    ("etl/02_bronze/90_validate_taxi_zones.sql", "90_validate_taxi_zones"),
}


def tracked_files():
    output = subprocess.check_output(["git", "ls-files", "-z"], cwd=REPO_ROOT)
    return [Path(name) for name in output.decode().split("\0") if name]


FILES = tracked_files()


def files_with_suffix(*suffixes):
    return [path for path in FILES if path.suffix in suffixes]


def read(path):
    return (REPO_ROOT / path).read_text(encoding="utf-8")


def strip_sql_comments(text):
    return "\n".join(line.split("--", 1)[0] for line in text.splitlines())


# ---------------------------------------------------------------------------
# Syntax
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("path", files_with_suffix(".py"), ids=str)
def test_python_parses(path):
    ast.parse(read(path), filename=str(path))


@pytest.mark.parametrize("path", files_with_suffix(".json"), ids=str)
def test_json_parses(path):
    json.loads(read(path))


@pytest.mark.parametrize("path", files_with_suffix(".yml", ".yaml"), ids=str)
def test_yaml_parses(path):
    yaml.safe_load(read(path))


# ---------------------------------------------------------------------------
# Layout and notebook format
# ---------------------------------------------------------------------------

def test_no_ipynb_outside_notebooks_folder():
    offenders = [
        str(path) for path in files_with_suffix(".ipynb")
        if path.parts[0] != "notebooks"
    ]
    assert not offenders, (
        "Commit notebooks in Databricks source format (.py or .sql), not .ipynb: "
        f"{offenders}"
    )


def test_etl_files_follow_layout():
    problems = []
    for path in FILES:
        if path.parts[0] != "etl" or len(path.parts) == 2:
            continue  # files directly under etl/, such as etl/README.md
        layer, name = path.parts[1], path.parts[-1]
        if layer not in ETL_LAYERS:
            problems.append(f"{path}: unknown layer folder '{layer}'")
        elif len(path.parts) != 3:
            problems.append(f"{path}: no subfolders inside a layer folder")
        elif name != "README.md" and not ETL_FILE_NAME.match(name):
            problems.append(f"{path}: name must look like NN_lowercase_name.sql or .py")
    assert not problems, "\n".join(problems)


@pytest.mark.parametrize(
    "path",
    [p for p in files_with_suffix(".py") if p.parts[0] == "etl"],
    ids=str,
)
def test_etl_python_is_databricks_source_format(path):
    first_line = read(path).splitlines()[0] if read(path) else ""
    assert first_line == "# Databricks notebook source", (
        f"{path} must start with '# Databricks notebook source'"
    )


# ---------------------------------------------------------------------------
# Naming rules in SQL and Python code
# ---------------------------------------------------------------------------

# .ipynb is scanned too, so a notebook still gets a clear message before it is converted.
CODE_FILES = [
    p for p in files_with_suffix(".sql", ".py", ".ipynb")
    if p.parts[0] in {"etl", "src"}
]


def digit_table_names(text):
    pattern = re.compile(PROJECT_SCHEMA + r"\.`?(\d\w*)")
    return set(pattern.findall(strip_sql_comments(text)))


@pytest.mark.parametrize("path", CODE_FILES, ids=str)
def test_table_names_do_not_start_with_a_digit(path):
    found = {(str(path), name) for name in digit_table_names(read(path))}
    new = found - KNOWN_DIGIT_TABLE_NAMES
    assert not new, (
        "Table names must not begin with a digit (D13). The 90_ prefix is for "
        f"file names only: {sorted(name for _, name in new)}"
    )


def test_known_digit_table_names_are_still_present():
    """Fails when a known violation is fixed, so the allowlist gets cleaned up."""
    stale = [
        entry for entry in KNOWN_DIGIT_TABLE_NAMES
        if not (REPO_ROOT / entry[0]).exists()
        or entry[1] not in digit_table_names(read(Path(entry[0])))
    ]
    assert not stale, f"Remove fixed entries from KNOWN_DIGIT_TABLE_NAMES: {stale}"


@pytest.mark.parametrize("path", CODE_FILES, ids=str)
def test_schema_references_include_the_catalog(path):
    pattern = re.compile(r"(?<!" + re.escape(CATALOG) + r"\.)" + PROJECT_SCHEMA + r"\.")
    lines = [
        f"line {number}: {line.strip()}"
        for number, line in enumerate(strip_sql_comments(read(path)).splitlines(), 1)
        if pattern.search(line)
    ]
    assert not lines, (
        f"Use fully qualified names ({CATALOG}.`schema`.table):\n" + "\n".join(lines)
    )


# ---------------------------------------------------------------------------
# Self-tests for the rules above
# ---------------------------------------------------------------------------

def test_digit_table_rule_examples():
    assert digit_table_names("CREATE TABLE `ftw-week-08`.`02-bronze`.90_validate_x (") == {"90_validate_x"}
    assert digit_table_names("FROM `ftw-week-08`.`02-bronze`.`90_validate_x`") == {"90_validate_x"}
    assert digit_table_names("FROM `ftw-week-08`.`02-bronze`.green_taxi_raw") == set()
    assert digit_table_names("-- `02-bronze`.90_old_name in a comment") == set()


def test_etl_file_name_rule_examples():
    assert ETL_FILE_NAME.match("90_validate_green_taxi.sql")
    assert ETL_FILE_NAME.match("10_load_green_taxi.py")
    assert not ETL_FILE_NAME.match("validate_green_taxi.ipynb")
    assert not ETL_FILE_NAME.match("green_taxi_trip_create_table.sql")
    assert not ETL_FILE_NAME.match("10_Load_Green_Taxi.sql")
