"""Tests for public_schema.load — DDL generation and CSV loading (ADR-0002/0006/0007/0008)."""

from pathlib import Path
from unittest.mock import patch

import duckdb
import pytest
from conftest import TEST_RESOURCES_DIR, mock_resolve_resource

from public_schema.connection import create_connection
from public_schema.load import (
    generate_create_table_sql,
    load_source_table,
)


# Patch resolve_resource to return test resource descriptors instead of the real ones, so that the tests
# don't require network access or the real resource descriptors (which could potentially change over time).
@pytest.fixture(scope="module", autouse=True)
def patch_resolve_resource():
    with patch("public_schema.load.resolve_resource", mock_resolve_resource):
        yield


# --- generate_create_table_sql ---


def test_generate_create_table_sql_returns_create_table():
    sql = generate_create_table_sql("bgc_trip")
    assert sql.strip().startswith("CREATE TABLE bgc_trip")


def test_generate_create_table_sql_maps_types():
    sql = generate_create_table_sql("bgc_chemistry")
    assert "TRIP_CODE VARCHAR" in sql
    assert "SAMPLEDEPTH_M DOUBLE" in sql
    assert "SAMPLEDATELOCAL TIMESTAMP" in sql
    assert "SALINITY_FLAG INTEGER" in sql


def test_generate_create_table_sql_required_becomes_not_null():
    sql = generate_create_table_sql("bgc_chemistry")
    assert "TRIP_CODE VARCHAR NOT NULL" in sql


def test_generate_create_table_sql_not_required_has_no_not_null():
    sql = generate_create_table_sql("bgc_chemistry")
    # SALINITY_FLAG has no constraints
    assert "SALINITY_FLAG INTEGER\n" in sql or "SALINITY_FLAG INTEGER," in sql
    assert "SALINITY_FLAG INTEGER NOT NULL" not in sql


def test_generate_create_table_sql_unique_field():
    sql = generate_create_table_sql("bgc_trip")
    assert "TRIP_ID VARCHAR NOT NULL UNIQUE" in sql


def test_generate_create_table_sql_single_column_primary_key():
    sql = generate_create_table_sql("bgc_trip")
    assert "PRIMARY KEY (TRIP_CODE)" in sql


def test_generate_create_table_sql_composite_primary_key():
    sql = generate_create_table_sql("bgc_chemistry")
    assert "PRIMARY KEY (TRIP_CODE, SAMPLEDEPTH_M)" in sql


def test_generate_create_table_sql_foreign_key():
    sql = generate_create_table_sql("bgc_tss_meta")
    assert "FOREIGN KEY (TRIP_CODE) REFERENCES bgc_trip" in sql


def test_generate_create_table_sql_no_foreign_key_when_absent():
    sql = generate_create_table_sql("bgc_trip")
    assert "FOREIGN KEY" not in sql


def test_generate_create_table_sql_is_valid_duckdb_ddl():
    con = duckdb.connect(":memory:")
    try:
        con.execute(generate_create_table_sql("bgc_trip"))
        con.execute(generate_create_table_sql("bgc_chemistry"))
        con.execute(generate_create_table_sql("bgc_tss_meta"))
    finally:
        con.close()


# --- load_source_table ---


def test_load_source_table_loads_csv(tmp_path: Path):
    db_path = tmp_path / "test.duckdb"
    csv_path = TEST_RESOURCES_DIR / "bgc_trip.csv"
    load_source_table(db_path, "bgc_trip", csv_path)

    con = create_connection(db_path)
    try:
        rows = con.execute(
            "SELECT TRIP_CODE FROM bgc_trip ORDER BY TRIP_CODE"
        ).fetchall()
    finally:
        con.close()
    assert rows == [("TRIP001",), ("TRIP002",)]


def test_load_source_table_raises_on_missing_required_column(tmp_path: Path):
    db_path = tmp_path / "test.duckdb"
    csv_path = tmp_path / "bgc_trip.csv"
    # missing required PROJECTNAME column entirely -> CSV load must fail, not silently pass
    csv_path.write_text(
        "FID,TRIP_CODE,STATIONNAME,STATIONCODE,LONGITUDE\n1,TRIP1,station,STN,123.4\n"
    )
    with pytest.raises(duckdb.Error):
        load_source_table(db_path, "bgc_trip", csv_path)


def test_load_source_table_raises_on_foreign_key_violation(tmp_path: Path):
    db_path = tmp_path / "test.duckdb"
    # bgc_tss_meta.TRIP_CODE references bgc_trip, which is never loaded here
    con = create_connection(db_path)
    con.close()
    csv_path = TEST_RESOURCES_DIR / "bgc_tss_meta.csv"

    with pytest.raises(duckdb.Error):
        load_source_table(db_path, "bgc_tss_meta", csv_path)
