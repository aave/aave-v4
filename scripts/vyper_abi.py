"""Check production entry points against the Solidity ABI, including raw dispatch."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def signature(entry):
    def type_name(item):
        if item["type"].startswith("tuple"):
            return (
                "("
                + ",".join(type_name(x) for x in item["components"])
                + ")"
                + item["type"][5:]
            )
        return item["type"]

    return entry["name"] + "(" + ",".join(type_name(x) for x in entry["inputs"]) + ")"


def check_surface(source, artifact):
    manifest = json.loads((ROOT / "vyper/production-abi.json").read_text())["contracts"]
    if source.stem not in manifest or "harness" in source.parts:
        return
    specification = manifest[source.stem]
    # These implementations deliberately return standard ABI bytes via raw dispatch.
    # The compiler's Bytes return metadata does not describe their public wire format.
    for raw in specification["raw_abi"]:
        entry = raw["abi"]
        name = signature(entry)
        artifact["abi"] = [
            x
            for x in artifact["abi"]
            if x["type"] != "function" or signature(x) != name
        ]
        artifact["abi"].append(entry)
        artifact["methodIdentifiers"][name] = raw["selector"]
    actual = {signature(x) for x in artifact["abi"] if x["type"] == "function"}
    expected = set(specification["functions"])
    missing = expected - actual
    extra = actual - expected
    if extra or missing != set(specification["unimplemented"]):
        raise RuntimeError(
            f"{source.name}: production ABI drift: extra={sorted(extra)}, missing={sorted(missing)}"
        )
    artifact["metadata"]["knownUnimplementedMethods"] = specification["unimplemented"]
    # A fallback has no callable __default__() selector, even if included by the compiler.
    artifact["methodIdentifiers"].pop("__default__()", None)
