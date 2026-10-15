"""
Load stage task — Prefect wrapper for bulk loading of source tables into DuckDB (see ADR-0002,
ADR-0006, ADR-0007, ADR-0009).
"""

from pathlib import Path
from pprint import pformat

from prefect import get_run_logger, task

from public_schema.config import RunsheetConfig
from public_schema.load import (
    _foreign_key_dependencies,
    _load_schema,
    load_source_table,
)
from public_schema.results import LoadResult


@task
def load_source_tables(
    db_path: Path,
    runsheet: RunsheetConfig,
    csv_dir: Path,
    skip: dict[str, str] | None = None,
) -> LoadResult:
    """
    Load every Source table declared in *runsheet*, in order, into the DuckDB file at *db_path*.

    Catches per-table failures rather than raising, and skips a table once any Source table its
    ``databaseForeignKeys`` reference has failed or been skipped (blocking dependents, see
    ADR-0002/ADR-0006). *skip* seeds additional names (with a reason) known to have failed/been
    skipped in an earlier pipeline stage — see `docs/water_sampling_db.md`'s "Cross-stage skip
    propagation".

    :param db_path: path to the DuckDB database file (see ADR-0007).
    :param runsheet: runsheet declaring ``source_tables`` in load order.
    :param csv_dir: directory containing ``<name>.csv`` for each Source table.
    :param skip: name -> reason, seeded from an earlier stage's result.
    :return: :class:`LoadResult` listing succeeded, failed, and skipped table names.
    """
    logger = get_run_logger()
    logger.info(
        f"Starting load of {len(runsheet.source_tables)} source tables into {db_path}"
    )
    result = LoadResult(skipped=skip if skip is not None else {})

    for name in runsheet.source_tables:
        if name in result.skipped:
            logger.debug(f"[{name}] Skipping (already marked as skipped)")
            continue

        depends = _foreign_key_dependencies(_load_schema(name))
        blocking = [
            dep for dep in depends if dep in result.failed or dep in result.skipped
        ]
        if blocking:
            logger.warning(
                f"[{name}] Skipping (depends on failed/skipped table(s): {blocking})"
            )
            result.skipped[name] = f"depends on failed/skipped table(s): {blocking}"
            continue

        logger.debug(f"[{name}] Loading source table")
        try:
            load_source_table(db_path, name, csv_dir / f"{name}.csv")
            logger.info(f"[{name}] Load succeeded")
            result.succeeded.append(name)
        except Exception as e:
            logger.exception(f"[{name}] Error loading")
            result.failed[name] = str(e)

    logger.info(
        f"Load complete: {len(result.succeeded)} succeeded, {len(result.failed)} failed, {len(result.skipped)} skipped"
    )
    logger.debug(pformat(result.model_dump(), sort_dicts=False))

    return result
