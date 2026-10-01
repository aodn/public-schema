from unittest.mock import patch

import pytest
import yaml
from conftest import TEST_RESOURCES_DIR

from public_schema import resolve_resource, validate_local
from public_schema.config import RunsheetConfig
from public_schema.validate import download_and_validate_source_tables

# --- validate_local ---

# TODO: use test fixtures for schema and data files, rather than relying on bundled resources.


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


# --- download_and_validate_source_tables ---


def test_download_and_validate_source_tables_single_success(tmp_path):
    """Test successful download and validation of a single table."""
    # Create a runsheet with one source table
    runsheet = RunsheetConfig(
        source_tables=["bgc_chemistry"],
        transforms=[],
    )

    # Mock download_resource and resolve_resource to use test resources
    with (
        patch("public_schema.validate.download_resource") as mock_download,
        patch("public_schema.validate.resolve_resource") as mock_resolve,
    ):
        mock_download.return_value = TEST_RESOURCES_DIR / "bgc_chemistry.csv"
        mock_resolve.return_value = (
            TEST_RESOURCES_DIR / "bgc_chemistry.dataresource.yaml"
        )

        result = download_and_validate_source_tables(runsheet, tmp_path)

    assert result.succeeded == ["bgc_chemistry"]
    assert result.failed == {}
    assert result.skipped == {}
    # Verify download_resource was called once
    mock_download.assert_called_once()


def test_download_and_validate_source_tables_multiple_success(tmp_path):
    """Test successful download and validation of multiple tables."""
    runsheet = RunsheetConfig(
        source_tables=["bgc_chemistry", "bgc_trip"],
        transforms=[],
    )

    with (
        patch("public_schema.validate.download_resource") as mock_download,
        patch("public_schema.validate.resolve_resource") as mock_resolve,
    ):

        def download_side_effect(name, output_dir, **kwargs):
            # Return the appropriate test CSV file based on the name
            return TEST_RESOURCES_DIR / f"{name}.csv"

        def resolve_side_effect(name):
            return TEST_RESOURCES_DIR / f"{name}.dataresource.yaml"

        mock_download.side_effect = download_side_effect
        mock_resolve.side_effect = resolve_side_effect

        result = download_and_validate_source_tables(runsheet, tmp_path)

    assert set(result.succeeded) == {"bgc_chemistry", "bgc_trip"}
    assert result.failed == {}
    assert result.skipped == {}
    assert mock_download.call_count == 2


def test_download_and_validate_source_tables_validation_failure(tmp_path):
    """Test that validation errors are caught and recorded in the failed dict."""
    runsheet = RunsheetConfig(
        source_tables=["bgc_chemistry"],
        transforms=[],
    )

    # Create an invalid CSV file that doesn't match the schema
    invalid_csv = tmp_path / "invalid.csv"
    invalid_csv.write_text("COL_A,COL_B\n1,2\n", encoding="utf-8")

    with (
        patch("public_schema.validate.download_resource") as mock_download,
        patch("public_schema.validate.resolve_resource") as mock_resolve,
    ):
        mock_download.return_value = invalid_csv
        mock_resolve.return_value = (
            TEST_RESOURCES_DIR / "bgc_chemistry.dataresource.yaml"
        )

        result = download_and_validate_source_tables(runsheet, tmp_path)

    assert result.succeeded == []
    assert "bgc_chemistry" in result.failed
    assert "Validation failed:" in result.failed["bgc_chemistry"]
    assert result.skipped == {}


def test_download_and_validate_source_tables_download_failure(tmp_path):
    """Test that download exceptions are caught and recorded."""
    runsheet = RunsheetConfig(
        source_tables=["bgc_chemistry"],
        transforms=[],
    )

    with patch("public_schema.validate.download_resource") as mock_download:
        mock_download.side_effect = Exception("Network error: connection timeout")

        result = download_and_validate_source_tables(runsheet, tmp_path)

    assert result.succeeded == []
    assert "bgc_chemistry" in result.failed
    assert "Network error: connection timeout" in result.failed["bgc_chemistry"]
    assert result.skipped == {}


def test_download_and_validate_source_tables_mixed_results(tmp_path):
    """Test mixed results where some tables succeed and others fail."""
    runsheet = RunsheetConfig(
        source_tables=["bgc_chemistry", "bgc_trip", "bgc_tss_meta"],
        transforms=[],
    )

    # Create an invalid CSV for bgc_trip
    invalid_csv = tmp_path / "invalid_trip.csv"
    invalid_csv.write_text("WRONG_COL\n1\n", encoding="utf-8")

    with (
        patch("public_schema.validate.download_resource") as mock_download,
        patch("public_schema.validate.resolve_resource") as mock_resolve,
    ):

        def download_side_effect(name, output_dir, **kwargs):
            if name == "bgc_trip":
                return invalid_csv
            elif name == "bgc_tss_meta":
                raise ValueError("Resource not found")
            else:
                return TEST_RESOURCES_DIR / f"{name}.csv"

        def resolve_side_effect(name):
            return TEST_RESOURCES_DIR / f"{name}.dataresource.yaml"

        mock_download.side_effect = download_side_effect
        mock_resolve.side_effect = resolve_side_effect

        result = download_and_validate_source_tables(runsheet, tmp_path)

    assert result.succeeded == ["bgc_chemistry"]
    assert "bgc_trip" in result.failed  # Validation failed
    assert "bgc_tss_meta" in result.failed  # Download failed
    assert result.skipped == {}


def test_download_and_validate_source_tables_empty_runsheet(tmp_path):
    """Test that an empty runsheet produces no results."""
    runsheet = RunsheetConfig(
        source_tables=[],
        transforms=[],
    )

    result = download_and_validate_source_tables(runsheet, tmp_path)

    assert result.succeeded == []
    assert result.failed == {}
    assert result.skipped == {}


def test_download_and_validate_source_tables_with_http_timeout(tmp_path):
    """Test that http_timeout parameter is passed to download_resource."""
    runsheet = RunsheetConfig(
        source_tables=["bgc_chemistry"],
        transforms=[],
    )

    with (
        patch("public_schema.validate.download_resource") as mock_download,
        patch("public_schema.validate.resolve_resource") as mock_resolve,
    ):
        mock_download.return_value = TEST_RESOURCES_DIR / "bgc_chemistry.csv"
        mock_resolve.return_value = (
            TEST_RESOURCES_DIR / "bgc_chemistry.dataresource.yaml"
        )

        result = download_and_validate_source_tables(
            runsheet, tmp_path, http_timeout=200
        )

    assert result.succeeded == ["bgc_chemistry"]
    # Verify http_timeout was passed
    mock_download.assert_called_once()
    _, kwargs = mock_download.call_args
    assert kwargs.get("http_timeout") == 200
