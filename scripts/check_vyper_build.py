#!/usr/bin/env python3
"""Record O2/O3 sizes and same-seed compiler reproducibility. Does not change build artifacts."""

import concurrent.futures, hashlib, json, os, subprocess, sys
from pathlib import Path

r = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(r / "scripts"))
from vyper_abi import check_surface
from importlib.metadata import distribution

compiler = distribution("vyper")
provenance = json.loads(compiler.read_text("direct_url.json"))
assert provenance["vcs_info"]["commit_id"] == "8af5e83c10af4f065cc660fe20293dac11fdff83"


def compile_case(job):
    contract, opt, seed, run = job
    p = r / f"vyper/src/{contract.lower()}/{contract}Instance.vy"
    cmd = [
        str(r / ".venv/bin/vyper"),
        "-p",
        str(r / "vyper/src"),
        "--evm-version",
        "cancun",
        "--experimental-codegen",
        "--disable-bytecode-metadata",
        "-O",
        str(opt),
        "-W",
        "none",
        "-f",
        "bytecode_runtime",
        str(p),
    ]
    if contract == "Hub":
        cmd[1:1] = [
            "--storage-layout-file",
            str(r / "vyper/storage-layouts/HubInstance.json"),
        ]
    b = subprocess.check_output(
        cmd, env={**os.environ, "PYTHONHASHSEED": str(seed)}, text=True
    ).strip()
    binary = bytes.fromhex(b.removeprefix("0x"))
    return {
        "contract": contract,
        "optimizer": opt,
        "pythonHashSeed": seed,
        "run": run,
        "runtimeBytes": len(binary),
        "deployedBytes": len(binary) + (96 if contract == "Spoke" else 0),
        "sha256": hashlib.sha256(binary).hexdigest(),
    }


with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
    results = list(
        pool.map(
            compile_case,
            [
                ("Spoke", 3, 0, 1),
                ("Spoke", 3, 0, 2),
                ("Spoke", 3, 1, 1),
                ("Spoke", 2, 0, 1),
                ("Hub", 2, 0, 1),
                ("Hub", 3, 0, 1),
            ],
        )
    )
output = {"compiler": provenance, "measurements": results}
(r / "vyper/compiler-feedback/build-verification.json").write_text(
    json.dumps(output, indent=2) + "\n"
)
print(json.dumps(output, indent=2))
