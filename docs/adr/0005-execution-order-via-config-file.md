# Execution order specified in a config file, not inferred from a dependency graph

> **Supersedes [ADR-0001](./0001-execution-order-via-unified-dependency-graph.md).**

ADR-0001 decided to infer execution order automatically by building a unified dependency graph
(source-table FK edges + transform `FROM`/`JOIN` edges) and topologically sorting it, to avoid
relying on the private `aodn/chef-private` ordering lists and to stay correct automatically as
`public_schema` evolves.

After external review with other data engineers, we reverted this decision. Execution order (both
which source tables must load before which transforms, and the order transforms run in) will
instead be declared explicitly in a config file bundled with `public_schema`, alongside the
resource descriptors and SQL files it already versions.

## Why we reverted

- **A parsed dependency graph is an inferred, implicit contract.** Correctness depends on a SQL
  `FROM`/`JOIN` reference parser correctly identifying every dependency across ~44 hand-written SQL
  files, forever, as they change — a parsing bug silently produces a wrong execution order rather
  than a visible error.
- **An explicit config file is reviewable.** Reviewers of a `public_schema` PR that adds/changes a
  transform can see the order change directly in the diff, the same way they already review the
  SQL and schema changes, rather than trusting a graph algorithm.
- **It matches how order was already managed.** The pre-existing `aodn/chef-private` data bags
  (`IMOS_BGC_DB.json`, `IMOS_CPR_DB.json`) already specified order as an explicit list. Declaring
  order explicitly in `public_schema` is a smaller, more familiar conceptual change than replacing
  that list with a derived graph, while still moving the "contract" into the public repo where it
  belongs.
- **Simpler to implement and debug.** No SQL reference parser is needed; the flow just reads an
  ordered list (or ordered groups, if parallelism within a stage is desired) from config.

## Decision

`public_schema` will bundle a config file (format/location to be finalized here — e.g. YAML)
declaring, for each source table and transform, its explicit position/stage in the execution
order. 

## Consequences

- The SQL reference parser designed under ADR-0001 is no longer needed and should not be built.
- Whenever a new transform or source table is added to `public_schema`, the PR must also update the
  order config — this is a manual step, unlike the automatic inference ADR-0001 would have given,
  but it is reviewable and explicit.
- `public_schema` needs its own validation (e.g. a test or lint step) to check that every source
  table with FK references and every transform with `FROM`/`JOIN` references appears in the config
  in a position at least after everything it depends on. This check does not need to derive the
  full graph — it only needs to verify the declared order is consistent, which is a much smaller
  problem than deriving order from scratch.
