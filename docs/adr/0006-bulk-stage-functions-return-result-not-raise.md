# Bulk load/transform functions catch per-item failures and return a result, rather than raising

Each bulk stage function (`load_source_tables`, `run_transforms`) loops over its `Runsheet` items in
declared order, catching any individual item's exception rather than letting it propagate. A name is
skipped once any of its declared `depends` has failed or been skipped, per ADR-0002/ADR-0005's "block
dependents" policy. The function returns a result object (`LoadResult`/`TransformResult`) listing
succeeded, failed (with error message), and skipped (with the dependency that caused the skip) names,
instead of raising on the first failure.

This makes the skip-dependents policy testable as plain Python independently of Prefect, and gives
the bulk functions a well-defined contract to prototype what the wrapper flow's per-`@task` looping
logic will eventually replicate (per-item calls wrapped in tasks, skip decisions driven by the same
`Runsheet` order) — see ADR-0004. The alternative (raise on first failure, or abort the whole run) was
rejected because it doesn't match the "continue independent branches" behaviour already decided.
