"""
Top-level Prefect flow implementing the IMOS Water Sampling DB ELT pipeline (see ADR-0009).

Requires the optional ``prefect`` dependency group (``uv sync --group prefect``); the rest of
``public_schema`` has no Prefect dependency.
"""

import tempfile
from pathlib import Path
from pprint import pformat
from shutil import rmtree

from prefect import flow, get_run_logger
from prefect.states import Failed

from public_schema.config import load_runsheet
from public_schema.flow.export import download_and_validate_source_tables
from public_schema.flow.load import load_source_tables
from public_schema.flow.store import store_all_products
from public_schema.flow.transform import run_transforms


@flow
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
    logger = get_run_logger()
    logger.info(f"Starting pipeline with runsheet: {runsheet_path}")

    # Load the runsheet
    runsheet = load_runsheet(runsheet_path)

    if base_dir is None:
        base_dir = Path(tempfile.mkdtemp(prefix="water_sampling_db_"))
    else:
        base_dir = Path(base_dir).resolve()

    # set up subdirectory for source tables and clear it if it already exists
    source_tables_dir = base_dir / "source_tables"
    if source_tables_dir.exists():
        rmtree(source_tables_dir)
    source_tables_dir.mkdir(parents=True, exist_ok=True)

    # set up subdirectory for exported products and clear it if it already exists
    products_dir = base_dir / "products"
    if products_dir.exists():
        rmtree(products_dir)
    products_dir.mkdir(parents=True, exist_ok=True)

    # set up path for the DuckDB database file and clear it if it already exists
    db_path = base_dir / "water_sampling.duckdb"
    if db_path.exists():
        db_path.unlink()

    config_dict = {
        "db_path": db_path,
        "source_tables_dir": source_tables_dir,
        "products_dir": products_dir,
        "http_timeout": http_timeout,
    }
    logger.info(
        f"Pipeline configuration:\n{pformat(config_dict, sort_dicts=False, indent=2)}"
    )

    # Download and validate source tables
    logger.info("Starting export/validation stage")
    export_result = download_and_validate_source_tables(
        runsheet, csv_dir=source_tables_dir, http_timeout=http_timeout
    )

    # Load source tables into the database
    logger.info("Starting load stage")
    load_result = load_source_tables(
        db_path,
        runsheet,
        csv_dir=source_tables_dir,
        skip=export_result.skip_downstream(),
    )

    # Run transforms against the loaded database
    logger.info("Starting transform stage")
    transform_result = run_transforms(
        db_path,
        runsheet,
        skip=load_result.skip_downstream(),
    )

    # Export Products to CSV
    logger.info("Starting store stage")
    store_result = store_all_products(
        db_path,
        runsheet,
        output_dir=products_dir,
        skip=transform_result.skip_downstream(),
    )

    # Determine final status of the pipeline - fail unless all stages succeeded (or were skipped)
    not_processed = list(store_result.skipped) + list(store_result.failed)
    if not_processed:
        return Failed(message="Not all products were successfully processed.")

    logger.info("Pipeline completed")
