"""Tests for public_schema.flow.transform — bulk run_transforms task (ADR-0005/0006/0007/0009)."""

from pathlib import Path
from unittest.mock import patch

import pytest
from conftest import TEST_RESOURCES_DIR, mock_resolve_resource, mock_sql_files_dict

from public_schema.config import RunsheetConfig, TransformConfig
from public_schema.flow.transform import run_transforms
from public_schema.load import load_source_table
from public_schema.results import TransformResult


# Patch resolve_resource/sql_files_dict so tests use fixture descriptors and fixture SQL files
# instead of the real bundled resources (which could potentially change over time).
# `run_transforms` calls `run_transform`, which still lives in `public_schema.transform`, so
# that's the module to patch `sql_files_dict` on.
@pytest.fixture()
def patch_resources():
    with (
        patch("public_schema.load.resolve_resource", mock_resolve_resource),
        patch("public_schema.transform.sql_files_dict", mock_sql_files_dict),
    ):
        yield


def _db_with_bgc_trip(tmp_path: Path) -> Path:
    db_path = tmp_path / "test.duckdb"
    load_source_table(db_path, "bgc_trip", TEST_RESOURCES_DIR / "bgc_trip.csv")
    return db_path


def _runsheet(transforms: list[TransformConfig]):
    return RunsheetConfig(source_tables=["bgc_trip"], transforms=transforms)


def test_run_transforms_all_succeed(tmp_path: Path, patch_resources):
    db_path = _db_with_bgc_trip(tmp_path)
    runsheet = _runsheet(
        [
            TransformConfig(name="bgc_trip_metadata", depends=["bgc_trip"]),
            TransformConfig(name="bgc_chemistry_data", depends=["bgc_trip_metadata"]),
        ]
    )
    result = run_transforms(db_path, runsheet)
    assert isinstance(result, TransformResult)
    assert result.succeeded == ["bgc_trip_metadata", "bgc_chemistry_data"]
    assert result.failed == {}
    assert result.skipped == {}


def test_run_transforms_records_failure_without_raising(
    tmp_path: Path, patch_resources
):
    # bgc_tss_data.sql depends on a non-existent table, so it will fail when run_transform is called.
    db_path = _db_with_bgc_trip(tmp_path)
    runsheet = _runsheet([TransformConfig(name="bgc_tss_data", depends=[])])
    result = run_transforms(db_path, runsheet)
    assert result.succeeded == []
    assert "bgc_tss_data" in result.failed


def test_run_transforms_skips_dependent_of_failed_transform(
    tmp_path: Path, patch_resources
):
    db_path = _db_with_bgc_trip(tmp_path)
    runsheet = _runsheet(
        [
            TransformConfig(name="bgc_tss_data", depends=[]),
            TransformConfig(name="bgc_chemistry_data", depends=["bgc_tss_data"]),
        ]
    )
    result = run_transforms(db_path, runsheet)
    assert "bgc_tss_data" in result.failed
    assert "bgc_chemistry_data" in result.skipped


def test_run_transforms_honours_incoming_skip(tmp_path: Path, patch_resources):
    db_path = _db_with_bgc_trip(tmp_path)
    runsheet = _runsheet(
        [TransformConfig(name="bgc_trip_metadata", depends=["bgc_trip"])]
    )
    result = run_transforms(
        db_path, runsheet, skip={"bgc_trip_metadata": "skipped upstream"}
    )
    assert result.succeeded == []
    assert result.failed == {}
    assert result.skipped == {"bgc_trip_metadata": "skipped upstream"}
