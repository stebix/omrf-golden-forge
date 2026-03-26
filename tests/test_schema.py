"""Tests for the omrf-mlab-golden-schema package."""

import json
from pathlib import Path

import pytest
from omrf_mlab_golden_schema import SCHEMA_VERSION
from omrf_mlab_golden_schema import SCHEMA_VERSION_MAJOR
from omrf_mlab_golden_schema import ComplexEncoding
from omrf_mlab_golden_schema import ComplexMatrixEncoding
from omrf_mlab_golden_schema import GoldenRecord
from pydantic import ValidationError

FIXTURES_DIR = Path(__file__).parent / 'fixtures'
SCHEMA_JSON_PATH = (
    Path(__file__).parents[1]
    / 'packages'
    / 'omrf-mlab-golden-schema'
    / 'src'
    / 'omrf_mlab_golden_schema'
    / 'golden_record.schema.json'
)


# --- round-trip parsing ---


def test_round_trip_fixture() -> None:
    """Fixture JSON parses into GoldenRecord without errors."""
    path = FIXTURES_DIR / 'sim_free_relax.json'
    data = json.loads(path.read_text(encoding='utf-8'))
    record = GoldenRecord.model_validate(data)

    assert record.operator == 'sim_free_relax'
    assert record.metadata.schema_version == '1.0'
    assert len(record.test_cases) == 1

    tc = record.test_cases[0]
    assert tc.tag == 'equilibrium_typical_brain_nstates4'
    assert tc.nstates == 4
    assert tc.Q_in.shape == (3, 4)
    assert tc.params['T1'] == 1.0


# --- ComplexEncoding ---


def test_complex_encoding_to_complex() -> None:
    enc = ComplexEncoding(real=3.0, imag=4.0)
    assert enc.to_complex() == complex(3.0, 4.0)


def test_complex_encoding_in_params() -> None:
    """Dict with real/imag keys coerces to ComplexEncoding in params."""
    data = {
        'tag': 'test',
        'nstates': 2,
        'Q_in': {
            'shape': [3, 2],
            'real': [[0.0, 0.0], [0.0, 0.0], [1.0, 0.0]],
            'imag': [[0.0, 0.0], [0.0, 0.0], [0.0, 0.0]],
        },
        'Q_out': {
            'shape': [3, 2],
            'real': [[0.0, 0.0], [0.0, 0.0], [1.0, 0.0]],
            'imag': [[0.0, 0.0], [0.0, 0.0], [0.0, 0.0]],
        },
        'params': {'wSL': {'real': 1.5, 'imag': -2.3}},
    }
    from omrf_mlab_golden_schema import GoldenTestCase

    tc = GoldenTestCase.model_validate(data)
    assert isinstance(tc.params['wSL'], ComplexEncoding)
    assert tc.params['wSL'].to_complex() == complex(1.5, -2.3)


# --- ComplexMatrixEncoding dimension validation ---


def test_matrix_encoding_valid() -> None:
    mat = ComplexMatrixEncoding(
        shape=(2, 3),
        real=[[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]],
        imag=[[0.0, 0.0, 0.0], [0.0, 0.0, 0.0]],
    )
    assert mat.shape == (2, 3)


def test_matrix_encoding_row_mismatch() -> None:
    with pytest.raises(ValidationError, match='row count'):
        ComplexMatrixEncoding(
            shape=(2, 3),
            real=[[1.0, 2.0, 3.0]],  # only 1 row, expected 2
            imag=[[0.0, 0.0, 0.0], [0.0, 0.0, 0.0]],
        )


def test_matrix_encoding_col_mismatch() -> None:
    with pytest.raises(ValidationError, match='column count'):
        ComplexMatrixEncoding(
            shape=(2, 3),
            real=[[1.0, 2.0], [4.0, 5.0]],  # 2 cols, expected 3
            imag=[[0.0, 0.0, 0.0], [0.0, 0.0, 0.0]],
        )


# --- extra='ignore' behaviour ---


def test_extra_fields_ignored() -> None:
    """Unknown fields are silently dropped, not rejected."""
    data = json.loads((FIXTURES_DIR / 'sim_free_relax.json').read_text(encoding='utf-8'))
    data['unknown_top_level'] = 'should be ignored'
    data['metadata']['future_field'] = 'also ignored'
    data['test_cases'][0]['extra_key'] = 42

    record = GoldenRecord.model_validate(data)
    assert not hasattr(record, 'unknown_top_level')
    assert not hasattr(record.metadata, 'future_field')


# --- schema version gate ---


def test_version_constants() -> None:
    assert SCHEMA_VERSION == '1.0'
    assert SCHEMA_VERSION_MAJOR == '1'


# --- JSON Schema drift check ---


def test_json_schema_matches_models() -> None:
    """Committed golden_record.schema.json matches live model output."""
    committed = json.loads(SCHEMA_JSON_PATH.read_text(encoding='utf-8'))
    generated = GoldenRecord.model_json_schema()
    assert committed == generated, (
        'golden_record.schema.json is out of date; regenerate from models'
    )
