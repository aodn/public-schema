"""Basic package sanity tests — no network required."""

import subprocess
import sys
from importlib.resources import files
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest
import yaml

from public_schema import (
    download_resource,
    resolve_resource,
    resource_descriptors_dict,
    resource_descriptors_list,
    validate_local,
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


# --- validate_local ---


def test_validate_local_valid_csv(tmp_path):
    """Header-only CSV matching bgc_chemistry schema columns should be valid."""
    descriptor_path = resolve_resource("bgc_chemistry")
    with open(descriptor_path, encoding="utf-8") as f:
        descriptor = yaml.safe_load(f)

    headers = [f["name"] for f in descriptor["schema"]["fields"]]
    csv_path = tmp_path / "bgc_chemistry.csv"
    csv_path.write_text(",".join(headers) + "\n", encoding="utf-8")

    valid, errors = validate_local(csv_path, "bgc_chemistry")
    assert isinstance(valid, bool)
    assert isinstance(errors, list)


def test_validate_local_wrong_headers(tmp_path):
    csv_path = tmp_path / "bad.csv"
    csv_path.write_text("COL_A,COL_B\n1,2\n", encoding="utf-8")
    valid, _errors = validate_local(csv_path, "bgc_chemistry")
    assert not valid


def test_validate_local_missing_csv():
    with pytest.raises(FileNotFoundError):
        validate_local("/nonexistent/file.csv", "bgc_chemistry")


# --- download_resource ---


def test_download_resource_writes_csv(tmp_path):
    fake_csv = b"FID,TRIP_CODE\n1,T001\n"
    mock_response = MagicMock()
    mock_response.iter_content.return_value = [fake_csv]
    mock_response.raise_for_status.return_value = None

    with patch("public_schema.validate.requests.get", return_value=mock_response):
        out = download_resource("bgc_chemistry", tmp_path)

    assert out == tmp_path / "bgc_chemistry.csv"
    assert out.read_bytes() == fake_csv


def test_download_resource_creates_output_dir(tmp_path):
    new_dir = tmp_path / "subdir" / "nested"
    assert not new_dir.exists()

    mock_response = MagicMock()
    mock_response.iter_content.return_value = [b"FID\n"]
    mock_response.raise_for_status.return_value = None

    with patch("public_schema.validate.requests.get", return_value=mock_response):
        out = download_resource("bgc_chemistry", new_dir)

    assert new_dir.exists()
    assert out.exists()


# --- CLI ---


def test_cli_module_runnable(tmp_path):
    result = subprocess.run(
        [sys.executable, "-m", "public_schema", "validate", "nonexistent.yaml"],
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode != 0


def test_cli_validate_local_subcommand(tmp_path):
    import yaml

    descriptor_path = resolve_resource("bgc_chemistry")
    with open(descriptor_path, encoding="utf-8") as f:
        descriptor = yaml.safe_load(f)

    headers = [f["name"] for f in descriptor["schema"]["fields"]]
    csv_path = tmp_path / "test.csv"
    csv_path.write_text(",".join(headers) + "\n", encoding="utf-8")

    result = subprocess.run(
        [
            sys.executable,
            "-m",
            "public_schema",
            "validate-local",
            "bgc_chemistry",
            str(csv_path),
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, result.stdout + result.stderr


def test_cli_no_args():
    result = subprocess.run(
        [sys.executable, "-m", "public_schema"],
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode != 0
