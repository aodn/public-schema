from pathlib import Path

import yaml

TEST_BASE_DIR = Path(__file__).resolve().parent
TEST_RESOURCES_DIR = TEST_BASE_DIR / "resources_for_tests"


def _load_test_schema(name: str) -> dict:
    descriptor_path = TEST_RESOURCES_DIR / f"{name}.dataresource.yaml"
    with open(descriptor_path, encoding="utf-8") as f:
        descriptor = yaml.safe_load(f)
    return descriptor["schema"]


def _mock_load_schema(name: str) -> dict:
    """
    Mock schemas here so that tests don't depend on the actual bundled Frictionless descriptors.
    The mock schemas are simplified and only include the fields needed for the tests.
    """
    return _load_test_schema(name)


def mock_resolve_resource(name_or_path: str | Path) -> Path:
    """
    Mock resolve_resource to return the path to the test resource descriptor.
    """
    if isinstance(name_or_path, Path):
        descriptor_path = TEST_RESOURCES_DIR / name_or_path.name
    else:
        descriptor_path = TEST_RESOURCES_DIR / f"{name_or_path}.dataresource.yaml"
    if not descriptor_path.exists():
        raise ValueError(f"No test resource for {name_or_path!r}.")
    return descriptor_path.resolve()


def mock_download_resource(
    name_or_path: str | Path,
    output_dir: Path,
    http_timeout: int = 100,
) -> Path:
    """
    Mock download_resource to return the path to a test CSV file instead of actually downloading it.
    """
    if isinstance(name_or_path, Path):
        resource_name = name_or_path.stem.removesuffix(".dataresource")
    else:
        resource_name = str(name_or_path)

    csv_path = TEST_RESOURCES_DIR / f"{resource_name}.csv"
    if not csv_path.exists():
        raise FileNotFoundError(f"Test CSV file {csv_path} does not exist.")
    return csv_path.resolve()
