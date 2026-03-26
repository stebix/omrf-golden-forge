# Monorepo Restructure Plan

## Context

This repository is being restructured from a single-package Python project into a
uv workspace monorepo. The driver is the planned `golden-data-sink` package in the
adjacent Python monorepo, which will consume the JSON golden data produced here.
Keeping schema models in the sink only creates implicit, unverified coupling.
A published `omrf-mlab-golden-schema` package — hosted here, where the MATLAB
emitter lives — makes that coupling explicit, versioned, and machine-checkable.

---

## Repository Rename

`omrf-mlab-golden-forge` → `omrf-mlab-golden`

Rationale: the repo now hosts two packages whose names share the `omrf-mlab-golden-`
prefix. The repo name is their common parent namespace, not one of the packages.

**Out of scope for this plan.** The GitHub rename is performed manually by the repo
owner. All tasks below use the *current* repo name and are rename-agnostic.

---

## Target Directory Layout

```
omrf-mlab-golden/
├── packages/
│   ├── omrf-mlab-golden-forge/          ← extraction CLI (existing code, relocated)
│   │   ├── src/omrf_mlab_golden_forge/
│   │   │   ├── __init__.py
│   │   │   ├── _logging.py
│   │   │   ├── extract_operators.py
│   │   │   ├── validate.py              ← NEW (validate subcommand)
│   │   │   └── cli.py                   ← NEW (subcommand dispatch)
│   │   └── pyproject.toml               ← depends on omrf-mlab-golden-schema
│   └── omrf-mlab-golden-schema/         ← contract package (new)
│       ├── src/omrf_mlab_golden_schema/
│       │   ├── __init__.py
│       │   ├── _version.py
│       │   ├── models.py
│       │   └── golden_record.schema.json
│       └── pyproject.toml
├── matlab_code/                         ← renamed from matlab/; MATLAB source only
│   ├── generated/                       ← gitignored *.m files (auto-extracted)
│   └── harness/                         ← golden data generation pipeline
├── golden_data/                         ← PRIMARY DELIVERABLE; committed to git
│   ├── sim_free_relax.json              ← created by MATLAB harness, not moved
│   ├── sim_rf.json
│   ├── sim_dephasing.json
│   └── sim_spoiler.json
├── vendor/openmrf-core-matlab/          ← git submodule; unchanged
├── pyproject.toml                       ← uv workspace root + shared tool config
├── uv.lock                              ← single lockfile for both packages
├── .pre-commit-config.yaml              ← unchanged
├── .gitmodules                          ← unchanged
├── .gitignore                           ← updated for new layout
├── artifacts/
└── CLAUDE.md                            ← updated for new layout
```

### Rationale for separating `matlab_code/` and `golden_data/`

`golden_data/` is the primary deliverable of the repository — the versioned JSON
artifacts that downstream consumers pin against. Nesting it inside `matlab_code/`
would imply it is a build artefact of the MATLAB code, when it is actually the
output product of the whole pipeline. Placing it at the root gives it first-class
visibility and signals its role clearly to any consumer cloning the repo.

`matlab_code/generated/` remains gitignored (auto-extracted from vendor source,
always reproducible). `golden_data/` is committed (deterministic but MATLAB-
dependent; consumers should not need MATLAB to access it).

---

## Task 1 — uv Workspace Scaffolding

Move `src/` and `pyproject.toml` into `packages/omrf-mlab-golden-forge/`.
Create the workspace root `pyproject.toml`. Migrate all `[tool.ruff]`,
`[tool.pyright]`, and `[build-system]` configuration to the root, leaving
each package's `pyproject.toml` lean (name, version, dependencies only).

**Root `pyproject.toml` shape:**
```toml
[tool.uv.workspace]
members = ["packages/*"]

[tool.ruff]
# ... (migrated from current pyproject.toml)

[tool.pyright]
# ... (migrated from current pyproject.toml)
```

The `uv.lock` file lives at the workspace root and covers both packages.

