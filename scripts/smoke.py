#!/usr/bin/env python3
"""Run the included image and video examples and verify their archives."""
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MEDIA = str(ROOT / 'scripts' / 'media')


def call(*args):
    proc = subprocess.run([MEDIA, *map(str, args)], text=True, capture_output=True)
    if proc.returncode:
        raise RuntimeError(proc.stderr.strip() or proc.stdout.strip())
    return json.loads(proc.stdout)


for name, graph in [('MOSS image', 'moss-image.json'), ('Pika H3 video', 'pika-text-to-video.json')]:
    workflow = ROOT / 'workflows' / graph
    print('Preparing ' + name, flush=True)
    prepared = call('submit', workflow, '--project', 'setup-check', '--title', name, '--prepare-only')
    details = call('show', prepared['run_id'])
    if details.get('gaps'):
        raise SystemExit(f"{name}: provenance gaps in {prepared['run_id']}: {details['gaps']}. Inspect before continuing.")
    print('Rendering ' + name, flush=True)
    result = call('submit', workflow, '--project', 'setup-check', '--title', name, '--wait')
    verified = call('verify', result['run_id'])
    if result.get('state') != 'succeeded' or not verified.get('ok') or not result.get('outputs'):
        raise SystemExit(f"{name} did not complete verification: {result['run_id']}")
    print(f"{name}: {result['run_id']}")
    for output in result['outputs']:
        print('  ' + output['path'])
