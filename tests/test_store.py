"""Tests for public_schema.store — Product CSV export (ADR-0006/0007)."""

from pathlib import Path

import duckdb
import pytest

from public_schema.connection import create_connection
from public_schema.store import is_product, store_product

# --- is_product ---


def test_is_product_true_for_data_suffix():
    assert is_product("bgc_chemistry_data") is True


def test_is_product_false_for_other_suffix():
    assert is_product("bgc_trip_metadata") is False
    assert is_product("bgc_larval_fish_map") is False


# --- store_product ---


def _create_table(db_path: Path, name: str, rows: str) -> None:
    con = create_connection(db_path)
    try:
        con.execute(f"CREATE TABLE {name} AS {rows}")
    finally:
        con.close()


def test_store_product_creates_csv(tmp_path: Path):
    db_path = tmp_path / "test.duckdb"
    _create_table(
        db_path,
        "bgc_chemistry_data",
        "SELECT 'TRIP001' AS TRIP_CODE UNION ALL SELECT 'TRIP002'",
    )
    output_dir = tmp_path / "products"

    output_path = store_product(db_path, "bgc_chemistry_data", output_dir)

    assert output_path == output_dir / "bgc_chemistry_data.csv"
    assert output_path.exists()
    content = output_path.read_text()
    assert "TRIP_CODE" in content
    assert "TRIP001" in content
    assert "TRIP002" in content


def test_store_product_raises_if_table_missing(tmp_path: Path):
    db_path = tmp_path / "test.duckdb"
    con = create_connection(db_path)
    con.close()

    with pytest.raises(duckdb.Error):
        store_product(db_path, "bgc_chemistry_data", tmp_path / "products")
