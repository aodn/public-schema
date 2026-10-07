"""Tests for public_schema.transform — sql_files_list, sql_files_dict, run_transform,
and run_transforms (ADR-0005/0006/0007)."""

from pathlib import Path
from unittest.mock import patch

import duckdb
import pytest
from conftest import TEST_RESOURCES_DIR, mock_resolve_resource, mock_sql_files_dict

from public_schema import sql_files_dict, sql_files_list
from public_schema.config import RunsheetConfig, TransformConfig
from public_schema.connection import create_connection
from public_schema.load import load_source_table
from public_schema.results import TransformResult
from public_schema.transform import run_transform, run_transforms

# --- sql_files_list ---


def test_sql_files_list_returns_list():
    assert isinstance(sql_files_list(), list)


def test_sql_files_list_nonempty():
    assert len(sql_files_list()) > 0


def test_sql_files_list_are_paths():
    assert all(isinstance(p, Path) for p in sql_files_list())


def test_sql_files_list_paths_exist():
    assert all(p.exists() for p in sql_files_list())


def test_sql_files_list_all_sql():
    assert all(p.suffix == ".sql" for p in sql_files_list())


def test_sql_files_list_is_sorted():
    result = sql_files_list()
    assert result == sorted(result)


def test_sql_files_list_contains_known_bgc():
    names = {p.stem for p in sql_files_list()}
    assert "bgc_trip_metadata" in names


def test_sql_files_list_contains_known_cpr():
    names = {p.stem for p in sql_files_list()}
    assert "cpr_phytoplankton_map" in names


def test_sql_files_list_excludes_resource_names():
    # bgc_chemistry/cpr_phyto_raw are Resource names, not Transforms — they must never appear
    # here, whether or not a resource happens to share a name with some unrelated .sql file.
    names = {p.stem for p in sql_files_list()}
    assert "bgc_chemistry" not in names
    assert "cpr_phyto_raw" not in names


# --- sql_files_dict ---


def test_sql_files_dict_returns_dict():
    assert isinstance(sql_files_dict(), dict)


def test_sql_files_dict_nonempty():
    assert len(sql_files_dict()) > 0


def test_sql_files_dict_keys_are_str():
    assert all(isinstance(k, str) for k in sql_files_dict())


def test_sql_files_dict_values_are_paths():
    assert all(isinstance(v, Path) for v in sql_files_dict().values())


def test_sql_files_dict_paths_exist():
    assert all(v.exists() for v in sql_files_dict().values())


def test_sql_files_dict_contains_known_bgc():
    assert "bgc_trip_metadata" in sql_files_dict()


def test_sql_files_dict_contains_known_cpr():
    assert "cpr_phytoplankton_map" in sql_files_dict()


def test_sql_files_dict_excludes_resource_names():
    d = sql_files_dict()
    assert "bgc_chemistry" not in d
    assert "cpr_phyto_raw" not in d


def test_sql_files_dict_key_matches_stem():
    for name, path in sql_files_dict().items():
        assert path.stem == name


# --- consistency between list and dict ---


def test_sql_files_list_matches_dict_values():
    assert sql_files_list() == sorted(sql_files_dict().values())


# --- run_transform / run_transforms ---


# Patch resolve_resource/sql_files_dict so tests use fixture descriptors and fixture SQL files
# instead of the real bundled resources (which could potentially change over time).
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


def test_run_transform_creates_table(tmp_path: Path, patch_resources):
    db_path = _db_with_bgc_trip(tmp_path)
    run_transform(db_path, "bgc_trip_metadata")

    con = create_connection(db_path)
    try:
        rows = con.execute(
            "SELECT TRIP_CODE FROM bgc_trip_metadata ORDER BY TRIP_CODE"
        ).fetchall()
    finally:
        con.close()
    assert rows == [("TRIP001",), ("TRIP002",)]


def test_run_transform_raises_on_missing_dependency(tmp_path: Path, patch_resources):
    db_path = tmp_path / "test.duckdb"
    # bgc_trip_metadata depends on bgc_trip, which is never loaded here
    with pytest.raises(duckdb.Error):
        run_transform(db_path, "bgc_trip_metadata")


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
