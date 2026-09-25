"""Configuration contract and rendered manifest tests; no cluster access."""
import copy
import importlib.util
import json
import io
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

REPO = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('configure', REPO / 'scripts/configure-supervisor.py')
configure = importlib.util.module_from_spec(spec)
spec.loader.exec_module(configure)

class SupervisorConfigurationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        configure.ROOT = self.root
        self.config = json.loads((REPO / 'deployment/supervisor/settings.example.json').read_text())

    def test_direct_routes_without_deployment_controller(self):
        output = configure.generate(self.config)
        self.assertFalse((output / 'workloads/contour-backend.yaml').exists())
        proxy = (output / 'workloads/httpproxy.yaml').read_text()
        self.assertIn('name: "ssc-raas"', proxy)
        self.assertFalse((output / 'bootstrap/argocd.yaml').exists())
        self.assertFalse((output / 'bootstrap/certificate.yaml').exists())

    def test_managed_certificate_uses_requested_issuer_and_hostname(self):
        for kind in ('Issuer', 'ClusterIssuer'):
            self.config['environment'] = kind.lower()
            self.config['tls'] = {'mode': 'cert-manager', 'issuer_name': 'platform-ca', 'issuer_kind': kind}
            output = configure.generate(self.config)
            certificate = (output / 'bootstrap/certificate.yaml').read_text()
            self.assertIn('namespace: "my-ssc-namespace"', certificate)
            self.assertIn('secretName: ssc-web-tls', certificate)
            self.assertIn('- "ssc.example.com"', certificate)
            self.assertIn(f'kind: "{kind}"', certificate)
            self.assertIn('name: "platform-ca"', certificate)
            self.assertNotIn('${', certificate)

    def test_rejects_invalid_tls(self):
        for tls in ({'mode': 'unknown'}, {'mode': 'existing', 'issuer_name': 'ignored'},
                    {'mode': 'cert-manager'},
                    {'mode': 'cert-manager', 'issuer_name': 'a', 'issuer_kind': 'Bad'},
                    {'mode': 'cert-manager', 'issuer_name': '../bad', 'issuer_kind': 'Issuer'}):
            self.config['tls'] = tls
            with self.subTest(tls=tls), self.assertRaises(ValueError):
                configure.validate(self.config)

    def test_bridge_and_digest(self):
        self.config['contour_mode'] = 'bridge'
        self.config['images']['raas'] = 'registry.example.com:443/ssc/raas@sha256:' + 'a' * 64
        output = configure.generate(self.config)
        self.assertTrue((output / 'workloads/contour-backend.yaml').exists())
        self.assertIn('ssc-raas-contour', (output / 'workloads/httpproxy.yaml').read_text())
        content = (output / 'workloads/kustomization.yaml').read_text()
        self.assertIn('digest: "sha256:' + 'a' * 64 + '"', content)
        self.assertNotIn('8.18.3-release-1', content)

    def test_bridge_helper_requires_bridge_and_uses_selected_namespace(self):
        output = configure.generate(self.config)
        command = [sys.executable, str(REPO / 'scripts/contour-supervisor-backend.py'),
                   '--environment', str(output), '--address', '192.0.2.10']
        result = subprocess.run(command, text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.config['environment'] = 'bridge-test'; self.config['contour_mode'] = 'bridge'
        output = configure.generate(self.config)
        command[3] = str(output)
        subprocess.run(command, check=True, capture_output=True)
        endpoint = json.loads((output / 'bootstrap/contour-endpoints.json').read_text())
        self.assertEqual(endpoint['metadata']['namespace'], self.config['namespace'])
        self.assertEqual(endpoint['subsets'][0]['addresses'], [{'ip': '192.0.2.10'}])

    def test_preflight_checks_certificate_readiness_without_mutations(self):
        spec = importlib.util.spec_from_file_location('preflight', REPO / 'scripts/check-supervisor.py')
        preflight = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(preflight)
        for mode in ('existing', 'cert-manager'):
            self.config['environment'] = mode
            self.config['tls'] = {'mode': mode}
            if mode == 'cert-manager':
                self.config['tls'].update(issuer_name='ca', issuer_kind='ClusterIssuer')
            output = configure.generate(self.config)
            commands = []
            def run(command, **kwargs):
                commands.append(command)
                status = 1 if 'wait' in command else 0
                return subprocess.CompletedProcess(command, status, 'yes' if 'can-i' in command else '', '')
            with patch.object(sys, 'argv', ['check', '--environment', str(output), '--context', 'selected']), \
                 patch.object(subprocess, 'run', side_effect=run), patch('sys.stdout', new_callable=io.StringIO), \
                 patch('sys.stderr', new_callable=io.StringIO):
                self.assertEqual(preflight.main(), 1 if mode == 'cert-manager' else 0)
            self.assertEqual(any('wait' in cmd for cmd in commands), mode == 'cert-manager')
            for cmd in commands:
                self.assertNotIn('argocd', ' '.join(cmd))
                if 'apply' in cmd:
                    self.assertIn('--dry-run=server', cmd)
                if 'kustomize' not in cmd:
                    self.assertIn('selected', cmd)

    def test_refuses_overwrite(self):
        output = configure.generate(self.config)
        marker = output / 'operator-file'; marker.write_text('preserve')
        with self.assertRaises(ValueError):
            configure.generate(self.config)
        self.assertEqual(marker.read_text(), 'preserve')

    def test_rejects_invalid_and_credential_bearing_settings(self):
        for key, value in [('environment', '../escape'), ('namespace', 'Invalid'),
                           ('contour_mode', 'auto'), ('ssc_hostname', 'bad\nname'),
                           ('git_repository', 'https://user:secret@example.com/repo.git'),
                           ('argo_destination', 'https://user:secret@example.com')]:
            with self.subTest(key=key):
                config = copy.deepcopy(self.config); config[key] = value
                with self.assertRaises(ValueError):
                    configure.validate(config)
        for image in ['raas:latest', 'localhost/ssc/raas:1', 'registry.example.com/ssc/raas',
                      'registry.example.com/ssc/raas@sha256:bad']:
            with self.subTest(image=image), self.assertRaises(ValueError):
                configure.image_entry('raas', image)

    def test_quotes_arbitrary_scalar_values(self):
        self.config['master_id'] = 'master: # literal'
        output = configure.generate(self.config)
        self.assertIn('value: "master: # literal"', (output / 'workloads/kustomization.yaml').read_text())

    @unittest.skipUnless(os.environ.get('KUSTOMIZE_KUBECTL'), 'Set KUSTOMIZE_KUBECTL to run local Kustomize integration tests')
    def test_render_both_modes(self):
        for component in ('postgres', 'redis', 'raas', 'salt-master', 'storage'):
            shutil.copytree(REPO / component, self.root / component)
        for mode in ('direct', 'bridge'):
            with self.subTest(mode=mode):
                config = copy.deepcopy(self.config)
                config['environment'] = mode; config['contour_mode'] = mode
                output = configure.generate(config)
                rendered = subprocess.check_output([os.environ['KUSTOMIZE_KUBECTL'], 'kustomize', str(output / 'workloads')], text=True)
                self.assertEqual(rendered.count('kind: Deployment\n'), 4)
                self.assertEqual(rendered.count('kind: PersistentVolumeClaim\n'), 5)
                self.assertNotIn('namespace: aria-config', rendered)
                self.assertNotIn('imagePullPolicy: Never', rendered)
                self.assertNotIn('image: localhost/', rendered)
                self.assertNotIn('${', rendered)
                self.assertNotIn('argocd.argoproj.io', rendered)
                self.assertIn('targetPort: 8443', rendered)
                if mode == 'bridge':
                    bridge = next(doc for doc in rendered.split('---') if '\n  name: ssc-raas-contour\n' in doc)
                    self.assertNotIn('selector:', bridge)
                else:
                    self.assertNotIn('ssc-raas-contour', rendered)

if __name__ == '__main__':
    unittest.main()
