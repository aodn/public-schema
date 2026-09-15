# Water Sampling Database ETL

This package (`public_schema`) is the home of both the data "contract" (Resource descriptors +
transform SQL) and, going forward, the ETL pipeline logic that turns them into published products.
A thin Prefect wrapper flow in `aodn/dataflow-orchestration` calls this package's API; see
[ADR-0004](./adr/0004-flow-logic-packaged-in-public-schema.md). Domain terms (Resource, Source
table, Transform, Product, Intermediate table, Execution order config, Wrapper flow) are defined
in [`CONTEXT.md`](../CONTEXT.md).

## Pipeline stages

1. **Export** — download each Resource's CSV from its WFS `path` URL (done: `export.py`).
2. **Validate** — check each CSV against its Frictionless schema (done: `validate.py`).
3. **Load** — generate `CREATE TABLE` DDL per source table (types + `PRIMARY KEY` from the
   schema, `FOREIGN KEY` spliced in from the matching `.sql` file) and load the validated CSV into
   an ephemeral DuckDB database, in execution-order-config order. A constraint violation blocks
   that table's dependent transforms but not the raw CSV upload (which stays the wrapper flow's
   job). See [ADR-0002](./adr/0002-pk-fk-constraints-via-create-table-ddl.md) and
   [ADR-0003](./adr/0003-ephemeral-duckdb-per-run.md).
4. **Transform** — execute the ~44 bundled `.sql` files against the DuckDB database, strictly in
   execution-order-config order (done: `transform.py` only *lists* these files today; executing
   them is not yet implemented). See [ADR-0005](./adr/0005-execution-order-via-config-file.md).
5. **Publish** — export every Product (name ends in `_data`) as CSV for the wrapper flow to upload;
   Intermediate tables (e.g. `_map`) are never exported.

## What's not yet implemented (start here)

- **Execution order config** — a YAML file bundled alongside the resource descriptors and SQL
  files, declaring each source table's and transform's position in the load/execute order. Add a
  test that the declared order never places a dependency after its dependent.
- **DDL generator** — build `CREATE TABLE` statements from a Resource's schema + its FK `.sql` file
  (all 11 FK files follow one pattern: `ALTER TABLE <table>\n ADD FOREIGN KEY (<col>) REFERENCES
  <ref_table>\n;` — trivial to parse and splice in). Keep column identifiers **unquoted** — schemas
  use UPPERCASE columns, transform SQL uses lowercase, and DuckDB's case-insensitive unquoted
  identifier folding is what makes them interoperate.
- **Public API** for the wrapper flow to call, e.g. `load_source_tables(conn, order)` and
  `run_transforms(conn, order)` — plain functions/classes, no Prefect dependency.
- **CTD Parquet integration** — some transforms need CTD profile data from the
  `aodn-cloud-optimised` S3 bucket, read via DuckDB's `httpfs` extension. Exact dataset path/table
  name still unknown; AWS credential injection should be passed in by the caller, not loaded
  directly by this package.
- **Spatial extension** — load DuckDB's `spatial` extension; 8 of the 44 transform files use
  `ST_GeomFromText`/`ST_AsWKB`.
- Add `duckdb` (and spatial/httpfs setup) to `pyproject.toml` dependencies.

## Verified facts (tested against DuckDB 1.5.5, save yourself re-testing)

- `ALTER TABLE ... ADD FOREIGN KEY` → `NotImplementedException`. Inline `FOREIGN KEY (col)
  REFERENCES table` in `CREATE TABLE` works and defaults to referencing the target's primary key.
- Composite `PRIMARY KEY (col1, col2, ...)` inline works; most Resources declare composite keys
  (e.g. `bgc_chemistry`: `[TRIP_CODE, SAMPLEDEPTH_M]`).
- Transform SQL is already written in DuckDB dialect (not raw Postgres) — see
  `resources/README.md`'s Postgres→DuckDB translation table.
- Product vs Intermediate naming rule verified against all 44 transform files with zero
  exceptions: name ends in `_data` → Product; anything else → Intermediate.

## Open questions

- How to deliver `PIVOT`-based products (e.g. plankton abundances) with dynamic schemas via the
  AODN Portal — CSV export works today but doesn't support subsetting via the Portal.
- Is there value in publishing legacy `_map` (Intermediate) tables as CSV/Parquet?
- Is it worth persisting the DuckDB database between runs (e.g. to track row created/updated
  times)? Current decision is no — see [ADR-0003](./adr/0003-ephemeral-duckdb-per-run.md).
