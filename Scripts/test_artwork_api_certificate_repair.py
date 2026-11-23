import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import repair_artwork_api_certificates as repair


class CertificateRepairTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.project = self.root / 'project'
        self.bundle = self.root / 'bundle'
        self.bundle.mkdir()
        (self.project / 'Docs').mkdir(parents=True)
        (self.project / 'Scripts').mkdir()
        (self.project / '.artwork-api/pilot-medium').mkdir(parents=True)
        (self.project / 'Docs/ArtworkAPIPilot.json').write_text(json.dumps({'batchID': 'api-pilot-20261123'}))
        for name in repair.FILES:
            (self.project / 'Scripts' / name).write_text('old ' + name)
            (self.bundle / name).write_text('updated ' + name)
        self.state = self.project / '.artwork-api/pilot-medium/state.json'
        self.state.write_text('{"status":"needs_reconciliation"}')
        self.image = self.state.with_name('retained.png')
        self.image.write_bytes(b'unchanged original fixture')

    def test_repair_preserves_checkpoint_images_and_original_scripts(self):
        repair.update_scripts(self.project, self.bundle)
        self.assertEqual(self.state.read_text(), '{"status":"needs_reconciliation"}')
        self.assertEqual(self.image.read_bytes(), b'unchanged original fixture')
        backup = self.project / '.artwork-api/certificate-repair-backup'
        self.assertEqual(len(list(backup.iterdir())), 2)
        self.assertTrue(all(p.read_text().startswith('old ') for p in backup.iterdir()))
        repair.update_scripts(self.project, self.bundle)
        self.assertEqual(len(list(backup.iterdir())), 2)
        for name in repair.FILES:
            self.assertEqual((self.project / 'Scripts' / name).read_bytes(), (self.bundle / name).read_bytes())

    def test_wrong_folder_or_incomplete_bundle_cannot_partially_replace_scripts(self):
        with self.assertRaises(ValueError):
            repair.update_scripts(self.bundle, self.bundle)
        (self.bundle / repair.FILES[-1]).unlink()
        with self.assertRaises(OSError):
            repair.update_scripts(self.project, self.bundle)
        for name in repair.FILES:
            self.assertTrue((self.project / 'Scripts' / name).read_text().startswith('old '))

    def test_repair_only_installs_ca_bundle_and_probes_without_generation(self):
        python = self.project / '.artwork-api/venv/bin/python3'
        python.parent.mkdir(parents=True)
        python.touch()
        with patch.object(repair.subprocess, 'check_call') as install, patch.object(repair.subprocess, 'run') as probe:
            probe.return_value = subprocess.CompletedProcess([], 0, '{"ok":true,"httpStatus":401}', '')
            self.assertEqual(repair.repair(self.project, self.bundle), 0)
        args = install.call_args.args[0]
        self.assertIn('certifi>=2025.1', args)
        self.assertNotIn('--trusted-host', args)
        probe_args = probe.call_args.args[0]
        self.assertEqual(probe_args[-1], '--diagnose')
        self.assertNotIn('--execute', probe_args)
        self.assertEqual(self.state.read_text(), '{"status":"needs_reconciliation"}')


if __name__ == '__main__':
    unittest.main()
