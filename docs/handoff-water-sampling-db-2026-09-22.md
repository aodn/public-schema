# Handoff: Water Sampling Database ETL — implementation phase

**Repo:** `aodn/public-schema`, working copy at `/sw/public-schema`, branch `v2`.
**Prior phase:** design/planning via the `grill-with-docs` skill. **This phase:** implement the
pipeline stage functions. No pipeline code exists yet — this is a fresh start on the code, with a
fully-settled design.

## Start here

Read, in this order:

1. [`CONTEXT.md`](../../sw/public-schema/CONTEXT.md) (repo root) — domain glossary. Know these
   terms before reading anything else: Resource, Descriptor, Source table, Transform, Product,
   Intermediate table, Runsheet, `databaseForeignKeys`, Wrapper flow.
2. [`docs/water_sampling_db.md`](../../sw/public-schema/docs/water_sampling_db.md) — the master
   plan. Pipeline stages 1–3 are done; stages 4–6 (Load, Transform execution, Store) are not, and
   are what you're implementing. The "Implementation plan" section gives concrete module/function
   signatures, including how per-stage `skip` dicts chain together across stages.
3. ADRs `0002`, `0003`, `0005`, `0006`, `0007`, `0008` in `docs/adr/` — each is short and backs one
   specific API decision (constraint DDL, ephemeral DB file, config-driven order, catch-and-return
   result contract, `db_path` not connection + sequential execution, FK info in
   `databaseForeignKeys`). Don't re-litigate these; they were deliberately settled.
4. `src/public_schema/config.py` — existing `RunsheetConfig`/`TransformConfig`/`DescriptorName`/
   `TransformName`/`load_runsheet`, and the two runsheets (`resources/bgc_data/bgc_runsheet.yaml`,
   `resources/cpr_data/cpr_runsheet.yaml`) — these define the execution order you'll loop over.
5. `src/public_schema/transform.py` and `export.py` — existing patterns to follow (resource/SQL
   file discovery, `resolve_resource`) when writing the new modules.

## What to build, in order

Per `water_sampling_db.md`'s Implementation plan (do not duplicate its content here — read it for
exact signatures and type-mapping tables):

1. `results.py` — shared `StageResult` model, aliased as `LoadResult`/`TransformResult`/`StoreResult`.
2. `connection.py` — `create_connection(db_path: Path)`.
3. `load.py` — DDL generation from Frictionless schema (incl. `databaseForeignKeys`) + CSV loading,
   per-item and bulk functions.
4. `transform.py` — extend with `run_transform`/`run_transforms` (execution), alongside the
   existing `sql_files_dict`/`sql_files_list` (listing).
5. `store.py` — `is_product`, `store_product`, `store_all_products`.
6. `config.py` — extend with `runsheet_paths_dict()` and name-or-path support in `load_runsheet`.
7. Add `duckdb` to `pyproject.toml` dependencies.

Each bulk function takes a `skip: dict[str, str] = {}` param seeded from the previous stage's
result (see `water_sampling_db.md`'s "Cross-stage skip propagation" — this was a gap found and
fixed during final doc review this session, so it won't be in your memory of any earlier design
discussion; read that section carefully).

CTD/Parquet + S3 `httpfs` integration (used by ~8 of 44 transforms) is explicitly **blocked** on
external coordination — don't try to solve it; work around it (e.g. skip/stub those transforms) if
you reach that stage.

## Repo state right now

- Branch `v2`, HEAD is commit `59186ca` ("Update architecture diagram to match design terms").
- Two files have uncommitted edits from this session's final doc review (a stale sentence fixed in
  `water_sampling_db.md` Stage 4, and the cross-stage skip-propagation section added to both
  `water_sampling_db.md` and ADR-0006). Check `git diff` and commit them (or fold into your first
  commit) before starting code — they're the ones with the exact function signatures you need.
- `uv run pytest tests/ -q` → 55 passed. `uvx ruff check`/`format` clean.
- Untracked, **not related to this work, leave alone**: `.idea/`, `public-schema.wiki/`, and
  `src/public_schema/resources/bgc_data/bgc_phyto_TEST.datapackage.yaml` (the user's own earlier
  experiment).

## Suggested skills

- **`tdd`** — the stage-function contracts (per-item + bulk, catch/skip/result) are unusually
  well-specified up front; write tests from the ADRs' stated behavior before implementing each
  module (`results.py` first, since everything else depends on it).
- **`review`** once `load.py`/`transform.py`/`store.py` exist, to check the implementation against
  `CONTEXT.md`'s terms and the ADRs' stated consequences (e.g. did you actually keep everything
  sequential per ADR-0007? does DDL generation match ADR-0002/0008 exactly?).
- **`grill-with-docs`** again if you hit a genuinely new design ambiguity (e.g. exact CTD/httpfs
  wiring once that's unblocked) — it will keep `CONTEXT.md`/ADRs in sync as you resolve it, the way
  this session did for the FK-constraint and skip-propagation questions.
