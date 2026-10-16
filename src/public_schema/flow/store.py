"""
Store stage task — Prefect wrapper for bulk export of Products to CSV (see ADR-0006, ADR-0007,
ADR-0009).
"""

from pathlib import Path
from pprint import pformat

from prefect import get_run_logger, task
from prefect_aws import S3Bucket

from public_schema.config import RunsheetConfig
from public_schema.results import StoreResult
from public_schema.store import is_product, store_product


@task
def store_all_products(
    db_path: Path,
    runsheet: RunsheetConfig,
    output_dir: Path,
    skip: dict[str, str] | None = None,
) -> StoreResult:
    """
    Export every Product declared in *runsheet* (per :func:`is_product`) from the DuckDB file at
    *db_path* to CSV files in *output_dir*.

    Catches per-product failures rather than raising. Products are leaf nodes — nothing in this
    package depends on a Product's CSV output — so unlike `load_source_tables`/`run_transforms`,
    this never needs to *derive* new skips itself; it only consults its *skip* input (seeded from
    an earlier stage's result, see `docs/water_sampling_db.md`'s "Cross-stage skip propagation")
    and otherwise tries every Product independently.

    :param db_path: path to the DuckDB database file (see ADR-0007).
    :param runsheet: runsheet declaring ``transforms``, filtered here to Products.
    :param output_dir: directory to write CSV files into.
    :param skip: name -> reason, seeded from an earlier stage's result.
    :return: :class:`StoreResult` listing succeeded, failed, and skipped Product names.
    """
    logger = get_run_logger()
    products = [t.name for t in runsheet.transforms if is_product(t.name)]
    logger.info(f"Starting store of {len(products)} products from {db_path}")
    result = StoreResult(skipped=skip if skip is not None else {})

    for name in products:
        if name in result.skipped:
            logger.debug(f"[{name}] Skipping (already marked as skipped)")
            continue

        logger.debug(f"[{name}] Storing product")
        try:
            store_product(db_path, name, output_dir)
            logger.info(f"[{name}] Store succeeded")
            result.succeeded.append(name)
        except Exception as e:
            logger.exception(f"[{name}] Error storing")
            result.failed[name] = str(e)

    logger.info(
        f"Store complete: {len(result.succeeded)} succeeded, {len(result.failed)} failed, {len(result.skipped)} skipped"
    )
    logger.debug(pformat(result.model_dump(), sort_dicts=False))

    return result


@task
def upload_to_s3(
    source_dir: Path,
    output_bucket_block_name: str,
    folder: str | None = None,
) -> None:
    """
    Upload all files in *source_dir* to the S3 bucket, under an optional *folder* prefix, using the Prefect block
     named *output_bucket_block_name*.

    :param source_dir: path to file or directory containing files to upload.
    :param output_bucket_block_name: name of the Prefect block to upload to.
    :param folder: optional folder prefix in the S3 bucket (additional to any bucket_folder defined in the bucket block).
    """
    logger = get_run_logger()
    s3_bucket = S3Bucket.load(output_bucket_block_name)
    logger.info(
        f"Uploading files from {source_dir} to S3 bucket {s3_bucket.bucket_name}."
    )
    s3_bucket.upload_from_folder(from_folder=source_dir, to_folder=folder)
