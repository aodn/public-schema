"""
DuckDB connection helper for pipeline stage functions (see ADR-0007).

Every stage function (`load_source_table`, `run_transform`, `store_product`, and their bulk
counterparts) takes a `db_path: Path` rather than a live connection, and opens its own connection
via `create_connection` internally — a connection is not shareable/serializable across the Prefect
task boundaries these functions are each meant to become. Callers must not share a connection
returned from here across calls; open and close one per stage-function invocation.
"""

from pathlib import Path

import duckdb


def create_connection(db_path: Path | str) -> duckdb.DuckDBPyConnection:
    """
    Open a connection to the DuckDB file at *db_path*, creating it (and any parent directories)
    if it doesn't already exist, with the `spatial` extension installed and loaded.

    :param db_path: path to the (possibly not-yet-existing) DuckDB database file.
    :return: an open :class:`duckdb.DuckDBPyConnection`. Callers are responsible for closing it.
    """
    db_path = Path(db_path)
    db_path.parent.mkdir(parents=True, exist_ok=True)

    con = duckdb.connect(str(db_path))
    con.execute("INSTALL spatial; LOAD spatial;")
    return con
