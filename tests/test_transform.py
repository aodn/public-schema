"""Tests for public_schema.transform — sql_files_list and sql_files_dict."""

from pathlib import Path

from public_schema import sql_files_dict, sql_files_list

# --- sql_files_list ---


def test_sql_files_list_returns_list():
    assert isinstance(sql_files_list(), list)


def test_sql_files_list_nonempty():
    assert len(sql_files_list()) > 0


def test_sql_files_list_are_paths():
    assert all(isinstance(p, Path) for p in sql_files_list())


def test_sql_files_list_paths_exist():
    assert all(p.exists() for p in sql_files_list())


def test_sql_files_list_all_sql():
    assert all(p.suffix == ".sql" for p in sql_files_list())


def test_sql_files_list_is_sorted():
    result = sql_files_list()
    assert result == sorted(result)


def test_sql_files_list_contains_known_bgc():
    names = {p.stem for p in sql_files_list()}
    assert "bgc_chemistry" in names


def test_sql_files_list_contains_known_cpr():
    names = {p.stem for p in sql_files_list()}
    assert "cpr_phyto_raw" in names


# --- sql_files_dict ---


def test_sql_files_dict_returns_dict():
    assert isinstance(sql_files_dict(), dict)


def test_sql_files_dict_nonempty():
    assert len(sql_files_dict()) > 0


def test_sql_files_dict_keys_are_str():
    assert all(isinstance(k, str) for k in sql_files_dict())


def test_sql_files_dict_values_are_paths():
    assert all(isinstance(v, Path) for v in sql_files_dict().values())


def test_sql_files_dict_paths_exist():
    assert all(v.exists() for v in sql_files_dict().values())


def test_sql_files_dict_contains_known_bgc():
    assert "bgc_chemistry" in sql_files_dict()


def test_sql_files_dict_contains_known_cpr():
    assert "cpr_phyto_raw" in sql_files_dict()


def test_sql_files_dict_key_matches_stem():
    for name, path in sql_files_dict().items():
        assert path.stem == name


# --- consistency between list and dict ---


def test_sql_files_list_matches_dict_values():
    assert sql_files_list() == sorted(sql_files_dict().values())
