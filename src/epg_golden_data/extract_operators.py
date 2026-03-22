"""Extract local EPG operator functions from vendored MRF_sim_EPG.m into standalone files.

The vendored MATLAB file defines EPG operators as local functions that are not
callable from outside the file. This module parses the source and writes each
operator as a standalone .m file for use in harness scripts.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path

_FUNC_DEF = re.compile(r"^function\b")
_FUNC_NAME = re.compile(r"^function\s+(?:[\w\[\],\s]+=\s*)?(\w+)\s*\(")

VENDOR_SOURCE = Path(
    "vendor/openmrf-core-matlab/include_pulseq_toolbox"
    "/src_mrf/src_simulations/MRF_sim_EPG.m"
)
OUTPUT_DIR = Path("matlab/generated")


@dataclass(frozen=True)
class MatlabFunction:
    """A MATLAB function parsed from source."""

    name: str
    source: str


def _find_header_start(lines: list[str], func_line: int) -> int:
    """Scan backward from a function line to include preceding comment/blank lines."""
    pos = func_line
    while pos > 0 and (
        lines[pos - 1].strip() == ""
        or lines[pos - 1].strip().startswith("%")
    ):
        pos -= 1
    return pos


def parse_local_functions(text: str) -> list[MatlabFunction]:
    """Extract local functions from MATLAB source text.

    Local functions are top-level ``function`` definitions following the
    main (first) function in the file. Each block includes its preceding
    comment header.
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
        while block and block[-1].strip() == "":
            block.pop()

        match = _FUNC_NAME.match(lines[func_line])
        name = match.group(1) if match else f"function_{k}"

        results.append(MatlabFunction(name=name, source="\n".join(block) + "\n"))

    return results


def write_standalone_files(
    functions: list[MatlabFunction],
    output_dir: Path,
    *,
    source_label: str = "",
) -> list[Path]:
    """Write each function to ``output_dir/<name>.m``, returning written paths."""
    output_dir.mkdir(parents=True, exist_ok=True)

    written: list[Path] = []
    for fn in functions:
        preamble = (
            f"% Auto-extracted from: {source_label}\n"
            "% Do not edit — regenerate via extract_operators.\n\n"
        ) if source_label else ""

        path = output_dir / f"{fn.name}.m"
        path.write_text(preamble + fn.source)
        written.append(path)

    return written


def main(project_root: Path | None = None) -> None:
    """Extract EPG operators and write to matlab/generated/."""
    root = project_root or Path(__file__).resolve().parents[2]
    source = root / VENDOR_SOURCE

    if not source.exists():
        raise FileNotFoundError(
            f"Vendor source not found: {source}\n"
            "Ensure the submodule is initialized: git submodule update --init"
        )

    functions = parse_local_functions(source.read_text())

    if not functions:
        print("No local functions found.")
        return

    out = root / OUTPUT_DIR
    written = write_standalone_files(
        functions, out, source_label=str(VENDOR_SOURCE),
    )

    print(f"Extracted {len(written)} functions to {out}:")
    for p in written:
        print(f"  {p.relative_to(root)}")


if __name__ == "__main__":
    main()
