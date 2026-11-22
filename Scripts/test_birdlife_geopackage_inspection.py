"""Read-only inspector checks using a tiny fictional GeoPackage, not BirdLife GIS."""
import hashlib
import json
from pathlib import Path
import sqlite3
import tempfile
import unittest

from inspect_birdlife_geopackage import inspect_geopackage, write_report


class BirdLifeInspectionTests(unittest.TestCase):
    def fixture(self, directory):
        path = Path(directory) / 'Fictief ? # é.gpkg'
        with sqlite3.connect(path) as db:
            db.executescript('''
                CREATE TABLE gpkg_contents(table_name TEXT, identifier TEXT, data_type TEXT, srs_id INTEGER);
                CREATE TABLE gpkg_geometry_columns(table_name TEXT, column_name TEXT, geometry_type_name TEXT, srs_id INTEGER, z INTEGER, m INTEGER);
                CREATE TABLE gpkg_spatial_ref_sys(srs_name TEXT, srs_id INTEGER, organization TEXT, organization_coordsys_id INTEGER);
                CREATE TABLE "birds layer"(id_no INTEGER PRIMARY KEY, sci_name TEXT, presence INTEGER, seasonal INTEGER, geom BLOB, private_note TEXT);
                INSERT INTO gpkg_contents VALUES ('birds layer', 'Fictional test', 'features', 4326);
                INSERT INTO gpkg_geometry_columns VALUES ('birds layer', 'geom', 'MULTIPOLYGON', 4326, 0, 0);
                INSERT INTO gpkg_spatial_ref_sys VALUES ('WGS 84', 4326, 'EPSG', 4326);
                INSERT INTO "birds layer" VALUES (1, 'Fictional species', 1, 2, X'010203', 'DO NOT EXPORT');
            ''')
        return path

    def test_read_only_schema_names_and_no_geometry_or_private_content(self):
        with tempfile.TemporaryDirectory() as directory:
            source = self.fixture(directory)
            before = hashlib.sha256(source.read_bytes()).digest()
            report = inspect_geopackage(source)
            self.assertEqual(hashlib.sha256(source.read_bytes()).digest(), before)
            layer = report['layers'][0]
            self.assertEqual(layer['table'], 'birds layer')
            self.assertEqual(layer['geometry'][0]['geometry_type_name'], 'MULTIPOLYGON')
            self.assertEqual(layer['sampleAttributes'][0]['sci_name'], 'Fictional species')
            self.assertNotIn('geom', layer['sampleAttributes'][0])
            self.assertNotIn('DO NOT EXPORT', json.dumps(report))
            self.assertNotIn(str(source.parent), json.dumps(report))
            self.assertEqual(report['spatialReferenceSystems'][0]['organization'], 'EPSG')
            self.assertTrue(report['sourceOpenedReadOnly'])
            destination = Path(directory) / 'report.json'
            write_report(report, destination)
            self.assertEqual(json.loads(destination.read_text()), report)
            self.assertEqual(hashlib.sha256(source.read_bytes()).digest(), before)

    def test_non_geopackage_and_bad_header_fail_without_report(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'not-a-package.gpkg'
            path.write_text('not a database')
            with self.assertRaises(ValueError):
                inspect_geopackage(path)
            path.unlink()
            with sqlite3.connect(path) as db:
                db.execute('CREATE TABLE irrelevant (id INTEGER)')
            with self.assertRaises(ValueError):
                inspect_geopackage(path)


if __name__ == '__main__':
    unittest.main()
