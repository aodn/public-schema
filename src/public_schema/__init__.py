"""
public_schema — IMOS public schema definitions and validation utilities.

Data resources (YAML + SQL) are bundled under `public_schema.resources`:

    from importlib.resources import files
    path = files("public_schema.resources.bgc_data") / "bgc_chemistry.dataresource.yaml"
"""

from public_schema.connection import create_connection
from public_schema.export import (
    download_resource,
    resolve_resource,
    resource_descriptors_dict,
    resource_descriptors_list,
)
from public_schema.load import (
    generate_create_table_sql,
    load_source_table,
    load_source_tables,
)
from public_schema.results import (
    ExportResult,
    LoadResult,
    StageResult,
    StoreResult,
    TransformResult,
)
from public_schema.transform import (
    sql_files_dict,
    sql_files_list,
)
from public_schema.validate import (
    download_and_validate_source_tables,
    validate_local,
    validate_resource,
)

__all__ = [
    "ExportResult",
    "LoadResult",
    "StageResult",
    "StoreResult",
    "TransformResult",
    "create_connection",
    "download_and_validate_source_tables",
    "download_resource",
    "generate_create_table_sql",
    "load_source_table",
    "load_source_tables",
    "resolve_resource",
    "resource_descriptors_dict",
    "resource_descriptors_list",
    "sql_files_dict",
    "sql_files_list",
    "validate_local",
    "validate_resource",
]
