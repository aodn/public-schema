# Bulk load/transform functions catch per-item failures and return a result, rather than raising

Each bulk stage function (`load_source_tables`, `run_transforms`, `store_all_products`) loops over
its `Runsheet` items in declared order, catching any individual item's exception rather than letting
it propagate. A name is skipped once any of its declared `depends` has failed or been skipped, per
ADR-0002/ADR-0005's "block dependents" policy. Each function also accepts a `skip: dict[str, str]`
parameter (name → reason) seeded from an *earlier* stage's result, since a stage has no other way to
know about failures/skips that happened before it was called — see `water_sampling_db.md`'s
"Cross-stage skip propagation" for the exact chaining shape. Every function returns a result object
(`LoadResult`/`TransformResult`/`StoreResult`, all aliases of one shared `StageResult`) listing
succeeded, failed (with error message), and skipped (with the reason, whether inherited via `skip`
or newly derived) names, instead of raising on the first failure.

This makes the skip-dependents policy testable as plain Python independently of Prefect, and gives
the bulk functions a well-defined contract to prototype what the wrapper flow's per-`@task` looping
logic will eventually replicate (per-item calls wrapped in tasks, skip decisions driven by the same
`Runsheet` order) — see ADR-0004. The alternative (raise on first failure, or abort the whole run) was
rejected because it doesn't match the "continue independent branches" behaviour already decided.
