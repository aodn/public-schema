"""Tests for public_schema.results — the shared StageResult model (see ADR-0006).

StageResult is reused across pipeline stages via type aliases (LoadResult/TransformResult/
StoreResult) so that a later stage's `skip` input can be built directly from an earlier stage's
result — see `docs/water_sampling_db.md`'s "Cross-stage skip propagation".
"""

from public_schema.results import (
    LoadResult,
    StageResult,
    StoreResult,
    TransformResult,
)


def test_stage_result_defaults_are_empty():
    result = StageResult()
    assert result.succeeded == []
    assert result.failed == {}
    assert result.skipped == {}


def test_stage_result_holds_succeeded_names():
    result = StageResult(succeeded=["bgc_trip", "bgc_chemistry"])
    assert result.succeeded == ["bgc_trip", "bgc_chemistry"]


def test_stage_result_holds_failed_with_reason():
    result = StageResult(failed={"bgc_trip": "constraint violation"})
    assert result.failed == {"bgc_trip": "constraint violation"}


def test_stage_result_holds_skipped_with_reason():
    result = StageResult(skipped={"bgc_trip_metadata": "depends on failed bgc_trip"})
    assert result.skipped == {"bgc_trip_metadata": "depends on failed bgc_trip"}


def test_stage_result_instances_are_independent():
    # mutable-default footgun check: each instance must get its own list/dicts
    a = StageResult()
    b = StageResult()
    a.succeeded.append("bgc_trip")
    a.failed["bgc_chemistry"] = "boom"
    assert b.succeeded == []
    assert b.failed == {}


def test_load_transform_store_result_are_stage_result():
    # aliases (or subclasses) of the one shared model, per water_sampling_db.md
    assert LoadResult is StageResult or issubclass(LoadResult, StageResult)
    assert TransformResult is StageResult or issubclass(TransformResult, StageResult)
    assert StoreResult is StageResult or issubclass(StoreResult, StageResult)


def test_stage_result_chains_skip_dict_across_stages():
    # exact shape from water_sampling_db.md's "Cross-stage skip propagation"
    load_result = LoadResult(
        succeeded=["bgc_chemistry"],
        failed={"bgc_trip": "constraint violation"},
        skipped={"bgc_trip_metadata": "depends on failed bgc_trip"},
    )
    skip = {**load_result.failed, **load_result.skipped}
    assert skip == {
        "bgc_trip": "constraint violation",
        "bgc_trip_metadata": "depends on failed bgc_trip",
    }
