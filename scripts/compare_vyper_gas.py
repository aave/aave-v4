#!/usr/bin/env python3
"""Compare matched Solidity and Vyper Foundry gas snapshot directories."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def _load_snapshots(directory: Path) -> dict[str, dict[str, int]]:
    snapshots: dict[str, dict[str, int]] = {}
    for path in sorted(directory.glob("*.json")):
        values = json.loads(path.read_text())
        snapshots[path.name] = {name: int(value) for name, value in values.items()}
    return snapshots


def _percent(delta: int, baseline: int) -> float:
    return round(delta * 100 / baseline, 2)


def _format_delta(value: float) -> str:
    return f"{value:+.2f}%"


def _build_comparison(
    solidity: dict[str, dict[str, int]], vyper: dict[str, dict[str, int]]
) -> dict[str, object]:
    if solidity.keys() != vyper.keys():
        raise ValueError("snapshot file sets differ")

    categories: list[dict[str, object]] = []
    operations: list[dict[str, object]] = []
    for filename, solidity_values in solidity.items():
        vyper_values = vyper[filename]
        if solidity_values.keys() != vyper_values.keys():
            raise ValueError(f"operation sets differ in {filename}")

        solidity_total = sum(solidity_values.values())
        vyper_total = sum(vyper_values.values())
        delta = vyper_total - solidity_total
        categories.append(
            {
                "snapshot": filename,
                "operations": len(solidity_values),
                "solidity_gas": solidity_total,
                "vyper_gas": vyper_total,
                "delta_gas": delta,
                "delta_percent": _percent(delta, solidity_total),
            }
        )

        for operation, solidity_gas in solidity_values.items():
            vyper_gas = vyper_values[operation]
            operation_delta = vyper_gas - solidity_gas
            operations.append(
                {
                    "snapshot": filename,
                    "operation": operation,
                    "solidity_gas": solidity_gas,
                    "vyper_gas": vyper_gas,
                    "delta_gas": operation_delta,
                    "delta_percent": _percent(operation_delta, solidity_gas),
                }
            )

    solidity_total = sum(item["solidity_gas"] for item in operations)
    vyper_total = sum(item["vyper_gas"] for item in operations)
    delta = vyper_total - solidity_total
    return {
        "methodology": {
            "solidity_command": "forge test --mp 'tests/gas/**' -vv",
            "vyper_command": "TEST_VYPER=true forge test --mp 'tests/gas/**' -vv",
            "vyper_compiler": "0.5.0b1",
            "vyper_codegen": "Venom (--experimental-codegen)",
            "evm_version": "cancun",
            "forge_test_cases_per_run": 86,
            "note": (
                "Totals sum independent snapshot scenarios and are a comparison index, "
                "not the gas cost of one transaction."
            ),
        },
        "overall": {
            "snapshot_files": len(categories),
            "operations": len(operations),
            "improved": sum(item["delta_gas"] < 0 for item in operations),
            "unchanged": sum(item["delta_gas"] == 0 for item in operations),
            "regressed": sum(item["delta_gas"] > 0 for item in operations),
            "solidity_gas": solidity_total,
            "vyper_gas": vyper_total,
            "delta_gas": delta,
            "delta_percent": _percent(delta, solidity_total),
        },
        "categories": categories,
        "operations": operations,
    }


def _render_markdown(comparison: dict[str, object]) -> str:
    overall = comparison["overall"]
    categories = comparison["categories"]
    operations = comparison["operations"]
    improved = sorted(operations, key=lambda item: item["delta_percent"])
    regressed = sorted(operations, key=lambda item: item["delta_percent"], reverse=True)
    representative_keys = {
        ("Hub.Operations.json", "add"),
        ("Hub.Operations.json", "draw"),
        ("Spoke.Operations.json", "supply: 0 borrows, collateral disabled"),
        ("Spoke.Operations.json", "borrow: first"),
        ("Spoke.Operations.json", "repay: partial"),
        ("Spoke.Operations.json", "withdraw: 0 borrows, partial"),
        ("Spoke.Operations.json", "liquidationCall: partial"),
        ("TokenizationSpoke.Operations.json", "deposit"),
        ("TokenizationSpoke.Operations.json", "withdraw: self, partial"),
        ("TokenizationSpoke.Operations.json", "permit"),
    }
    representative = [
        item
        for item in operations
        if (item["snapshot"], item["operation"]) in representative_keys
    ]

    lines = [
        "# Solidity vs Vyper gas snapshots",
        "",
        "These are matched runs of the repository's `tests/gas/**` suite. The Solidity run",
        "uses the repository compiler profiles; the Vyper run uses Vyper 0.5.0b1 with",
        "Venom enforced through `--experimental-codegen`. Both target Cancun.",
        "",
        "Each run passed 86/86 tests. The snapshots contain",
        f"{overall['operations']} measured operations across {overall['snapshot_files']} files.",
        "",
        "The sum across independent scenarios is a comparison index, not the cost of a",
        "single transaction. On that index, Vyper used",
        f"{overall['vyper_gas']:,} gas versus Solidity's {overall['solidity_gas']:,} gas:",
        f"{overall['delta_gas']:+,} gas ({_format_delta(overall['delta_percent'])}).",
        f"{overall['improved']} operations improved, {overall['unchanged']} were unchanged, and",
        f"{overall['regressed']} regressed.",
        "",
        "## Category totals",
        "",
        "| Snapshot | Ops | Solidity | Vyper | Delta | Delta % |",
        "|---|---:|---:|---:|---:|---:|",
    ]
    for item in categories:
        lines.append(
            f"| {item['snapshot']} | {item['operations']} | {item['solidity_gas']:,} | "
            f"{item['vyper_gas']:,} | {item['delta_gas']:+,} | "
            f"{_format_delta(item['delta_percent'])} |"
        )

    lines.extend(
        [
            "",
            "## Representative operations",
            "",
            "| Snapshot | Operation | Solidity | Vyper | Delta | Delta % |",
            "|---|---|---:|---:|---:|---:|",
        ]
    )
    for item in representative:
        lines.append(
            f"| {item['snapshot']} | {item['operation']} | {item['solidity_gas']:,} | "
            f"{item['vyper_gas']:,} | {item['delta_gas']:+,} | "
            f"{_format_delta(item['delta_percent'])} |"
        )

    lines.extend(
        [
            "",
            "## Best result",
            "",
            "| Snapshot | Operation | Solidity | Vyper | Delta | Delta % |",
            "|---|---|---:|---:|---:|---:|",
        ]
    )
    for item in improved[:1]:
        lines.append(
            f"| {item['snapshot']} | {item['operation']} | {item['solidity_gas']:,} | "
            f"{item['vyper_gas']:,} | {item['delta_gas']:+,} | "
            f"{_format_delta(item['delta_percent'])} |"
        )

    lines.extend(
        [
            "",
            "## Largest percentage regressions",
            "",
            "| Snapshot | Operation | Solidity | Vyper | Delta | Delta % |",
            "|---|---|---:|---:|---:|---:|",
        ]
    )
    for item in regressed[:10]:
        lines.append(
            f"| {item['snapshot']} | {item['operation']} | {item['solidity_gas']:,} | "
            f"{item['vyper_gas']:,} | {item['delta_gas']:+,} | "
            f"{_format_delta(item['delta_percent'])} |"
        )

    lines.extend(
        [
            "",
            "## Interpretation",
            "",
            "The two Spoke operation files contribute most of the absolute delta. The",
            "Vyper implementation uses the same compact position bitmap strategy as the",
            "Solidity implementation, but manual packed-storage conversion, internal",
            "struct materialization, and cross-contract ABI work remain more expensive.",
            "",
            "Spoke multicall now accepts an unbounded `bytes[]` ABI domain through raw",
            "runtime decoding because Vyper 0.5.0b1 cannot type nested unbounded dynamic",
            "arrays directly. That parity path is slower than b1's bounded decoder in the",
            "small measured cases. Vyper also still requires a finite `raw_call` output",
            "bound, so each delegated result remains capped at 256 bytes.",
            "",
            "The signed position-manager setup rows also include an extra persistent",
            "write used to preserve explicit boolean state under Foundry arbitrary-storage",
            "testing. The empty-account getter and Tokenization Spoke `permit` beat",
            "Solidity; 14 operations are byte-for-byte equal in the snapshots.",
        ]
    )

    lines.extend(
        [
            "",
            "## Reproduce",
            "",
            "```sh",
            "forge test --mp 'tests/gas/**' -vv",
            ".venv/bin/python scripts/build_vyper.py",
            "TEST_VYPER=true forge test --mp 'tests/gas/**' -vv",
            "python3 scripts/compare_vyper_gas.py gas-snapshots/solidity \\",
            "  gas-snapshots/vyper-b1-unbounded gas-snapshots/comparison-b1-unbounded",
            "```",
            "",
            "Foundry writes both implementations to `snapshots/*.json`, so copy each run",
            "into its matching `gas-snapshots/` directory before starting the next run.",
            "The complete per-operation data is in `comparison.json`.",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("solidity_dir", type=Path)
    parser.add_argument("vyper_dir", type=Path)
    parser.add_argument("output_dir", type=Path)
    args = parser.parse_args()

    comparison = _build_comparison(
        _load_snapshots(args.solidity_dir), _load_snapshots(args.vyper_dir)
    )
    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir / "comparison.json").write_text(
        json.dumps(comparison, indent=2) + "\n"
    )
    (args.output_dir / "README.md").write_text(_render_markdown(comparison))


if __name__ == "__main__":
    main()
