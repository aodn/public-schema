"""Tests for the non-standard `databaseForeignKeys` schema property (see ADR-0008).

These check structural/referential consistency of the property as hand-authored in the bundled
`.dataresource.yaml` files, ahead of the DDL generator (`load.py`) that will consume it.
"""

import yaml

from public_schema import resource_descriptors_dict


def _load_schema(path):
    with open(path, encoding="utf-8") as f:
        return yaml.safe_load(f)["schema"]


def _descriptors_with_fks():
    for name, path in resource_descriptors_dict().items():
        fks = _load_schema(path).get("databaseForeignKeys")
        if fks:
            yield name, fks


def test_some_descriptors_declare_foreign_keys():
    assert len(list(_descriptors_with_fks())) > 0


def test_foreign_key_entries_are_well_formed():
    for name, fks in _descriptors_with_fks():
        for fk in fks:
            assert isinstance(fk["fields"], list), name
            assert all(isinstance(f, str) for f in fk["fields"]), name
            assert isinstance(fk["reference"]["resource"], str), name


def test_foreign_key_fields_exist_in_own_schema():
    for name, fks in _descriptors_with_fks():
        schema = _load_schema(resource_descriptors_dict()[name])
        field_names = {f["name"] for f in schema["fields"]}
        for fk in fks:
            for field in fk["fields"]:
                assert field in field_names, f"{name}: {field} not in own fields"


def test_foreign_key_references_point_to_bundled_resources():
    descriptors = resource_descriptors_dict()
    for name, fks in _descriptors_with_fks():
        for fk in fks:
            ref = fk["reference"]["resource"]
            assert ref in descriptors, f"{name}: references unknown resource {ref!r}"
