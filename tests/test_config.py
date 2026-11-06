"""Tests for public_schema.config — no network required."""

import pytest

from public_schema.config import RunsheetConfig, load_runsheet, resolve_runsheet

# --- resolve_runsheet ---


def test_resolve_runsheet_by_name_bgc():
    path = resolve_runsheet("bgc_runsheet")
    assert path.exists()
    assert path.name == "bgc_runsheet.yaml"


def test_resolve_runsheet_by_name_cpr():
    path = resolve_runsheet("cpr_runsheet")
    assert path.exists()
    assert path.name == "cpr_runsheet.yaml"


def test_resolve_runsheet_by_path(tmp_path):
    src = resolve_runsheet("bgc_runsheet")
    dest = tmp_path / "anything.yaml"
    dest.write_bytes(src.read_bytes())
    result = resolve_runsheet(dest)
    assert result == dest.resolve()


def test_resolve_runsheet_unknown_name():
    with pytest.raises(ValueError, match="No bundled runsheet"):
        resolve_runsheet("does_not_exist")


def test_resolve_runsheet_missing_path():
    with pytest.raises(FileNotFoundError):
        resolve_runsheet("/nonexistent/path.yaml")


# --- load_runsheet ---


def test_load_runsheet_by_name_bgc():
    runsheet = load_runsheet("bgc_runsheet")
    assert isinstance(runsheet, RunsheetConfig)
    assert runsheet.source_tables


def test_load_runsheet_by_name_cpr():
    runsheet = load_runsheet("cpr_runsheet")
    assert isinstance(runsheet, RunsheetConfig)
    assert runsheet.source_tables


def test_load_runsheet_by_path():
    path = resolve_runsheet("bgc_runsheet")
    runsheet = load_runsheet(path)
    assert isinstance(runsheet, RunsheetConfig)