---

## Task 2 — `omrf-mlab-golden-schema` Package

### Purpose

The schema package is the **single source of truth** for the JSON contract between
the MATLAB harness and all Python consumers. It has no runtime logic — only data
model declarations, a version constant, and the JSON Schema file.

It is consumed by:
- `omrf-mlab-golden-forge` (validation CLI, imports models to check emitted JSON)
- `omrf-mlab-golden-sink` in the adjacent monorepo (imports models directly,
  adds numpy/JAX materialization on top)

### Distribution strategy

Within this repo, uv resolves the schema package as a workspace sibling — no path
hack needed.

For the sink in the adjacent monorepo, the schema package is consumed as a **git
dependency**:
```toml
# in the sink's pyproject.toml
dependencies = [
    "omrf-mlab-golden-schema @ git+https://github.com/<org>/omrf-mlab-golden.git@v1.0.0#subdirectory=packages/omrf-mlab-golden-schema",
]
```

This avoids standing up a private PyPI index while still giving the sink a pinnable,
versioned dependency. Tags like `schema-v1.0.0` on this repo mark stable schema
releases. If a private index is introduced later, the switch is a one-line dependency
change in the sink.

### `_version.py`

```python
SCHEMA_VERSION: str = '1.0'
SCHEMA_VERSION_MAJOR: str = '1'
```

The major version is the compatibility gate. The full version supports future minor
bumps for additive (non-breaking) field additions.

### Versioning policy

| Change type | Action |
|---|---|
| New optional field anywhere | Minor bump (`1.0` → `1.1`); consumers ignore unknown fields |
| New required field | **Major bump** (`1.x` → `2.0`); old consumers will error |
| Field rename or removal | **Major bump** |
| Type change of existing field | **Major bump** |
| New operator added to registry | No bump; `params` is operator-specific and opaque |

The schema package's own version (`pyproject.toml` `version`) tracks schema major:
`omrf-mlab-golden-schema==1.x.y` implements schema version `1.x`.

### `models.py` — Pydantic v2 models

Models mirror the exact JSON emitted by `save_golden_record.m`,
`collect_metadata.m`, and `encode_complex_matrix.m`.

```python
from typing import Self

from pydantic import BaseModel
from pydantic import ConfigDict
from pydantic import model_validator


class ComplexEncoding(BaseModel):
    """Encoding of a complex scalar: {"real": float, "imag": float}.
    Produced by save_golden_record.m for complex-valued operator params."""

    model_config = ConfigDict(extra='ignore')

    real: float
    imag: float

    def to_complex(self) -> complex:
        return complex(self.real, self.imag)


class ComplexMatrixEncoding(BaseModel):
    """Encoding from encode_complex_matrix.m: {shape, real, imag}.
    shape: [rows, cols]; real/imag: nested lists of float."""

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


# Params values are either a plain scalar, a bool, or a ComplexEncoding struct.
# save_golden_record.m encodes complex-valued params (e.g. wSL in sim_sl)
# as {"real": ..., "imag": ...} rather than a bare complex number.
# bool is included because MATLAB logical values serialize as JSON true/false.
# Pydantic v2 lax-mode union resolution handles dict → ComplexEncoding
# coercion automatically (tries left-to-right: float, int, bool fail for a
# dict, then ComplexEncoding succeeds), so no manual before-validator is needed.
type ParamValue = float | int | bool | ComplexEncoding


class GoldenMetadata(BaseModel):
    model_config = ConfigDict(extra='ignore')

    schema_version: str        # e.g. "1.0"; gate checked by loader
    git_commit: str
    matlab_version: str
    generated_at: str          # ISO 8601 UTC string; treated as opaque provenance
    operator_file_sha256: str
    source_manifest_sha256: str
    harness_version: str       # e.g. "1.0.0"
    rng_seed: int              # always 42 for deterministic Q state library


class GoldenTestCase(BaseModel):
    model_config = ConfigDict(extra='ignore')

    tag: str                            # e.g. "equilibrium_typical_brain_nstates8"
    nstates: int                        # == shape[1] of Q_in and Q_out
    Q_in: ComplexMatrixEncoding         # EPG state matrix, shape (3, nstates)
    Q_out: ComplexMatrixEncoding        # operator output, shape (3, nstates)
    params: dict[str, ParamValue]       # operator-specific scalar parameters


class GoldenRecord(BaseModel):
    model_config = ConfigDict(extra='ignore')

    operator: str                       # e.g. "sim_free_relax"
    metadata: GoldenMetadata
    test_cases: list[GoldenTestCase]
```

