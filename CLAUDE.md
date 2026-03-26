# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

uv workspace monorepo producing reproducible golden data for equivalence testing of Extended Phase Graph (EPG) implementations. Contains two Python packages and a MATLAB harness.

## Commands

### Setup
```bash
uv sync --dev --all-packages  # Install all workspace packages + dev tools
git submodule update --init    # Initialize the vendored openmrf-core-matlab submodule
```

### Lint & Format
```bash
uv run ruff check .          # Lint
uv run ruff format --check . # Check formatting
uv run ruff check --fix .    # Lint with auto-fix
uv run ruff format .         # Auto-format
uv run pyright               # Type checking
```

### Test
```bash
uv run pytest                # Run all tests
```

### Run
```bash
uv run omrf-mlab-golden-forge extract    # Extract EPG operators from vendor source
uv run omrf-mlab-golden-forge validate golden_data/  # Validate golden data against schema
```

Pre-commit hooks run ruff (lint + format) and pyright automatically on commit.

## Architecture

### Python packages (under `packages/`)

- **`omrf-mlab-golden-forge`** — CLI for extraction and validation
  - `extract_operators.py` — Parses `vendor/openmrf-core-matlab/.../MRF_sim_EPG.m`, extracts local MATLAB functions, writes each as a standalone file to `matlab_code/generated/`
  - `validate.py` — Validates `golden_data/*.json` against the schema models
  - `cli.py` — Subcommand dispatch (extract, validate)
- **`omrf-mlab-golden-schema`** — Pydantic v2 models defining the JSON contract
  - `models.py` — GoldenRecord, GoldenTestCase, GoldenMetadata, ComplexMatrixEncoding, ComplexEncoding
  - `_version.py` — SCHEMA_VERSION constant
  - `golden_record.schema.json` — JSON Schema derived from models (must stay in sync; tested by CI)

### Other top-level directories

- **`matlab_code/harness/`** — MATLAB golden data generation pipeline
- **`matlab_code/generated/`** — Auto-generated standalone MATLAB operator files (gitignored; regenerate, don't edit)
- **`golden_data/`** — Primary deliverable: committed golden data JSON files
- **`vendor/openmrf-core-matlab/`** — Git submodule (shallow clone) of the OpenMRF MATLAB library
- **`tests/`** — pytest test suite at workspace root

## Code Style

- Python >=3.12, managed with **uv** workspaces
- Ruff: line length 89, single quotes, force single-line imports
- Pyright: standard type checking mode
- numpy style docstrings for Python functions
- MATLAB: standard MATLAB style, with function signatures and comments
