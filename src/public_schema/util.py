"""
Utility functions.
"""

import re
from importlib.resources import as_file, files
from pathlib import Path


def resource_files_dict(pattern: str = "*/*", suffix: str = ".yaml") -> dict[str, Path]:
    """
    Return a (name: path) mapping of bundled resources.

    Resources are YAML and SQL files bundled inside subdirectories of the ``public_schema.resources`` sub-package.
    Each key in the returned dictionary is the name of an external data resource, database table or view.
    By convention this name is the first part of the file's name, up to the first '.'.

    :param pattern: optional glob pattern to filter resource paths (relative to public_schema/resources/). Note the
                    suffix is added separately. For example, 'bgc_data/*' will match all
                    resources in the bgc_data/ subdirectory. Defaults to all resources ('*/*').
    :param suffix: optional suffix to filter the resources (e.g. ".yaml", ".sql")

    :return: dict mapping resource names to absolute paths (:class:`str`, :class:`~pathlib.Path`)
    """
    resources = {}
    pkg_dir = files("public_schema.resources")
    for entry in pkg_dir.glob(f"{pattern}{suffix}"):
        name = re.sub(r"\..*$", "", entry.name)
        if name in resources:
            raise ValueError(
                f"Duplicate resource name {name!r} in {entry.resolve()} and {resources[name]}"
            )
        with as_file(entry) as p:
            resources[name] = Path(p).resolve()
    return resources


def resource_files_list(pattern: str = "*/*", suffix: str = ".yaml") -> list[Path]:
    """
    Return a list of bundled resources.

    Resources are YAML and SQL files bundled inside subdirectories of the ``public_schema.resources`` sub-package.

    :param pattern: optional glob pattern to filter resource paths (relative to public_schema/resources/). Note the
                    suffix is added separately. For example, 'bgc_data/*' will match all
                    resources in the bgc_data/ subdirectory. Defaults to all resources ('*/*').
    :param suffix: optional suffix to filter the resources (e.g. ".yaml", ".sql")

    :return: sorted list of :class:`~pathlib.Path` objects
    """
    resource_dict = resource_files_dict(pattern, suffix)
    return sorted(resource_dict.values())
