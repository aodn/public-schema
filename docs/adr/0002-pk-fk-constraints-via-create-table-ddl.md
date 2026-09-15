> **Amended by [ADR-0004](./0004-flow-logic-packaged-in-public-schema.md) and
> [ADR-0005](./0005-execution-order-via-config-file.md).** The DDL-generation approach described
> below is unchanged, but the code that generates and executes it lives in this package
> (`public_schema`), and table load order comes from the ADR-0005 config file rather than a derived
> dependency graph.

# Primary and foreign key constraints are enforced via CREATE TABLE DDL, not ALTER TABLE

We first assumed DuckDB couldn't enforce the FK constraints bundled here (11
`ALTER TABLE ... ADD FOREIGN KEY` files), since DuckDB (v1.5.5) confirmed-rejects
`ALTER TABLE ADD FOREIGN KEY` with `NotImplementedException`. Testing further showed DuckDB *does*
support the identical constraint clause when declared inline at `CREATE TABLE` time instead. So for
each source table, the pipeline generates an explicit `CREATE TABLE` statement: column types are
mapped from the Resource's Frictionless schema, the `PRIMARY KEY` clause comes from the schema's
`primaryKey` field, and any `FOREIGN KEY (...) REFERENCES ...` clause is spliced in verbatim from
the corresponding `.sql` file (stripped of its `ALTER TABLE <table> ADD` wrapper). A constraint
violation when loading a table's data blocks that table's dependent transforms (same policy as a
Frictionless validation failure) but does not block uploading the raw CSV to S3.
