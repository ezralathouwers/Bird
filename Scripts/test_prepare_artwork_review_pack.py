import hashlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile
from PIL import Image
import prepare_artwork_review_pack as pack


class ArtworkReviewPackTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.archive = self.root / 'Archief.zip'
        image = Image.new('RGBA', (1200, 1600)); image.putpixel((1199, 100), (80, 40, 20, 255))
        image.putpixel((600, 800), (120, 80, 40, 255))
        buf = io.BytesIO(); image.save(buf, 'PNG'); self.png = buf.getvalue()
        with zipfile.ZipFile(self.archive, 'w') as z:
            z.writestr('Foute vleugels/pose/birdnet-v3-BN09847-dynamic.png', self.png)
            z.writestr('__MACOSX/._ignored.png', b'not an image')
        self.original_hash = hashlib.sha256(self.archive.read_bytes()).hexdigest()

    def test_all_images_preserve_identity_categories_alpha_and_original_hash(self):
        output, inventory = pack.prepare(self.archive)
        self.assertLess(output.stat().st_size, 24*1024*1024)
        row = inventory['entries'][0]
        self.assertEqual(row['speciesID'], 'birdnet-v3:BN09847')
        self.assertEqual(row['role'], 'dynamic')
        self.assertEqual(row['originalName'], 'Foute vleugels/pose/birdnet-v3-BN09847-dynamic.png')
        self.assertEqual(row['originalSHA256'], hashlib.sha256(self.png).hexdigest())
        self.assertTrue(row['edgeContact']['right'])
        with zipfile.ZipFile(output) as z:
            image = Image.open(io.BytesIO(z.read(row['preview'])))
            self.assertEqual(image.size, (720, 960))
            self.assertIn('A', image.getbands())
            self.assertFalse(any(name.endswith('.png') for name in z.namelist()))
        self.assertEqual(hashlib.sha256(self.archive.read_bytes()).hexdigest(), self.original_hash)
        self.assertFalse(inventory['originalsChanged'])
        self.assertEqual(inventory['generationsRequested'], 0)

    def test_six_extra_species_are_discovered_in_actual_project_imagesets(self):
        project = self.root / 'app'; resources = project / 'BirdingCompanion/Resources'
        folder = resources / 'Assets.xcassets/birdnet-v3-BN06072-dynamic.imageset'; folder.mkdir(parents=True)
        (folder/'original.png').write_bytes(self.png)
        (folder/'Contents.json').write_text(json.dumps({'images': [{'filename': 'original.png'}]}))
        (resources/'WorldSpeciesCatalog.json').write_text(json.dumps([{'id':'birdnet-v3:BN06072','dutchName':'Bonte zanger','scientificName':'Mniotilta varia'}]))
        _, inventory = pack.prepare(self.archive, project)
        self.assertEqual(len(inventory['entries']), 2)
        self.assertEqual(inventory['extraSpeciesFound'], ['birdnet-v3:BN06072'])
        self.assertEqual(len(inventory['extraSpeciesMissing']), 5)
        self.assertEqual(inventory['entries'][1]['dutchName'], 'Bonte zanger')
        self.assertNotIn(str(project), json.dumps(inventory))

    def test_unsafe_members_and_empty_archives_are_rejected(self):
        for name in ['../escape.png', '/escape.png', 'x\\escape.png']:
            with zipfile.ZipFile(self.archive, 'w') as z: z.writestr(name, self.png)
            with self.assertRaises(ValueError): pack.prepare(self.archive)
        with zipfile.ZipFile(self.archive, 'w') as z: z.writestr('LEESMIJ.txt','Geen beelden')
        with self.assertRaises(ValueError): pack.prepare(self.archive)
        self.assertEqual(list(self.root.glob('*.tmp')), [])

    def test_existing_output_is_never_overwritten_and_oversize_is_cleaned(self):
        output, _ = pack.prepare(self.archive)
        original = output.read_bytes()
        with self.assertRaises(ValueError): pack.prepare(self.archive)
        self.assertEqual(output.read_bytes(), original)
        with patch.object(pack, 'MAX_PACK_BYTES', 1):
            with self.assertRaises(ValueError): pack.prepare(self.archive, output=self.root/'too-large.zip')
        self.assertFalse((self.root/'too-large.zip').exists())
        self.assertEqual(list(self.root.glob('*.tmp')), [])

    def test_no_alpha_is_reported_as_unknown_not_truncated(self):
        image = Image.new('RGB',(40,40),'white'); buf=io.BytesIO(); image.save(buf,'PNG')
        _, row = pack.image_info(buf.getvalue(), 'opaque.png')
        self.assertFalse(row['hasAlpha']); self.assertIsNone(row['edgeContact'])


if __name__ == '__main__': unittest.main()
