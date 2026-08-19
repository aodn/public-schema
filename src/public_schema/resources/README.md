# Bundled resources
This package contains descriptions of data resources (tables) and transformations to be applied to them. 
The resources are grouped into subdirectories based on the data source:
- `bgc_data/` - BGC (BioGeoChemical) measurements from water samples at fixed sites or stations (including plankton abundances). 
- `cpr_data/` - CPR (Continuous Plankton Recorder) measurements of plankton abundances along transects.

Within each subdirectory, two types of files are present.

## Data Resource descriptors
- Files that describe the location, name and schema of each (tabular) data source.
- Naming convention: `<resource_name>.dataresource.yaml`.

## SQL transformations
  - SQL code to transform the source data into various products, or to apply constraints between tables in the database.
  - Naming convention: `<table_name>.sql`, where `<table_name>` is the name of the table or view that will be created 
    or modified by the SQL code.

### Translate SQL statements from PostgreSQL to DuckDB dialect. 
The original transformations were written for PostgreSQL. They have now been adapted to run in DuckDB.

Key adaptations:
- `to_char(ts, 'YYYY-MM-DD HH24:MI:SS')` → `strftime(ts, '%Y-%m-%d %H:%M:%S')`
- `to_char(ts, 'HH24:MI')` → `strftime(ts, '%H:%M')`
- `st_geomfromtext('POINT(...)', 4326)` → `ST_AsWKB(ST_GeomFromText('POINT(...)'))`  (DuckDB spatial ext, SRID arg dropped)
- `CREATE MATERIALIZED VIEW` → `CREATE OR REPLACE TABLE` (DuckDB does not support materialised views)
- `::int`, `::text`, `EXTRACT` — preserved (DuckDB supports PostgreSQL cast syntax)
- `jsonb_object_agg` → `PIVOT` e.g.
```sql
    SELECT trip_code,
           methods,
           jsonb_object_agg(taxon_name, cell_l) AS abundances
    FROM bgc_phyto_raw
    GROUP BY trip_code, methods
```
becomes
```sql
    PIVOT bgc_phyto_raw
    ON taxon_name
    USING sum(cell_l)
    GROUP BY trip_code, methods
```

The simpler translations were applied using `scripts/translate_sql.py`, with some help from GitHub Copilot.