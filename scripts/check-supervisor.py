#!/usr/bin/env python3
"""Read-only prerequisite checks plus server-side dry-run; never sync or apply changes."""
import argparse
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--environment', type=Path, required=True, help='Generated environment directory')
    parser.add_argument('--context', required=True, help='Explicit workload kubectl context')
    args = parser.parse_args()
    try:
        settings = json.loads((args.environment / 'settings.json').read_text())
        failures = []
        def check(title, command, data=None, expected=None):
            result = subprocess.run(command, input=data, text=True, capture_output=True)
            good = result.returncode == 0 and (expected is None or result.stdout.strip() == expected)
            print(('PASS' if good else 'FAIL') + ': ' + title)
            if not good:
                failures.append(title)
                # Never print API Secret objects. Commands below only return names/status.
                print(result.stderr.strip() or result.stdout.strip(), file=sys.stderr)
            return result
        k = ['kubectl', '--context', args.context, '-n', settings['namespace']]
        check('workload API / namespace access', k + ['get', 'pods', '-o', 'name'])
        check('Contour HTTPProxy API / namespace access', k + ['get', 'httpproxies.projectcontour.io', '-o', 'name'])
        for kind in ('deployments.apps', 'services', 'persistentvolumeclaims', 'httpproxies.projectcontour.io'):
            check('create ' + kind, k + ['auth', 'can-i', 'create', kind], expected='yes')
        for secret in ('ssc-db', 'ssc-registry', 'ssc-web-tls'):
            check('required secret ' + secret, k + ['get', 'secret', secret, '-o', 'name'])
        if settings['tls']['mode'] == 'cert-manager':
            check('issued edge certificate Ready', k + ['wait', '--for=condition=Ready',
                  'certificate/ssc-web', '--timeout=5s'])
        rendered = check('Kustomize render', ['kubectl', 'kustomize', str(args.environment / 'workloads')])
        if rendered.returncode == 0:
            check('workload server admission dry-run', k + ['apply', '--dry-run=server', '-f', '-'], data=rendered.stdout)
        print('Still verify: namespace quota/storage capacity, native-pod admission and image pulls,')
        print('Envoy backend reachability, DNS, certificate hostname/expiry and client trust.')
        return 1 if failures else 0
    except (OSError, ValueError, KeyError) as exc:
        print(f'Error: {exc}', file=sys.stderr)
        return 2

if __name__ == '__main__':
    sys.exit(main())
