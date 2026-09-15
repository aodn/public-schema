# Most flow logic is packaged in `public_schema`; `dataflow-orchestration` holds only a thin wrapper flow

We originally built the full ETL (discovery, dependency ordering, DDL generation, CSV load,
transform execution, product export) as Prefect tasks directly inside
`projects/water_sampling_db/flow.py` in this repo, with `public_schema` supplying only the raw
data — resource descriptors and SQL files — that the flow read.

After external review with other data engineers, we reversed that split. The `public_schema`
package will now own essentially all of the pipeline logic — discovery, dependency-ordered
execution (see ADR-0005), DDL generation (see ADR-0002), source-table load, transform execution
(see ADR-0003), and product export — exposed as plain Python functions/classes with no Prefect
dependency. `dataflow-orchestration`'s `flow.py` becomes a thin wrapper: it calls into
`public_schema`'s public API, wraps each meaningful step in a `@task` (for Prefect observability,
retries, and the "block dependents on failure" policy), and handles the Prefect-specific concerns
(S3Bucket blocks, run logging, deployment scheduling).

## Why

- **Testability without Prefect.** The bulk of the logic (dependency resolution, DDL generation,
  SQL execution order, CSV/DuckDB plumbing) can be unit-tested as plain Python in `public_schema`,
  without spinning up a Prefect flow run or mocking Prefect blocks.
- **Reusability.** `public_schema` already is the canonical, public "contract" repo for the
  data/SQL themselves (see its README's design considerations). Packaging the execution logic
  there too means any other consumer of `public_schema` (e.g. a local dev script, a different
  orchestrator) can run the same pipeline without depending on Prefect or this monorepo.
- **Smaller blast radius in this repo.** `dataflow-orchestration` stays a thin orchestration layer,
  consistent with how other projects in this monorepo (e.g. `cloud_optimised`) mostly call out to
  an external library and wrap it in tasks/flows.

## Consequences

- Phase 3 implementation work (DDL generation, dependency-ordered load/transform execution, product
  export) now happens in the `aodn/public-schema` repository, not here. See the handoff doc for the
  concrete next-steps checklist.
- `flow.py` in this repo will need to be rewritten once `public_schema` exposes the new
  higher-level API (currently it only exposes `resource_descriptors_dict`, `download_resource`, and
  `validate_local` — the Phase 1 primitives). The current prototype flow is expected to be replaced,
  not incrementally extended.
- `public_schema`'s dependencies (DuckDB, spatial/httpfs extensions, etc.) move to be dependencies
  of `public_schema` itself rather than of `projects/water_sampling_db/requirements.in`. This
  repo's `requirements.in` only needs whatever `public_schema`'s new API surface requires (likely
  just `public_schema` itself, transitively).
- CI/testing for the pipeline logic (dependency resolution, DDL generation, transform execution)
  moves to `public_schema`'s own test suite; `tests/projects/water_sampling_db/` in this repo only
  needs to test the thin wrapper flow (task wiring, error handling, S3 upload).
