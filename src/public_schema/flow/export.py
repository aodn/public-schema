"""
Export+Validate stage task — Prefect wrapper for bulk download/validation of source tables (see
ADR-0006, ADR-0009).
"""

import logging
from pathlib import Path

from prefect import task

from public_schema.config import RunsheetConfig
from public_schema.export import download_resource
from public_schema.results import ExportResult
from public_schema.validate import validate_local

logger = logging.getLogger(__name__)


@task
def download_and_validate_source_tables(
    runsheet: RunsheetConfig, csv_dir: Path, http_timeout: int = 100
) -> ExportResult:
    """
    Download the CSV data for all resources in the runsheet and validate them against their schemas.

    :param runsheet: runsheet declaring ``source_tables`` to download & validate.
    :param csv_dir: directory to save each source table to (as ``<name>.csv``).
    :param http_timeout: HTTP response timeout in seconds
    :return: :class:`ExportResult` listing succeeded, failed, and skipped table names.
    """
    # TODO: retries?

    logger.info(
        f"Starting download and validation of {len(runsheet.source_tables)} source tables"
    )
    result = ExportResult()
    for name in runsheet.source_tables:
        logger.debug(f"[{name}] Processing source table")
        try:
            csv_path = download_resource(name, csv_dir, http_timeout=http_timeout)
            logger.debug(f"[{name}] Downloaded to {csv_path}")
            valid, errors = validate_local(csv_path, name)
            if valid:
                logger.info(f"[{name}] Validation succeeded")
                result.succeeded.append(name)
            else:
                logger.warning(f"[{name}] Validation failed: {errors}")
                result.failed[name] = f"Validation failed: {errors}"
        except Exception as e:
            logger.exception(f"[{name}] Error processing")
            result.failed[name] = str(e)

    logger.info(
        f"Download and validation complete: {len(result.succeeded)} succeeded, {len(result.failed)} failed"
    )
    return result
