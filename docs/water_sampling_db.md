# Water Sampling Database ETL Flow
This flow does the following:
* **Export** a list of source data tables from the CSIRO database, storing them as local CSV files.
* **Validate** each CSV against a pre-defined schema.
* **Transform** the source data using SQL into the products/views required.
* **(Up)Load** (i.e. save) the source data and products to a public S3 bucket in CSV format.

## Source data
Source data are specified in Frictionless [Data Resource](https://specs.frictionlessdata.io/data-resource/) 
descriptors (yaml files) in the `public-schema` package 
  (currently versioned in [releases](https://github.com/aodn/public-schema/releases) off the `v2` branch of the 
  [aodn/public-schema](https://github.com/aodn/public-schema) repository).
Each descriptor defines:
- the source data table name and URL (a GeoServer WFS `GetFeature` request);
- the schema of the source data (column names, types, constraints, etc.).

Each table is extracted from by downloading the CSV from the WFS URL, and saved to a local file. The source data are then validated against the schema defined in the corresponding data resource descriptor.

## Transformations
The transformations are defined in SQL files that are also versioned in the `public-schema` package. The SQL files 
are executed in a specific order to build a hierarchy of intermediate tables and output products.

Originally these SQL files were written for PostgreSQL, but they can be run in DuckDB with minor modifications. The 
intermediate tables and output products are created in a (temporary) DuckDB database, and then exported to
CSV files, which are then uploaded to the public S3 bucket.

## Design considerations
- The source data descriptors and transform SQL form part of the "contract" between CSIRO and AODN for how we 
  jointly these data products. Any changes are made via pull requests to the `aodn/public-schema` repo, which must 
  therefore be public.
- Most of the pipeline logic (dependency-ordered execution, DDL generation, transform execution, product
  export) is packaged in `public_schema`, not this repo — this repo's `flow.py` is a thin Prefect wrapper
  around `public_schema`'s API. See [ADR-0004](./docs/adr/0004-flow-logic-packaged-in-public-schema.md).
- The existing SQL builds a hierarchy of tables & (materialised) views that depend on each other -- the order in
  which they are constructed is declared explicitly in a config file bundled with `public_schema`, alongside the
  resource descriptors and SQL files (this replaces the order previously kept in `aodn/chef-private` data bags
  [IMOS_BGC_DB.json](https://github.com/aodn/chef-private/blob/master/data_bags/imos_po_watches/IMOS_BGC_DB.json)
  and [IMOS_CPR_DB.json](https://github.com/aodn/chef-private/blob/master/data_bags/imos_po_watches/IMOS_CPR_DB.json)).
  See [ADR-0005](./docs/adr/0005-execution-order-via-config-file.md).
- Some views rely on the CTD profiles data extracted from NetCDF files. This will be available as a Parquet dataset in the `aodn-cloud-optimised` S3 bucket, so should be accessible from there.

## Questions/Challenges
- How to deliver the products in the AODN Portal? In particular, products that are created via `PIVOT` operations 
 (e.g. all the plankton abundances) have a dynamic schema that is not known until the SQL is executed. Converting 
  these to Parquet format is simple, but doing so using 
  the [aodn_cloud_optimised](https://github.com/aodn/aodn_cloud_optimised) library could be painful every time the 
  schema changes. For now, we are just exporting these products as CSV files to be linked directly from the 
  collection metadata records, but this will not allow downloading a subset via the Portal.
- Is there any value in publishing the legacy `_map` views as CSV (or Parquet)?
- Is it worth saving a persistent DuckDB database between weekly updates?
	- Could keep track of when each row was created/updated?
- Can we just use `pyarrow` for schema validation (or DuckDB?), while retaining the  `frictionless` dataresource format to define the schemas?
- We need to apply foreign key constraints in DuckDB to enforce references between the source tables. SQL files 
  already exist in the `public-schema` package to create these constraints, but they are not currently applied in the ETL flow. We need to decide whether to apply them or not.