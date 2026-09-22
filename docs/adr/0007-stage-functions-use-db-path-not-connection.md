# Stage functions take a DuckDB file path, not a live connection

Every pipeline stage function (`load_source_table`, `run_transform`, `store_product`, and their bulk
counterparts) takes `db_path: Path` identifying a temporary on-disk DuckDB database file, rather than
a shared `duckdb.DuckDBPyConnection` object. Each function opens its own connection to `db_path`
internally (via a `create_connection(db_path)` helper that also loads the `spatial` extension), does
its work, and closes it.

This is necessary because these functions are each meant to become an individual Prefect `@task`
(see ADR-0004), and a live DuckDB connection object is not serializable/shareable across Prefect task
boundaries — passing one directly between tasks would either fail outright or silently defeat
Prefect's task isolation. A file path is trivially serializable and lets every task reopen the same
on-disk database (created fresh per run, per ADR-0003).

## Consequences

- Stage functions cannot rely on transaction/session state persisting between calls (e.g. temp views,
  open transactions) — anything needed later must be committed to the database file itself.
- Concurrent writers to the same DuckDB file are not safe, so stage functions (and the eventual
  Prefect flow) always run sequentially against a given `db_path` — never in parallel, even for
  runsheet branches that are logically independent. Dependencies between transforms already limit
  how much concurrency would be possible, and total data volume is small, so sequential execution is
  not a performance concern.
