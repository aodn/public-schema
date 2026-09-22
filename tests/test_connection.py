"""Tests for public_schema.connection — create_connection (see ADR-0007)."""

from pathlib import Path

import duckdb

from public_schema.connection import create_connection


def test_create_connection_returns_duckdb_connection(tmp_path: Path):
    con = create_connection(tmp_path / "test.duckdb")
    try:
        assert isinstance(con, duckdb.DuckDBPyConnection)
    finally:
        con.close()


def test_create_connection_creates_db_file(tmp_path: Path):
    db_path = tmp_path / "sub" / "test.duckdb"
    con = create_connection(db_path)
    con.close()
    assert db_path.exists()


def test_create_connection_loads_spatial_extension(tmp_path: Path):
    # a query using a spatial function must succeed without an explicit INSTALL/LOAD
    con = create_connection(tmp_path / "test.duckdb")
    try:
        (wkt,) = con.execute("SELECT ST_AsText(ST_Point(1, 2))").fetchone()
        assert wkt == "POINT (1 2)"
    finally:
        con.close()


def test_create_connection_reopens_same_file(tmp_path: Path):
    db_path = tmp_path / "test.duckdb"
    con1 = create_connection(db_path)
    con1.execute("CREATE TABLE t (a INTEGER)")
    con1.execute("INSERT INTO t VALUES (1)")
    con1.close()

    con2 = create_connection(db_path)
    try:
        (count,) = con2.execute("SELECT count(*) FROM t").fetchone()
        assert count == 1
    finally:
        con2.close()


def test_create_connection_accepts_str_path(tmp_path: Path):
    con = create_connection(str(tmp_path / "test.duckdb"))
    try:
        assert isinstance(con, duckdb.DuckDBPyConnection)
    finally:
        con.close()
