# The Prefect flow itself is packaged in `public_schema`, not a separate wrapper repo

Supersedes [ADR-0004](./0004-flow-logic-packaged-in-public-schema.md).

ADR-0004 kept this package free of a Prefect dependency: `public_schema` exposed plain Python
functions/classes, and a thin Prefect wrapper flow in `aodn/dataflow-orchestration` was expected to
call into this package's API, wrapping each stage function in a `@task` itself.

We've reversed that split further: `run_pipeline` and the four bulk stage functions it calls
(`download_and_validate_source_tables`, `load_source_tables`, `run_transforms`,
`store_all_products`) now live in a `public_schema.flow` sub-package, where `run_pipeline` is
itself a Prefect `@flow` and each bulk function is wrapped `@task`. There is no longer a separate
wrapper-flow repository step that re-implements this wiring.

## Why

- **One source of truth for orchestration.** The task/flow wiring (what calls what, in what order,
  with what `skip` propagation) was already fully specified by `run_pipeline`'s plain-Python
  implementation in this package; duplicating that wiring in a second repository as Prefect
  decorators was redundant and could drift out of sync.
- **Still importable without Prefect.** Only `public_schema.flow.*` requires the optional
  `prefect` dependency group (see `pyproject.toml`'s `[dependency-groups]`). The rest of
  `public_schema` (per-item stage functions, config, validation, export) remains plain Python with
  no Prefect dependency, preserving ADR-0004's testability argument for that part of the package.
- **Per-item functions stay the reusable primitive.** `load_source_table`, `run_transform`,
  `store_product`, `validate_local`/`validate_resource`, etc. are unchanged and still importable
  from their original top-level modules — only the bulk/looping functions moved.

## Consequences

- `src/public_schema/flow/` is a new sub-package: `__init__.py` (`run_pipeline` as `@flow`),
  `__main__.py` (CLI entry point, `python -m public_schema.flow <runsheet>`), and `export.py`/
  `load.py`/`transform.py`/`store.py`, each holding one `@task`-wrapped bulk function moved out of
  the corresponding top-level module.
- Consumers that need to run the full pipeline (or just the bulk/task functions) must install the
  `prefect` dependency group (`uv sync --group prefect`); consumers that only need per-item
  functions, config/validation, or the bundled resources do not.
- Any orchestration wiring previously planned for `aodn/dataflow-orchestration` is no longer
  needed for this pipeline; that repo (if it still calls this package) should call
  `public_schema.flow.run_pipeline` directly rather than re-wrapping the bulk functions itself.
