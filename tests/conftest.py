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
