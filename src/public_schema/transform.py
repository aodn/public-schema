"""
Functions for listing the SQL product-generation files bundled with the public_schema package.
"""

from importlib.resources import as_file, files
from pathlib import Path

_RESOURCE_SUBDIRS = ["bgc_data", "cpr_data"]


def sql_files_list() -> list[Path]:
    """
    Return the absolute paths of all bundled ``.sql`` files.

    Files are sourced from the ``bgc_data/`` and ``cpr_data/`` subdirectories
    bundled inside the ``public_schema`` package.

    :return: sorted list of :class:`~pathlib.Path` objects
    """
    paths = []
    for subdir in _RESOURCE_SUBDIRS:
        pkg_dir = files(f"public_schema.resources.{subdir}")
        for entry in pkg_dir.iterdir():
            if entry.name.endswith(".sql"):
                with as_file(entry) as p:
                    paths.append(Path(p).resolve())
    return sorted(paths)


def sql_files_dict() -> dict[str, Path]:
    """
    Return a (name: path) mapping for all bundled ``.sql`` files.

    Files are sourced from the ``bgc_data/`` and ``cpr_data/`` subdirectories
    bundled inside the ``public_schema`` package.

    :return: dict mapping SQL stem names to absolute :class:`~pathlib.Path` objects
    :raises ValueError: if the same stem name appears in more than one subdirectory
    """
    result: dict[str, Path] = {}
    for subdir in _RESOURCE_SUBDIRS:
        pkg_dir = files(f"public_schema.resources.{subdir}")
        for entry in pkg_dir.iterdir():
            if entry.name.endswith(".sql"):
                name = entry.stem
                if name in result:
                    raise ValueError(
                        f"Duplicate SQL name {name!r} found in {subdir} and {result[name]}"
                    )
                with as_file(entry) as p:
                    result[name] = Path(p).resolve()
    return result
