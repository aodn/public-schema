"""
Functions for listing the SQL product-generation files bundled with the public_schema package.
"""

from pathlib import Path

from public_schema.util import resource_files_dict


def sql_files_dict(pattern: str = "*/*") -> dict[str, Path]:
    """
    Return a (name: path) mapping for all bundled SQL files. Each key is the names of the view or table
    created by the SQL file (by convention this is also the first part of the file's name, up to the first '.').

    SQL files are bundled inside subdirectories of the ``public_schema.resources`` sub-package.

    :param pattern: optional glob pattern to filter paths (relative to public_schema/resources/). Note the
                    '.sql' suffix is added automatically. For example, 'bgc_data/*' will match all
                    SQL files in the bgc_data/ subdirectory. Defaults to all subdirectories ('*/*').

    :return: dict mapping table/view names to absolute paths (:class:`str`, :class:`~pathlib.Path`)
    """
    return resource_files_dict(pattern, suffix=".sql")


def sql_files_list(pattern: str = "*/*") -> list[Path]:
    """
    Return the absolute paths of all bundled SQL files.

    SQL files are bundled inside subdirectories of the ``public_schema.resources`` sub-package.

    :param pattern: optional glob pattern to filter paths (relative to public_schema/resources/). Note the
                    '.sql' suffix is added automatically. For example, 'bgc_data/*' will match all
                    SQL files in the bgc_data/ subdirectory. Defaults to all subdirectories ('*/*').

    :return: sorted list of :class:`~pathlib.Path` objects
    """
    resource_dict = sql_files_dict(pattern)
    return sorted(resource_dict.values())
