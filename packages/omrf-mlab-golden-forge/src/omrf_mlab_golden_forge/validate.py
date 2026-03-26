"""Validate golden data JSON files against the schema models."""

import enum
import json
import sys
from pathlib import Path

import structlog
from omrf_mlab_golden_schema import SCHEMA_VERSION_MAJOR
from omrf_mlab_golden_schema import GoldenRecord
from omrf_mlab_golden_schema._version import SCHEMA_VERSION

log = structlog.get_logger()


class ExitCode(enum.IntEnum):
    """Process exit codes for the validate subcommand."""

    OK = 0
    VALIDATION_FAILED = 1
    NO_FILES = 2


class SchemaVersionError(ValueError):
    pass


def validate_golden_data_dir(directory: Path) -> ExitCode:
    """Validate all *.json files in directory against the schema models.

    Returns an ExitCode: OK on success, VALIDATION_FAILED if any file
    is invalid, NO_FILES if the directory contains no JSON files.
    """
    files = sorted(directory.glob('*.json'))
    if not files:
        log.warning('no_json_files', directory=str(directory))
        return ExitCode.NO_FILES

    errors: list[tuple[Path, Exception]] = []
    for path in files:
        try:
            _validate_file(path)
            log.info('valid', file=path.name)
        except Exception as exc:
            log.error('invalid', file=path.name, error=str(exc))
            errors.append((path, exc))

    if errors:
        log.error('validation_failed', n_errors=len(errors), n_files=len(files))
        return ExitCode.VALIDATION_FAILED
    log.info('all_valid', n_files=len(files), schema_version=SCHEMA_VERSION)
    return ExitCode.OK


def _validate_file(path: Path) -> GoldenRecord:
    data = json.loads(path.read_text(encoding='utf-8'))
    _check_schema_version(data, path)
    return GoldenRecord.model_validate(data)


def _check_schema_version(data: dict, source: Path) -> None:
    version = data.get('metadata', {}).get('schema_version', 'MISSING')
    major = str(version).split('.')[0] if '.' in str(version) else str(version)
    if major != SCHEMA_VERSION_MAJOR:
        raise SchemaVersionError(
            f'schema_version={version!r} in {source.name}; '
            f'expected major={SCHEMA_VERSION_MAJOR!r}'
        )


def main(argv: list[str] | None = None) -> None:
    import argparse

    p = argparse.ArgumentParser(prog='omrf-mlab-golden-forge validate')
    p.add_argument(
        'directory',
        type=Path,
        help='Directory containing golden data *.json files',
    )
    args = p.parse_args(argv)
    sys.exit(validate_golden_data_dir(args.directory))
