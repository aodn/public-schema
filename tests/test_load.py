"""Tests for public_schema.load — DDL generation and CSV loading (ADR-0002/0006/0007/0008)."""

from pathlib import Path

import duckdb
import pytest

from public_schema.config import RunsheetConfig
from public_schema.connection import create_connection
from public_schema.load import (
    generate_create_table_sql,
    load_source_table,
    load_source_tables,
)
from public_schema.results import LoadResult

# --- generate_create_table_sql ---


def test_generate_create_table_sql_returns_create_table():
    sql = generate_create_table_sql("bgc_trip")
    assert sql.strip().upper().startswith("CREATE TABLE BGC_TRIP".upper())


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
    # SILICATE_UMOLL has no constraints
    assert "SILICATE_UMOLL DOUBLE\n" in sql or "SILICATE_UMOLL DOUBLE," in sql
    assert "SILICATE_UMOLL DOUBLE NOT NULL" not in sql


def test_generate_create_table_sql_unique_field():
    sql = generate_create_table_sql("bgc_lfish_samples")
    assert "I_SAMPLE_ID INTEGER NOT NULL UNIQUE" in sql


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
    csv_path = tmp_path / "bgc_trip.csv"
    csv_path.write_text(
        "FID,PROJECTNAME,TRIP_CODE,STATIONNAME,STATIONCODE,LONGITUDE,LATITUDE,SAMPLEDATEUTC\n"
        "1,proj,TRIP1,station,STN,123.4,-33.1,2020-01-01 00:00:00\n"
    )
    load_source_table(db_path, "bgc_trip", csv_path)

    con = create_connection(db_path)
    try:
        rows = con.execute("SELECT TRIP_CODE FROM bgc_trip").fetchall()
    finally:
        con.close()
    assert rows == [("TRIP1",)]


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
    csv_path = tmp_path / "bgc_tss_meta.csv"
    csv_path.write_text(
        "FID,TRIP_CODE,SAMPLEDATELOCAL,SAMPLEDEPTH_M,REPLICATE,TSS_FLAG\n"
        "1,NOPE,2020-01-01 00:00:00,1,1,1\n"
    )
    with pytest.raises(duckdb.Error):
        load_source_table(db_path, "bgc_tss_meta", csv_path)


# --- load_source_tables (bulk) ---


def _runsheet(source_tables):
    return RunsheetConfig(source_tables=source_tables, transforms=[])


def test_load_source_tables_all_succeed(tmp_path: Path):
    db_path = tmp_path / "test.duckdb"
    csv_dir = tmp_path / "csv"
    csv_dir.mkdir()
    (csv_dir / "bgc_trip.csv").write_text(
        "FID,PROJECTNAME,TRIP_CODE,STATIONNAME,STATIONCODE,LONGITUDE,LATITUDE,SAMPLEDATEUTC\n"
        "1,proj,TRIP1,station,STN,123.4,-33.1,2020-01-01 00:00:00\n"
    )
    result = load_source_tables(db_path, _runsheet(["bgc_trip"]), csv_dir)
    assert isinstance(result, LoadResult)
    assert result.succeeded == ["bgc_trip"]
    assert result.failed == {}
    assert result.skipped == {}


def test_load_source_tables_records_failure_without_raising(tmp_path: Path):
    db_path = tmp_path / "test.duckdb"
    csv_dir = tmp_path / "csv"
    csv_dir.mkdir()
    (csv_dir / "bgc_trip.csv").write_text("not,a,valid,csv,at,all\n1,2\n")
    result = load_source_tables(db_path, _runsheet(["bgc_trip"]), csv_dir)
    assert result.succeeded == []
    assert "bgc_trip" in result.failed


def test_load_source_tables_skips_dependent_of_failed_table(tmp_path: Path):
    db_path = tmp_path / "test.duckdb"
    csv_dir = tmp_path / "csv"
    csv_dir.mkdir()
    # bgc_trip fails (bad CSV); bgc_tss_meta depends on it via databaseForeignKeys
    (csv_dir / "bgc_trip.csv").write_text("not,a,valid,csv\n1,2\n")
    (csv_dir / "bgc_tss_meta.csv").write_text(
        "FID,TRIP_CODE,SAMPLEDATELOCAL,SAMPLEDEPTH_M,REPLICATE,TSS_FLAG\n"
        "1,TRIP1,2020-01-01 00:00:00,1,1,1\n"
    )
    result = load_source_tables(
        db_path, _runsheet(["bgc_trip", "bgc_tss_meta"]), csv_dir
    )
    assert "bgc_trip" in result.failed
    assert "bgc_tss_meta" in result.skipped


def test_load_source_tables_honours_incoming_skip(tmp_path: Path):
    db_path = tmp_path / "test.duckdb"
    csv_dir = tmp_path / "csv"
    csv_dir.mkdir()
    result = load_source_tables(
        db_path,
        _runsheet(["bgc_trip"]),
        csv_dir,
        skip={"bgc_trip": "skipped upstream"},
    )
    assert result.succeeded == []
    assert result.failed == {}
    assert result.skipped == {"bgc_trip": "skipped upstream"}
