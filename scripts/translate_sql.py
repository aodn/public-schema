"""
translate_sql.py — Translate PostgreSQL SQL files to DuckDB dialect.

Applies the following mechanical substitutions to all .sql files under
src/public_schema/resources/bgc_data/ and .../cpr_data/:

  1. CREATE MATERIALIZED VIEW name AS  →  CREATE OR REPLACE TABLE name AS
  2. CREATE VIEW name AS               →  CREATE OR REPLACE VIEW name AS
  3. to_char(ts, 'YYYY-MM-DD HH24:MI:SS')  →  strftime(ts, '%Y-%m-%d %H:%M:%S')
  4. to_char(ts, 'HH24:MI')           →  strftime(ts, '%H:%M')
  5. st_geomfromtext('POINT(...)', 4326) →  ST_AsWKB(ST_GeomFromText('POINT(...)'))

jsonb_object_agg → PIVOT rewrites are NOT handled here (done manually per file).
DISTINCT ON is NOT changed.
"""

import re
from pathlib import Path


def apply_substitutions(sql: str) -> tuple[str, list[str]]:
    """Apply all mechanical substitutions. Returns (new_sql, list_of_changes)."""
    changes = []

    # 1. CREATE MATERIALIZED VIEW name AS  →  CREATE OR REPLACE TABLE name AS
    new, n = re.subn(
        r"CREATE MATERIALIZED VIEW (\w+) AS",
        r"CREATE OR REPLACE TABLE \1 AS",
        sql,
        flags=re.IGNORECASE,
    )
    if n:
        changes.append(f"  MATERIALIZED VIEW → TABLE ({n}x)")
    sql = new

    # 2. CREATE VIEW name AS  →  CREATE OR REPLACE VIEW name AS
    # (only bare CREATE VIEW, not CREATE OR REPLACE VIEW already)
    new, n = re.subn(
        r"CREATE VIEW (\w+) AS",
        r"CREATE OR REPLACE VIEW \1 AS",
        sql,
        flags=re.IGNORECASE,
    )
    if n:
        changes.append(f"  CREATE VIEW → CREATE OR REPLACE VIEW ({n}x)")
    sql = new

    # 3. to_char(expr, 'YYYY-MM-DD HH24:MI:SS')  →  strftime(expr, '%Y-%m-%d %H:%M:%S')
    new, n = re.subn(
        r"to_char\(([^,]+),\s*'YYYY-MM-DD HH24:MI:SS'\)",
        r"strftime(\1, '%Y-%m-%d %H:%M:%S')",
        sql,
        flags=re.IGNORECASE,
    )
    if n:
        changes.append(f"  to_char datetime → strftime ({n}x)")
    sql = new

    # 4. to_char(expr, 'HH24:MI')  →  strftime(expr, '%H:%M')
    new, n = re.subn(
        r"to_char\(([^,]+),\s*'HH24:MI'\)",
        r"strftime(\1, '%H:%M')",
        sql,
        flags=re.IGNORECASE,
    )
    if n:
        changes.append(f"  to_char time → strftime ({n}x)")
    sql = new

    # 5. st_geomfromtext('POINT(' || x || ' ' || y || ')', 4326)
    #    →  ST_AsWKB(ST_GeomFromText('POINT(' || x || ' ' || y || ')'))
    #    Matches the specific pattern used across these files.
    new, n = re.subn(
        r"st_geomfromtext\(('POINT\(' \|\|[^)]+\|\| '\)')\s*,\s*4326\)",
        r"ST_AsWKB(ST_GeomFromText(\1))",
        sql,
        flags=re.IGNORECASE,
    )
    if n:
        changes.append(f"  st_geomfromtext → ST_AsWKB(ST_GeomFromText) ({n}x)")
    sql = new

    return sql, changes


def main():
    resources_root = (
        Path(__file__).parent.parent / "src" / "public_schema" / "resources"
    )
    subdirs = ["bgc_data", "cpr_data"]

    total_files = 0
    total_changed = 0

    for subdir in subdirs:
        for sql_file in sorted((resources_root / subdir).glob("*.sql")):
            original = sql_file.read_text(encoding="utf-8")
            translated, changes = apply_substitutions(original)

            if translated != original:
                sql_file.write_text(translated, encoding="utf-8")
                total_changed += 1
                print(
                    f"✓ {sql_file.relative_to(resources_root.parent.parent.parent.parent)}"
                )
                for c in changes:
                    print(c)
            total_files += 1

    print(f"\n{total_changed}/{total_files} files changed.")


if __name__ == "__main__":
    main()
