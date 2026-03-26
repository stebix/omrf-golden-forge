"""Tests for the validate subcommand."""

import json
from pathlib import Path

import pytest
from omrf_mlab_golden_forge.validate import ExitCode
from omrf_mlab_golden_forge.validate import SchemaVersionError
from omrf_mlab_golden_forge.validate import _check_schema_version
from omrf_mlab_golden_forge.validate import validate_golden_data_dir

FIXTURES_DIR = Path(__file__).parent / 'fixtures'


def test_validate_fixture_dir() -> None:
    """Validates the fixtures directory successfully."""
    result = validate_golden_data_dir(FIXTURES_DIR)
    assert result == ExitCode.OK


def test_validate_empty_dir(tmp_path: Path) -> None:
    """Empty directory returns NO_FILES."""
    result = validate_golden_data_dir(tmp_path)
    assert result == ExitCode.NO_FILES


def test_validate_invalid_json(tmp_path: Path) -> None:
    """Invalid JSON content returns VALIDATION_FAILED."""
    bad = tmp_path / 'bad.json'
    bad.write_text('{"operator": "test"}')  # missing required fields
    result = validate_golden_data_dir(tmp_path)
    assert result == ExitCode.VALIDATION_FAILED


def test_schema_version_mismatch(tmp_path: Path) -> None:
    """Wrong schema_version major triggers SchemaVersionError."""
    data = json.loads((FIXTURES_DIR / 'sim_free_relax.json').read_text(encoding='utf-8'))
    data['metadata']['schema_version'] = '99.0'

    bad_file = tmp_path / 'bad_version.json'
    bad_file.write_text(json.dumps(data))

    result = validate_golden_data_dir(tmp_path)
    assert result == ExitCode.VALIDATION_FAILED


def test_check_schema_version_pass() -> None:
    data = {'metadata': {'schema_version': '1.0'}}
    _check_schema_version(data, Path('test.json'))  # should not raise


def test_check_schema_version_fail() -> None:
    data = {'metadata': {'schema_version': '2.0'}}
    with pytest.raises(SchemaVersionError):
        _check_schema_version(data, Path('test.json'))


def test_check_schema_version_missing() -> None:
    data = {'metadata': {}}
    with pytest.raises(SchemaVersionError):
        _check_schema_version(data, Path('test.json'))
