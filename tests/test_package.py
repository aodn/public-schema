"""Basic package sanity tests — no network required."""

from importlib.resources import files


def test_validate_resource_importable():
    from public_schema.validate import validate_resource

    assert callable(validate_resource)


def test_bgc_data_resource_accessible():
    resource = (
        files("public_schema.resources.bgc_data") / "bgc_chemistry.dataresource.yaml"
    )
    assert resource.is_file(), "bgc_chemistry.dataresource.yaml not found in package"


def test_cpr_data_resource_accessible():
    resource = (
        files("public_schema.resources.cpr_data") / "cpr_phyto_raw.dataresource.yaml"
    )
    assert resource.is_file(), "cpr_phyto_raw.dataresource.yaml not found in package"


def test_bgc_data_resource_readable():
    resource = (
        files("public_schema.resources.bgc_data") / "bgc_chemistry.dataresource.yaml"
    )
    content = resource.read_text(encoding="utf-8")
    assert "profile: tabular-data-resource" in content


def test_cli_module_runnable(tmp_path):
    """Confirm __main__.py exits non-zero for a missing file (no network needed)."""
    import subprocess
    import sys

    result = subprocess.run(
        [sys.executable, "-m", "public_schema", "nonexistent.yaml"],
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode != 0
