# public-schema

Schema specifications and SQL product-generation code for IMOS data exchange between CSIRO and AODN. Schemas define the agreed structure of tabular data served via CSIRO GeoServer WFS layers and consumed by AODN harvest pipelines and the AODN Portal.

## Language

**Resource**:
A named tabular dataset described by a `.dataresource.yaml` file. Each resource has a `path` (the live GeoServer WFS URL), a schema, and metadata. Resources are bundled inside the `public_schema` Python package.
_Avoid_: dataset, table, layer

**Descriptor**:
The `.dataresource.yaml` file that fully describes a Resource — its path, schema, encoding, and licence.
_Avoid_: schema file, resource file, YAML file

**Resource name**:
The short identifier for a resource (e.g. `bgc_chemistry`), which maps to `<name>.dataresource.yaml` in either the `bgc_data/` or `cpr_data/` resource subdirectory.
_Avoid_: resource ID, slug

**Download**:
Fetching the CSV data from a resource's WFS `path` URL and writing it to a local file. The output filename is `<resource_name>.csv`.
_Avoid_: export, extract, pull

**Local validation**:
Validating a local CSV file against the schema extracted from a resource's descriptor, without hitting the live WFS endpoint.
_Avoid_: offline validation, schema check

### Water Sampling Database ETL (see `docs/water_sampling_db.md`)

**Source table**:
A DuckDB table loaded from one Resource's downloaded CSV, with columns/types/`PRIMARY KEY` derived
from its schema, and any `FOREIGN KEY` clause built from the schema's `databaseForeignKeys`.
_Avoid_: raw table, staging table

**Transform**:
One bundled `.sql` file that creates a table/view from source tables and/or other transforms.
_Avoid_: query, view definition

**Product**:
A transform whose output name ends in `_data` — exported as CSV for AODN Portal consumption.
_Avoid_: output, deliverable

**Intermediate table**:
A transform whose output name does not end in `_data` (e.g. `_map`) — never exported.
_Avoid_: staging view, helper table

**Runsheet**:
A YAML config file bundled with `public_schema` (e.g. `bgc_runsheet.yaml`) declaring the source
tables to load and the transforms to run, with each transform's dependencies, such that every item
appears after everything it depends on. Replaces both the old `aodn/chef-private` data bags and any
idea of inferring order from a parsed dependency graph.
_Avoid_: execution order config, dependency graph, DAG

**`databaseForeignKeys`**:
A non-standard `schema` property in a Descriptor declaring FK constraints for a Source table's
generated `CREATE TABLE` DDL. Deliberately not Frictionless's real `foreignKeys` property, since
that fails validation unless the referencing and referenced resources are in one Data Package;
Frictionless silently ignores unknown properties, so this one validates cleanly per-resource.
_Avoid_: foreignKeys, FK constraint file

**Flow** (or **pipeline flow**):
The Prefect `@flow` `public_schema.flow.run_pipeline`, in this package's `public_schema.flow`
sub-package (requires the optional `prefect` dependency group). Calls the four bulk stage `@task`s
(`download_and_validate_source_tables`, `load_source_tables`, `run_transforms`,
`store_all_products`) in order, piping each stage's `skip_downstream()` into the next. See
[ADR-0009](./docs/adr/0009-prefect-flow-packaged-in-public-schema.md); supersedes the earlier
"Wrapper flow" concept of a separate `aodn/dataflow-orchestration` repo owning this wiring.
_Avoid_: wrapper flow, orchestrator (when meaning specifically this package's own flow)
