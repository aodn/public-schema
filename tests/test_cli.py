import subprocess
import sys

from public_schema import resolve_resource


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
