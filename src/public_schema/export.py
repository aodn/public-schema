"""
Functions for accessing the resource descriptors bundled with the public_schema package and exporting (downloading)
 the data they describe.
"""

from importlib.resources import as_file, files
from pathlib import Path

import requests
import yaml

from public_schema.util import resource_files_dict

_RESOURCE_SUBDIRS = ["bgc_data", "cpr_data"]


def resource_descriptors_dict(pattern: str = "*/*") -> dict[str, Path]:
    """
    Return a (name: path) mapping for all bundled ``.dataresource.yaml`` files.

    Resources are bundled inside subdirectories of the ``public_schema.resources`` sub-package.

    :param pattern: optional glob pattern to filter resource paths (relative to public_schema/resources/). Note the
                    '.dataresource.yaml' suffix is added automatically. For example, 'bgc_data/*' will match all
                    resources in the bgc_data/ subdirectory. Defaults to all resources ('*/*').

    :return: dict mapping resource names to absolute paths (:class:`str`, :class:`~pathlib.Path`)
    """
    return resource_files_dict(pattern, suffix=".dataresource.yaml")


def resource_descriptors_list(pattern: str = "*/*") -> list[Path]:
    """
    Return the absolute paths of all bundled ``.dataresource.yaml`` files.

    Resources are bundled inside subdirectories of the ``public_schema.resources`` sub-package.

    :param pattern: optional glob pattern to filter resource paths (relative to public_schema/resources/). Note the
                    '.dataresource.yaml' suffix is added automatically. For example, 'bgc_data/*' will match all
                    resources in the bgc_data/ subdirectory. Defaults to all resources ('*/*').

    :return: sorted list of :class:`~pathlib.Path` objects
    """
    resource_dict = resource_descriptors_dict(pattern)
    return sorted(resource_dict.values())


def resolve_resource(name_or_path: str | Path) -> Path:
    """
    Resolve a resource name or path to the absolute path of its .dataresource.yaml file.

    If *name_or_path* looks like an existing YAML file path, return it directly.
    Otherwise, treat it as a resource name and search the bundled bgc_data/ and
    cpr_data/ subdirectories for ``<name>.dataresource.yaml``.

    :param name_or_path: resource name (e.g. ``"bgc_chemistry"``) or path to a
        ``.dataresource.yaml`` file
    :return: resolved absolute :class:`~pathlib.Path`
    :raises FileNotFoundError: if *name_or_path* is a path that does not exist
    :raises ValueError: if *name_or_path* is a name that matches no bundled descriptor
    """
    candidate = Path(name_or_path)
    if candidate.suffix in (".yaml", ".yml") or candidate.exists():
        if not candidate.exists():
            raise FileNotFoundError(
                f"Resource file {candidate.resolve()} does not exist"
            )
        return candidate.resolve()

    name = str(name_or_path)
    filename = f"{name}.dataresource.yaml"
    for subdir in _RESOURCE_SUBDIRS:
        pkg_path = files(f"public_schema.resources.{subdir}") / filename
        if pkg_path.is_file():
            with as_file(pkg_path) as p:
                return Path(p).resolve()

    raise ValueError(f"No bundled resource named {name!r}.")


def download_resource(
    name_or_path: str | Path,
    output_dir: Path,
    http_timeout: int = 100,
) -> Path:
    """
    Download the CSV data for a resource and write it to *output_dir*.

    The WFS URL is read from the ``path`` field of the descriptor.  The output
    file is named ``<resource_name>.csv``.

    :param name_or_path: resource name or path to a ``.dataresource.yaml`` file
    :param output_dir: directory to write the CSV file into
    :param http_timeout: HTTP response timeout in seconds
    :return: path of the written CSV file
    """
    descriptor_path = resolve_resource(name_or_path)
    with open(descriptor_path, encoding="utf-8") as f:
        descriptor = yaml.safe_load(f)

    wfs_url = descriptor.get("path")
    if not wfs_url:
        raise ValueError(f"Descriptor {descriptor_path} has no 'path' field")

    resource_name = descriptor.get("name") or descriptor_path.stem.replace(
        ".dataresource", ""
    )
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / f"{resource_name}.csv"

    response = requests.get(wfs_url, timeout=http_timeout, stream=True)
    response.raise_for_status()

    with open(output_path, "wb") as f:
        f.writelines(response.iter_content(chunk_size=8192))

    return output_path
