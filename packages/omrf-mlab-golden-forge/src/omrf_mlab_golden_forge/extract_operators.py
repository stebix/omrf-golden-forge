"""Extract local EPG operators from vendored MRF_sim_EPG.m.

The vendored MATLAB file defines EPG operators as local functions
that are not callable from outside the file. This module parses the
source and writes each operator as a standalone .m file for use in
harness scripts.
"""

import hashlib
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from datetime import UTC
from datetime import datetime
from pathlib import Path

import structlog

log = structlog.get_logger()

_FUNC_DEF = re.compile(r'^function\b')
_FUNC_NAME = re.compile(r'^function\s+(?:[\w\[\],\s]+=\s*)?(\w+)\s*\(')

VENDOR_SOURCE = Path(
    'vendor/openmrf-core-matlab/include_pulseq_toolbox'
    '/src_mrf/src_simulations/MRF_sim_EPG.m'
)
SUBMODULE_DIR = Path('vendor/openmrf-core-matlab')
OUTPUT_DIR = Path('matlab_code/generated')
MANIFEST_NAME = 'manifest.json'


# --- git helpers ---


def _run_git(*args: str, cwd: Path) -> str | None:
    """Run a git command, returning stripped stdout or None on failure."""
    try:
        result = subprocess.run(
            ['git', *args],
            cwd=cwd,
            capture_output=True,
            text=True,
            check=True,
        )
        return result.stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None


def _file_sha256(path: Path) -> str:
    """Return hex SHA-256 digest of a file's contents."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


# --- parsing ---


@dataclass(frozen=True)
class MatlabFunction:
    """A MATLAB function parsed from source."""

    name: str
    source: str


def _find_header_start(lines: list[str], func_line: int) -> int:
    """Scan backward from a function line to include preceding comment/blank lines."""
    pos = func_line
    while pos > 0 and (
        lines[pos - 1].strip() == '' or lines[pos - 1].strip().startswith('%')
    ):
        pos -= 1
    return pos


def parse_local_functions(text: str) -> list[MatlabFunction]:
    """Extract local functions from MATLAB source text.

    Local functions are top-level ``function`` definitions following
    the main (first) function in the file. Each block includes its
    preceding comment header.
    """
    lines = text.splitlines()
    func_indices = [i for i, line in enumerate(lines) if _FUNC_DEF.match(line)]

    if len(func_indices) < 2:
        return []

    local_indices = func_indices[1:]
    header_starts = [_find_header_start(lines, i) for i in local_indices]

    results: list[MatlabFunction] = []
    for k, func_line in enumerate(local_indices):
        block_start = header_starts[k]
        block_end = header_starts[k + 1] if k + 1 < len(local_indices) else len(lines)

        block = lines[block_start:block_end]
        while block and block[-1].strip() == '':
            block.pop()

        match = _FUNC_NAME.match(lines[func_line])
        name = match.group(1) if match else f'function_{k}'

        log.debug('parsed local function', name=name, line=func_line + 1)
        results.append(MatlabFunction(name=name, source='\n'.join(block) + '\n'))

    log.info('parsed local functions', count=len(results))
    return results


# --- file writing ---


def write_standalone_files(
    functions: list[MatlabFunction],
    output_dir: Path,
    *,
    source_label: str = '',
) -> list[Path]:
    """Write each function to ``output_dir/<name>.m``."""
    output_dir.mkdir(parents=True, exist_ok=True)

    written: list[Path] = []
    for fn in functions:
        preamble = (
            (
                f'% Auto-extracted from: {source_label}\n'
                '% Do not edit — regenerate via extract_operators.\n\n'
            )
            if source_label
            else ''
        )

        path = output_dir / f'{fn.name}.m'
        path.write_text(preamble + fn.source)
        written.append(path)
        log.debug('wrote standalone file', path=str(path.name))

    log.info('wrote standalone files', count=len(written))
    return written


# --- manifest ---


def build_manifest(
    source_path: Path,
    written_files: list[Path],
    functions: list[MatlabFunction],
    project_root: Path,
) -> dict:
    """Build an extraction manifest capturing full provenance."""
    repo_commit = _run_git('rev-parse', 'HEAD', cwd=project_root)
    repo_dirty_output = _run_git('status', '--porcelain', cwd=project_root)
    submodule_commit = _run_git('rev-parse', 'HEAD', cwd=project_root / SUBMODULE_DIR)

    outputs = []
    for fn, path in zip(functions, written_files, strict=True):
        outputs.append(
            {
                'name': fn.name,
                'file': path.name,
                'sha256': _file_sha256(path),
            }
        )

    manifest = {
        'extraction_timestamp': datetime.now(UTC).isoformat(),
        'source': {
            'relative_path': str(VENDOR_SOURCE),
            'sha256': _file_sha256(source_path),
        },
        'git': {
            'repo_commit': repo_commit,
            'repo_dirty': (
                bool(repo_dirty_output) if repo_dirty_output is not None else None
            ),
            'submodule_commit': submodule_commit,
        },
        'outputs': outputs,
        'environment': {
            'python_version': sys.version,
        },
    }

    log.info(
        'built extraction manifest',
        repo_commit=repo_commit,
        submodule_commit=submodule_commit,
    )
    return manifest


def write_manifest(manifest: dict, output_dir: Path) -> Path:
    """Write the manifest to ``output_dir/manifest.json``."""
    path = output_dir / MANIFEST_NAME
    path.write_text(json.dumps(manifest, indent=2) + '\n')
    log.info('wrote manifest', path=str(path))
    return path


# --- entry point ---


def main(project_root: Path | None = None) -> None:
    """Extract EPG operators and write to matlab_code/generated/."""
    from omrf_mlab_golden_forge import setup_logging

    setup_logging()

    # packages/omrf-mlab-golden-forge/src/omrf_mlab_golden_forge/ → repo root
    root = project_root or Path(__file__).resolve().parents[4]
    source = root / VENDOR_SOURCE

    if not source.exists():
        log.error(
            'vendor source not found',
            path=str(source),
            hint='git submodule update --init',
        )
        raise SystemExit(1)

    log.info('starting extraction', source=str(VENDOR_SOURCE))

    functions = parse_local_functions(source.read_text())

    if not functions:
        log.warning(
            'no local functions found',
            source=str(VENDOR_SOURCE),
        )
        return

    out = root / OUTPUT_DIR
    written = write_standalone_files(
        functions,
        out,
        source_label=str(VENDOR_SOURCE),
    )

    manifest = build_manifest(source, written, functions, root)
    write_manifest(manifest, out)

    log.info(
        'extraction complete',
        functions=len(written),
        output_dir=str(OUTPUT_DIR),
    )


if __name__ == '__main__':
    main()
