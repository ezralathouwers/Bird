import base64
import io
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from PIL import Image
import artwork_api_pilot as api
import artwork_api_repairs as repairs
import artwork_followup_20261126 as followup


class FollowupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.project = Path(self.temp.name) / 'app'
        self.output = Path(self.temp.name) / 'output'
        self.res = self.project / 'BirdingCompanion/Resources'
        (self.res / 'Assets.xcassets').mkdir(parents=True)
        shutil.copy2(api.ROOT / 'BirdingCompanion/Resources/WorldSpeciesCatalog.json', self.res / 'WorldSpeciesCatalog.json')
        self.spec = repairs.read(followup.SPEC)
        manifest = []
        for t in self.spec['targets']:
            if t['operation'] == 'create': continue
            asset = t['id'].replace(':', '-') + '-' + t['role']
            folder = self.res / 'Assets.xcassets' / (asset + '.imageset'); folder.mkdir()
            image = Image.new('RGBA', (1024, 1536)); image.putpixel((400, 400), (50, 30, 20, 255)); image.save(folder / 'old.png')
            api.write_json(folder / 'Contents.json', dict(images=[dict(filename='old.png')]))
            manifest.append(dict(asset=asset, speciesID=t['id'], view=t['role'], sha256=repairs.digest(folder / 'old.png'), version=3))
        api.write_json(self.res / 'ArtworkManifest.json', manifest)
        for relative in self.spec['referenceAssets'].values():
            path = self.project / relative; path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(api.ROOT / relative, path)
        self.calls = 0

    def sender(self, blob, key):
        self.calls += 1
        data = json.loads(blob)
        image = Image.new('RGBA', tuple(map(int, data['size'].split('x'))))
        image.putpixel((500, 500), (20, 30, 40, 255))
        buffer = io.BytesIO(); image.save(buffer, 'PNG')
        return dict(data=[dict(b64_json=base64.b64encode(buffer.getvalue()).decode())], usage=dict(input_tokens_details=dict(text_tokens=100, image_tokens=200), output_tokens=300)), 'synthetic-request'

    def generate(self):
        self.plan = followup.prepare(self.project, self.output)
        self.jobs = repairs.repair_jobs(self.plan, self.project)
        return api.run(self.plan, self.jobs, self.output, 'fake', 15, 2, sender=self.sender)

    def test_exact_scope_local_snapshot_and_resume(self):
        self.generate()
        self.assertEqual(len(self.jobs), 15)
        self.assertEqual(sum(t['operation'] == 'create' for t in self.plan['targets']), 4)
        self.assertEqual(len(list((self.output / 'originals').glob('*.png'))), 11)
        frozen = (self.output / 'plan.json').read_bytes()
        self.generate()
        self.assertEqual(self.calls, 15)
        self.assertEqual((self.output / 'plan.json').read_bytes(), frozen)
        self.assertTrue(all('small lower-throat' in j['prompt'] for j in self.jobs if j['id'] == 'birdnet-v3:BN04396'))

    def test_mixed_replacements_additions_backup_and_noop(self):
        before = (self.res / 'ArtworkManifest.json').read_bytes()
        self.generate()
        self.assertEqual(repairs.install_completed(self.plan, self.project, self.output, accept=True), 15)
        manifest = repairs.read(self.res / 'ArtworkManifest.json')
        self.assertEqual(len(manifest), 15)
        for row in manifest:
            addition = row['speciesID'] in ['birdnet-v3:BN00814', 'birdnet-v3:BN09561']
            self.assertEqual(row['version'], 1 if addition else 4)
            self.assertEqual('replacesSHA256' in row, not addition)
            self.assertFalse(row['anatomyReview']['twoWings'])
        backups = list((self.project / '.artwork-api/repair-import-backups').iterdir())
        self.assertEqual((backups[0] / 'ArtworkManifest.json').read_bytes(), before)
        self.assertEqual(len(list(backups[0].glob('*.imageset'))), 11)
        self.assertEqual(repairs.install_completed(self.plan, self.project, self.output, accept=True), 0)

    def test_changed_original_blocks_everything_before_install(self):
        self.generate()
        folder = self.res / 'Assets.xcassets' / (self.plan['targets'][0]['key'] + '.imageset')
        (folder / 'old.png').write_bytes(b'external modification')
        before = (self.res / 'ArtworkManifest.json').read_bytes()
        with self.assertRaises(ValueError): repairs.install_completed(self.plan, self.project, self.output, accept=True)
        self.assertEqual((self.res / 'ArtworkManifest.json').read_bytes(), before)
        for t in self.plan['targets']:
            if t['operation'] == 'create': self.assertFalse((self.res / 'Assets.xcassets' / (t['key'] + '.imageset')).exists())
        self.assertEqual(followup.prepare(self.project, self.output), self.plan)

    def test_create_role_never_overwrites_later_existing_asset(self):
        self.generate()
        t = next(t for t in self.plan['targets'] if t['operation'] == 'create')
        folder = self.res / 'Assets.xcassets' / (t['key'] + '.imageset'); folder.mkdir()
        shutil.copy2(self.output / (self.plan['targets'][0]['key'] + '.png'), folder / 'later.png')
        api.write_json(folder / 'Contents.json', dict(images=[dict(filename='later.png')]))
        before = (self.res / 'ArtworkManifest.json').read_bytes()
        with self.assertRaises(ValueError): repairs.install_completed(self.plan, self.project, self.output, accept=True)
        self.assertEqual((self.res / 'ArtworkManifest.json').read_bytes(), before)

    def test_missing_local_original_and_changed_style_stop_generation(self):
        t = self.spec['targets'][0]
        folder = self.res / 'Assets.xcassets' / (t['id'].replace(':', '-') + '-' + t['role'] + '.imageset')
        shutil.rmtree(folder)
        with self.assertRaises(ValueError): followup.prepare(self.project, self.output)
        self.assertFalse((self.output / 'plan.json').exists())

    def test_style_hash_is_frozen_and_rechecked(self):
        plan = followup.prepare(self.project, self.output)
        (self.project / plan['referenceAssets']['primary']).write_bytes(b'changed style')
        with self.assertRaises(ValueError): followup.prepare(self.project, self.output)

    def test_mixed_install_failure_recovers_originals_and_removes_new_roles(self):
        self.generate()
        before = (self.res / 'ArtworkManifest.json').read_bytes()
        swaps = 0
        def fail_after_addition():
            nonlocal swaps
            swaps += 1
            if swaps == 12: raise RuntimeError('synthetic interruption after first addition')
        with self.assertRaises(RuntimeError): repairs.install_completed(self.plan, self.project, self.output, accept=True, after_swap=fail_after_addition)
        self.assertEqual((self.res / 'ArtworkManifest.json').read_bytes(), before)
        self.assertEqual(len(list((self.res / 'Assets.xcassets').glob('birdnet*.imageset'))), 11)
        self.assertFalse((self.project / '.artwork-api/pending-repair-install.json').exists())


if __name__ == '__main__': unittest.main()
