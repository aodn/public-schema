"""
Shared result model for pipeline stage functions (Load, Transform, Store — see ADR-0006).

Each bulk stage function (`load_source_tables`, `run_transforms`, `store_all_products`) loops over
its Runsheet items in declared order, catching per-item failures instead of raising, and returns a
`StageResult` listing what succeeded, what failed (with an error message), and what was skipped
(with a reason — either inherited via that function's `skip` input, or newly derived because a
dependency failed/was skipped within the same stage).

`LoadResult`/`TransformResult`/`StoreResult` are the same model under stage-specific names, so a
stage's result can be fed directly into the next stage's `skip` parameter — see
`docs/water_sampling_db.md`'s "Cross-stage skip propagation":

    load_result = load_source_tables(db_path, runsheet, csv_dir)
    transform_result = run_transforms(
        db_path, runsheet, skip={**load_result.failed, **load_result.skipped}
    )
"""

from pydantic import BaseModel, Field


class StageResult(BaseModel):
    """
    Outcome of a bulk pipeline stage function.

    Attributes:
        succeeded: Names that completed successfully.
        failed: Names that raised, mapped to a str description of the error.
        skipped: Names not attempted, mapped to the reason (e.g. a failed/skipped dependency),
            whether inherited via the function's `skip` input or newly derived.
    """

    succeeded: list[str] = Field(default_factory=list)
    failed: dict[str, str] = Field(default_factory=dict)
    skipped: dict[str, str] = Field(default_factory=dict)


LoadResult = StageResult
TransformResult = StageResult
StoreResult = StageResult
