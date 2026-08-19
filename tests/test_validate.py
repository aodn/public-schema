import pytest
import yaml

from public_schema import resolve_resource, validate_local

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
