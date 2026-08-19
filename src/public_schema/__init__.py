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
from public_schema.validate import (
    validate_local,
    validate_resource,
)

__all__ = [
    "download_resource",
    "resolve_resource",
    "resource_descriptors_dict",
    "resource_descriptors_list",
    "validate_local",
    "validate_resource",
]
