"""
Transform stage task — Prefect wrapper for bulk execution of transform SQL files (see ADR-0005,
ADR-0006, ADR-0007, ADR-0009).
"""

from pathlib import Path
from pprint import pformat

from prefect import get_run_logger, task

from public_schema.config import RunsheetConfig
from public_schema.results import TransformResult
from public_schema.transform import run_transform


@task
def run_transforms(
    db_path: Path,
    runsheet: RunsheetConfig,
    skip: dict[str, str] | None = None,
) -> TransformResult:
    """
    Run every transform declared in *runsheet*, in order, against the DuckDB file at *db_path*.

    Catches per-transform failures rather than raising, and skips a transform once any table it
    declares a dependency on (via its ``depends`` list) has failed or been skipped (blocking
    dependents, see ADR-0006). *skip* seeds additional names (with a reason) known to have
    failed/been skipped in an earlier pipeline stage — see `docs/water_sampling_db.md`'s
    "Cross-stage skip propagation".

    :param db_path: path to the DuckDB database file (see ADR-0007).
    :param runsheet: runsheet declaring ``transforms`` in execution order.
    :param skip: name -> reason, seeded from an earlier stage's result.
    :return: :class:`TransformResult` listing succeeded, failed, and skipped transform names.
    """
    logger = get_run_logger()
    logger.info(f"Starting {len(runsheet.transforms)} transforms into {db_path}")
    result = TransformResult(skipped=skip if skip is not None else {})

    for transform in runsheet.transforms:
        name = transform.name
        if name in result.skipped:
            logger.debug(f"[{name}] Skipping (already marked as skipped)")
            continue

        blocking = [
            dep
            for dep in transform.depends
            if dep in result.failed or dep in result.skipped
        ]
        if blocking:
            logger.warning(
                f"[{name}] Skipping (depends on failed/skipped table(s): {blocking})"
            )
            result.skipped[name] = f"depends on failed/skipped table(s): {blocking}"
            continue

        logger.debug(f"[{name}] Running transform")
        try:
            run_transform(db_path, name)
            logger.info(f"[{name}] Transform succeeded")
            result.succeeded.append(name)
        except Exception as e:
            logger.exception(f"[{name}] Error running transform")
            result.failed[name] = str(e)

    logger.info(
        f"Transform complete: {len(result.succeeded)} succeeded, {len(result.failed)} failed, {len(result.skipped)} skipped"
    )
    logger.debug(pformat(result.model_dump(), sort_dicts=False))

    return result
