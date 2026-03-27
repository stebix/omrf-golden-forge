# omrf-mlab-golden

Reproducible golden data for equivalence testing of Extended Phase Graph (EPG) implementations.

This is a **uv workspace monorepo** containing two Python packages and a MATLAB harness:

| Package | Path | Purpose |
|---------|------|---------|
| `omrf-mlab-golden-schema` | `packages/omrf-mlab-golden-schema` | Pydantic v2 models defining the golden data JSON contract |
| `omrf-mlab-golden-forge` | `packages/omrf-mlab-golden-forge` | CLI for MATLAB operator extraction and golden data validation |

## Setup

```bash
uv sync --dev --all-packages   # Install all workspace packages + dev tools
git submodule update --init     # Initialize the vendored openmrf-core-matlab submodule
```

Requires Python >= 3.12.

## Packages

### omrf-mlab-golden-schema

Defines the JSON contract for golden data files using Pydantic v2 models.

```python
from omrf_mlab_golden_schema import (
    SCHEMA_VERSION,          # e.g. '1.0'
    SCHEMA_VERSION_MAJOR,    # e.g. '1'
    GoldenRecord,
    GoldenTestCase,
    GoldenMetadata,
    ComplexEncoding,
    ComplexMatrixEncoding,
)
```

**Models:**

- **`GoldenRecord`** — Top-level record: operator name, metadata, and test cases
- **`GoldenTestCase`** — Single test case: tag, nstates, input/output Q-state matrices, and operator parameters
- **`GoldenMetadata`** — Provenance: schema version, git commit, MATLAB version, timestamps, checksums, RNG seed
- **`ComplexMatrixEncoding`** — Shape + separate real/imag 2D arrays for complex matrices
- **`ComplexEncoding`** — Real/imag pair for complex scalars

A machine-readable JSON Schema is also published at `golden_record.schema.json` within the package and kept in sync via CI.

### omrf-mlab-golden-forge

CLI tool for extracting MATLAB operators and validating golden data.

#### Extract MATLAB operators

Parse the vendored `MRF_sim_EPG.m` source and write each local function as a standalone `.m` file:

```bash
uv run omrf-mlab-golden-forge extract
```

Writes standalone `.m` files and a `manifest.json` (with checksums and provenance) to `matlab_code/generated/`.

#### Validate golden data

Validate golden data JSON files against the schema:

```bash
uv run omrf-mlab-golden-forge validate golden_data/
```

Exit codes: `0` = all valid, `1` = validation failures, `2` = no JSON files found.

## Generate golden data

In MATLAB, from the project root:

```matlab
run('matlab_code/harness/run_harness.m')
```

Outputs one JSON file per operator to `golden_data/`. Each file contains tagged input/output pairs (Q-state matrices + parameters) with provenance metadata.

### Configuring nstates sizes

The number of Q-state columns in test matrices is resolved in order:

1. **Explicit argument:** `generate_golden_data([4, 8, 32])`
2. **Config file:** edit `matlab_code/harness/config.json`
3. **Built-in default:** `[4, 8, 16]`

### Adding operators

Create `matlab_code/harness/cases_<operator>.m` returning a struct array of test cases, then add the operator to the registry in `generate_golden_data.m`.

## Development

### Lint & format

```bash
uv run ruff check .            # Lint
uv run ruff format --check .   # Check formatting
uv run ruff check --fix .      # Lint with auto-fix
uv run ruff format .           # Auto-format
uv run pyright                 # Type checking
```

### Test

```bash
uv run pytest
```

Pre-commit hooks run ruff (lint + format) and pyright automatically on commit.

## Repository layout

```
├── packages/
│   ├── omrf-mlab-golden-schema/   # JSON contract (Pydantic models)
│   └── omrf-mlab-golden-forge/    # CLI (extract + validate)
├── matlab_code/
│   ├── harness/                   # MATLAB golden data generation pipeline
│   └── generated/                 # Auto-generated standalone operator files (gitignored)
├── golden_data/                   # Committed golden data JSON files
├── vendor/openmrf-core-matlab/    # Git submodule (OpenMRF MATLAB library)
├── tests/                         # pytest test suite
└── pyproject.toml                 # uv workspace root
```
