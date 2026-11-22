import hashlib
import json
from pathlib import Path
import sqlite3
import struct
import tempfile
import unittest
from convert_birdlife_geopackage import convert, geopackage_wkb, resolve_names
from shapely.geometry import MultiPolygon, Polygon


class BirdLifeConversionTests(unittest.TestCase):
    def fixture(self, root):
        source = root / 'Fictional.gpkg'
        polygon = MultiPolygon([Polygon([(0, 0), (4, 0), (4, 4), (0, 4)],
                                        holes=[[(1, 1), (2, 1), (2, 2), (1, 2)]])])
        blob = b'GP\x00\x01' + struct.pack('<i', 4326) + polygon.wkb
        with sqlite3.connect(source) as db:
            db.executescript('''
                CREATE TABLE gpkg_geometry_columns(table_name TEXT, column_name TEXT, geometry_type_name TEXT, srs_id INTEGER);
                INSERT INTO gpkg_geometry_columns VALUES ('all_species', 'geom', 'MULTIPOLYGON', 4326);
                CREATE TABLE all_species(geom BLOB,sci_name TEXT,presence INTEGER,origin INTEGER,seasonal INTEGER,citation TEXT);
            ''')
            db.executemany('INSERT INTO all_species VALUES (?,?,?,?,?,?)', [
                (blob, 'Fictional alpha', 1, 1, 1, 'Fictional source'),
                (blob, 'Fictional alpha', 5, 1, 3, 'Fictional source'),
                (blob, 'Old beta', 1, 3, 2, 'Fictional source'),
                (blob, 'Unmapped species', 1, 1, 1, 'Fictional source'),
            ])
        catalog = root / 'catalog.json'
        catalog.write_text(json.dumps([
            {'id': 'test:alpha', 'scientificName': 'Fictional alpha', 'aliases': []},
            {'id': 'test:beta', 'scientificName': 'Fictional beta', 'aliases': ['Old beta']},
        ]))
        return source, catalog

    def test_stream_export_preserves_codes_holes_hashes_and_read_only_source(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            source, catalog = self.fixture(root)
            digest = hashlib.sha256(source.read_bytes()).hexdigest()
            output = root / 'PrivateBirdLifeRanges'
            output.mkdir()
            (output / 'README.txt').write_text('Old folder')
            report = convert(source, catalog, output)
            self.assertEqual(report['exportedSpecies'], 2)
            self.assertEqual(report['exportedFeatures'], 3)
            self.assertEqual(report['unmatchedSourceNames'], ['Unmapped species'])
            manifest = json.loads((output / 'manifest.json').read_text())
            entry = manifest['files']['test:alpha']
            data = (output / entry['file']).read_bytes()
            self.assertEqual(hashlib.sha256(data).hexdigest(), entry['sha256'])
            alpha = json.loads(data)
            self.assertEqual(alpha['speciesID'], 'test:alpha')
            self.assertEqual(alpha['version'], '2025.2')
            self.assertEqual([f['properties']['presence'] for f in alpha['features']], [1, 5])
            geometry = alpha['features'][0]['geometry']
            rings = geometry['coordinates'] if geometry['type'] == 'Polygon' else geometry['coordinates'][0]
            self.assertEqual(len(rings), 2)
            self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), digest)
            self.assertEqual(len(list(root.glob('.birdlife-backup-*'))), 1)

    def test_bad_source_never_replaces_previous_export(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            source, catalog = self.fixture(root)
            with sqlite3.connect(source) as db:
                db.execute('UPDATE all_species SET geom=?', (b'broken',))
            output = root / 'PrivateBirdLifeRanges'
            output.mkdir()
            (output / 'sentinel').write_text('Keep previous export')
            with self.assertRaises(ValueError):
                convert(source, catalog, output)
            self.assertEqual((output / 'sentinel').read_text(), 'Keep previous export')
            self.assertFalse(list(root.glob('.birdlife-stage-*')))

    def test_taxonomic_ambiguity_does_not_union_or_duplicate_ranges(self):
        catalog = [
            {'id': 'a', 'scientificName': 'Current A', 'aliases': ['Old', 'Older']},
            {'id': 'b', 'scientificName': 'Current B', 'aliases': ['Old']},
        ]
        self.assertEqual(resolve_names(catalog, {'Old'}), {})
        self.assertEqual(resolve_names(catalog, {'Current A', 'Older'}), {'Current A': 'a'})
        one = catalog[:1]
        self.assertEqual(resolve_names(one, {'Old', 'Older'}), {})

    def test_geometry_header_envelopes_and_srs(self):
        payload = b'fake-wkb'
        header = b'GP\x00\x03' + struct.pack('<i', 4326) + b'\x00' * 32
        self.assertEqual(geopackage_wkb(header + payload), payload)
        with self.assertRaises(ValueError):
            geopackage_wkb(b'GP\x00\x01' + struct.pack('<i', 3857) + payload)
        with self.assertRaises(ValueError):
            geopackage_wkb(b'GP\x00\x11' + struct.pack('<i', 4326) + payload)


if __name__ == '__main__':
    unittest.main()
