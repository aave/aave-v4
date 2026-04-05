#!/usr/bin/env python3
"""Simplified Aave V4 bytecode-only verification script.

Reads a deployment report JSON, connects to an RPC endpoint, and verifies that
the on-chain bytecode of every deployed contract matches the local Forge
build artifacts.  Does NOT require a config input — only the deploy report.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from functools import lru_cache
from pathlib import Path
from typing import Any, Optional

from web3 import Web3

ARTIFACTS_DIR = Path(__file__).resolve().parent.parent.parent / "out"

GREEN = "\033[92m"
RED = "\033[91m"
BOLD = "\033[1m"
RESET = "\033[0m"


# ---------------------------------------------------------------------------
# Artifact mapping
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class ArtifactInfo:
    sol_file: str
    contract_name: str
    impl_sol_file: Optional[str] = None
    impl_contract_name: Optional[str] = None


EIP712_IMMUTABLES: list[tuple[str, str]] = [
    ("_cachedThis", "uint256"),
    ("_cachedChainId", "uint256"),
    ("_cachedNameHash", "bytes32"),
    ("_cachedVersionHash", "bytes32"),
    ("_cachedDomainSeparator", "bytes32"),
]

# Immutable variable labels per contract, ordered by declaration (base classes first).
# Sorted AST node IDs in immutableReferences correspond to this declaration order.
IMMUTABLE_LABELS: dict[str, list[tuple[str, str]]] = {
    "TransparentUpgradeableProxy": [
        ("_admin", "address"),
    ],
    "AssetInterestRateStrategy": [
        ("HUB", "address"),
    ],
    "AaveOracle": [
        ("DECIMALS", "uint8"),
        ("DEPLOYER", "address"),
    ],
    "NativeTokenGateway": [
        ("NATIVE_TOKEN_WRAPPER", "address"),
    ],
    "SpokeInstance": [
        *EIP712_IMMUTABLES,
        ("MAX_USER_RESERVES_LIMIT", "uint16"),
        ("ORACLE", "address"),
    ],
    "TokenizationSpokeInstance": [
        *EIP712_IMMUTABLES,
        ("MAX_ALLOWED_SPOKE_CAP", "uint40"),
        ("HUB", "address"),
        ("ASSET_ID", "uint256"),
        ("ASSET", "address"),
        ("DECIMALS", "uint8"),
        ("ASSET_UNITS", "uint256"),
    ],
    "SignatureGateway": [*EIP712_IMMUTABLES],
    "TakerPositionManager": [*EIP712_IMMUTABLES],
    "ConfigPositionManager": [*EIP712_IMMUTABLES],
}


ARTIFACT_MAP: dict[str, ArtifactInfo] = {
    "AccessManager": ArtifactInfo("AccessManagerEnumerable.sol", "AccessManagerEnumerable"),
    "HubConfigurator": ArtifactInfo("HubConfigurator.sol", "HubConfigurator"),
    "SpokeConfigurator": ArtifactInfo("SpokeConfigurator.sol", "SpokeConfigurator"),
    "TreasurySpoke": ArtifactInfo(
        "TransparentUpgradeableProxy.sol", "TransparentUpgradeableProxy",
        impl_sol_file="TreasurySpokeInstance.sol",
        impl_contract_name="TreasurySpokeInstance",
    ),
    "Hub": ArtifactInfo(
        "TransparentUpgradeableProxy.sol", "TransparentUpgradeableProxy",
        impl_sol_file="HubInstance.sol",
        impl_contract_name="HubInstance",
    ),
    "InterestRateStrategy": ArtifactInfo(
        "AssetInterestRateStrategy.sol", "AssetInterestRateStrategy",
    ),
    "Spoke": ArtifactInfo(
        "TransparentUpgradeableProxy.sol", "TransparentUpgradeableProxy",
        impl_sol_file="SpokeInstance.sol",
        impl_contract_name="SpokeInstance",
    ),
    "AaveOracle": ArtifactInfo("AaveOracle.sol", "AaveOracle"),
    "SignatureGateway": ArtifactInfo("SignatureGateway.sol", "SignatureGateway"),
    "NativeTokenGateway": ArtifactInfo("NativeTokenGateway.sol", "NativeTokenGateway"),
    "GiverPositionManager": ArtifactInfo("GiverPositionManager.sol", "GiverPositionManager"),
    "TakerPositionManager": ArtifactInfo("TakerPositionManager.sol", "TakerPositionManager"),
    "ConfigPositionManager": ArtifactInfo("ConfigPositionManager.sol", "ConfigPositionManager"),
    "TokenizationSpoke": ArtifactInfo(
        "TransparentUpgradeableProxy.sol", "TransparentUpgradeableProxy",
        impl_sol_file="TokenizationSpokeInstance.sol",
        impl_contract_name="TokenizationSpokeInstance",
    ),
    "LiquidationLogic": ArtifactInfo("LiquidationLogic.sol", "LiquidationLogic"),
}


# ---------------------------------------------------------------------------
# Deploy report parsing
# ---------------------------------------------------------------------------

@dataclass
class HubInfo:
    label: str
    address: str
    ir_strategy: str


@dataclass
class SpokeInfo:
    label: str
    proxy: str
    oracle: str


@dataclass
class DeployReport:
    salt: str
    access_manager: str
    hub_configurator: str
    spoke_configurator: str
    treasury_spoke: str
    hubs: list[HubInfo] = field(default_factory=list)
    spokes: list[SpokeInfo] = field(default_factory=list)
    signature_gateway: Optional[str] = None
    native_token_gateway: Optional[str] = None
    giver_position_manager: Optional[str] = None
    taker_position_manager: Optional[str] = None
    config_position_manager: Optional[str] = None

    @classmethod
    def from_json(cls, data: dict) -> "DeployReport":
        hubs: list[HubInfo] = []
        hub_addrs = data.get("hub", {})
        ir_addrs = data.get("irStrategy", {})
        for key, addr in hub_addrs.items():
            hubs.append(HubInfo(label=key, address=addr, ir_strategy=ir_addrs[key]))

        spokes: list[SpokeInfo] = []
        spoke_addrs = data.get("spoke", {})
        oracle_addrs = data.get("oracle", {})
        for key, addr in spoke_addrs.items():
            spokes.append(SpokeInfo(label=key, proxy=addr, oracle=oracle_addrs[key]))

        return cls(
            salt=data.get("salt", ""),
            access_manager=data["accessManager"],
            hub_configurator=data["hubConfigurator"],
            spoke_configurator=data["spokeConfigurator"],
            treasury_spoke=data["treasurySpoke"],
            hubs=hubs,
            spokes=spokes,
            signature_gateway=data.get("signatureGateway"),
            native_token_gateway=data.get("nativeTokenGateway"),
            giver_position_manager=data.get("giverPositionManager"),
            taker_position_manager=data.get("takerPositionManager"),
            config_position_manager=data.get("configPositionManager"),
        )

    def all_addresses(self) -> list[tuple[str, str]]:
        pairs: list[tuple[str, str]] = [
            ("AccessManager", self.access_manager),
            ("HubConfigurator", self.hub_configurator),
            ("SpokeConfigurator", self.spoke_configurator),
            ("TreasurySpoke", self.treasury_spoke),
        ]
        for h in self.hubs:
            pairs.append((f"{h.label}/Hub", h.address))
            pairs.append((f"{h.label}/InterestRateStrategy", h.ir_strategy))
        for s in self.spokes:
            pairs.append((f"{s.label}/Spoke", s.proxy))
            pairs.append((f"{s.label}/AaveOracle", s.oracle))
        for name, addr in [
            ("SignatureGateway", self.signature_gateway),
            ("NativeTokenGateway", self.native_token_gateway),
            ("GiverPositionManager", self.giver_position_manager),
            ("TakerPositionManager", self.taker_position_manager),
            ("ConfigPositionManager", self.config_position_manager),
        ]:
            if addr:
                pairs.append((name, addr))
        return pairs


# ---------------------------------------------------------------------------
# Result tracking
# ---------------------------------------------------------------------------

class VerificationResult:
    def __init__(self) -> None:
        self.passed = 0
        self.failed = 0

    def ok(self, label: str, details: str = "") -> None:
        self.passed += 1
        suffix = f" ({details})" if details else ""
        print(f"  {GREEN}OK{RESET}  {label}{suffix}")

    def error(self, label: str, expected: Any, actual: Any) -> None:
        self.failed += 1
        print(f"  {RED}ERROR{RESET}  {label}")
        print(f"         expected: {expected}")
        print(f"         actual:   {actual}")

    def section(self, title: str) -> None:
        print(f"\n{BOLD}=== {title} ==={RESET}\n")

    def summary(self) -> int:
        total = self.passed + self.failed
        print(f"\n{BOLD}--- Summary ---{RESET}")
        print(f"  {GREEN}Passed:{RESET} {self.passed}/{total}")
        if self.failed:
            print(f"  {RED}Failed:{RESET} {self.failed}/{total}")
            return 1
        print("  All checks passed.")
        return 0


# ---------------------------------------------------------------------------
# Bytecode helpers
# ---------------------------------------------------------------------------

@lru_cache(maxsize=None)
def load_deployed_bytecode(
    sol_file: str, contract_name: str
) -> tuple[bytes, dict, list[dict]]:
    """Return (bytecode, immutable_refs, link_refs) from the Forge artifact."""
    path = ARTIFACTS_DIR / sol_file / f"{contract_name}.json"
    if not path.exists():
        sys.exit(f"Artifact not found: {path}\nRun `forge build` first.")
    with open(path) as f:
        artifact = json.load(f)
    deployed = artifact["deployedBytecode"]
    bytecode_hex = deployed["object"]
    if bytecode_hex.startswith("0x"):
        bytecode_hex = bytecode_hex[2:]

    bytecode_hex = re.sub(r"__\$[0-9a-fA-F]+\$__", "0" * 40, bytecode_hex)

    immutable_refs: dict[str, list[dict]] = {}
    for key, ranges in deployed.get("immutableReferences", {}).items():
        immutable_refs[key] = ranges

    link_refs: list[dict] = []
    for file_refs in deployed.get("linkReferences", {}).values():
        for _, ranges in file_refs.items():
            link_refs.extend(ranges)

    return bytes.fromhex(bytecode_hex), immutable_refs, link_refs


def link_artifact_bytecode(
    artifact_bytes: bytearray,
    onchain_bytes: bytes,
    link_refs: list[dict],
) -> bytearray:
    """Patch library placeholders in *artifact_bytes* with real addresses
    extracted from *onchain_bytes*."""
    if not link_refs:
        return artifact_bytes

    first = link_refs[0]
    address = onchain_bytes[first["start"]:first["start"] + first["length"]]

    for ref in link_refs[1:]:
        chunk = onchain_bytes[ref["start"]:ref["start"] + ref["length"]]
        if chunk != address:
            raise ValueError(
                f"Library address mismatch in on-chain bytecode: "
                f"offset {first['start']} has {address.hex()}, "
                f"offset {ref['start']} has {chunk.hex()}"
            )

    for ref in link_refs:
        start = ref["start"]
        length = ref["length"]
        artifact_bytes[start:start + length] = address

    return artifact_bytes


def mask_bytecode_ranges(bytecode: bytes, refs: dict) -> bytearray:
    masked = bytearray(bytecode)
    for ranges in refs.values():
        for ref in ranges:
            start = ref["start"]
            length = ref["length"]
            for i in range(start, start + length):
                if i < len(masked):
                    masked[i] = 0
    return masked


def _first_diff_offset(a: bytes | bytearray, b: bytes | bytearray) -> int:
    for i in range(min(len(a), len(b))):
        if a[i] != b[i]:
            return i
    return min(len(a), len(b))


# ---------------------------------------------------------------------------
# On-chain helpers
# ---------------------------------------------------------------------------

ERC1967_IMPL_SLOT = int(
    "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc", 16
)


def get_code(w3: Web3, address: str) -> bytes:
    return w3.eth.get_code(Web3.to_checksum_address(address))


def get_implementation(w3: Web3, proxy_address: str) -> str:
    raw = w3.eth.get_storage_at(
        Web3.to_checksum_address(proxy_address), ERC1967_IMPL_SLOT
    )
    return Web3.to_checksum_address("0x" + raw[-20:].hex())


def call_spoke_get_liquidation_logic(w3: Web3, spoke_address: str) -> str | None:
    spoke_abi = _load_spoke_abi()
    try:
        contract = w3.eth.contract(
            address=Web3.to_checksum_address(spoke_address), abi=spoke_abi
        )
        return contract.functions.getLiquidationLogic().call()
    except Exception as e:
        print(f"  {RED}CALL FAILED{RESET} getLiquidationLogic() on {spoke_address}: {e}")
        return None


def call_owner(w3: Web3, address: str) -> str | None:
    owner_abi = [{"inputs": [], "name": "owner", "outputs": [{"type": "address"}], "stateMutability": "view", "type": "function"}]
    try:
        contract = w3.eth.contract(
            address=Web3.to_checksum_address(address), abi=owner_abi
        )
        return Web3.to_checksum_address(contract.functions.owner().call())
    except Exception as e:
        print(f"  {RED}CALL FAILED{RESET} owner() on {address}: {e}")
        return None


@lru_cache(maxsize=1)
def _load_spoke_abi() -> list:
    path = ARTIFACTS_DIR / "ISpoke.sol" / "ISpoke.json"
    if not path.exists():
        sys.exit(f"Artifact not found: {path}\nRun `forge build` first.")
    with open(path) as f:
        return json.load(f)["abi"]


# ---------------------------------------------------------------------------
# Verification
# ---------------------------------------------------------------------------

def _verify_single_bytecode(
    w3: Web3,
    result: VerificationResult,
    label: str,
    address: str,
    sol_file: str,
    contract_name: str,
) -> None:
    expected_bytes, immutable_refs, link_refs = load_deployed_bytecode(
        sol_file, contract_name
    )
    onchain_code = get_code(w3, address)

    if not onchain_code or onchain_code in (b"", b"\x00"):
        result.error(label, "deployed bytecode", f"empty code at {address}")
        return

    if len(expected_bytes) != len(onchain_code):
        result.error(
            label,
            f"bytecode length {len(expected_bytes)}",
            f"bytecode length {len(onchain_code)} at {address}",
        )
        return

    expected = bytearray(expected_bytes)
    onchain = bytes(onchain_code)

    if link_refs:
        expected = link_artifact_bytecode(expected, onchain, link_refs)

    if immutable_refs:
        expected_cmp = mask_bytecode_ranges(bytes(expected), immutable_refs)
        onchain_cmp = mask_bytecode_ranges(onchain, immutable_refs)
        tag = "masked"
    else:
        expected_cmp = expected
        onchain_cmp = bytearray(onchain)
        tag = ""

    if expected_cmp == onchain_cmp:
        suffix = f"{address} ({tag})" if tag else address
        result.ok(label, suffix)
    else:
        offset = _first_diff_offset(expected_cmp, onchain_cmp)
        kind = f"matching bytecode ({tag})" if tag else "matching bytecode"
        result.error(
            label,
            kind,
            f"mismatch at byte offset {offset} at {address}",
        )


def _decode_immutable(raw: bytes, type_hint: str) -> str:
    """Decode a 32-byte immutable slot according to its Solidity type."""
    if type_hint == "address":
        return Web3.to_checksum_address("0x" + raw[-20:].hex())
    if type_hint == "bytes32":
        return "0x" + raw.hex()
    # uint types: big-endian integer
    return str(int.from_bytes(raw, "big"))


def _extract_immutables(
    onchain_code: bytes,
    immutable_refs: dict[str, list[dict]],
    contract_name: str,
) -> list[tuple[str, str, str]]:
    """Return [(name, type, decoded_value)] for each immutable in the contract."""
    labels = IMMUTABLE_LABELS.get(contract_name)
    sorted_ids = sorted(immutable_refs.keys(), key=lambda x: int(x))

    entries: list[tuple[str, str, str]] = []
    for i, ast_id in enumerate(sorted_ids):
        refs = immutable_refs[ast_id]
        first = refs[0]
        raw = onchain_code[first["start"]:first["start"] + first["length"]]

        if labels and i < len(labels):
            name, type_hint = labels[i]
        else:
            name, type_hint = f"immutable_{ast_id}", "bytes32"

        entries.append((name, type_hint, _decode_immutable(raw, type_hint)))
    return entries


def print_immutables(
    w3: Web3, report: DeployReport, result: VerificationResult
) -> None:
    result.section("Immutable Values")
    for name, addr in report.all_addresses():
        suffix = name.rsplit("/", 1)[-1]
        artifact = ARTIFACT_MAP.get(suffix)
        if artifact is None:
            continue

        for sol_file, contract_name, label_prefix in [
            (artifact.sol_file, artifact.contract_name, name),
            (artifact.impl_sol_file, artifact.impl_contract_name, f"{name}/Implementation"),
        ]:
            if sol_file is None:
                continue

            _, immutable_refs, _ = load_deployed_bytecode(sol_file, contract_name)
            if not immutable_refs:
                continue

            target_addr = addr
            if label_prefix.endswith("/Implementation"):
                target_addr = get_implementation(w3, addr)

            onchain_code = get_code(w3, target_addr)
            if not onchain_code or onchain_code in (b"", b"\x00"):
                continue

            entries = _extract_immutables(onchain_code, immutable_refs, contract_name)
            print(f"  {BOLD}{label_prefix}{RESET} ({target_addr})")
            for var_name, type_hint, value in entries:
                print(f"    {var_name} ({type_hint}): {value}")
                if var_name == "_admin" and type_hint == "address":
                    owner = call_owner(w3, value)
                    if owner:
                        print(f"      ProxyAdmin owner (address): {owner}")
            print()


def verify_liquidation_logic_libraries(
    w3: Web3, report: DeployReport, result: VerificationResult
) -> None:
    artifact = ARTIFACT_MAP["LiquidationLogic"]
    addresses: dict[str, str] = {}

    for spoke in report.spokes:
        lib_addr = call_spoke_get_liquidation_logic(w3, spoke.proxy)
        label = f"{spoke.label}/LiquidationLogic"

        if lib_addr is None or lib_addr == "0x" + "0" * 40:
            result.error(label, "non-zero library address", str(lib_addr))
            continue

        lib_addr = Web3.to_checksum_address(lib_addr)
        addresses[spoke.label] = lib_addr

        _verify_single_bytecode(
            w3, result, label, lib_addr,
            artifact.sol_file, artifact.contract_name,
        )

    unique_addrs = set(addresses.values())
    if len(unique_addrs) == 1:
        result.ok("LiquidationLogic/consistency", f"all spokes use {unique_addrs.pop()}")
    elif len(unique_addrs) > 1:
        details = ", ".join(f"{lbl}={addr}" for lbl, addr in addresses.items())
        result.error("LiquidationLogic/consistency", "same address across all spokes", details)


def verify_bytecode(
    w3: Web3, report: DeployReport, result: VerificationResult
) -> None:
    result.section("Bytecode Verification")
    for name, addr in report.all_addresses():
        suffix = name.rsplit("/", 1)[-1]
        artifact = ARTIFACT_MAP.get(suffix)
        if artifact is None:
            result.error(name, "known artifact mapping", f"no mapping for '{suffix}'")
            continue

        _verify_single_bytecode(
            w3, result, name, addr,
            artifact.sol_file, artifact.contract_name,
        )

        if artifact.impl_sol_file:
            impl_addr = get_implementation(w3, addr)
            _verify_single_bytecode(
                w3, result, f"{name}/Implementation", impl_addr,
                artifact.impl_sol_file, artifact.impl_contract_name,
            )

    verify_liquidation_logic_libraries(w3, report, result)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Verify bytecode of an Aave V4 deployment against local Forge artifacts."
    )
    parser.add_argument("--rpc-url", required=True, help="RPC endpoint URL")
    parser.add_argument(
        "--report", required=True, help="Path to deployment report JSON"
    )
    args = parser.parse_args()

    with open(args.report) as f:
        report = DeployReport.from_json(json.load(f))

    w3 = Web3(Web3.HTTPProvider(args.rpc_url))
    if not w3.is_connected():
        print(f"{RED}ERROR{RESET}: Cannot connect to {args.rpc_url}")
        sys.exit(1)

    print(f"Connected to chain {w3.eth.chain_id}")

    result = VerificationResult()
    verify_bytecode(w3, report, result)
    print_immutables(w3, report, result)
    sys.exit(result.summary())


if __name__ == "__main__":
    main()
