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
