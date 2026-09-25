#!/usr/bin/env python3
"""Generate a private, environment-specific Supervisor overlay; no network or mutations to a cluster."""
import argparse
import json
from pathlib import Path
import re
import shutil
import tempfile

ROOT = Path(__file__).resolve().parents[1]
TEMPLATES = ROOT / 'deployment/supervisor/templates'
FIELDS = {'environment', 'namespace', 'storage_class', 'ssc_hostname', 'salt_hostname',
          'master_id', 'images', 'contour_mode', 'tls'}
IMAGE_NAMES = {'raas': 'localhost/ssc-raas', 'master': 'localhost/ssc-salt-master',
               'postgres': 'docker.io/postgres', 'redis': 'docker.io/redis'}

def label(value):
    return bool(re.fullmatch(r'[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?', value))

def image_entry(name, reference):
    if not isinstance(reference, str) or re.search(r'\s|://', reference):
        raise ValueError(f'{name}: expected a registry image reference')
    if '@' in reference:
        repository, digest = reference.rsplit('@', 1)
        if not re.fullmatch(r'sha256:[a-f0-9]{64}', digest):
            raise ValueError(f'{name}: digest must be sha256 plus 64 lowercase hex characters')
        field, version = 'digest', digest
    else:
        repository, sep, version = reference.rpartition(':')
        if not sep or not re.fullmatch(r'[\w][\w.-]{0,127}', version, re.ASCII):
            raise ValueError(f'{name}: explicit tag or sha256 digest required')
        field = 'newTag'
    if not re.fullmatch(r'[a-z0-9.-]+(?::[0-9]+)?/[a-z0-9._/-]+', repository):
        raise ValueError(f'{name}: use a fully qualified registry/project/image reference')
    if repository.split('/')[0].split(':')[0] in ('localhost', '127.0.0.1'):
        raise ValueError(f'{name}: Supervisor cannot pull from a workstation localhost registry')
    return f'  - name: {IMAGE_NAMES[name]}\n    newName: {json.dumps(repository)}\n    {field}: {json.dumps(version)}\n'

def validate(config):
    if not isinstance(config, dict) or set(config) != FIELDS:
        raise ValueError(f'Configuration must contain exactly: {", ".join(sorted(FIELDS))}')
    for key in FIELDS - {'images', 'tls'}:
        if not isinstance(config[key], str) or not config[key] or any(ord(c) < 32 for c in config[key]):
            raise ValueError(f'{key}: expected a nonempty single-line string')
    for key in ('environment', 'namespace'):
        if not label(config[key]):
            raise ValueError(f'{key}: expected a DNS label (lowercase, at most 63 characters)')
    for key in ('ssc_hostname', 'salt_hostname'):
        if len(config[key]) > 253 or '.' not in config[key] or not all(map(label, config[key].split('.'))):
            raise ValueError(f'{key}: expected a fully qualified DNS name')
    if config['contour_mode'] not in ('direct', 'bridge'):
        raise ValueError('contour_mode must be direct or bridge')
    tls = config['tls']
    if not isinstance(tls, dict) or tls.get('mode') not in ('existing', 'cert-manager'):
        raise ValueError('tls.mode must be existing or cert-manager')
    expected = {'mode'} if tls['mode'] == 'existing' else {'mode', 'issuer_name', 'issuer_kind'}
    if set(tls) != expected:
        raise ValueError(f'tls must contain exactly: {", ".join(sorted(expected))}')
    if tls['mode'] == 'cert-manager':
        name = tls['issuer_name']
        if not isinstance(name, str) or len(name) > 253 or not all(map(label, name.split('.'))):
            raise ValueError('tls.issuer_name must be a Kubernetes DNS name')
        if tls['issuer_kind'] not in ('Issuer', 'ClusterIssuer'):
            raise ValueError('tls.issuer_kind must be Issuer or ClusterIssuer')
    if not isinstance(config['images'], dict) or set(config['images']) != set(IMAGE_NAMES):
        raise ValueError('images must contain raas, master, postgres and redis')
    for key, reference in config['images'].items():
        image_entry(key, reference)
    return config

def render(template, values):
    return re.sub(r'\$\{([a-z_]+)\}', lambda m: values[m[1]], template)

def generate(config):
    validate(config)
    output = ROOT / 'deployment/environments' / config['environment']
    if output.exists():
        raise ValueError(f'{output} already exists; edit it deliberately or choose a new environment name')
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = Path(tempfile.mkdtemp(prefix='.configure-', dir=output.parent))
    try:
        workloads = temporary / 'workloads'; workloads.mkdir()
        bootstrap = temporary / 'bootstrap'; bootstrap.mkdir()
        values = {key: json.dumps(value) for key, value in config.items() if key not in ('images', 'tls')}
        values['bridge_resource'] = '  - contour-backend.yaml\n' if config['contour_mode'] == 'bridge' else ''
        values['contour_service'] = json.dumps('ssc-raas-contour' if config['contour_mode'] == 'bridge' else 'ssc-raas')
        values['image_entries'] = ''.join(image_entry(key, config['images'][key]) for key in IMAGE_NAMES)
        for filename in ('kustomization.yaml', 'httpproxy.yaml'):
            (workloads / filename).write_text(render((TEMPLATES / (filename + '.tmpl')).read_text(), values))
        if config['contour_mode'] == 'bridge':
            shutil.copyfile(TEMPLATES / 'contour-backend.yaml', workloads / 'contour-backend.yaml')
        if config['tls']['mode'] == 'cert-manager':
            values.update({key: json.dumps(config['tls'][key]) for key in ('issuer_name', 'issuer_kind')})
            (bootstrap / 'certificate.yaml').write_text(render((TEMPLATES / 'certificate.yaml.tmpl').read_text(), values))
        shutil.copyfile(TEMPLATES / 'postgres-keepalives.sql', bootstrap / 'postgres-keepalives.sql')
        (temporary / 'settings.json').write_text(json.dumps(config, indent=2) + '\n')
        (temporary / 'README.md').write_text(
            '# Generated Supervisor environment\n\n'
            'This directory is ignored in the public template. Review its non-secret files, then\n'
            'optionally track them in your own deployment repository. Never add credentials here.\n\n'
            'Follow `deployment/supervisor/README.md` for certificates, secrets, preflight,\n'
            'direct deployment, DNS, database tuning and acceptance. No cluster changes have been made.\n'
        )
        temporary.rename(output)
    except Exception:
        shutil.rmtree(temporary)
        raise
    return output

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', type=Path, required=True, help='JSON copied from deployment/supervisor/settings.example.json')
    args = parser.parse_args()
    try:
        output = generate(json.loads(args.config.read_text()))
    except (ValueError, OSError, KeyError) as exc:
        parser.exit(2, f'Error: {exc}\n')
    print(f'Generated {output}\nReview the files, then follow deployment/supervisor/README.md. Nothing was applied.')

if __name__ == '__main__':
    main()
