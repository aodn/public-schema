"""Top-level flow implementing the IMOS Water Sampling DB ELT pipeline."""

import argparse
from pathlib import Path
from pprint import pprint
from shutil import rmtree

from public_schema import StageResult
from public_schema.config import load_runsheet
from public_schema.load import load_source_tables
from public_schema.validate import download_and_validate_source_tables


def report_result(result: StageResult):
    print(
        f"{result.name.title()} result: {len(result.succeeded)} succeeded, {len(result.failed)} failed,"
        f" {len(result.skipped)} skipped."
    )
    pprint(result.model_dump())


def run_pipeline(
    runsheet_path: str | Path,
    base_dir: str | Path | None = None,
    http_timeout: int = 100,
):
    """
    Run the IMOS Water Sampling DB ELT pipeline.

    :param runsheet_path: path to the runsheet file
    :param base_dir: base directory for database and exported tables (if None, a temporary directory is created)
    :param http_timeout: http response timeout in seconds (for downloading source tables)
    """
    # Load the runsheet
    runsheet = load_runsheet(runsheet_path)

    if base_dir is None:
        base_dir = Path("/tmp/water_sampling_db")
    else:
        base_dir = Path(base_dir).resolve()

    # set up subdirectory for source tables and clear it if it already exists
    source_tables_dir = base_dir / "source_tables"
    if source_tables_dir.exists():
        rmtree(source_tables_dir)
    source_tables_dir.mkdir(parents=True, exist_ok=True)

    # set up path for the DuckDB database file and clear it if it already exists
    db_path = base_dir / "water_sampling.duckdb"
    if db_path.exists():
        db_path.unlink()

    print(
        f"Running pipeline with\n  runsheet: {runsheet_path}\n  db_path: {db_path}\n  source_tables_dir: {source_tables_dir}\n  http_timeout: {http_timeout}"
    )

    # Download and validate source tables
    print("\nDownloading and validating source tables...")
    export_result = download_and_validate_source_tables(
        runsheet, csv_dir=source_tables_dir, http_timeout=http_timeout
    )

    report_result(export_result)

    # Load source tables into the database
    print("\nLoading source tables into the database...")
    load_result = load_source_tables(
        db_path,
        runsheet,
        csv_dir=source_tables_dir,
        skip=export_result.skip_downstream(),
    )

    report_result(load_result)

    print("\nPipeline completed.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Run the IMOS Water Sampling DB ELT pipeline."
    )
    parser.add_argument("runsheet_path", type=Path, help="Path to the runsheet file")
    parser.add_argument(
        "--base_dir",
        type=Path,
        default=None,
        help="Base directory for database and exported tables (default: temporary directory)",
    )
    parser.add_argument(
        "--http_timeout",
        type=int,
        default=100,
        help="HTTP response timeout in seconds (for downloading source tables; default 100)",
    )
    args = parser.parse_args()

    run_pipeline(
        runsheet_path=args.runsheet_path,
        base_dir=args.base_dir,
        http_timeout=args.http_timeout,
    )
