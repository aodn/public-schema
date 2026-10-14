"""Tests for public_schema.flow.store — bulk store_all_products task (ADR-0006/0007/0009)."""

from pathlib import Path

from public_schema.config import RunsheetConfig, TransformConfig
from public_schema.connection import create_connection
from public_schema.flow.store import store_all_products
from public_schema.results import StoreResult


def _create_table(db_path: Path, name: str, rows: str) -> None:
    con = create_connection(db_path)
    try:
        con.execute(f"CREATE TABLE {name} AS {rows}")
    finally:
        con.close()


def _runsheet(transforms: list[TransformConfig]):
    return RunsheetConfig(source_tables=[], transforms=transforms)


def test_store_all_products_all_succeed(tmp_path: Path):
    db_path = tmp_path / "test.duckdb"
    _create_table(db_path, "bgc_chemistry_data", "SELECT 1 AS x")
    runsheet = _runsheet([TransformConfig(name="bgc_chemistry_data", depends=[])])
    output_dir = tmp_path / "products"

    result = store_all_products(db_path, runsheet, output_dir)

    assert isinstance(result, StoreResult)
    assert result.succeeded == ["bgc_chemistry_data"]
    assert result.failed == {}
    assert result.skipped == {}
    assert (output_dir / "bgc_chemistry_data.csv").exists()


def test_store_all_products_ignores_non_product_transforms(tmp_path: Path):
    db_path = tmp_path / "test.duckdb"
    _create_table(db_path, "bgc_chemistry_data", "SELECT 1 AS x")
    runsheet = _runsheet(
        [
            TransformConfig(name="bgc_trip_metadata", depends=[]),
            TransformConfig(name="bgc_chemistry_data", depends=["bgc_trip_metadata"]),
        ]
    )
    output_dir = tmp_path / "products"

    result = store_all_products(db_path, runsheet, output_dir)

    assert result.succeeded == ["bgc_chemistry_data"]
    assert "bgc_trip_metadata" not in result.succeeded
    assert not (output_dir / "bgc_trip_metadata.csv").exists()


def test_store_all_products_records_failure_without_raising(tmp_path: Path):
    db_path = tmp_path / "test.duckdb"
    con = create_connection(db_path)
    con.close()
    # bgc_chemistry_data table was never created
    runsheet = _runsheet([TransformConfig(name="bgc_chemistry_data", depends=[])])

    result = store_all_products(db_path, runsheet, tmp_path / "products")

    assert result.succeeded == []
    assert "bgc_chemistry_data" in result.failed


def test_store_all_products_honours_incoming_skip(tmp_path: Path):
    db_path = tmp_path / "test.duckdb"
    con = create_connection(db_path)
    con.close()
    runsheet = _runsheet([TransformConfig(name="bgc_chemistry_data", depends=[])])

    result = store_all_products(
        db_path,
        runsheet,
        tmp_path / "products",
        skip={"bgc_chemistry_data": "skipped upstream"},
    )

    assert result.succeeded == []
    assert result.failed == {}
    assert result.skipped == {"bgc_chemistry_data": "skipped upstream"}
