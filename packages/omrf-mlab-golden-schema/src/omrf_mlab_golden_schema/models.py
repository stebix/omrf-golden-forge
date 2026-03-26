"""Pydantic v2 models for the golden data JSON contract.

Models mirror the exact JSON emitted by save_golden_record.m,
collect_metadata.m, and encode_complex_matrix.m.
"""

from typing import Self

from pydantic import BaseModel
from pydantic import ConfigDict
from pydantic import model_validator


class ComplexEncoding(BaseModel):
    """Encoding of a complex scalar: {"real": float, "imag": float}.

    Produced by save_golden_record.m for complex-valued operator params.
    """

    model_config = ConfigDict(extra='ignore')

    real: float
    imag: float

    def to_complex(self) -> complex:
        return complex(self.real, self.imag)


class ComplexMatrixEncoding(BaseModel):
    """Encoding from encode_complex_matrix.m: {shape, real, imag}.

    shape: [rows, cols]; real/imag: nested lists of float.
    """

    model_config = ConfigDict(extra='ignore')

    shape: tuple[int, int]
    real: list[list[float]]
    imag: list[list[float]]

    @model_validator(mode='after')
    def _check_dimensions(self) -> Self:
        rows, cols = self.shape
        if len(self.real) != rows or len(self.imag) != rows:
            raise ValueError('row count does not match shape[0]')
        if any(len(r) != cols for r in self.real + self.imag):
            raise ValueError('column count does not match shape[1]')
        return self


# Params values are either a plain scalar, a bool, or a ComplexEncoding
# struct.  save_golden_record.m encodes complex-valued params (e.g. wSL
# in sim_sl) as {"real": ..., "imag": ...} rather than a bare complex
# number.  bool is included because MATLAB logical values serialize as
# JSON true/false.
#
# Pydantic v2 lax-mode union resolution handles dict -> ComplexEncoding
# coercion automatically (tries left-to-right: float, int, bool fail
# for a dict, then ComplexEncoding succeeds), so no manual
# before-validator is needed.
type ParamValue = float | int | bool | ComplexEncoding


class GoldenMetadata(BaseModel):
    """Provenance metadata emitted by collect_metadata.m."""

    model_config = ConfigDict(extra='ignore')

    schema_version: str
    git_commit: str
    matlab_version: str
    generated_at: str
    operator_file_sha256: str
    source_manifest_sha256: str
    harness_version: str
    rng_seed: int


class GoldenTestCase(BaseModel):
    """A single EPG operator test case with input/output matrices."""

    model_config = ConfigDict(extra='ignore')

    tag: str
    nstates: int
    Q_in: ComplexMatrixEncoding
    Q_out: ComplexMatrixEncoding
    params: dict[str, ParamValue]


class GoldenRecord(BaseModel):
    """Top-level golden data record for one EPG operator."""

    model_config = ConfigDict(extra='ignore')

    operator: str
    metadata: GoldenMetadata
    test_cases: list[GoldenTestCase]
