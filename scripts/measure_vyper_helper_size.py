#!/usr/bin/env python3
"""Isolate the bytecode cost of the former production test helpers at a fixed revision."""

import concurrent.futures
import io
import json
import os
import re
import subprocess
import tarfile
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COMPILER = Path(os.environ.get("VYPER_BIN", ROOT / ".venv/bin/vyper"))
REVISION = "44751e4e"
HELPERS = {
    "Hub": ["setAssetAddedShares"],
    "Spoke": [
        "borrowWithoutHfCheck",
        "calculateUserAccountData",
        "setReserveDynamicConfigKey",
    ],
}


def remove_functions(source, names):
    for name in names:
        # Each function starts with its decorators and ends before the next decorator.
        pattern = (
            r"(?:@[a-zA-Z_]+(?:\([^\n]*\))?\n)+def " + name + r"\([\s\S]*?(?=\n@|\Z)"
        )
        source, count = re.subn(pattern, "", source)
        assert count == 1, (name, count)
    return source


with tempfile.TemporaryDirectory(prefix="vyper-helper-size-") as directory:
    frozen = Path(directory)
    archive = subprocess.check_output(
        ["git", "archive", REVISION, "vyper/src", "vyper/storage-layouts"], cwd=ROOT
    )
    with tarfile.open(fileobj=io.BytesIO(archive)) as files:
        files.extractall(frozen, filter="data")
    for contract, helpers in HELPERS.items():
        interface = frozen / f"vyper/src/{contract.lower()}/interfaces/I{contract}.vyi"
        interface.write_text(remove_functions(interface.read_text(), helpers))
        original = (
            frozen / f"vyper/src/{contract.lower()}/{contract}Instance.vy"
        ).read_text()
        (frozen / f"{contract}WithHelpers.vy").write_text(original)
        (frozen / f"{contract}WithoutHelpers.vy").write_text(
            remove_functions(original, helpers)
        )

    def measure(job):
        contract, variant, optimizer = job
        source = frozen / f"{contract}{variant}.vy"
        command = [
            str(COMPILER),
            "-p",
            str(frozen / "vyper/src"),
            "--evm-version",
            "cancun",
            "--experimental-codegen",
            "--disable-bytecode-metadata",
            "-O",
            str(optimizer),
            "-W",
            "none",
            "-f",
            "bytecode_runtime",
            str(source),
        ]
        if contract == "Hub":
            command[1:1] = [
                "--storage-layout-file",
                str(frozen / "vyper/storage-layouts/HubInstance.json"),
            ]
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            env={**os.environ, "PYTHONHASHSEED": "0"},
            check=True,
        )
        runtime = len(result.stdout.strip().removeprefix("0x")) // 2
        immutables = 96 if contract == "Spoke" else 0
        return {
            "contract": contract,
            "variant": variant,
            "optimizer": optimizer,
            "runtime_bytes": runtime,
            "immutable_bytes": immutables,
            "deployed_bytes": runtime + immutables,
            "eip170_remaining": 24576 - runtime - immutables,
        }

    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        results = list(
            pool.map(
                measure,
                [
                    (c, v, o)
                    for c in HELPERS
                    for v in ["WithHelpers", "WithoutHelpers"]
                    for o in [2, 3]
                ],
            )
        )
output = ROOT / "vyper/compiler-feedback/helper-removal-sizes.json"
output.write_text(
    json.dumps(
        {
            "source_revision": REVISION,
            "compiler_requirement": (ROOT / "vyper/requirements.txt")
            .read_text()
            .strip(),
            "python_hash_seed": "0",
            "measurements": results,
        },
        indent=2,
    )
    + "\n"
)
print(output)
