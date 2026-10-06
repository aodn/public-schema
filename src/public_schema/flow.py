"""Top-level flow implementing the IMOS Water Sampling DB ELT pipeline."""

import argparse
import logging
from pathlib import Path
from pprint import pformat
from shutil import rmtree

from public_schema import StageResult
from public_schema.config import load_runsheet
from public_schema.load import load_source_tables
from public_schema.validate import download_and_validate_source_tables

logger = logging.getLogger(__name__)


def format_result(result: StageResult):
    return (
        f"{result.name.title()} result: {len(result.succeeded)} succeeded, {len(result.failed)} failed,"
        f" {len(result.skipped)} skipped."
    )


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
    logger.info(f"Starting pipeline with runsheet: {runsheet_path}")

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

    logger.info(
        f"Pipeline configuration: db_path={db_path}, source_tables_dir={source_tables_dir}, http_timeout={http_timeout}"
    )

    # Download and validate source tables
    logger.info("Starting export/validation stage")
    export_result = download_and_validate_source_tables(
        runsheet, csv_dir=source_tables_dir, http_timeout=http_timeout
    )

    logger.info(format_result(export_result))
    logger.debug(pformat(export_result.model_dump()))

    # Load source tables into the database
    logger.info("Starting load stage")
    load_result = load_source_tables(
        db_path,
        runsheet,
        csv_dir=source_tables_dir,
        skip=export_result.skip_downstream(),
    )

    logger.info(format_result(load_result))
    logger.debug(pformat(load_result.model_dump()))

    logger.info("Pipeline completed")


if __name__ == "__main__":
    logging.basicConfig(
        level=logging.DEBUG,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    )

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
