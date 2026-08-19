# public-schema

Shared schema specifications and SQL product-generation code for IMOS (Integrated Marine Observing System) data exchange between CSIRO and AODN.

Schemas are specified according to the [Tabular Data Resource](https://specs.frictionlessdata.io/tabular-data-resource/) format from [Frictionless Data](https://frictionlessdata.io), and validated using the [frictionless](https://pypi.org/project/frictionless) Python library.

## Licensing

This project is licensed under the terms of the GNU GPLv3 license.

---

## Installation

The repository is packaged as the `public-schema` Python package (importable as `public_schema`). Requires Python 3.11+.

**Install with `uv` (recommended):**
```shell
uv sync
```

**Install with pip (e.g. in another project):**
```shell
pip install git+https://github.com/aodn/public-schema.git@v2
```

---

## Python API

All public functions are importable directly from `public_schema`.

### List bundled resource descriptors

```python
from public_schema import resource_descriptors_list, resource_descriptors_dict

# Sorted list of Path objects for all .dataresource.yaml files
paths = resource_descriptors_list()

# Dict mapping resource name → Path
resources = resource_descriptors_dict()
path = resources["bgc_chemistry"]  # Path to bgc_chemistry.dataresource.yaml
```

### List bundled SQL files

```python
from public_schema import sql_files_list, sql_files_dict

# Sorted list of Path objects for all .sql files
sql_paths = sql_files_list()

# Dict mapping SQL stem name → Path
sql = sql_files_dict()
path = sql["bgc_chemistry_data"]  # Path to bgc_chemistry_data.sql
```

### Access bundled files directly

```python
from importlib.resources import files

yaml_path = files("public_schema.resources.bgc_data") / "bgc_chemistry.dataresource.yaml"
sql_path  = files("public_schema.resources.cpr_data") / "cpr_phyto_raw.sql"
```

### Resolve a resource by name or path

```python
from public_schema import resolve_resource

path = resolve_resource("bgc_chemistry")          # looks up bundled descriptor
path = resolve_resource("path/to/my.dataresource.yaml")  # uses file directly
```

### Validate a live WFS resource

Fetches data from the CSIRO Geoserver WFS endpoint and validates it against the schema.

```python
from public_schema import validate_resource

valid, errors = validate_resource("bgc_chemistry")
valid, errors = validate_resource("path/to/bgc_chemistry.dataresource.yaml")
```

### Validate a local CSV file

```python
from public_schema import validate_local

valid, errors = validate_local("data/bgc_chemistry.csv", "bgc_chemistry")
```

### Download a resource CSV

```python
from public_schema import download_resource
from pathlib import Path

csv_path = download_resource("bgc_chemistry", output_dir=Path("data/"))
```

---

## Command-line interface

```
python -m public_schema <subcommand> [args]
```

### `validate` — validate live WFS resource(s)

```shell
python -m public_schema validate bgc_chemistry cpr_phyto_raw
python -m public_schema validate path/to/bgc_chemistry.dataresource.yaml
```

### `validate-local` — validate a local CSV against a schema

```shell
python -m public_schema validate-local bgc_chemistry data/bgc_chemistry.csv
```

### `download` — download a resource CSV from the WFS endpoint

```shell
python -m public_schema download bgc_chemistry ./data/
python -m public_schema download bgc_chemistry ./data/ --timeout 300
```

---

## Development

Install dependencies including dev tools:
```shell
uv sync --group dev
```

Set up pre-commit hooks (lint on commit, tests on push):
```shell
make init
```

Run tests:
```shell
make test
```

Run linter:
```shell
make lint
```

---

## Validating standalone schemas (ATF)

The `IMOS_ATF-ACOUSTIC/` schemas are standalone [Table Schema](https://specs.frictionlessdata.io/table-schema) files and can be validated directly with `frictionless`:

```shell
frictionless validate --schema IMOS_ATF-ACOUSTIC/IMOS_ATF-ACOUSTIC.schema.yaml path/to/file.csv
```

---

## Releases

Releases are created by pushing a `v2.*.*` tag. The GitHub Actions `release.yml` workflow builds the wheel and sdist and publishes a GitHub Release automatically.

