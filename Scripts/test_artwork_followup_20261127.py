import json
from pathlib import Path
import unittest
from PIL import Image
import artwork_api_pilot as api
import artwork_api_repairs as repairs
import artwork_followup_20261126 as followup
import test_artwork_followup_20261126 as previous_round


class November27RoundTests(unittest.TestCase):
    def setUp(self):
        # Retain a complete older intake as unrelated artwork in the same project.
        self.fixture = previous_round.FollowupTests(); self.fixture.setUp()
        self.addCleanup(self.fixture.doCleanups)
        self.project = self.fixture.project; self.res = self.fixture.res
        self.output = self.fixture.output.parent / 'nov27'
        self.spec_path = api.ROOT / 'Docs/ArtworkFollowup20261127.json'
        self.spec = repairs.read(self.spec_path)
        manifest = repairs.read(self.res / 'ArtworkManifest.json')
        self.older_records = json.loads(json.dumps(manifest))
        for t in self.spec['targets']:
            asset = t['id'].replace(':', '-') + '-dynamic'
            folder = self.res / 'Assets.xcassets' / (asset + '.imageset'); folder.mkdir()
            image = Image.new('RGBA', (1024, 1536)); image.putpixel((320, 500), (100, 70, 30, 255)); image.save(folder / 'old.png')
            api.write_json(folder / 'Contents.json', dict(images=[dict(filename='old.png')]))
            manifest.append(dict(asset=asset, speciesID=t['id'], view='dynamic', sha256=repairs.digest(folder / 'old.png'), version=2))
        api.write_json(self.res / 'ArtworkManifest.json', manifest)

    def generate(self):
        self.plan = followup.prepare(self.project, self.output, self.spec_path)
        self.jobs = repairs.repair_jobs(self.plan, self.project)
        return api.run(self.plan, self.jobs, self.output, 'fake-key', 9, 2, sender=self.fixture.sender)

    def test_nine_exact_dynamic_replacements_and_repeated_run_costs_nothing(self):
        self.generate(); self.generate()
        self.assertEqual(self.fixture.calls, 9)
        self.assertEqual({j['id'] for j in self.jobs}, {
            'birdnet-v3:BN04617', 'birdnet-v3:BN09278', 'birdnet-v3:BN09270',
            'birdnet-v3:BN07662', 'birdnet-v3:BN06901', 'birdnet-v3:BN07149',
            'birdnet-v3:BN01179', 'birdnet-v3:BN07931', 'birdnet-v3:BN00323'})
        self.assertTrue(all(j['role'] == 'dynamic' for j in self.jobs))
        self.assertEqual(len(list((self.output / 'originals').glob('*.png'))), 9)
        self.assertTrue(all('BOTH naturally folded' in j['prompt'] for j in self.jobs if j['id'] != 'birdnet-v3:BN04617'))

    def test_install_preserves_previous_artwork_and_has_exact_backups(self):
        before = (self.res / 'ArtworkManifest.json').read_bytes()
        self.generate()
        self.assertEqual(repairs.install_completed(self.plan, self.project, self.output, accept=True), 9)
        records = repairs.read(self.res / 'ArtworkManifest.json')
        old_assets = {r['asset'] for r in self.older_records}
        self.assertEqual([r for r in records if r['asset'] in old_assets], self.older_records)
        for r in records:
            if r['asset'] not in old_assets:
                self.assertEqual(r['version'], 3)
                self.assertFalse(r['anatomyReview']['twoWings'])
                t = next(t for t in self.plan['targets'] if t['key'] == r['asset'])
                self.assertEqual(r['replacesSHA256'], t['originalSHA256'])
        backup = next((self.project / '.artwork-api/repair-import-backups').iterdir())
        self.assertEqual((backup / 'ArtworkManifest.json').read_bytes(), before)
        self.assertEqual(len(list(backup.glob('*.imageset'))), 9)
        self.assertEqual(repairs.install_completed(self.plan, self.project, self.output, accept=True), 0)

    def test_older_and_newer_generation_checkpoints_remain_separate(self):
        self.fixture.generate()
        old_plan = (self.fixture.output / 'plan.json').read_bytes()
        old_state = (self.fixture.output / 'state.json').read_bytes()
        self.generate()
        self.assertEqual(self.fixture.calls, 24)
        self.assertEqual((self.fixture.output / 'plan.json').read_bytes(), old_plan)
        self.assertEqual((self.fixture.output / 'state.json').read_bytes(), old_state)
        self.assertNotEqual(repairs.read(self.output / 'state.json')['recipeSHA256'], repairs.read(self.fixture.output / 'state.json')['recipeSHA256'])
        with self.assertRaises(ValueError): followup.prepare(self.project, self.fixture.output, self.spec_path)
        with self.assertRaises(ValueError): followup.prepare(self.project, self.output)

    def test_replaced_original_is_not_silently_rebound_or_overwritten(self):
        self.generate()
        t = self.plan['targets'][0]
        path = self.res / 'Assets.xcassets' / (t['key'] + '.imageset') / 'old.png'
        path.write_bytes(b'another local version')
        self.assertEqual(followup.prepare(self.project, self.output, self.spec_path), self.plan)
        before = (self.res / 'ArtworkManifest.json').read_bytes()
        with self.assertRaises(ValueError): repairs.install_completed(self.plan, self.project, self.output, accept=True)
        self.assertEqual((self.res / 'ArtworkManifest.json').read_bytes(), before)
        self.assertEqual(path.read_bytes(), b'another local version')


if __name__ == '__main__': unittest.main()
