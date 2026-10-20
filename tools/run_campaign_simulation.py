#!/usr/bin/env python3
"""Reproducible real-physics campaign batches; strict errors and retained raw evidence."""
from __future__ import annotations
import argparse
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import re
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
ERROR = re.compile(r'SCRIPT ERROR:|\bERROR:|Assertion failed|instances leaked|resources still in use')

def batch(engine: str, count: int, name: str, seed: int, destination: Path, hero: str, boss: str, ally: str = '') -> dict:
    output = destination / f'{name}.json'
    log = destination / f'{name}.log'
    command = [engine, '--headless', '--path', str(ROOT), '--fixed-fps', '60',
               '--log-file', str(destination / f'{name}.godot.log'),
               '--script', 'res://tools/campaign_simulation.gd', '--', str(count), str(output), str(seed), hero,boss,ally]
    started = time.monotonic()
    try:
        with log.open('w', encoding='utf-8') as stream:
            hidden = {'creationflags': subprocess.CREATE_NO_WINDOW} if os.name == 'nt' else {}
            result = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, timeout=3600, **hidden)
        text = log.read_text(encoding='utf-8', errors='replace')
        ok = result.returncode == 0 and not ERROR.search(text) and 'CAMPAIGN SIM PASS' in text
        report = json.loads(output.read_text(encoding='utf-8')) if ok else {}
        actual = len(report.get('trials', []))
        expected = int(report.get('requested_trials', 0))
        ok = bool(ok and actual == expected)
        summary = {'name': name, 'ok': ok, 'seed': seed, 'trials': actual,
                   'seconds': round(time.monotonic()-started, 3), 'report': str(output), 'log': str(log)}
    except (subprocess.TimeoutExpired, OSError, ValueError) as exc:
        summary = {'name': name, 'ok': False, 'error': str(exc), 'log': str(log)}
    print(json.dumps(summary), flush=True)
    return summary

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--per-pair', type=int, default=20)
    parser.add_argument('--batches', type=int, default=1)
    parser.add_argument('--seed', type=int, default=1800000)
    parser.add_argument('--name', default='validation')
    parser.add_argument('--hero', default='', help='Optional playable ID; default tests the entire data registry.')
    parser.add_argument('--boss', default='', help='Optional boss ID for a focused regression.')
    parser.add_argument('--ally', default='', help='Optional second playable hero; empty keeps solo scenarios.')
    parser.add_argument('--output', type=Path, default=ROOT/'builds/campaign-work/validation')
    args = parser.parse_args()
    if not 1 <= args.batches <= 4 or not 1 <= args.per_pair <= 10000 or not args.name.replace('-', '').isalnum():
        parser.error('Use 1..4 batches, 1..10000 scenarios per pair, and a simple report name.')
    destination = args.output.resolve()
    if not destination.is_relative_to(ROOT):
        parser.error('Keep experiment logs and reports inside the experimental worktree.')
    destination.mkdir(parents=True, exist_ok=True)
    jobs = [(f'{args.name}-{i+1}', args.seed+i*10000000) for i in range(args.batches)]
    print(f'Starting {args.batches} isolated Godot processes; {args.per_pair*args.batches} trials per hero/boss pair.', flush=True)
    with ThreadPoolExecutor(max_workers=args.batches) as pool:
        results = list(pool.map(lambda job: batch(args.godot, args.per_pair, job[0], job[1], destination,args.hero,args.boss,args.ally), jobs))
    (destination/'execution.json').write_text(json.dumps(results, indent=2)+'\n', encoding='utf-8')
    return 0 if all(result['ok'] for result in results) else 1

if __name__ == '__main__':
    raise SystemExit(main())
