"""
public_schema — IMOS public schema definitions and validation utilities.

Data resources (YAML + SQL) are bundled under `public_schema.resources`:

    from importlib.resources import files
    path = files("public_schema.resources.bgc_data") / "bgc_chemistry.dataresource.yaml"

The full ELT pipeline (``run_pipeline`` and its bulk stage tasks) lives in the
`public_schema.flow` sub-package, which requires the optional ``prefect`` dependency group
(``uv sync --group prefect``) — see ADR-0009. Everything imported here has no Prefect dependency.
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
)
from public_schema.results import (
    ExportResult,
    LoadResult,
    StageResult,
    StoreResult,
    TransformResult,
)
from public_schema.store import is_product, store_product
from public_schema.transform import (
    run_transform,
    sql_files_dict,
    sql_files_list,
)
from public_schema.validate import (
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
    "download_resource",
    "generate_create_table_sql",
    "is_product",
    "load_source_table",
    "resolve_resource",
    "resource_descriptors_dict",
    "resource_descriptors_list",
    "run_transform",
    "sql_files_dict",
    "sql_files_list",
    "store_product",
    "validate_local",
    "validate_resource",
]