**Design notes:**

- `params` values are typed as `float | int | bool | ComplexEncoding`, not `Any`.
  Pydantic will reject unexpected structures, which catches novel MATLAB encoding
  changes. `bool` covers MATLAB `logical` values that serialize as JSON `true`/`false`.
- `generated_at` is a raw string, not `datetime`. It is provenance, not logic input.
- `model_config = ConfigDict(extra='ignore')` is set on all models so that
  minor-version additions in newer forge outputs do not break old consumers.
- The `_coerce_complex_params` before-validator from the original draft has been
  removed. Pydantic v2's default lax-mode union resolution already handles
  `{"real": ..., "imag": ...}` → `ComplexEncoding` coercion for `dict[str, ParamValue]`.

### `golden_record.schema.json`

A JSON Schema (draft-07) file derived from the Pydantic models. It serves two
purposes:
1. Used by the forge's `validate` CLI subcommand as an independent check
2. Human-readable contract documentation for sink maintainers

It is generated from the Pydantic models via `model.model_json_schema()` and
committed. To prevent drift between `models.py` and the JSON file, a CI check
regenerates the schema and diffs against the committed copy — the check fails if
they differ. This avoids the maintenance trap of "update manually and hope nobody
forgets."

### `__init__.py` — public API

```python
from omrf_mlab_golden_schema._version import SCHEMA_VERSION, SCHEMA_VERSION_MAJOR
from omrf_mlab_golden_schema.models import (
    GoldenRecord,
    GoldenMetadata,
    GoldenTestCase,
    ComplexMatrixEncoding,
    ComplexEncoding,
)

__all__ = [
    'SCHEMA_VERSION',
    'SCHEMA_VERSION_MAJOR',
    'GoldenRecord',
    'GoldenMetadata',
    'GoldenTestCase',
    'ComplexMatrixEncoding',
    'ComplexEncoding',
]
```

### `pyproject.toml`

```toml
[project]
name = "omrf-mlab-golden-schema"
version = "1.0.0"
description = "JSON schema contract for omrf-mlab-golden golden data"
requires-python = ">=3.12"
dependencies = ["pydantic>=2.0"]

[build-system]
requires = ["uv_build>=0.10.6,<0.11.0"]
build-backend = "uv_build"
```

No dev dependencies at the package level — dev tooling (ruff, pyright, pytest)
lives in the workspace root dependency group.

---

## Task 3 — `validate` Subcommand in `omrf-mlab-golden-forge`

### Purpose

After the MATLAB harness generates `golden_data/*.json`, the forge's Python
CLI validates every file against the schema package's Pydantic models. This is
**authoring-time enforcement**: it catches mismatches between what MATLAB emits and
what the schema declares before the artifacts are published.

This step runs in forge CI immediately after MATLAB generation, before any artifact
upload or tag.

### CLI design

The existing entry point (`omrf-mlab-golden-forge`) is a single function call. It
gains a subcommand dispatch via argparse subparsers. Both subcommands remain
accessible:

```
omrf-mlab-golden-forge extract   # existing: parse vendor source, write .m files
omrf-mlab-golden-forge validate  # new: load golden_data/*.json against schema
```

For backward compatibility the bare `omrf-mlab-golden-forge` (no subcommand)
continues to invoke `extract`.

### `validate.py` — implementation shape

