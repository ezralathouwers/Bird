import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from PIL import Image
import local_artwork_import as local


class LocalArtworkImportTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.project = self.root / 'app'
        (self.project / 'BirdingCompanion.xcodeproj').mkdir(parents=True)
        (self.project / 'BirdingCompanion.xcodeproj/project.pbxproj').write_text('synthetic project fixture')
        self.res = self.project / 'BirdingCompanion/Resources'
        (self.res / 'Assets.xcassets').mkdir(parents=True)
        (self.res / 'ArtworkManifest.json').write_text('[]')
        (self.res / 'WorldSpeciesCatalog.json').write_text(json.dumps([{'id': 'test:bird', 'dutchName': 'Testvogel', 'englishName': 'Test bird'}]))
        self.source = self.root / 'producer/.artwork-api/belgium-medium'
        self.source.mkdir(parents=True)
        image = Image.new('RGBA', (1024, 1024))
        image.putpixel((50, 50), (1, 2, 3, 255))
        image.save(self.source / 'test-bird-primary.png')
        sha = local.digest(self.source / 'test-bird-primary.png')
        (self.source / 'state.json').write_text(json.dumps({'jobs': {'test-bird-primary': {'status': 'generated_unreviewed', 'file': 'test-bird-primary.png', 'outputSHA256': sha}}}))
        (self.source / 'review-template.json').write_text(json.dumps([dict(id='test:bird', role='primary', path='/old/mac/path.png', composition='bird-only', representativePlumage='synthetic fixture', anatomyReview={'sha256': sha}, generationProvenance={'outputSHA256': sha, 'requestID': 'fixture-only'})]))

    def approval(self):
        rows, skipped = local.candidates(self.source, self.project)
        for row in rows:
            for flag in ['twoWings', 'singleHeadAndBill', 'poseAndFraming', 'noProps']:
                row['anatomyReview'][flag] = True  # Synthetic test pixels, not real visual approval.
            for flag in ['speciesPlumage', 'styleMatch', 'transparency']:
                row['visualReview'][flag] = True
        path = self.root / 'approved.json'
        path.write_text(json.dumps({'format': local.FORMAT, 'rows': rows}))
        return path

    def test_preview_does_not_approve_anything_or_trust_old_absolute_paths(self):
        rows, skipped = local.candidates(self.source.parents[1], self.project)
        self.assertEqual(len(rows), 1)
        self.assertEqual(skipped, 0)
        self.assertEqual(Path(rows[0]['path']).parent, self.source)
        self.assertFalse(rows[0]['anatomyReview']['noProps'])
        page = local.review_page(rows, self.root / 'review.html').read_text()
        self.assertIn('disabled onchange', page)
        self.assertIn('loading="lazy"', page)
        self.assertEqual(json.loads((self.res / 'ArtworkManifest.json').read_text()), [])

    def test_production_package_cannot_be_chosen_as_target_app(self):
        (self.project / 'BirdingCompanion.xcodeproj/project.pbxproj').unlink()
        with self.assertRaisesRegex(ValueError, 'volledige Birder-projectmap'):
            local.candidates(self.source, self.project)

    def test_hash_mismatch_and_missing_original_are_not_silently_skipped(self):
        path = self.source / 'test-bird-primary.png'
        path.write_bytes(path.read_bytes() + b'changed')
        with self.assertRaisesRegex(ValueError, 'bestandshash'):
            local.candidates(self.source, self.project)
        path.unlink()
        with self.assertRaises(FileNotFoundError):
            local.candidates(self.source, self.project)

    def test_install_preserves_bytes_and_provenance_and_repeat_is_noop(self):
        approved = self.approval()
        original = (self.source / 'test-bird-primary.png').read_bytes()
        self.assertEqual(local.import_review(approved, self.project)[0], 1)
        target = self.res / 'Assets.xcassets/test-bird-primary.imageset/primary.png'
        self.assertEqual(target.read_bytes(), original)
        manifest = local.read(self.res / 'ArtworkManifest.json')
        self.assertEqual(manifest[0]['generationProvenance']['requestID'], 'fixture-only')
        self.assertEqual(local.import_review(approved, self.project)[0], 0)
        rows, skipped = local.candidates(self.source, self.project)
        self.assertEqual((len(rows), skipped), (0, 1))
        self.assertEqual(local.read(self.res / 'ArtworkManifest.json'), manifest)
        self.assertEqual(len(list((self.project / '.artwork-api/import-backups').iterdir())), 1)

    def test_unreviewed_selection_does_not_write_assets(self):
        rows, _ = local.candidates(self.source, self.project)
        path = self.root / 'unreviewed.json'
        path.write_text(json.dumps({'format': local.FORMAT, 'rows': rows}))
        with self.assertRaises(ValueError):
            local.import_review(path, self.project)
        self.assertEqual(list((self.res / 'Assets.xcassets').iterdir()), [])
        self.assertEqual(local.read(self.res / 'ArtworkManifest.json'), [])

    def test_partial_import_failure_restores_manifest_and_removes_only_new_assets(self):
        approved = self.approval()
        existing = self.res / 'Assets.xcassets/untouched.imageset'
        existing.mkdir()
        (existing / 'keep.txt').write_text('preserve')
        def failure(mapping, batch):
            (self.res / 'Assets.xcassets/test-bird-primary.imageset').mkdir()
            (self.res / 'ArtworkManifest.json').write_text('partial-invalid')
            raise OSError('Synthetic write failure')
        with patch.object(local.installer, 'install', side_effect=failure):
            with self.assertRaises(OSError):
                local.import_review(approved, self.project)
        self.assertEqual(local.read(self.res / 'ArtworkManifest.json'), [])
        self.assertEqual((existing / 'keep.txt').read_text(), 'preserve')
        self.assertFalse((self.res / 'Assets.xcassets/test-bird-primary.imageset').exists())

    def test_conflicting_existing_asset_cannot_be_overwritten(self):
        approved = self.approval()
        target = self.res / 'Assets.xcassets/test-bird-primary.imageset'
        target.mkdir()
        (target / 'keep.txt').write_text('existing work')
        with self.assertRaisesRegex(ValueError, 'ander of onvolledig'):
            local.import_review(approved, self.project)
        self.assertEqual((target / 'keep.txt').read_text(), 'existing work')

    def test_forged_review_digest_does_not_change_files(self):
        approved = self.approval()
        document = local.read(approved)
        document['rows'][0]['anatomyReview']['sha256'] = 'bad'
        approved.write_text(json.dumps(document))
        with self.assertRaisesRegex(ValueError, 'gewijzigd'):
            local.import_review(approved, self.project)
        self.assertEqual(local.read(self.res / 'ArtworkManifest.json'), [])


if __name__ == '__main__':
    unittest.main()
