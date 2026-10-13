"""
Store stage — export Products (tables/views whose name ends in ``_data``) from the DuckDB file to
CSV for the wrapper flow to upload (see ADR-0006, ADR-0007).
"""

import logging
from pathlib import Path

from public_schema.config import RunsheetConfig, TransformName
from public_schema.connection import create_connection
from public_schema.results import StoreResult

logger = logging.getLogger(__name__)


def is_product(name: str) -> bool:
    """
    Return True iff *name* is a Product (as opposed to an Intermediate table) — i.e. its name ends
    in ``_data`` (see `docs/water_sampling_db.md`'s "Verified facts").

    :param name: a transform's table/view name.
    :return: whether *name* is a Product.
    """
    return name.endswith("_data")


def store_product(db_path: Path, name: TransformName, output_dir: Path) -> Path:
    """
    Export the table *name* from the DuckDB file at *db_path* to ``<output_dir>/<name>.csv``.

    :param db_path: path to the DuckDB database file (see ADR-0007).
    :param name: name of a Product table/view to export.
    :param output_dir: directory to write the CSV file into (created if it doesn't exist).
    :return: path to the written CSV file.
    """
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / f"{name}.csv"

    con = create_connection(db_path)
    try:
        con.table(name).to_csv(str(output_path), header=True)
    finally:
        con.close()

    return output_path


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
