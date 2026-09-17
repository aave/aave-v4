"""Compile isolated Foundry fixtures: compile.py VYPER OUT [OPTIMIZER] [--no-inline]."""
import json
import os
from pathlib import Path
import subprocess
import sys

compiler = sys.argv[1]
out = Path(sys.argv[2])
optimizer = sys.argv[3] if len(sys.argv) > 3 else '3'
for name in ('Forwarder', 'Bounded', 'Unbounded', 'Coupled'):
    path = Path(__file__).resolve().parent / f'{name}.vy'
    command = [compiler, '--experimental-codegen', '-O', optimizer,
               '--evm-version', 'cancun', '--disable-bytecode-metadata', '-f', 'combined_json', str(path)]
    if '--no-inline' in sys.argv: command.insert(1, '--disable-inlining')
    data = json.loads(subprocess.check_output(command, env={**os.environ, 'PYTHONHASHSEED':'0'}, text=True))
    contract = data[str(path)]
    artifact = {'abi':contract['abi'], 'bytecode':{'object':contract['bytecode']},
                'deployedBytecode':{'object':contract['bytecode_runtime']},
                'methodIdentifiers':contract['method_identifiers'], 'settings':contract['settings_dict']}
    directory = out / f'{name}.vy'
    directory.mkdir(parents=True, exist_ok=True)
    (directory / f'{name}.json').write_text(json.dumps(artifact, indent=2)+'\n')
    print(name, data['version'], optimizer, flush=True)
