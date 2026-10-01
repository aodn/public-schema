"""
Helper functions for validating schemas and resources using the Frictionless framework
"""

from pathlib import Path

import yaml
from frictionless import FrictionlessException, Resource, Schema, validate
from frictionless.schemes.remote import RemoteControl

from public_schema.config import RunsheetConfig
from public_schema.export import download_resource, resolve_resource
from public_schema.results import ExportResult

# TODO: check that the file name follows convention "<resource_name>.dataresource.yaml" for bundled resources


def validate_local(
    csv_path: str | Path,
    name_or_path: str | Path,
) -> tuple[bool, list]:
    """
    Validate a local CSV file against the schema from a resource descriptor.

    The ``path`` (WFS URL) in the descriptor is ignored; only its ``schema``
    is used.

    :param csv_path: path to the local CSV file to validate
    :param name_or_path: resource name or path to a ``.dataresource.yaml`` file
    :return: tuple (valid:bool, errors:list)
    """
    csv_path = Path(csv_path)
    if not csv_path.exists():
        raise FileNotFoundError(f"CSV file {csv_path.resolve()} does not exist")

    descriptor_path = resolve_resource(name_or_path)
    with open(descriptor_path, encoding="utf-8") as f:
        descriptor = yaml.safe_load(f)

    raw_schema = descriptor.get("schema")
    if not raw_schema:
        raise ValueError(f"Descriptor {descriptor_path} has no 'schema' field")

    try:
        schema = Schema.from_descriptor(raw_schema)
        csv_path = csv_path.resolve()
        res = Resource(path=csv_path.name, basepath=str(csv_path.parent), schema=schema)
        report = validate(res)
    except FrictionlessException as e:
        return False, [f"An exception occurred during validation:\n{e}"]

    return report.valid, report.flatten(["name", "message"])


def validate_resource(name_or_path: str | Path, http_timeout: int = 100):
    """
    Validate the given resource (including data accessed from the specified path)

    :param name_or_path: resource name or path to a ``.dataresource.yaml`` file
    :param http_timeout: http response timeout in seconds
    :return: tuple (valid:bool, errors:list)
    """
    descriptor_path = resolve_resource(name_or_path)
    if not descriptor_path.exists():
        raise FileNotFoundError(
            f"Resource file {descriptor_path.resolve()} does not exist"
        )

    try:
        # create (a copy of) Resource object
        # set longer timeout to allow for slow response
        res = Resource(
            descriptor_path, control=RemoteControl(http_timeout=http_timeout)
        )
    except FrictionlessException as e:
        return False, [f"Not a valid resource description:\n{e}"]

    try:
        report = validate(res)
    except FrictionlessException as e:
        return False, [f"An exception occurred during validation:\n{e}"]

    return report.valid, report.flatten(["name", "message"])


def download_and_validate_source_tables(
    runsheet: RunsheetConfig, csv_dir: Path, http_timeout: int = 100
) -> ExportResult:
    """
    Download the CSV data for all resources in the runsheet and validate them against their schemas.

    :param runsheet: runsheet declaring ``source_tables`` to download & validate.
    :param csv_dir: directory to save each source table to (as ``<name>.csv``).
    :param http_timeout: HTTP response timeout in seconds
    :return: :class:`ExportResult` listing succeeded, failed, and skipped table names.
    """
    # TODO: add tests
    # TODO: retries?

    result = ExportResult()
    for name in runsheet.source_tables:
        try:
            csv_path = download_resource(name, csv_dir, http_timeout=http_timeout)
            valid, errors = validate_local(csv_path, name)
            if valid:
                result.succeeded.append(name)
            else:
                result.failed[name] = f"Validation failed: {errors}"
        except Exception as e:  # noqa: BLE001 (per-item catch is the ADR-0006 contract)
            result.failed[name] = str(e)

    return result
