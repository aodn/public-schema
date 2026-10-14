"""CLI entry point: python -m public_schema.flow <runsheet_path> [options]"""

import argparse
import logging
from pathlib import Path

from public_schema.flow import run_pipeline

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Run the IMOS Water Sampling DB ELT pipeline."
    )
    parser.add_argument("runsheet_path", type=Path, help="Path to the runsheet file")
    parser.add_argument(
        "--base_dir",
        type=Path,
        default=None,
        help="Base directory for database and exported tables (default: temporary directory)",
    )
    parser.add_argument(
        "--http_timeout",
        type=int,
        default=100,
        help="HTTP response timeout in seconds (for downloading source tables; default 100)",
    )
    parser.add_argument(
        "-d",
        "--debug",
        action="store_true",
        help="Enable debug logging",
    )
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.debug else logging.INFO,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    )

    run_pipeline(
        runsheet_path=args.runsheet_path,
        base_dir=args.base_dir,
        http_timeout=args.http_timeout,
    )
