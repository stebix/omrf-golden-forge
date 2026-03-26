"""Subcommand dispatch for the omrf-mlab-golden-forge CLI."""

import argparse
import sys
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(
        prog='omrf-mlab-golden-forge',
        description='Golden data extraction and validation CLI',
    )
    subparsers = parser.add_subparsers(dest='command')

    # extract (default when no subcommand given)
    sub_extract = subparsers.add_parser(
        'extract',
        help='Parse vendor source, write standalone .m files',
    )
    sub_extract.add_argument(
        '--project-root',
        type=Path,
        default=None,
        help='Override project root directory',
    )

    # validate
    sub_validate = subparsers.add_parser(
        'validate',
        help='Validate golden_data/*.json against schema models',
    )
    sub_validate.add_argument(
        'directory',
        type=Path,
        help='Directory containing golden data *.json files',
    )

    args = parser.parse_args()

    # Default to extract when no subcommand given
    if args.command is None or args.command == 'extract':
        from omrf_mlab_golden_forge.extract_operators import main as extract_main

        extract_main(project_root=getattr(args, 'project_root', None))
    elif args.command == 'validate':
        from omrf_mlab_golden_forge.validate import validate_golden_data_dir

        sys.exit(validate_golden_data_dir(args.directory))
