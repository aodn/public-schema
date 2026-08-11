# Copilot Instructions

## Purpose

This repository stores schema specifications and SQL product-generation code for IMOS (Integrated Marine Observing System) data exchange between CSIRO and AODN. Schemas define the agreed structure of tabular data (CSV) served via CSIRO Geoserver WFS layers and consumed by AODN harvest pipelines and the AODN Portal.

## Validation commands

Install dependencies (use `uv` — `uv.lock` is present):
```shell
uv sync
# or
pip install frictionless
```

Validate a single `.dataresource.yaml` file (fetches live data from CSIRO Geoserver):
```shell
python code/validate.py bgc_data/bgc_chemistry.dataresource.yaml
```

Validate a local CSV against a standalone schema:
```shell
frictionless validate --schema IMOS_ATF-ACOUSTIC/IMOS_ATF-ACOUSTIC.schema.yaml <path/to/file.csv>
```

The CI workflow (`test_resources.yaml`) automatically runs `code/validate.py` against any changed `.dataresource.yaml` files on PRs to `master`.

## Repository structure

- **`bgc_data/`** — BGC (Biogeochemical) data: paired `.dataresource.yaml` + `.sql` files per dataset
- **`cpr_data/`** — CPR (Continuous Plankton Recorder) data: same pattern as bgc_data
- **`IMOS_ATF-ACOUSTIC/`** — Acoustic animal tracking: `.schema.yaml` (standalone schema) + `.resource.yaml` (resource descriptors)
- **`IMOS_ATF-SATTAG/`** — Satellite tag data: `.resource.yaml` files per product type
- **`code/`** — Python/shell utilities: `validate.py`, `download_resource.sh` (fetch CSVs from Geoserver)
- **`public-schema.wiki/`** — Wiki docs including the BGC schema management process

## File format conventions

### `.dataresource.yaml` / `.resource.yaml` (BGC, CPR, SATTAG)
Full [Frictionless Tabular Data Resource](https://specs.frictionlessdata.io/tabular-data-resource/) descriptors — include `path` (Geoserver WFS URL), `schema`, `layout`, and `licenses`.

```yaml
profile: tabular-data-resource
name: bgc_chemistry
path: https://www.cmar.csiro.au/geoserver/imos/wfs?...
schema:
  fields:
    - name: FID
      title: "Unique identifier for record, added by Geoserver WFS"
      type: string
    - name: COLUMN_NAME
      type: number        # string | number | integer | date | datetime | boolean
      title: "Human-readable description"
      constraints:
        required: true
  primaryKey:
    - COLUMN_A
    - COLUMN_B
licenses:
  - name: CC-BY-4.0
    title: Creative Commons Attribution 4.0
    path: https://creativecommons.org/licenses/by/4.0/
```

### `.schema.yaml` (ATF Acoustic)
Standalone [Table Schema](https://specs.frictionlessdata.io/table-schema) — no `path` or `profile`. Used to validate local CSV files with `frictionless validate --schema`.

### `.sql` files
SQL queries for generating AODN Portal products from harvested raw data. Live alongside their corresponding schema files.

## Key conventions

- **Column names are ALL_CAPS** in BGC/CPR schemas; mixed case in ATF schemas.
- **Datetime format strings** must use Python/C `strptime` syntax (e.g., `"%Y-%m-%d %H:%M:%S"`), with a comment referencing the Python docs.
- **Measurement fields** (e.g., `SALINITY_PSU`) are paired with a required `*_FLAG` integer field. The measurement field itself is typically not `required`.
- **WFS resources** serve a `FID` column as the first column from GeoServer that is not part of the original schema. Resources exported via GeoServer must specify this as the first `field` in their schema.
- **`missingValues`** is specified at the schema level for ATF files: `["", " ", "NA"]`.
- All schemas use **CC-BY-4.0** license.
- Changes to `master` require a PR reviewed by another party (CSIRO or AODN). CI validates schemas live against CSIRO Geoserver — a PR will fail if the schema doesn't match the actual WFS layer.
