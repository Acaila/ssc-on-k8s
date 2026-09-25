#!/usr/bin/env python3
"""Write a bridge Endpoints manifest using an explicitly supplied, assigned IPv4 LB address."""
import argparse
import ipaddress
import json
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--environment', type=Path, required=True)
parser.add_argument('--address', type=ipaddress.IPv4Address, required=True)
args = parser.parse_args()
try:
    settings = json.loads((args.environment / 'settings.json').read_text())
    if settings['contour_mode'] != 'bridge':
        raise ValueError('This environment uses direct routing; no bridge Endpoints needed')
    manifest = {
        'apiVersion': 'v1', 'kind': 'Endpoints',
        'metadata': {'name': 'ssc-raas-contour', 'namespace': settings['namespace']},
        'subsets': [{'addresses': [{'ip': str(args.address)}],
                     'ports': [{'name': 'https', 'protocol': 'TCP', 'port': 443}]}]
    }
    target = args.environment / 'bootstrap/contour-endpoints.json'
    target.write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'Wrote {target}; review and apply with the workload context. Nothing was applied.')
except (OSError, ValueError, KeyError) as exc:
    parser.exit(2, f'Error: {exc}\n')
