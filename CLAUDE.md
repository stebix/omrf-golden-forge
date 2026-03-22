# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Produces reproducible golden data for equivalence testing of Extended Phase Graph (EPG) implementations. Extracts EPG operator functions from a vendored OpenMRF MATLAB library (git submodule) into standalone `.m` files.

## Commands

### Setup
```bash
uv sync --dev          # Install all dependencies (including dev)
git submodule update --init  # Initialize the vendored openmrf-core-matlab submodule
```

### Lint & Format
```bash
uv run ruff check .          # Lint
uv run ruff format --check . # Check formatting
uv run ruff check --fix .    # Lint with auto-fix
uv run ruff format .         # Auto-format
uv run pyright               # Type checking
```

### Run
```bash
uv run epg-golden-data       # Run the CLI entry point
```

Pre-commit hooks run ruff (lint + format) and pyright automatically on commit.

## Architecture

- **`src/epg_golden_data/`** — Python package (src layout)
  - `extract_operators.py` — Parses `vendor/openmrf-core-matlab/.../MRF_sim_EPG.m`, extracts local MATLAB functions, writes each as a standalone file to `matlab/generated/`
- **`vendor/openmrf-core-matlab/`** — Git submodule (shallow clone) of the OpenMRF MATLAB library; source of truth for EPG operators
- **`matlab/generated/`** — Auto-generated standalone MATLAB operator files (gitignored; regenerate, don't edit)

## Code Style

- Python >=3.12, managed with **uv**
- Ruff: line length 89, single quotes, force single-line imports
- Pyright: standard type checking mode
