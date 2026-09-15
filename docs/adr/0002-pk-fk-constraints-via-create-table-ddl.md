> **Amended by [ADR-0004](./0004-flow-logic-packaged-in-public-schema.md) and
> [ADR-0005](./0005-execution-order-via-config-file.md).** The DDL-generation approach described
> below is unchanged, but the code that generates and executes it now lives in the `public_schema`
> package (not this repo), and table load order comes from the ADR-0005 config file rather than a
> derived dependency graph.

# Primary and foreign key constraints are enforced via CREATE TABLE DDL, not ALTER TABLE

We first assumed DuckDB couldn't enforce the FK constraints bundled in `public_schema` (11
`ALTER TABLE ... ADD FOREIGN KEY` files), since DuckDB (v1.5.5) confirmed-rejects
`ALTER TABLE ADD FOREIGN KEY` with `NotImplementedException`. Testing further showed DuckDB *does*
support the identical constraint clause when declared inline at `CREATE TABLE` time instead. So for
each source table, the flow generates an explicit `CREATE TABLE` statement: column types are mapped
from the Resource's Frictionless schema, the `PRIMARY KEY` clause comes from the schema's
`primaryKey` field, and any `FOREIGN KEY (...) REFERENCES ...` clause is spliced in verbatim from the
corresponding `public_schema` `.sql` file (stripped of its `ALTER TABLE <table> ADD` wrapper). A
constraint violation when loading a table's data blocks that table's dependent transforms (same
policy as a Frictionless validation failure) but does not block uploading the raw CSV to S3.

Note for future consideration: The Frictionless schema specification allows a `foreignKeys` field to declare FK
constraints inline. If FK constraints were specified in this way, the flow could generate the `CREATE TABLE` DDL 
entirely from the `dataresource.yaml` spec, without needing to splice in the `.sql` files. However, resources with
such FK constraints would fail individual validation by Frictionless (since the referenced table is external to the
resource). The only way around this would be to combine all dependent resources into a single Frictionless Data Package,
would require significant re-structuring of the `public_schema` repository. So for now, we continue to 
rely on the existing `.sql` files for FK constraints.

