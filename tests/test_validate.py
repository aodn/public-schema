from unittest.mock import patch

import pytest
from conftest import TEST_RESOURCES_DIR, mock_resolve_resource

from public_schema import validate_local

# --- validate_local ---


@patch("public_schema.validate.resolve_resource", mock_resolve_resource)
def test_validate_local_valid_csv(tmp_path):
    csv_path = TEST_RESOURCES_DIR / "bgc_chemistry.csv"

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
