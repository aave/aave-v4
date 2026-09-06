#!/usr/bin/env python3
"""Compare uncached, serial production compilation via compiler standard JSON."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import resource
import statistics
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
OUTPUTS = ['abi', 'evm.bytecode.object', 'evm.deployedBytecode.object']


def solidity_jobs(names):
    paths = {p.stem: p for p in (ROOT / 'src').rglob('*.sol')
             if '/deployments/' not in str(p)}
    targets = {name: paths[name].relative_to(ROOT).as_posix() for name in names}
    for name in ['LiquidationLogic', 'TokenizationSpokeDeployer', 'HubEngine',
                 'SpokeEngine', 'AccessManagerEngine', 'PositionManagerEngine']:
        targets[name] = paths[name].relative_to(ROOT).as_posix()
    sources = {}

    def add(path):
        if path in sources:
            return
        assert path.startswith('src/'), path
        content = (ROOT / path).read_text()
        sources[path] = {'content': content}
        for imp in re.findall(r'import\s+(?:[^;]*?\sfrom\s*)?[\'"]([^\'"]+)[\'"]\s*;', content):
            child = (Path(path).parent / imp).as_posix() if imp.startswith('.') else imp
            add(os.path.normpath(child))

    for path in targets.values():
        add(path)
    jobs = []
    for label, via_ir, runs in [('default', False, 44444444), ('hub', True, 22300), ('spoke', True, 750)]:
        selected = {path: {name: OUTPUTS} for name, path in targets.items()
                    if ('hub' if name == 'HubInstance' else 'spoke' if name == 'SpokeInstance' else 'default') == label}
        jobs.append((label, {'language': 'Solidity', 'sources': sources, 'settings': {
            'evmVersion': 'cancun', 'optimizer': {'enabled': True, 'runs': runs},
            'viaIR': via_ir, 'metadata': {'bytecodeHash': 'none', 'appendCBOR': False},
            'outputSelection': selected}}))
    return jobs, targets


def vyper_job(names):
    paths = {p.stem: p for p in (ROOT / 'vyper/src').rglob('*.vy') if '/harness/' not in str(p)}
    targets = {n: paths[n].relative_to(ROOT / 'vyper/src').as_posix()
               for n in [*names, 'LiquidationLogicContract', 'TokenizationSpokeDeployer']}
    # Standard JSON carries imports as source inputs; only selected deployable roots
    # receive outputs. Harnesses and test-wrapper modules are deliberately excluded.
    sources = {p.relative_to(ROOT / 'vyper/src').as_posix(): {'content': p.read_text()}
               for p in (ROOT / 'vyper/src').rglob('*') if p.suffix in ('.vy', '.vyi')
               and '/harness/' not in str(p)
               and p.stem not in ('PositionManagerBaseWrapper', 'PositionManagerNoMulticall')}
    settings = {'evmVersion': 'cancun', 'optimize': 'O3', 'experimentalCodegen': True,
                'bytecodeMetadata': False, 'outputSelection': {p: OUTPUTS for p in targets.values()}}
    layouts = {}
    for n in ['HubInstance', 'TreasurySpokeInstance', 'TokenizationSpokeInstance']:
        filename = f'{n}.json'
        layouts[targets[n]] = {filename: json.loads((ROOT / 'vyper/storage-layouts' / filename).read_text())}
    return [('production', {'language': 'Vyper', 'sources': sources, 'settings': settings,
                            'storage_layout_overrides': layouts})], targets


def compile_one(binary, label, payload, directory):
    input_path = directory / f'{label}.input.json'
    output_path = directory / f'{label}.output.json'
    input_path.write_text(json.dumps(payload))
    before = resource.getrusage(resource.RUSAGE_CHILDREN)
    with input_path.open('rb') as inp, output_path.open('wb') as out:
        start = time.perf_counter()
        process = subprocess.run([str(binary), '--standard-json'], stdin=inp, stdout=out,
                                 stderr=subprocess.PIPE, cwd=ROOT,
                                 env={**os.environ, 'PYTHONHASHSEED': '0'})
        wall = time.perf_counter() - start
    after = resource.getrusage(resource.RUSAGE_CHILDREN)
    result = json.loads(output_path.read_text())
    errors = [e for e in result.get('errors', []) if e.get('severity') == 'error']
    if process.returncode or errors:
        raise RuntimeError(json.dumps(errors, indent=2) + process.stderr.decode())
    emitted = []
    for path, contracts in result.get('contracts', {}).items():
        for name, artifact in contracts.items():
            code = artifact.get('evm', {}).get('bytecode', {}).get('object', '')
            if code:
                emitted.append(f'{path}:{name}')
    if not emitted:
        raise RuntimeError(f'{label}: no creation bytecode emitted')
    expected_paths = set(payload['settings']['outputSelection'])
    if {entry.rsplit(':', 1)[0] for entry in emitted} != expected_paths:
        raise RuntimeError(f'{label}: emitted targets differ from requested scope')
    return {'wall_seconds': wall, 'cpu_seconds': after.ru_utime + after.ru_stime - before.ru_utime - before.ru_stime,
            'emitted': emitted}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--solc', type=Path, required=True)
    parser.add_argument('--vyper', type=Path, default=ROOT / '.venv/bin/vyper')
    parser.add_argument('--runs', type=int, default=3)
    parser.add_argument('--output', type=Path, default=ROOT / 'gas-snapshots/compilation-time/results.json')
    args = parser.parse_args()
    if args.runs < 1:
        parser.error('--runs must be positive')
    names = list(json.loads((ROOT / 'vyper/production-abi.json').read_text())['contracts'])
    sol_jobs, sol_targets = solidity_jobs(names)
    vy_jobs, vy_targets = vyper_job(names)
    binaries = {'solidity': args.solc.resolve(), 'vyper': args.vyper.resolve()}
    jobs = {'solidity': sol_jobs, 'vyper': vy_jobs}
    report = {'source_revision': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
              'machine': os.uname().machine, 'versions': {n: subprocess.check_output([str(p), '--version'], text=True).strip() for n, p in binaries.items()},
              'targets': {'solidity': sol_targets, 'vyper': vy_targets}, 'jobs': {}, 'runs': []}
    for language, group in jobs.items():
        report['jobs'][language] = [{'label': label, 'settings': data['settings'],
            'source_sha256': {p: hashlib.sha256(v['content'].encode()).hexdigest() for p, v in data['sources'].items()}}
            for label, data in group]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='aave-compile-benchmark-') as temp:
        for repetition in range(args.runs):
            # Reverse order on alternating rounds, never compile concurrently.
            for language in (['solidity', 'vyper'] if repetition % 2 == 0 else ['vyper', 'solidity']):
                stages = {}
                for label, data in jobs[language]:
                    stages[label] = compile_one(binaries[language], label, data, Path(temp))
                    print(f'{repetition + 1} {language} {label}: {stages[label]["wall_seconds"]:.3f}s', flush=True)
                report['runs'].append({'repetition': repetition + 1, 'language': language, 'stages': stages,
                    'wall_seconds': sum(s['wall_seconds'] for s in stages.values()),
                    'cpu_seconds': sum(s['cpu_seconds'] for s in stages.values())})
                args.output.write_text(json.dumps(report, indent=2) + '\n')
    report['summary'] = {n: {metric: statistics.median(r[metric] for r in report['runs'] if r['language'] == n)
                             for metric in ['wall_seconds', 'cpu_seconds']} for n in binaries}
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report['summary'], indent=2))


if __name__ == '__main__':
    main()
