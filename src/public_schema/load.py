"""
Load stage — DDL generation from Frictionless schemas and CSV loading into DuckDB (see
ADR-0002, ADR-0006, ADR-0007, ADR-0008).
"""

from pathlib import Path

import yaml

from public_schema.config import DescriptorName, RunsheetConfig
from public_schema.connection import create_connection
from public_schema.export import resolve_resource
from public_schema.results import LoadResult

_TYPE_MAP = {
    "string": "VARCHAR",
    "integer": "INTEGER",
    "number": "DOUBLE",
    "date": "DATE",
    "datetime": "TIMESTAMP",
}


def _load_schema(name: DescriptorName) -> dict:
    descriptor_path = resolve_resource(name)
    with open(descriptor_path, encoding="utf-8") as f:
        descriptor = yaml.safe_load(f)
    return descriptor["schema"]


def _primary_key_fields(schema: dict) -> list[str]:
    primary_key = schema.get("primaryKey")
    if primary_key is None:
        return []
    if isinstance(primary_key, str):
        return [primary_key]
    return list(primary_key)


def _foreign_key_dependencies(schema: dict) -> list[str]:
    """
    Names of other Source tables this schema's ``databaseForeignKeys`` reference (see ADR-0008).
    """
    return [fk["reference"]["resource"] for fk in schema.get("databaseForeignKeys", [])]


def generate_create_table_sql(name: DescriptorName) -> str:
    """
    Generate the ``CREATE TABLE`` DDL for a Source table from its Resource's Frictionless schema.

    Column types are mapped from the schema's field ``type``\\ s, ``required``/``unique``
    constraints become ``NOT NULL``/``UNIQUE``, the ``primaryKey`` field becomes a trailing
    ``PRIMARY KEY (...)`` clause, and the non-standard ``databaseForeignKeys`` property (if
    present) becomes trailing ``FOREIGN KEY (...) REFERENCES ...`` clauses (see ADR-0008). Column
    identifiers are left unquoted (see `docs/water_sampling_db.md`'s Implementation plan).

    :param name: name of a bundled Resource descriptor.
    :return: a ``CREATE TABLE`` SQL statement.
    """
    schema = _load_schema(name)

    column_defs = []
    for field in schema["fields"]:
        sql_type = _TYPE_MAP[field["type"]]
        constraints = field.get("constraints", {})
        col_def = f"{field['name']} {sql_type}"
        if constraints.get("required"):
            col_def += " NOT NULL"
        if constraints.get("unique"):
            col_def += " UNIQUE"
        column_defs.append(col_def)

    clauses = list(column_defs)

    primary_key = _primary_key_fields(schema)
    if primary_key:
        clauses.append(f"PRIMARY KEY ({', '.join(primary_key)})")

    for fk in schema.get("databaseForeignKeys", []):
        fields = ", ".join(fk["fields"])
        reference = fk["reference"]["resource"]
        clauses.append(f"FOREIGN KEY ({fields}) REFERENCES {reference}")

    body = ",\n    ".join(clauses)
    return f"CREATE TABLE {name} (\n    {body}\n)"


def _select_expr(field: dict, csv_columns: set[str]) -> str:
    """
    Build the SELECT expression for one schema field, reading from *csv_columns* if present in the
    CSV, or a typed ``NULL`` literal otherwise (letting a subsequent ``NOT NULL`` violation surface
    a missing required column as a load failure, rather than silently dropping it).
    """
    name = field["name"]
    sql_type = _TYPE_MAP[field["type"]]

    if name not in csv_columns:
        return f"CAST(NULL AS {sql_type}) AS {name}"

    if field["type"] in ("date", "datetime"):
        fmt = field["format"]
        return f"CAST(strptime({name}, '{fmt}') AS {sql_type}) AS {name}"

    return f"CAST({name} AS {sql_type}) AS {name}"


def load_source_table(db_path: Path, name: DescriptorName, csv_path: Path) -> None:
    """
    Create the Source table for *name* (per :func:`generate_create_table_sql`) and load
    *csv_path* into it.

    All CSV columns are read as text and explicitly cast per the schema's field types, using the
    schema's Frictionless ``format`` strings (already ``strptime``-compatible) for ``date``/
    ``datetime`` columns. A column declared in the schema but absent from the CSV is loaded as
    ``NULL`` — this surfaces as a ``NOT NULL`` constraint violation if that column is ``required``,
    rather than failing silently.

    :param db_path: path to the DuckDB database file (see ADR-0007).
    :param name: name of a bundled Resource descriptor / Source table.
    :param csv_path: path to the validated CSV file to load.
    """
    schema = _load_schema(name)
    con = create_connection(db_path)
    try:
        con.execute(generate_create_table_sql(name))

        csv_relation = con.read_csv(str(csv_path), header=True, all_varchar=True)
        csv_columns = set(csv_relation.columns)

        column_names = [field["name"] for field in schema["fields"]]
        select_exprs = [_select_expr(field, csv_columns) for field in schema["fields"]]

        insert_sql = (
            f"INSERT INTO {name} ({', '.join(column_names)}) "
            f"SELECT {', '.join(select_exprs)} FROM csv_relation"
        )
        con.execute(insert_sql)
    finally:
        con.close()


def load_source_tables(
    db_path: Path,
    runsheet: RunsheetConfig,
    csv_dir: Path,
    skip: dict[str, str] = {},  # noqa: B006 (never mutated; see results.py's shared-model note)
) -> LoadResult:
    """
    Load every Source table declared in *runsheet*, in order, into the DuckDB file at *db_path*.

    Catches per-table failures rather than raising, and skips a table once any Source table its
    ``databaseForeignKeys`` reference has failed or been skipped (blocking dependents, see
    ADR-0002/ADR-0006). *skip* seeds additional names (with a reason) known to have failed/been
    skipped in an earlier pipeline stage — see `docs/water_sampling_db.md`'s "Cross-stage skip
    propagation".

    :param db_path: path to the DuckDB database file (see ADR-0007).
    :param runsheet: runsheet declaring ``source_tables`` in load order.
    :param csv_dir: directory containing ``<name>.csv`` for each Source table.
    :param skip: name -> reason, seeded from an earlier stage's result.
    :return: :class:`LoadResult` listing succeeded, failed, and skipped table names.
    """
    result = LoadResult(skipped=dict(skip))

    for name in runsheet.source_tables:
        if name in result.skipped:
            continue

        depends = _foreign_key_dependencies(_load_schema(name))
        blocking = [
            dep for dep in depends if dep in result.failed or dep in result.skipped
        ]
        if blocking:
            result.skipped[name] = f"depends on failed/skipped table(s): {blocking}"
            continue

        try:
            load_source_table(db_path, name, csv_dir / f"{name}.csv")
            result.succeeded.append(name)
        except Exception as e:  # noqa: BLE001 (per-item catch is the ADR-0006 contract)
            result.failed[name] = str(e)

    return result
