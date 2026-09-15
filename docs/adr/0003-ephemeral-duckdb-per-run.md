> **Amended by [ADR-0004](./0004-flow-logic-packaged-in-public-schema.md).** The ephemeral-DuckDB
> decision below is unchanged, but the DuckDB build/execute logic now lives in the `public_schema`
> package rather than this repo's flow code.

# DuckDB is ephemeral, rebuilt from scratch on every run

The README raised the open question of whether to persist the DuckDB database between weekly runs
(e.g. to track per-row created/updated timestamps). We decided against this for now: the DuckDB
database is created fresh (in-memory or a run-scoped temp file) on every flow run, fully rebuilt from
the downloaded source CSVs and re-executed transforms, then discarded. This keeps the flow stateless
and simple to reason about, at the cost of not having row-level change history. Persisting the database
(e.g. in S3) to support incremental updates or change tracking is deferred to a future design round if
that need materialises.
