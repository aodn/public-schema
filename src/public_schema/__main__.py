"""CLI entry point: python -m public_schema <subcommand> [args]"""

import argparse
import sys
from pathlib import Path

from public_schema.validate import download_resource, validate_local, validate_resource


def _cmd_validate(args: argparse.Namespace) -> int:
    invalid = []
    for res in args.resources:
        print(f"\n{res} ... ", end="")
        valid, errors = validate_resource(res)
        if valid:
            print("ok")
        else:
            print("invalid!")
            print(*errors[:5], sep="\n")
            if len(errors) > 5:
                print(f"... ({len(errors)} errors)")
            invalid.append(res)

    if invalid:
        print("\n", 55 * "-", "Invalid resources:", *invalid, 55 * "-", sep="\n")

    return len(invalid)


def _cmd_download(args: argparse.Namespace) -> int:
    written = download_resource(
        args.name_or_path, args.output_dir, http_timeout=args.timeout
    )
    print(f"Downloaded: {written}")
    return 0


def _cmd_validate_local(args: argparse.Namespace) -> int:
    valid, errors = validate_local(args.csv_path, args.name_or_path)

    if valid:
        print(f"{args.csv_path} ... ok")
        return 0

    print(f"{args.csv_path} ... invalid!")
    print(*errors[:5], sep="\n")
    if len(errors) > 5:
        print(f"... ({len(errors)} errors)")
    return 1


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="python -m public_schema",
        description="IMOS public-schema validation and download utilities.",
    )
    subparsers = parser.add_subparsers(dest="subcommand", metavar="subcommand")

    # validate
    p_validate = subparsers.add_parser(
        "validate",
        help="Validate live WFS resource(s) against their descriptors.",
    )
    p_validate.add_argument(
        "resources",
        nargs="+",
        metavar="resource[.yaml]",
        help="Resource name(s) or path(s) to .yaml descriptor file(s).",
    )
    p_validate.set_defaults(func=_cmd_validate)

    # download
    p_download = subparsers.add_parser(
        "download",
        help="Download a resource CSV from the WFS endpoint.",
    )
    p_download.add_argument(
        "name_or_path",
        metavar="name_or_path",
        help="Resource name (e.g. bgc_chemistry) or path to a .dataresource.yaml file.",
    )
    p_download.add_argument(
        "output_dir",
        type=Path,
        metavar="output_dir",
        help="Directory to write <resource_name>.csv into.",
    )
    p_download.add_argument(
        "--timeout",
        type=int,
        default=100,
        metavar="SECONDS",
        help="HTTP timeout in seconds (default: 100).",
    )
    p_download.set_defaults(func=_cmd_download)

    # validate-local
    p_local = subparsers.add_parser(
        "validate-local",
        help="Validate a local CSV file against a resource descriptor schema.",
    )
    p_local.add_argument(
        "name_or_path",
        metavar="name_or_path",
        help="Resource name (e.g. bgc_chemistry) or path to a .dataresource.yaml file.",
    )
    p_local.add_argument(
        "csv_path",
        metavar="csv_path",
        help="Path to the local CSV file to validate.",
    )
    p_local.set_defaults(func=_cmd_validate_local)

    return parser


def main():
    parser = build_parser()
    args = parser.parse_args()

    if args.subcommand is None:
        parser.print_help()
        sys.exit(1)

    sys.exit(args.func(args))


if __name__ == "__main__":
    main()
