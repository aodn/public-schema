"""Tests for public_schema.flow.load — bulk load_source_tables task (ADR-0002/0006/0007/0008)."""

from pathlib import Path
from unittest.mock import patch

import pytest
from conftest import TEST_RESOURCES_DIR, mock_download_resource, mock_resolve_resource

from public_schema.config import RunsheetConfig
from public_schema.flow.load import load_source_tables
from public_schema.results import LoadResult


# Patch resolve_resource to return test resource descriptors instead of the real ones, so that the
# tests don't require network access or the real resource descriptors (which could potentially
# change over time). `load_source_tables` calls `load_source_table`/`_load_schema`, which still
# live in `public_schema.load`, so that's the module to patch.
@pytest.fixture(scope="module", autouse=True)
def patch_resolve_resource():
    with patch("public_schema.load.resolve_resource", mock_resolve_resource):
        yield


def _runsheet(source_tables):
    return RunsheetConfig(source_tables=source_tables, transforms=[])


def test_load_source_tables_all_succeed(tmp_path: Path):
    db_path = tmp_path / "test.duckdb"
    csv_dir = TEST_RESOURCES_DIR
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
    mock_download_resource("bgc_tss_meta", csv_dir)

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
