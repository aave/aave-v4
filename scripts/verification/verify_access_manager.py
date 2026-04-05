#!/usr/bin/env python3
"""Reconstruct AccessManagerEnumerable roles from events and compare with on-chain getters.

Fetches all historical events from the AccessManagerEnumerable contract, replays
them to reconstruct role state, then cross-validates against the contract's
enumerable getter functions.
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path

from web3 import Web3

ARTIFACTS_DIR = Path(__file__).resolve().parent.parent.parent / "out"

DEFAULT_ADDRESS = "0x08aE3BE30958cDd1847ec58fFfd4C451a87fDF01"
ADMIN_ROLE = 0
PUBLIC_ROLE = (1 << 64) - 1  # type(uint64).max

CHUNK_SIZE = 10_000  # blocks per getLogs request

# Terminal colors
GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[93m"
BOLD = "\033[1m"
RESET = "\033[0m"


def _canonical_type(param: dict) -> str:
    """Resolve an ABI parameter to its canonical type, expanding tuples recursively."""
    t = param["type"]
    if t == "tuple" or t.startswith("tuple["):
        components = param.get("components", [])
        inner = ",".join(_canonical_type(c) for c in components)
        # Preserve array suffix if present, e.g. "tuple[]" -> "(uint256,address)[]"
        suffix = t[5:]  # everything after "tuple"
        return f"({inner}){suffix}"
    return t


def build_selector_map() -> dict[str, str]:
    """Scan all ABI artifacts and build a selector -> function signature map."""
    selector_map: dict[str, str] = {}
    for abi_file in ARTIFACTS_DIR.rglob("*.json"):
        try:
            with open(abi_file) as f:
                data = json.load(f)
            abi = data.get("abi")
            if not abi:
                continue
            for item in abi:
                if item.get("type") != "function":
                    continue
                name = item["name"]
                input_types = ",".join(_canonical_type(inp) for inp in item.get("inputs", []))
                sig = f"{name}({input_types})"
                selector = Web3.keccak(text=sig)[:4].hex()
                selector_hex = "0x" + selector
                selector_map[selector_hex] = sig
        except (json.JSONDecodeError, KeyError):
            continue
    return selector_map


def load_abi(sol_file: str, contract_name: str) -> list:
    path = ARTIFACTS_DIR / sol_file / f"{contract_name}.json"
    if not path.exists():
        sys.exit(f"Artifact not found: {path}\nRun `forge build` first.")
    with open(path) as f:
        return json.load(f)["abi"]


# ---------------------------------------------------------------------------
# Reconstructed state from events
# ---------------------------------------------------------------------------

@dataclass
class ReconstructedState:
    role_members: dict[int, set[str]] = field(default_factory=lambda: defaultdict(set))
    role_labels: dict[int, str] = field(default_factory=dict)
    role_admin: dict[int, int] = field(default_factory=dict)
    role_guardian: dict[int, int] = field(default_factory=dict)
    # (target, selector_hex) -> roleId
    target_selector_role: dict[tuple[str, str], int] = field(default_factory=dict)

    @property
    def custom_roles(self) -> set[int]:
        """All role IDs seen, excluding ADMIN_ROLE and PUBLIC_ROLE."""
        all_ids: set[int] = set()
        all_ids.update(self.role_members.keys())
        all_ids.update(self.role_labels.keys())
        all_ids.update(self.role_admin.keys())
        all_ids.update(self.role_guardian.keys())
        for (_, _), rid in self.target_selector_role.items():
            all_ids.add(rid)
        all_ids.discard(ADMIN_ROLE)
        all_ids.discard(PUBLIC_ROLE)
        return all_ids

    @property
    def role_targets(self) -> dict[int, dict[str, set[str]]]:
        """roleId -> {target_addr -> {selector_hex, ...}}"""
        result: dict[int, dict[str, set[str]]] = defaultdict(lambda: defaultdict(set))
        for (target, sel), rid in self.target_selector_role.items():
            result[rid][target].add(sel)
        return dict(result)

    @property
    def admin_roles(self) -> set[int]:
        """All admin role IDs (excluding ADMIN_ROLE itself)."""
        admins: set[int] = set()
        for rid, admin in self.role_admin.items():
            if admin != ADMIN_ROLE:
                admins.add(admin)
        return admins

    def roles_of_admin(self, admin_role_id: int) -> set[int]:
        """Roles managed by a given admin role."""
        return {rid for rid, admin in self.role_admin.items() if admin == admin_role_id}


# ---------------------------------------------------------------------------
# Event fetching
# ---------------------------------------------------------------------------

def fetch_all_events(w3: Web3, contract, from_block: int) -> list:
    """Fetch all contract events in chunked block ranges, sorted chronologically."""
    latest = w3.eth.block_number
    all_logs = []

    event_names = [
        "RoleLabel",
        "RoleGranted",
        "RoleRevoked",
        "RoleAdminChanged",
        "RoleGuardianChanged",
        "TargetFunctionRoleUpdated",
    ]

    for event_name in event_names:
        event = getattr(contract.events, event_name)
        start = from_block
        print(f"  Fetching {event_name} events...", end="", flush=True)
        count = 0
        while start <= latest:
            end = min(start + CHUNK_SIZE - 1, latest)
            try:
                logs = event.get_logs(from_block=start, to_block=end)
                all_logs.extend(logs)
                count += len(logs)
            except Exception as e:
                print(f"\n    {RED}Error fetching {event_name} blocks {start}-{end}: {e}{RESET}")
            start = end + 1
        print(f" {count} events")

    # Sort by (blockNumber, logIndex)
    all_logs.sort(key=lambda l: (l.blockNumber, l.logIndex))
    return all_logs


# ---------------------------------------------------------------------------
# Replay events to build state
# ---------------------------------------------------------------------------

def replay_events(logs: list) -> ReconstructedState:
    """Process events chronologically and build reconstructed state."""
    state = ReconstructedState()

    for log in logs:
        name = log.event

        if name == "RoleGranted":
            role_id = log.args.roleId
            account = Web3.to_checksum_address(log.args.account)
            new_member = log.args.newMember
            if new_member:
                state.role_members[role_id].add(account)

        elif name == "RoleRevoked":
            role_id = log.args.roleId
            account = Web3.to_checksum_address(log.args.account)
            state.role_members[role_id].discard(account)

        elif name == "RoleLabel":
            role_id = log.args.roleId
            label = log.args.label
            state.role_labels[role_id] = label

        elif name == "RoleAdminChanged":
            role_id = log.args.roleId
            admin = log.args.admin
            state.role_admin[role_id] = admin

        elif name == "RoleGuardianChanged":
            role_id = log.args.roleId
            guardian = log.args.guardian
            state.role_guardian[role_id] = guardian

        elif name == "TargetFunctionRoleUpdated":
            target = Web3.to_checksum_address(log.args.target)
            selector = log.args.selector.hex() if isinstance(log.args.selector, bytes) else log.args.selector
            # Normalize to 0x-prefixed 8-char hex
            if not selector.startswith("0x"):
                selector = "0x" + selector
            role_id = log.args.roleId
            state.target_selector_role[(target, selector)] = role_id

    return state


# ---------------------------------------------------------------------------
# On-chain getter queries
# ---------------------------------------------------------------------------

@dataclass
class OnChainState:
    roles: list[int] = field(default_factory=list)
    role_members: dict[int, list[str]] = field(default_factory=dict)
    role_labels: dict[int, str] = field(default_factory=dict)
    role_admin: dict[int, int] = field(default_factory=dict)
    role_guardian: dict[int, int] = field(default_factory=dict)
    role_targets: dict[int, dict[str, list[str]]] = field(default_factory=dict)
    admin_roles: list[int] = field(default_factory=list)
    admin_role_to_roles: dict[int, list[int]] = field(default_factory=dict)
    labels: list[str] = field(default_factory=list)
    admin_members: list[str] = field(default_factory=list)


def call(contract, fn_name: str, *args):
    try:
        return contract.functions[fn_name](*args).call()
    except Exception as e:
        print(f"  {RED}CALL FAILED{RESET} {fn_name}({', '.join(str(a) for a in args)}): {e}")
        return None


def query_on_chain(contract, admin_candidates: set[str]) -> OnChainState:
    """Query all enumerable getters to build on-chain state."""
    oc = OnChainState()

    # Roles
    role_count = call(contract, "getRoleCount")
    if role_count and role_count > 0:
        oc.roles = list(call(contract, "getRoles", 0, role_count))
    print(f"  Roles: {len(oc.roles)}")

    # Per-role data
    all_role_ids = list(oc.roles) + [ADMIN_ROLE]
    for role_id in all_role_ids:
        # Members
        member_count = call(contract, "getRoleMemberCount", role_id)
        if member_count and member_count > 0:
            members = call(contract, "getRoleMembers", role_id, 0, member_count)
            oc.role_members[role_id] = [Web3.to_checksum_address(m) for m in members]
        else:
            oc.role_members[role_id] = []

        # Label (only for custom roles)
        if role_id not in (ADMIN_ROLE, PUBLIC_ROLE):
            is_labeled = call(contract, "isRoleLabeled", role_id)
            if is_labeled:
                label = call(contract, "getLabelOfRole", role_id)
                if label is not None:
                    oc.role_labels[role_id] = label

        # Admin & Guardian
        admin = call(contract, "getRoleAdmin", role_id)
        if admin is not None:
            oc.role_admin[role_id] = admin
        guardian = call(contract, "getRoleGuardian", role_id)
        if guardian is not None:
            oc.role_guardian[role_id] = guardian

        # Targets & selectors (only for custom roles — ADMIN_ROLE excluded from enumerable)
        if role_id not in (ADMIN_ROLE, PUBLIC_ROLE):
            target_count = call(contract, "getRoleTargetCount", role_id)
            if target_count and target_count > 0:
                targets = call(contract, "getRoleTargets", role_id, 0, target_count)
                oc.role_targets[role_id] = {}
                for t in targets:
                    t = Web3.to_checksum_address(t)
                    sel_count = call(contract, "getRoleTargetSelectorCount", role_id, t)
                    if sel_count and sel_count > 0:
                        sels = call(contract, "getRoleTargetSelectors", role_id, t, 0, sel_count)
                        oc.role_targets[role_id][t] = [
                            s.hex() if isinstance(s, bytes) else s for s in sels
                        ]
                    else:
                        oc.role_targets[role_id][t] = []

    # Admin roles
    admin_role_count = call(contract, "getAdminRoleCount")
    if admin_role_count and admin_role_count > 0:
        oc.admin_roles = list(call(contract, "getAdminRoles", 0, admin_role_count))
    print(f"  Admin roles: {len(oc.admin_roles)}")

    # Roles managed by each admin role
    for admin_id in oc.admin_roles:
        count = call(contract, "getRoleOfAdminRoleCount", admin_id)
        if count and count > 0:
            oc.admin_role_to_roles[admin_id] = list(
                call(contract, "getRolesOfAdminRole", admin_id, 0, count)
            )

    # Labels
    label_count = call(contract, "getRoleLabelCount")
    if label_count and label_count > 0:
        oc.labels = list(call(contract, "getRoleLabels", 0, label_count))
    print(f"  Labels: {len(oc.labels)}")

    return oc


# ---------------------------------------------------------------------------
# Comparison
# ---------------------------------------------------------------------------

def normalize_selector(s) -> str:
    """Ensure selector is a 0x-prefixed 8-char lowercase hex string."""
    if isinstance(s, bytes):
        s = s.hex()
    s = s.lower()
    if not s.startswith("0x"):
        s = "0x" + s
    return s


def compare_states(recon: ReconstructedState, oc: OnChainState) -> int:
    """Compare reconstructed vs on-chain state. Returns number of mismatches."""
    mismatches = 0

    def check(label: str, expected, actual) -> bool:
        nonlocal mismatches
        if expected == actual:
            print(f"  {GREEN}\u2713{RESET} {label}")
            return True
        else:
            print(f"  {RED}\u2717{RESET} {label}")
            print(f"    Expected (events): {expected}")
            print(f"    Actual  (getters): {actual}")
            mismatches += 1
            return False

    # 1. Roles list
    print(f"\n{BOLD}=== Roles ==={RESET}")
    recon_roles = sorted(recon.custom_roles)
    onchain_roles = sorted(oc.roles)
    check("Role list", recon_roles, onchain_roles)

    # 2. Per-role comparison
    all_role_ids = sorted(set(recon_roles) | set(onchain_roles))
    for role_id in all_role_ids:
        label_str = recon.role_labels.get(role_id, oc.role_labels.get(role_id, f"role#{role_id}"))
        print(f"\n{BOLD}--- Role {role_id} ({label_str}) ---{RESET}")

        # Members
        recon_members = sorted(recon.role_members.get(role_id, set()))
        onchain_members = sorted(oc.role_members.get(role_id, []))
        check("Members", recon_members, onchain_members)

        # Label
        recon_label = recon.role_labels.get(role_id)
        onchain_label = oc.role_labels.get(role_id)
        check("Label", recon_label, onchain_label)

        # Admin
        recon_admin = recon.role_admin.get(role_id, ADMIN_ROLE)
        onchain_admin = oc.role_admin.get(role_id)
        if onchain_admin is not None:
            check("Admin role", recon_admin, onchain_admin)

        # Guardian
        recon_guardian = recon.role_guardian.get(role_id, ADMIN_ROLE)
        onchain_guardian = oc.role_guardian.get(role_id)
        if onchain_guardian is not None:
            check("Guardian role", recon_guardian, onchain_guardian)

        # Targets & selectors
        recon_targets = recon.role_targets.get(role_id, {})
        onchain_targets = oc.role_targets.get(role_id, {})

        recon_target_addrs = sorted(recon_targets.keys())
        onchain_target_addrs = sorted(onchain_targets.keys())
        check("Target contracts", recon_target_addrs, onchain_target_addrs)

        for target in sorted(set(recon_target_addrs) | set(onchain_target_addrs)):
            recon_sels = sorted(normalize_selector(s) for s in recon_targets.get(target, set()))
            onchain_sels = sorted(normalize_selector(s) for s in onchain_targets.get(target, []))
            check(f"  Selectors on {target}", recon_sels, onchain_sels)

    # 3. ADMIN_ROLE members
    print(f"\n{BOLD}--- ADMIN_ROLE (0) members ---{RESET}")
    recon_admin_members = sorted(recon.role_members.get(ADMIN_ROLE, set()))
    onchain_admin_members = sorted(oc.role_members.get(ADMIN_ROLE, []))
    check("ADMIN_ROLE members", recon_admin_members, onchain_admin_members)

    # 4. Admin roles enumeration
    print(f"\n{BOLD}=== Admin Roles ==={RESET}")
    recon_admin_roles = sorted(recon.admin_roles)
    onchain_admin_roles = sorted(oc.admin_roles)
    check("Admin roles list", recon_admin_roles, onchain_admin_roles)

    for admin_id in sorted(set(recon_admin_roles) | set(onchain_admin_roles)):
        recon_managed = sorted(recon.roles_of_admin(admin_id))
        onchain_managed = sorted(oc.admin_role_to_roles.get(admin_id, []))
        check(f"Roles managed by admin {admin_id}", recon_managed, onchain_managed)

    # 5. Labels
    print(f"\n{BOLD}=== Labels ==={RESET}")
    recon_labels = sorted(recon.role_labels.values())
    onchain_labels = sorted(oc.labels)
    check("Labels list", recon_labels, onchain_labels)

    return mismatches


# ---------------------------------------------------------------------------
# Summary table
# ---------------------------------------------------------------------------

def print_roles(recon: ReconstructedState, selector_map: dict[str, str]):
    """Print detailed per-role information from reconstructed event data."""
    separator = "=" * 80
    role_targets = recon.role_targets

    def label_for(role_id: int) -> str:
        if role_id == ADMIN_ROLE:
            return "ADMIN_ROLE"
        if role_id == PUBLIC_ROLE:
            return "PUBLIC_ROLE"
        return recon.role_labels.get(role_id, f"role#{role_id}")

    def print_role(role_id: int):
        label = label_for(role_id)
        print(f"\n{BOLD}{separator}")
        print(f"ROLE {role_id} — {label}")
        print(f"{separator}{RESET}")

        # Admin
        if role_id == ADMIN_ROLE:
            print(f"  Admin: (locked)")
        else:
            admin_id = recon.role_admin.get(role_id, ADMIN_ROLE)
            admin_label = label_for(admin_id)
            print(f"  Admin: {admin_id} ({admin_label})")

        # Members
        members = sorted(recon.role_members.get(role_id, set()))
        print(f"  Members ({len(members)}):")
        if members:
            for m in members:
                print(f"    - {m}")
        else:
            print(f"    (none)")

        # Selectors by target
        targets = role_targets.get(role_id, {})
        if targets:
            print(f"  Selectors:")
            for target in sorted(targets.keys()):
                sels = sorted(normalize_selector(s) for s in targets[target])
                print(f"    Target {target}:")
                for s in sels:
                    sig = selector_map.get(s, s)
                    print(f"      - {sig}")
        else:
            print(f"  Selectors: (none)")

    # ADMIN_ROLE first
    print_role(ADMIN_ROLE)

    # Custom roles sorted by ID
    for role_id in sorted(recon.custom_roles):
        print_role(role_id)

    print()


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Verify AccessManagerEnumerable by comparing event reconstruction with getters."
    )
    parser.add_argument("--rpc-url", required=True, help="Ethereum RPC endpoint URL")
    parser.add_argument(
        "--address", default=DEFAULT_ADDRESS,
        help=f"AccessManagerEnumerable address (default: {DEFAULT_ADDRESS})",
    )
    parser.add_argument(
        "--from-block", type=int, default=0,
        help="Starting block for event fetching (default: 0 = contract deploy block via binary search)",
    )
    args = parser.parse_args()

    w3 = Web3(Web3.HTTPProvider(args.rpc_url))
    if not w3.is_connected():
        print(f"{RED}ERROR{RESET}: Cannot connect to {args.rpc_url}")
        sys.exit(1)
    print(f"Connected to chain {w3.eth.chain_id}")

    address = Web3.to_checksum_address(args.address)
    abi = load_abi("IAccessManagerEnumerable.sol", "IAccessManagerEnumerable")
    contract = w3.eth.contract(address=address, abi=abi)

    # Determine starting block
    from_block = args.from_block
    if from_block == 0:
        from_block = find_deploy_block(w3, address)
        print(f"Deploy block (approx): {from_block}")

    # Phase 1: Fetch events
    print(f"\n{BOLD}Phase 1: Fetching events from block {from_block}...{RESET}")
    logs = fetch_all_events(w3, contract, from_block)
    print(f"Total events: {len(logs)}")

    # Phase 2: Reconstruct state
    print(f"\n{BOLD}Phase 2: Reconstructing state from events...{RESET}")
    recon = replay_events(logs)
    print(f"  Custom roles found: {len(recon.custom_roles)}")
    print(f"  Labels found: {len(recon.role_labels)}")
    print(f"  ADMIN_ROLE members: {len(recon.role_members.get(ADMIN_ROLE, set()))}")

    # Phase 3: Query on-chain getters
    print(f"\n{BOLD}Phase 3: Querying on-chain getters...{RESET}")
    admin_candidates = recon.role_members.get(ADMIN_ROLE, set())
    oc = query_on_chain(contract, admin_candidates)

    # Phase 4: Compare
    print(f"\n{BOLD}Phase 4: Comparing reconstructed vs on-chain state...{RESET}")
    mismatches = compare_states(recon, oc)

    # Detailed role display
    selector_map = build_selector_map()
    print_roles(recon, selector_map)

    if mismatches == 0:
        print(f"{GREEN}{BOLD}All checks passed — event reconstruction matches on-chain getters.{RESET}")
    else:
        print(f"{RED}{BOLD}{mismatches} mismatch(es) found.{RESET}")
        sys.exit(1)


def find_deploy_block(w3: Web3, address: str) -> int:
    """Binary search for the block where the contract was deployed."""
    lo, hi = 0, w3.eth.block_number
    while lo < hi:
        mid = (lo + hi) // 2
        code = w3.eth.get_code(Web3.to_checksum_address(address), block_identifier=mid)
        if len(code) > 0:
            hi = mid
        else:
            lo = mid + 1
    return lo


if __name__ == "__main__":
    main()
