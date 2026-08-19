"""Basic package sanity tests — no network required."""

from importlib.resources import files
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

from public_schema.export import (
    download_resource,
    resolve_resource,
    resource_descriptors_dict,
    resource_descriptors_list,
)


def test_data_resource_accessible():
    resource = (
        files("public_schema.resources.cpr_data") / "cpr_phyto_raw.dataresource.yaml"
    )
    assert resource.is_file()


def test_data_resource_readable():
    resource = (
        files("public_schema.resources.bgc_data") / "bgc_chemistry.dataresource.yaml"
    )
    content = resource.read_text(encoding="utf-8")
    assert "name: bgc_chemistry" in content


# --- resource_descriptors_dict ---


def test_resource_descriptors_dict_returns_dict():
    result = resource_descriptors_dict()
    assert isinstance(result, dict)


def test_resource_descriptors_dict_nonempty():
    result = resource_descriptors_dict()
    assert len(result) > 0


def test_resource_descriptors_dict_keys_are_str():
    result = resource_descriptors_dict()
    assert all(isinstance(k, str) for k in result)


def test_resource_descriptors_dict_values_are_paths():
    result = resource_descriptors_dict()
    assert all(isinstance(v, Path) for v in result.values())


def test_resource_descriptors_dict_paths_exist():
    result = resource_descriptors_dict()
    assert all(v.exists() for v in result.values())


def test_resource_descriptors_dict_contains_known_bgc():
    result = resource_descriptors_dict()
    assert "bgc_chemistry" in result


def test_resource_descriptors_dict_contains_known_cpr():
    result = resource_descriptors_dict()
    assert "cpr_phyto_raw" in result


def test_resource_descriptors_dict_key_matches_filename():
    result = resource_descriptors_dict()
    for name, path in result.items():
        assert path.name == f"{name}.dataresource.yaml"


# --- resource_descriptors_list ---


def test_resource_descriptors_list_returns_list():
    result = resource_descriptors_list()
    assert isinstance(result, list)


def test_resource_descriptors_list_nonempty():
    result = resource_descriptors_list()
    assert len(result) > 0


def test_resource_descriptors_list_are_paths():
    result = resource_descriptors_list()
    assert all(isinstance(p, Path) for p in result)


def test_resource_descriptors_list_paths_exist():
    result = resource_descriptors_list()
    assert all(p.exists() for p in result)


def test_resource_descriptors_list_all_dataresource_yaml():
    result = resource_descriptors_list()
    assert all(p.name.endswith(".dataresource.yaml") for p in result)


def test_resource_descriptors_list_is_sorted():
    result = resource_descriptors_list()
    assert result == sorted(result)


def test_resource_descriptors_list_matches_dict_values():
    d = resource_descriptors_dict()
    lst = resource_descriptors_list()
    assert sorted(d.values()) == lst


# --- resolve_resource ---


def test_resolve_resource_by_name_bgc():
    path = resolve_resource("bgc_chemistry")
    assert path.exists()
    assert path.name == "bgc_chemistry.dataresource.yaml"


def test_resolve_resource_by_name_cpr():
    path = resolve_resource("cpr_phyto_raw")
    assert path.exists()
    assert path.name == "cpr_phyto_raw.dataresource.yaml"


def test_resolve_resource_by_path(tmp_path):
    src = resolve_resource("bgc_chemistry")
    dest = tmp_path / "anything.yaml"
    dest.write_bytes(src.read_bytes())
    result = resolve_resource(dest)
    assert result == dest.resolve()


def test_resolve_resource_unknown_name():
    with pytest.raises(ValueError, match="No bundled resource"):
        resolve_resource("does_not_exist")


def test_resolve_resource_missing_path():
    with pytest.raises(FileNotFoundError):
        resolve_resource("/nonexistent/path.dataresource.yaml")


# --- download_resource ---


def test_download_resource_writes_csv(tmp_path):
    fake_csv = b"FID,TRIP_CODE\n1,T001\n"
    mock_response = MagicMock()
    mock_response.iter_content.return_value = [fake_csv]
    mock_response.raise_for_status.return_value = None

    with patch("public_schema.export.requests.get", return_value=mock_response):
        out = download_resource("bgc_chemistry", tmp_path)

    assert out == tmp_path / "bgc_chemistry.csv"
    assert out.read_bytes() == fake_csv


def test_download_resource_creates_output_dir(tmp_path):
    new_dir = tmp_path / "subdir" / "nested"
    assert not new_dir.exists()

    mock_response = MagicMock()
    mock_response.iter_content.return_value = [b"FID\n"]
    mock_response.raise_for_status.return_value = None

    with patch("public_schema.export.requests.get", return_value=mock_response):
        out = download_resource("bgc_chemistry", new_dir)

    assert new_dir.exists()
    assert out.exists()
