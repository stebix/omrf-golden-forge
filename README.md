# omrf-mlab-golden-data

Produce reproducible golden data for equivalence testing of extended phase graph (EPG) implementations.

## Setup

```bash
uv sync --dev
git submodule update --init
```

## Extract MATLAB operators

```bash
uv run omrf-mlab-golden-data
```

Writes standalone `.m` files to `matlab/generated/`.

## Generate golden data

In MATLAB, from the project root:

```matlab
run('matlab/harness/run_harness.m')
```

Outputs one JSON file per operator to `matlab/golden_data/`. Each file contains tagged input/output pairs (Q state matrices + parameters) with provenance metadata.

### Configuring nstates sizes

The number of q-state columns in test matrices is resolved in order:

1. **Explicit argument:** `generate_golden_data([4, 8, 32])`
2. **Config file:** edit `matlab/harness/config.json`
3. **Built-in default:** `[4, 8, 16]`

### Adding operators

Create `matlab/harness/cases_<operator>.m` returning a struct array of test cases, then add the operator to the registry in `generate_golden_data.m`.