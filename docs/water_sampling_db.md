# Water Sampling Database ETL

This package (`public_schema`) is the home of both the data "contract" (Resource descriptors +
transform SQL) and, going forward, the ETL pipeline logic that turns them into published products.
A thin Prefect wrapper flow in `aodn/dataflow-orchestration` calls this package's API; see
[ADR-0004](./adr/0004-flow-logic-packaged-in-public-schema.md). Domain terms (Resource, Source
table, Transform, Product, Intermediate table, Runsheet, Wrapper flow) are defined
in [`CONTEXT.md`](../CONTEXT.md).

## Pipeline stages

1. **Export** — download each Resource's CSV from its WFS `path` URL (done: `export.py`).
2. **Validate** — check each CSV against its Frictionless schema (done: `validate.py`).
3. **Runsheet** — declare, per BGC/CPR pipeline, which source tables to load and which transforms
   to run, in dependency order (done: `config.py`'s `RunsheetConfig`/`load_runsheet`, plus
   `bgc_runsheet.yaml`/`cpr_runsheet.yaml`).
4. **Load** — generate `CREATE TABLE` DDL per source table (types + `PRIMARY KEY` from the schema,
   `FOREIGN KEY` built from the schema's `databaseForeignKeys` property, if any) and load the
   validated CSV into the DuckDB file. A constraint violation blocks that table's dependent
   transforms but not the raw CSV upload (wrapper flow's job). See
   [ADR-0002](./adr/0002-pk-fk-constraints-via-create-table-ddl.md),
   [ADR-0003](./adr/0003-ephemeral-duckdb-per-run.md),
   [ADR-0006](./adr/0006-bulk-stage-functions-return-result-not-raise.md),
   [ADR-0007](./adr/0007-stage-functions-use-db-path-not-connection.md), and
   [ADR-0008](./adr/0008-foreign-keys-declared-in-dataresource-yaml.md). *Not yet implemented.*
5. **Transform** — execute the 44 bundled transform `.sql` files against the DuckDB file, strictly
   in runsheet order, applying the same block-dependents-on-failure policy. See
   [ADR-0005](./adr/0005-execution-order-via-config-file.md). *Not yet implemented.*
6. **Store** — export every Product (name ends in `_data`) as CSV for the wrapper flow to upload;
   Intermediate tables (e.g. `_map`) are never exported. *Not yet implemented.*

## Implementation plan

Every stage-4/5/6 function takes `db_path: Path` (a temporary on-disk DuckDB file), not a live
connection — see ADR-0007. Each function is meant to become one Prefect `@task` in the wrapper
flow, so **per-item** functions (one source table / one transform / one product) are the primary
API; **bulk** functions are a thin loop over runsheet order for local/dev use and as a reference for
the wrapper flow's eventual per-task looping + skip logic (ADR-0006).

**Cross-stage skip propagation (resolved during doc review, double-check before implementing):**
`load_source_tables`, `run_transforms`, and `store_all_products` each apply ADR-0006's "block
dependents" policy *within* their own stage, but a later stage has no way to know a name failed or
was skipped in an *earlier* stage unless that's passed in explicitly. Every bulk function therefore
takes an additional `skip: dict[str, str] = {}` parameter (name → reason), seeded from the previous
stage's result:

```python
load_result = load_source_tables(db_path, runsheet, csv_dir)
transform_result = run_transforms(db_path, runsheet, skip={**load_result.failed, **load_result.skipped})
store_result = store_all_products(db_path, runsheet, output_dir, skip={**transform_result.failed, **transform_result.skipped})
```

Each function merges its `skip` input with whatever it discovers itself while walking runsheet
order, and includes both in its own returned `skipped`. `store_all_products` never needs to *derive*
new skips (Products are leaf nodes — nothing in this package depends on a Product's CSV output), so
it only consults its `skip` input and otherwise tries every Product independently.

- **`results.py`** (new): one shared `StageResult` model (`succeeded: list[str]`,
  `failed: dict[str, str]`, `skipped: dict[str, str]`), reused (via type alias or subclass) as
  `LoadResult`, `TransformResult`, `StoreResult` — this is what makes the chaining above type-check
  cleanly across stages.

- **`connection.py`** (new): `create_connection(db_path: Path) -> DuckDBPyConnection` — opens the
  DuckDB file and loads the `spatial` extension. Called internally by every stage function below;
  callers never share a connection across calls (ADR-0007).

- **`load.py`** (new) — DDL generation + CSV loading:
  - `generate_create_table_sql(name: DescriptorName) -> str` — builds `CREATE TABLE` from the
    Resource's Frictionless schema. Type mapping: `string`→`VARCHAR`, `integer`→`INTEGER`,
    `number`→`DOUBLE`, `date`→`DATE`, `datetime`→`TIMESTAMP`; `required`→`NOT NULL`,
    `unique`→`UNIQUE`, `primaryKey`→trailing `PRIMARY KEY (...)`. Builds the `FOREIGN KEY` clause
    from the schema's non-standard `databaseForeignKeys` property, if present (see
    [ADR-0008](./adr/0008-foreign-keys-declared-in-dataresource-yaml.md)). Column identifiers stay
    **unquoted** — schemas use UPPERCASE columns, transform SQL uses lowercase, and DuckDB's
    case-insensitive unquoted identifier folding is what makes them interoperate.
  - `load_source_table(db_path: Path, name: DescriptorName, csv_path: Path) -> None` — runs the
    generated DDL then loads `csv_path` into it (date/datetime columns loaded via DuckDB's
    `read_csv(..., dateformat=..., timestampformat=...)`, reusing the schema's Frictionless
    `format` strings directly — they're already `strftime`-compatible).
  - `load_source_tables(db_path: Path, runsheet: RunsheetConfig, csv_dir: Path, skip: dict[str, str] = {}) -> LoadResult` —
    loops `runsheet.source_tables` in order, catching per-table failures, skipping a table's
    dependents (per ADR-0006), returning `LoadResult(succeeded, failed, skipped)`.

- **`transform.py`** (extend existing module) — add transform *execution* alongside the existing
  `sql_files_dict`/`sql_files_list` (listing):
  - `run_transform(db_path: Path, name: TransformName) -> None` — executes the bundled `.sql` file.
  - `run_transforms(db_path: Path, runsheet: RunsheetConfig, skip: dict[str, str] = {}) -> TransformResult` —
    loops `runsheet.transforms` in order, same catch/skip/result contract as `load_source_tables`.

- **`store.py`** (new) — Publish stage:
  - `is_product(name: str) -> bool` — `True` iff `name` ends in `_data`.
  - `store_product(db_path: Path, name: TransformName, output_dir: Path) -> Path` — exports one
    table to CSV.
  - `store_all_products(db_path: Path, runsheet: RunsheetConfig, output_dir: Path, skip: dict[str, str] = {}) -> StoreResult` —
    filters `runsheet.transforms` to `is_product(t.name)`, skips names in `skip`, and calls
    `store_product` for everything else, catching per-item failures (no further skip-derivation
    needed — see above).

- **`config.py`** (extend): `runsheet_paths_dict() -> dict[str, Path]` (keys `"bgc"`/`"cpr"`,
  stripped of the `_runsheet` suffix); `load_runsheet(name_or_path: str | Path)` accepts a bundled
  name or explicit path, same pattern as `resolve_resource()`.

- **CTD Parquet + spatial extension** — 8 of the 44 transform files use
  `ST_GeomFromText`/`ST_AsWKB` (handled by `create_connection`'s `spatial` extension load). CTD
  profile data needs DuckDB's `httpfs` extension to read from the `aodn-cloud-optimised` S3 bucket
  — exact dataset path/table name still unknown, and AWS credential injection needs to be passed in
  by the caller (not loaded directly by this package). **Blocked** on coordination with another
  team; deferred until that's resolved.

- Add `duckdb` to `pyproject.toml` dependencies.

## Sequencing note

Stage functions always run sequentially against a given `db_path` — DuckDB doesn't support
concurrent writers to one file, and with dependencies between transforms already limiting possible
concurrency (and total data volume being small), sequential execution is not a performance concern.
See [ADR-0007](./adr/0007-stage-functions-use-db-path-not-connection.md).

## Verified facts (tested against DuckDB 1.5.5, save yourself re-testing)

- `ALTER TABLE ... ADD FOREIGN KEY` → `NotImplementedException`. Inline `FOREIGN KEY (col)
  REFERENCES table` in `CREATE TABLE` works and defaults to referencing the target's primary key.
- Composite `PRIMARY KEY (col1, col2, ...)` inline works; most Resources declare composite keys
  (e.g. `bgc_chemistry`: `[TRIP_CODE, SAMPLEDEPTH_M]`).
- Transform SQL is already written in DuckDB dialect (not raw Postgres) — see
  `resources/README.md`'s Postgres→DuckDB translation table.
- Product vs Intermediate naming rule verified against all 44 transform files with zero
  exceptions: name ends in `_data` → Product; anything else → Intermediate.
- All bundled schemas use only 5 Frictionless types (`string`, `number`, `integer`, `date`,
  `datetime`) and only 2 constraints (`required`, `unique`) — no `enum`/`pattern`/min-max, keeping
  DDL generation simple. `date`/`datetime` `format` strings are already `strftime`-compatible and
  can be passed directly to DuckDB's `read_csv(dateformat=..., timestampformat=...)`.
- Frictionless silently ignores unknown `schema` properties, so a non-standard
  `databaseForeignKeys` property can sit alongside a resource's real schema without breaking
  validation — see [ADR-0008](./adr/0008-foreign-keys-declared-in-dataresource-yaml.md). All 11
  FK constraints are single-column and never reference a non-primary-key column.

## Open questions

- How to deliver `PIVOT`-based products (e.g. plankton abundances) with dynamic schemas via the
  AODN Portal — CSV export works today but doesn't support subsetting via the Portal.
- Is there value in publishing legacy `_map` (Intermediate) tables as CSV/Parquet?
- Is it worth persisting the DuckDB database between runs (e.g. to track row created/updated
  times)? Current decision is no — see [ADR-0003](./adr/0003-ephemeral-duckdb-per-run.md).