```python
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
    p.add_argument('directory', type=Path,
                   help='Directory containing golden data *.json files')
    args = p.parse_args(argv)
    sys.exit(validate_golden_data_dir(args.directory))
```

### Updated `pyproject.toml` for forge package

```toml
[project]
name = "omrf-mlab-golden-forge"
version = "0.1.0"
requires-python = ">=3.12"
dependencies = [
    "omrf-mlab-golden-schema",   # workspace sibling; resolved by uv
    "structlog>=24.1",
    "rich>=13.0",
]

[project.scripts]
omrf-mlab-golden-forge = "omrf_mlab_golden_forge.cli:main"
```

The schema package is a workspace sibling — uv resolves it from the workspace,
no path hack needed.

### `cli.py` — subcommand dispatch via argparse

```python
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
        '--project-root', type=Path, default=None,
        help='Override project root directory',
    )

    # validate
    sub_validate = subparsers.add_parser(
        'validate',
        help='Validate golden_data/*.json against schema models',
    )
    sub_validate.add_argument(
        'directory', type=Path,
        help='Directory containing golden data *.json files',
    )

    args = parser.parse_args()

    # Default to extract when no subcommand given
    if args.command is None or args.command == 'extract':
        from omrf_mlab_golden_forge.extract_operators import main as extract_main
        extract_main(project_root=getattr(args, 'project_root', None))
    elif args.command == 'validate':
        from omrf_mlab_golden_forge.validate import (
            validate_golden_data_dir,
        )
        sys.exit(validate_golden_data_dir(args.directory))
```

---

## Task 4 — MATLAB Harness Changes

### Output path: use `git rev-parse --show-toplevel`

`generate_golden_data.m` currently computes `output_dir` relative to its own
directory tree (`fullfile(matlab_dir, 'golden_data')`). After the restructure,
`golden_data/` lives at the repo root. Rather than hardcoding the directory depth
(`../../golden_data`), the harness resolves the repo root via git — a pattern
already established in `collect_metadata.m` which shells out for
`git rev-parse HEAD`.

Updated path resolution in `generate_golden_data.m`:
```matlab
% Resolve paths relative to this file
harness_dir   = fileparts(mfilename('fullpath'));
matlab_dir    = fileparts(harness_dir);
generated_dir = fullfile(matlab_dir, 'generated');

% Resolve repo root via git (robust to directory depth changes)
[status, repo_root] = system('git rev-parse --show-toplevel');
if status ~= 0
    error('generate_golden_data:noGitRoot', ...
          'Could not determine repository root via git');
end
repo_root  = strtrim(repo_root);
output_dir = fullfile(repo_root, 'golden_data');
```

### Add `schema_version` to `collect_metadata.m`

```matlab
meta.schema_version = '1.0';
```

Added as the **first field** in `collect_metadata.m`, before `git_commit`. This is
the only required change to existing MATLAB code for the schema contract to work.
All other enforcement is on the Python side.

---

## Task 5 — Tests

The schema package's purpose is machine-checkable correctness, so it needs its own
tests. Tests live at the workspace root (or in a `tests/` directory at root) and
run via `uv run pytest`.

### Minimum test coverage

| Test | What it verifies |
|---|---|
| Round-trip parse of each existing golden JSON file | Models accept real MATLAB output without errors |
| `schema_version` major mismatch rejection | `_check_schema_version` raises `SchemaVersionError` for wrong major |
| `ComplexMatrixEncoding` dimension validation | Shape/data mismatch raises `ValidationError` |
| `ComplexEncoding.to_complex()` | Returns correct `complex` value |
| `ConfigDict(extra='ignore')` behaviour | Unknown fields are silently dropped, not rejected |
| JSON Schema drift check | `GoldenRecord.model_json_schema()` matches committed `golden_record.schema.json` |

The round-trip tests depend on golden data existing. Initially they can use a
small fixture JSON file committed to `tests/fixtures/`. Once the MATLAB harness
has produced real output in `golden_data/`, the round-trip tests should also
validate those files.

