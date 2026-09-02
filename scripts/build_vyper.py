#!/usr/bin/env python3
"""Compile pinned Vyper targets into artifacts consumable by Foundry cheatcodes."""

from __future__ import annotations

import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
VYPER = ROOT / ".venv" / "bin" / "vyper"
SOURCE_ROOT = ROOT / "vyper" / "src"
OUT_ROOT = ROOT / "out"
EXPECTED_VERSION = "0.5.0b1"
EXPECTED_OPTIMIZER = "O3"
TARGETS = (
    SOURCE_ROOT / "access" / "AccessManagerEnumerable.vy",
    SOURCE_ROOT / "config_engine" / "TokenizationSpokeDeployer.vy",
    SOURCE_ROOT / "config_engine" / "AaveV4ConfigEngine.vy",
    SOURCE_ROOT / "harness" / "AaveV4PayloadWrapper.vy",
    SOURCE_ROOT / "harness" / "MathHarness.vy",
    SOURCE_ROOT / "harness" / "EngineFlagsHarness.vy",
    SOURCE_ROOT / "harness" / "KeyValueListHarness.vy",
    SOURCE_ROOT / "hub" / "AssetInterestRateStrategy.vy",
    SOURCE_ROOT / "hub" / "HubInstance.vy",
    SOURCE_ROOT / "hub" / "HubConfigurator.vy",
    SOURCE_ROOT / "harness" / "RescuableHarness.vy",
    SOURCE_ROOT / "harness" / "NoncesKeyedHarness.vy",
    SOURCE_ROOT / "utils" / "ExtSload.vy",
    SOURCE_ROOT / "spoke" / "AaveOracle.vy",
    SOURCE_ROOT / "spoke" / "SpokeConfigurator.vy",
    SOURCE_ROOT / "spoke" / "LiquidationLogicContract.vy",
    SOURCE_ROOT / "harness" / "LiquidationLogicWrapper.vy",
    SOURCE_ROOT / "harness" / "MockSpokeStorage.vy",
    SOURCE_ROOT / "spoke" / "SpokeInstance.vy",
    SOURCE_ROOT / "spoke" / "TreasurySpokeInstance.vy",
    SOURCE_ROOT / "spoke" / "TokenizationSpokeInstance.vy",
    SOURCE_ROOT / "harness" / "MockTreasurySpokeInstance.vy",
    SOURCE_ROOT / "harness" / "MockTokenizationSpokeInstance.vy",
    SOURCE_ROOT / "harness" / "ReserveFlagsMapHarness.vy",
    SOURCE_ROOT / "harness" / "ConfigPermissionsMapHarness.vy",
    SOURCE_ROOT / "harness" / "PositionStatusMapHarness.vy",
    SOURCE_ROOT / "harness" / "SpokeUtilsHarness.vy",
    SOURCE_ROOT / "harness" / "RolesHarness.vy",
    SOURCE_ROOT / "harness" / "PositionManagerEIP712HashHarness.vy",
    SOURCE_ROOT / "harness" / "SpokeEIP712HashHarness.vy",
    SOURCE_ROOT / "position_manager" / "PositionManagerBaseWrapper.vy",
    SOURCE_ROOT / "position_manager" / "PositionManagerNoMulticall.vy",
    SOURCE_ROOT / "position_manager" / "GiverPositionManager.vy",
    SOURCE_ROOT / "position_manager" / "NativeTokenGateway.vy",
    SOURCE_ROOT / "harness" / "UserPositionUtilsHarness.vy",
    SOURCE_ROOT / "position_manager" / "TakerPositionManager.vy",
    SOURCE_ROOT / "position_manager" / "SignatureGateway.vy",
    SOURCE_ROOT / "position_manager" / "ConfigPositionManager.vy",
)
STORAGE_LAYOUTS = {
    SOURCE_ROOT / "hub" / "HubInstance.vy": ROOT
    / "vyper"
    / "storage-layouts"
    / "HubInstance.json",
    SOURCE_ROOT / "harness" / "NoncesKeyedHarness.vy": ROOT
    / "vyper"
    / "storage-layouts"
    / "NoncesKeyedHarness.json",
    SOURCE_ROOT / "spoke" / "TreasurySpokeInstance.vy": ROOT
    / "vyper"
    / "storage-layouts"
    / "TreasurySpokeInstance.json",
    SOURCE_ROOT / "spoke" / "TokenizationSpokeInstance.vy": ROOT
    / "vyper"
    / "storage-layouts"
    / "TokenizationSpokeInstance.json",
    SOURCE_ROOT / "harness" / "MockTreasurySpokeInstance.vy": ROOT
    / "vyper"
    / "storage-layouts"
    / "TreasurySpokeInstance.json",
    SOURCE_ROOT / "harness" / "MockTokenizationSpokeInstance.vy": ROOT
    / "vyper"
    / "storage-layouts"
    / "MockTokenizationSpokeInstance.json",
}


def compile_target(source: Path) -> None:
    command = [
        str(VYPER),
        "-p",
        str(SOURCE_ROOT),
        "--evm-version",
        "cancun",
        "-O",
        "3",
        "--disable-bytecode-metadata",
        "--experimental-codegen",
        "-f",
        "combined_json",
        str(source),
    ]
    storage_layout = STORAGE_LAYOUTS.get(source)
    if storage_layout is not None:
        command[1:1] = ["--storage-layout-file", str(storage_layout)]
    completed = subprocess.run(command, capture_output=True, text=True)
    if completed.returncode != 0:
        raise RuntimeError(completed.stderr or completed.stdout)
    combined = json.loads(completed.stdout)
    version = combined["version"]
    if version != EXPECTED_VERSION:
        raise RuntimeError(f"expected Vyper {EXPECTED_VERSION}, got {version}")

    contract = combined[str(source)]
    if contract["settings_dict"].get("experimental_codegen") is not True:
        raise RuntimeError("Vyper target was not compiled with the Venom code generator")
    if contract["settings_dict"].get("optimize") != EXPECTED_OPTIMIZER:
        raise RuntimeError(f"expected Vyper optimizer {EXPECTED_OPTIMIZER}")
    artifact = {
        "abi": contract["abi"],
        "bytecode": {
            "object": contract["bytecode"],
            "sourceMap": "",
            "linkReferences": {},
        },
        "deployedBytecode": {
            "object": contract["bytecode_runtime"],
            "sourceMap": "",
            "linkReferences": {},
            "immutableReferences": {},
        },
        "methodIdentifiers": contract["method_identifiers"],
        "metadata": {
            "compiler": {"version": version},
            "language": "Vyper",
            "settings": contract["settings_dict"],
            "sources": {str(source.relative_to(ROOT)): {}},
        },
    }
    artifact_dir = OUT_ROOT / source.name
    artifact_dir.mkdir(parents=True, exist_ok=True)
    artifact_path = artifact_dir / f"{source.stem}.json"
    artifact_path.write_text(json.dumps(artifact, indent=2) + "\n")
    print(f"Compiled {source.relative_to(ROOT)} -> {artifact_path.relative_to(ROOT)}")


def main() -> None:
    if not VYPER.exists():
        raise SystemExit("Vyper is not installed; run `make vyper-install`")
    for target in TARGETS:
        compile_target(target)


if __name__ == "__main__":
    main()
