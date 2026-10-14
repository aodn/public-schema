"""
Store stage — export Products (tables/views whose name ends in ``_data``) from the DuckDB file to
CSV for the wrapper flow to upload (see ADR-0006, ADR-0007).
"""

import logging
from pathlib import Path

from public_schema.config import TransformName
from public_schema.connection import create_connection

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
