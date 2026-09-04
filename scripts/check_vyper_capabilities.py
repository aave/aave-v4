#!/usr/bin/env python3
"""Compile minimal capability examples and retain the pinned compiler diagnostics."""

import json
import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COMPILER = Path(os.environ.get("VYPER_BIN", ROOT / ".venv/bin/vyper"))
OUT = ROOT / "vyper/compiler-feedback/capabilities.json"
results = []
for source in sorted((ROOT / "vyper/compiler-feedback/cases").glob("*.vy")):
    result = subprocess.run(
        [
            str(COMPILER),
            "--experimental-codegen",
            "-O",
            "2",
            "-f",
            "bytecode",
            str(source),
        ],
        capture_output=True,
        text=True,
        env={**os.environ, "PYTHONHASHSEED": "0"},
    )
    results.append(
        {
            "source": str(source.relative_to(ROOT)),
            "supported": result.returncode == 0,
            "diagnostic": result.stderr.replace(str(ROOT) + "/", ""),
        }
    )
OUT.write_text(
    json.dumps(
        {
            "compiler_requirement": (ROOT / "vyper/requirements.txt")
            .read_text()
            .strip(),
            "optimizer": "O2",
            "experimental_codegen": True,
            "cases": results,
        },
        indent=2,
    )
    + "\n"
)
for result in results:
    print(
        ("SUPPORTED" if result["supported"] else "UNSUPPORTED")
        + ": "
        + result["source"]
    )
print(OUT)
