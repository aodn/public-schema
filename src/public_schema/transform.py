"""
Transform stage — execution of the bundled SQL product-generation files against a DuckDB file (see
ADR-0005, ADR-0006, ADR-0007).
"""

import logging
from pathlib import Path
from typing import TYPE_CHECKING

from public_schema.connection import create_connection
from public_schema.util import resource_files_dict

if TYPE_CHECKING:
    # Deferred to avoid a circular import: config.py imports sql_files_dict from this module.
    from public_schema.config import TransformName

logger = logging.getLogger(__name__)


def sql_files_dict(pattern: str = "*/*") -> dict[str, Path]:
    """
    Return a (name: path) mapping for all bundled SQL files. Each key is the names of the view or table
    created by the SQL file (by convention this is also the first part of the file's name, up to the first '.').

    SQL files are bundled inside subdirectories of the ``public_schema.resources`` sub-package.

    :param pattern: optional glob pattern to filter paths (relative to public_schema/resources/). Note the
                    '.sql' suffix is added automatically. For example, 'bgc_data/*' will match all
                    SQL files in the bgc_data/ subdirectory. Defaults to all subdirectories ('*/*').

    :return: dict mapping table/view names to absolute paths (:class:`str`, :class:`~pathlib.Path`)
    """
    return resource_files_dict(pattern, suffix=".sql")


def sql_files_list(pattern: str = "*/*") -> list[Path]:
    """
    Return the absolute paths of all bundled SQL files.

    SQL files are bundled inside subdirectories of the ``public_schema.resources`` sub-package.

    :param pattern: optional glob pattern to filter paths (relative to public_schema/resources/). Note the
                    '.sql' suffix is added automatically. For example, 'bgc_data/*' will match all
                    SQL files in the bgc_data/ subdirectory. Defaults to all subdirectories ('*/*').

    :return: sorted list of :class:`~pathlib.Path` objects
    """
    resource_dict = sql_files_dict(pattern)
    return sorted(resource_dict.values())


def run_transform(db_path: Path, name: "TransformName") -> None:
    """
    Execute the bundled SQL file for *name* against the DuckDB file at *db_path*.

    Each bundled transform SQL file is a single ``CREATE OR REPLACE TABLE ... AS`` statement, so
    this simply reads the file and executes it as-is.

    :param db_path: path to the DuckDB database file (see ADR-0007).
    :param name: name of a bundled transform SQL file (table/view name).
    """
    sql_path = sql_files_dict()[name]
    sql = sql_path.read_text(encoding="utf-8")
    con = create_connection(db_path)
    try:
        con.execute(sql)
    finally:
        con.close()
