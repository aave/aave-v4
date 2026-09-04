#!/usr/bin/env python3
"""Measure allocation cost of a small call with an unrelated bounded-array sibling."""

from pathlib import Path
import json, os, subprocess, tempfile, shutil

r = Path(__file__).resolve().parents[1]
t = Path(tempfile.mkdtemp(prefix="vyper-memory-diagnostic-"))
(t / "test").mkdir(exist_ok=True)
(t / "foundry.toml").write_text(
    '[profile.default]\nsrc = "src"\ntest = "test"\nsolc_version = "0.8.28"\nevm_version = "cancun"\noptimizer = true\n'
)
source = """# pragma version 0.5.0b2
BOUND: constant(uint256) = {bound}
@external
@pure
def echo(values: DynArray[Bytes[BOUND], 64]) -> DynArray[Bytes[BOUND], 64]:
    return values

@external
@pure
def length(data: Bytes[INF]) -> uint256:
    return len(data)
"""
code = """pragma solidity ^0.8.28;
interface ILength { function length(bytes calldata data) external view returns(uint256); }
contract MemoryAllocationTest {
 event log_named_uint(string key, uint256 val);
 function deploy(bytes memory code) private returns(address target) {
   assembly { target := create(0, add(code, 32), mload(code)) }
   require(target != address(0));
 }
"""
examples = r / "vyper/compiler-feedback/memory-allocation"
examples.mkdir(exist_ok=True)
for bound, label in [(32, "Small"), (32768, "Large")]:
    p = examples / f"{label}.vy"
    p.write_text(source.format(bound=bound))
    for opt in [2, 3]:
        b = (
            subprocess.check_output(
                [
                    str(r / ".venv/bin/vyper"),
                    "--evm-version",
                    "cancun",
                    "--experimental-codegen",
                    "--disable-bytecode-metadata",
                    "-O",
                    str(opt),
                    "-f",
                    "bytecode",
                    str(p),
                ],
                env={**os.environ, "PYTHONHASHSEED": "0"},
                text=True,
            )
            .strip()
            .removeprefix("0x")
        )
        code += f''' function test_{label}_O{opt}() public {{
   address target = deploy(hex"{b}");
   bytes memory data = hex"01020304";
   uint256 before = gasleft();
   uint256 result = ILength(target).length(data);
   uint256 used = before - gasleft();
   require(result == 4);
   emit log_named_uint("{label} O{opt} length(bytes4) call gas", used);
 }}\n'''
code += "}\n"
(t / "test/MemoryAllocation.t.sol").write_text(code)

result = subprocess.run(
    ["forge", "test", "--root", str(t), "-vv"], capture_output=True, text=True
)
output = r / "vyper/compiler-feedback/memory-allocation/results.txt"
output.write_text(result.stdout + result.stderr)
print(result.stdout)
shutil.rmtree(t)
raise SystemExit(result.returncode)
