# Foreign keys declared via non-standard `databaseForeignKeys` in dataresource.yaml, not separate .sql files

FK constraints for the ADR-0002 DDL generator were originally kept in a separate `.sql` file per
constrained table (e.g. `bgc_data/foreign_keys/bgc_chemistry.sql`,
`ALTER TABLE bgc_chemistry ADD FOREIGN KEY (trip_code) REFERENCES bgc_trip`), because Frictionless's
real `foreignKeys` schema property fails validation unless the referencing and referenced resources
live in the same Data Package — which `public_schema`'s per-resource descriptors don't.

We moved the FK declarations into each resource's own `.dataresource.yaml`, under a **non-standard**
`databaseForeignKeys` property instead (same key structure as Frictionless's `foreignKeys`: a list of
`{fields: [...], reference: {resource: ...}}`). Frictionless silently ignores unknown schema
properties, so this validates cleanly per-resource while still letting the DDL generator read the FK
info directly from the descriptor it already parses — no separate file, no splicing/stripping an
`ALTER TABLE` wrapper.

`reference.fields` is omitted (not just optional) for every current FK, since none reference a
non-primary-key column and DuckDB's inline `FOREIGN KEY (...) REFERENCES table` already defaults to
the referenced table's primary key.

## Consequences

- The `bgc_data/foreign_keys/` and `cpr_data/foreign_keys/` subdirectories and their 11 `.sql` files
  are removed; FK info lives only in `databaseForeignKeys`.
- Any future FK that must reference a specific non-primary-key column should add an explicit
  `reference.fields` to that FK entry — the property structure already supports it.
