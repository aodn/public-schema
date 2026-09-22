"""
public_schema — IMOS public schema definitions and validation utilities.

Data resources (YAML + SQL) are bundled under `public_schema.resources`:

    from importlib.resources import files
    path = files("public_schema.resources.bgc_data") / "bgc_chemistry.dataresource.yaml"
"""

from public_schema.export import (
    download_resource,
    resolve_resource,
    resource_descriptors_dict,
    resource_descriptors_list,
)
from public_schema.results import (
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
    validate_local,
    validate_resource,
)

__all__ = [
    "LoadResult",
    "StageResult",
    "StoreResult",
    "TransformResult",
    "download_resource",
    "resolve_resource",
    "resource_descriptors_dict",
    "resource_descriptors_list",
    "sql_files_dict",
    "sql_files_list",
    "validate_local",
    "validate_resource",
]
