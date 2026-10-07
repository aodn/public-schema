from pathlib import Path

TEST_BASE_DIR = Path(__file__).resolve().parent
TEST_RESOURCES_DIR = TEST_BASE_DIR / "resources_for_tests"


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
    Mock download_resource to copy a test CSV file to output_dir instead of actually downloading it.
    """
    if isinstance(name_or_path, Path):
        resource_name = name_or_path.stem.removesuffix(".dataresource")
    else:
        resource_name = str(name_or_path)

    csv_path = TEST_RESOURCES_DIR / f"{resource_name}.csv"
    if not csv_path.exists():
        raise FileNotFoundError(f"Test CSV file {csv_path} does not exist.")

    output_path = output_dir / csv_path.name
    with open(csv_path, "rb") as src, open(output_path, "wb") as dst:
        dst.write(src.read())

    return output_path.resolve()
