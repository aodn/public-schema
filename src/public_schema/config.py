"""
Config validation and loading for the public_schema package.
"""

import sys
from importlib.resources import as_file, files
from pathlib import Path
from typing import Annotated

from pydantic import AfterValidator, BaseModel, model_validator

from public_schema.export import resource_descriptors_dict
from public_schema.transform import sql_files_dict

_DESCRITORS_LIST = list(resource_descriptors_dict().keys())
_SQL_FILES_LIST = list(sql_files_dict().keys())


def validate_descriptor_name(name: str) -> str:
    """
    Ensure the given name matches a bundled data descriptor in this package.
    """
    if name not in _DESCRITORS_LIST:
        raise ValueError(
            f"Data resource descriptor name '{name}' not found in bundled resources."
        )
    return name


DescriptorName = Annotated[str, AfterValidator(validate_descriptor_name)]


def validate_transform_name(name: str) -> str:
    """
    Ensure the given name matches a bundled transform SQL file (table/view name) in this package.
    """
    if name not in _SQL_FILES_LIST:
        raise ValueError(
            f"SQL file to generate '{name}' not found in bundled resources."
        )
    return name


TransformName = Annotated[str, AfterValidator(validate_transform_name)]


class TransformConfig(BaseModel):
    """
    Configuration for a SQL transform defining the transform's name, SQL query, and dependencies on other tables.

    Attributes:
        name: Name of the transform.
        depends: List of table names that this transform depends on.
    """

    name: TransformName
    depends: list[DescriptorName | TransformName] = []


class RunsheetConfig(BaseModel):
    """
    Configuration for a runsheet defining source tables to load and SQL transforms to run in the correct order.

    Attributes:
        source_tables: List of source table names to load.
        transforms: List of SQL transforms and their dependencies on other tables.
    """

    # TODO: source_tables list should include optional `depends:` to specify dependencies for foreign keys
    source_tables: list[DescriptorName]
    transforms: list[TransformConfig]

    @model_validator(mode="after")
    def validate_execution_order(self) -> "RunsheetConfig":
        """
        Validate that the execution order of transforms is correct based on their dependencies.
        """
        # initialise a set of available tables with the source tables
        available_tables = set(self.source_tables)
        errors = []
        for transform in self.transforms:
            # check that all dependencies of the transform are available
            depends = set(transform.depends)
            unavailable_tables = depends - available_tables
            if unavailable_tables:
                errors.append(
                    f"- '{transform.name}' has unavailable dependencies: {unavailable_tables}."
                )
            else:
                # add the transform's name to the set of available tables
                available_tables.add(transform.name)
        if errors:
            raise ValueError("Invalid execution order:\n    " + "\n    ".join(errors))

        return self


def resolve_runsheet(name_or_path: str | Path) -> Path:
    """
    Resolve a runsheet name or path to the absolute path of its YAML file.

    If *name_or_path* looks like an existing YAML file path, return it directly. Otherwise, treat
    it as a runsheet name and search the bundled ``public_schema.resources`` package (recursively)
    for ``<name>.yaml``.

    :param name_or_path: runsheet name (e.g. ``"bgc_runsheet"``) or path to a YAML file
    :return: resolved absolute :class:`~pathlib.Path`
    :raises FileNotFoundError: if *name_or_path* is a path that does not exist
    :raises ValueError: if *name_or_path* is a name that matches no bundled runsheet
    """
    candidate = Path(name_or_path)
    if candidate.suffix in (".yaml", ".yml") or candidate.exists():
        if not candidate.exists():
            raise FileNotFoundError(
                f"Runsheet file {candidate.resolve()} does not exist"
            )
        return candidate.resolve()

    name = str(name_or_path)
    filename = f"{name}.yaml"
    pkg_dir = files("public_schema.resources")
    for entry in pkg_dir.glob(f"**/{filename}"):
        with as_file(entry) as p:
            return Path(p).resolve()

    raise ValueError(f"No bundled runsheet named {name!r}.")


def load_runsheet(name_or_path: str | Path) -> RunsheetConfig:
    """
    Load a runsheet configuration from a YAML file and validate it against the RunsheetConfig schema.

    Args:
        name_or_path: Runsheet name (e.g. "bgc_runsheet") or path to the YAML file containing the
            runsheet configuration. A bare name is resolved via :func:`resolve_runsheet` by
            searching the bundled ``public_schema.resources`` package.

    Returns:
        An instance of RunsheetConfig containing the validated configuration.
    """
    import yaml

    path = resolve_runsheet(name_or_path)
    with open(path, "r") as f:
        config_data = yaml.safe_load(f)
    return RunsheetConfig.model_validate(config_data)


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Validate runsheet configuration.")
    parser.add_argument(
        "runsheet",
        help="Bundled runsheet name (e.g. 'bgc_runsheet') or path to a runsheet YAML file.",
    )
    args = parser.parse_args()

    print(f"Validating runsheet configuration in {resolve_runsheet(args.runsheet)}")
    try:
        runsheet_config = load_runsheet(args.runsheet)
        print(f"Runsheet configuration is valid: {runsheet_config}")
    except ValueError as e:
        print(f"Error validating runsheet configuration: {e}")
        sys.exit(1)
