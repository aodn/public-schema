"""CLI entry point: python -m public_schema.flow <runsheet_path> [options]"""

import argparse
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
    args = parser.parse_args()

    run_pipeline(
        runsheet_path=args.runsheet_path,
        base_dir=args.base_dir,
        http_timeout=args.http_timeout,
    )
