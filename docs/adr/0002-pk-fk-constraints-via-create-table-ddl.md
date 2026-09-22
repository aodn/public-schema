> **Amended by [ADR-0004](./0004-flow-logic-packaged-in-public-schema.md),
> [ADR-0005](./0005-execution-order-via-config-file.md), and
> [ADR-0008](./0008-foreign-keys-declared-in-dataresource-yaml.md).** The CREATE-TABLE-DDL approach
> described below is unchanged, but the code lives in this package (`public_schema`), table load
> order comes from the ADR-0005 config file, and the FK clause is now read from each descriptor's
> `databaseForeignKeys` property (ADR-0008) rather than spliced from a separate `.sql` file.

# Primary and foreign key constraints are enforced via CREATE TABLE DDL, not ALTER TABLE

We first assumed DuckDB couldn't enforce the FK constraints bundled here (originally 11
`ALTER TABLE ... ADD FOREIGN KEY` files, see ADR-0008), since DuckDB (v1.5.5) confirmed-rejects
`ALTER TABLE ADD FOREIGN KEY` with `NotImplementedException`. Testing further showed DuckDB *does*
support the identical constraint clause when declared inline at `CREATE TABLE` time instead. So for
each source table, the pipeline generates an explicit `CREATE TABLE` statement: column types are
mapped from the Resource's Frictionless schema, the `PRIMARY KEY` clause comes from the schema's
`primaryKey` field, and any `FOREIGN KEY (...) REFERENCES ...` clause is built from the schema's
`databaseForeignKeys` property. A constraint violation when loading a table's data blocks that
table's dependent transforms (same policy as a Frictionless validation failure) but does not block
uploading the raw CSV to S3.
