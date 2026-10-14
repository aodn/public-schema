"""
Store stage task — Prefect wrapper for bulk export of Products to CSV (see ADR-0006, ADR-0007,
ADR-0009).
"""

import logging
from pathlib import Path

from prefect import task

from public_schema.config import RunsheetConfig
from public_schema.results import StoreResult
from public_schema.store import is_product, store_product

logger = logging.getLogger(__name__)


@task
def store_all_products(
    db_path: Path,
    runsheet: RunsheetConfig,
    output_dir: Path,
    skip: dict[str, str] | None = None,
) -> StoreResult:
    """
    Export every Product declared in *runsheet* (per :func:`is_product`) from the DuckDB file at
    *db_path* to CSV files in *output_dir*.

    Catches per-product failures rather than raising. Products are leaf nodes — nothing in this
    package depends on a Product's CSV output — so unlike `load_source_tables`/`run_transforms`,
    this never needs to *derive* new skips itself; it only consults its *skip* input (seeded from
    an earlier stage's result, see `docs/water_sampling_db.md`'s "Cross-stage skip propagation")
    and otherwise tries every Product independently.

    :param db_path: path to the DuckDB database file (see ADR-0007).
    :param runsheet: runsheet declaring ``transforms``, filtered here to Products.
    :param output_dir: directory to write CSV files into.
    :param skip: name -> reason, seeded from an earlier stage's result.
    :return: :class:`StoreResult` listing succeeded, failed, and skipped Product names.
    """
    products = [t.name for t in runsheet.transforms if is_product(t.name)]
    logger.info(f"Starting store of {len(products)} products from {db_path}")
    result = StoreResult(skipped=skip if skip is not None else {})

    for name in products:
        if name in result.skipped:
            logger.debug(f"[{name}] Skipping (already marked as skipped)")
            continue

        logger.debug(f"[{name}] Storing product")
        try:
            store_product(db_path, name, output_dir)
            logger.info(f"[{name}] Store succeeded")
            result.succeeded.append(name)
        except Exception as e:
            logger.exception(f"[{name}] Error storing")
            result.failed[name] = str(e)

    logger.info(
        f"Store complete: {len(result.succeeded)} succeeded, {len(result.failed)} failed, {len(result.skipped)} skipped"
    )
    return result
