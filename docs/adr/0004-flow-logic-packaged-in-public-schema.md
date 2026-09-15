# Most flow logic is packaged in `public_schema`

The full ETL (DDL generation, CSV load, validation, transform execution,
product export) was originally implemented elsewhere, with `public_schema`
supplying only the raw data — resource descriptors and SQL files — that the flow read.

After external review with other data engineers, we reversed that split. `public_schema` (this
package) now owns essentially all of the pipeline logic — dependency-ordered execution (see
ADR-0005), DDL generation (see ADR-0002), source-table load, transform execution (see ADR-0003),
and product export — exposed as plain Python functions/classes with no Prefect dependency.
The orchestration layer (a Prefect flow) becomes a thin wrapper: it calls into this package's public
API, wraps each meaningful step in a `@task` (for Prefect observability, retries, and the "block
dependents on failure" policy), and handles the Prefect-specific concerns (S3Bucket blocks, run
logging, deployment scheduling).

## Why

- **Testability without Prefect.** The bulk of the logic (DDL generation, execution order, CSV/
  DuckDB plumbing) can be unit-tested as plain Python here, without spinning up a Prefect flow run
  or mocking Prefect blocks.
- **Reusability.** `public_schema` is already the canonical, public "contract" repo for the
  data/SQL themselves. Packaging the execution logic here too means any consumer (a local dev
  script, a different orchestrator) can run the same pipeline without depending on Prefect.


## Consequences

- Implementation work (DDL generation, dependency-ordered load/transform execution, product
  export) happens in this repository — see [`water_sampling_db.md`](../water_sampling_db.md) for
  the concrete next-steps checklist.

- CI/testing for the pipeline logic (DDL generation, transform execution, order validation) lives
  in this package's own test suite (`tests/`).