---

## Contract Lifecycle

### How forge and sink stay in sync (cross-repo)

```
[omrf-mlab-golden repo]
  MATLAB harness
    emits: golden_data/*.json  (schema_version field in every file)
  Python CLI (omrf-mlab-golden-forge)
    validates: JSON against omrf-mlab-golden-schema models  ← authoring-time check
  Forge CI pipeline:
    1. MATLAB generate  (output → golden_data/)
    2. omrf-mlab-golden-forge validate golden_data/
    3. (on pass) tag release, commit golden_data/ to git

[omrf-mlab-golden-schema]  ← published from the forge repo
  Pydantic models (GoldenRecord, GoldenMetadata, GoldenTestCase, ...)
  SCHEMA_VERSION constant
  golden_record.schema.json

[adjacent Python monorepo]
  omrf-mlab-golden-sink
    depends on: omrf-mlab-golden-schema @ git+...@schema-v1.0.0
    adds: loader.py (version gate + file I/O)
          arrays.py (GoldenRecord → numpy EpgGoldenCase)
          jax.py    (optional JAX conversion)
    downloads: forge release artifacts (pinned by schema version)
```

### Schema version bump checklist

When a breaking change is needed:

1. Update `collect_metadata.m` — bump `schema_version` string
2. Update `models.py` in schema package — edit affected Pydantic models
3. Regenerate `golden_record.schema.json` via `model_json_schema()` (CI will
   catch if forgotten — see JSON Schema drift check)
4. Bump `SCHEMA_VERSION` in `_version.py`
5. Bump schema package `version` in its `pyproject.toml` (major track)
6. Regenerate all golden data with the new harness
7. PR description must state the old and new schema_version explicitly
8. Tag the commit as `schema-v<major>.<minor>.<patch>`
9. Sink maintainer bumps `omrf-mlab-golden-schema` git pin and updates any
   affected downstream code (Pydantic will surface field-level errors)

For a **minor (additive) change**: steps 2–4 only, minor version bump.
No MATLAB harness change needed. Old consumers ignore new fields.

---

## Work Breakdown (ordered)

| # | Task | Location | Depends on |
|---|---|---|---|
| 1 | Rename `matlab/` → `matlab_code/` | repo root | — |
| 2 | Update `.gitignore`: `matlab/generated/*.m` → `matlab_code/generated/*.m` | repo root | 1 |
| 3 | Update `generate_golden_data.m` output path to use `git rev-parse --show-toplevel` for `golden_data/` at repo root | `matlab_code/harness/` | 1 |
| 4 | Add `meta.schema_version = '1.0'` to `collect_metadata.m` | `matlab_code/harness/` | 1 |
| 5 | Create workspace root `pyproject.toml` (workspace members, ruff, pyright config) | repo root | — |
| 6 | Move existing `src/` + `pyproject.toml` → `packages/omrf-mlab-golden-forge/` | forge package | 5 |
| 7 | Scaffold `packages/omrf-mlab-golden-schema/` directory structure | schema package | 5 |
| 8 | Implement `_version.py` | schema package | 7 |
| 9 | Implement `models.py` (Pydantic v2 with `ConfigDict(extra='ignore')`) | schema package | 7 |
| 10 | Generate `golden_record.schema.json` from models | schema package | 9 |
| 11 | Implement `__init__.py` re-exports | schema package | 8, 9 |
| 12 | Add `omrf-mlab-golden-schema` dep to forge `pyproject.toml` | forge package | 7 |
| 13 | Implement `validate.py` (with `ExitCode` enum) | forge package | 9, 12 |
| 14 | Implement `cli.py` subcommand dispatch (argparse subparsers) | forge package | 13 |
| 15 | Add tests (round-trip, version gate, dimension validation, schema drift) | repo root | 9, 13 |
| 16 | Update `CLAUDE.md` for new layout | repo root | last |
