"""Source integrity and active/historical catalog boundaries (no network)."""
import csv
import hashlib
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class CatalogVisibilityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.path = ROOT / 'BirdingCompanion/Resources/WorldSpeciesCatalog.json'
        cls.rows = json.loads(cls.path.read_text())
        cls.metadata = json.loads(cls.path.with_name('WorldSpeciesCatalogProvenance.json').read_text())
        cls.extinct = {r['id'] for r in cls.rows if (r.get('extinction') or '').lower().strip('() ') == 'extinct'}

    def test_source_fingerprint_and_identity_are_preserved(self):
        self.assertEqual(hashlib.sha256(self.path.read_bytes()).hexdigest(), self.metadata['catalogSHA256'])
        self.assertEqual(len(self.rows), 11173)
        self.assertEqual(len({r['id'] for r in self.rows}), len(self.rows))
        self.assertEqual(sum(r.get('soundIndex') is not None for r in self.rows), 9788)

    def test_audit_and_production_queue_exclude_only_definite_extinction(self):
        with (ROOT / 'Docs/ExtinctSpeciesCatalogAudit.csv').open() as handle:
            self.assertEqual({r['id'] for r in csv.DictReader(handle)}, self.extinct)
        self.assertEqual(len(self.extinct), 151)
        examples = {'Black-fronted Kakariki', 'White Swamphen', 'Red Rail',
                    'Red-moustached Fruit Dove', 'Black Mamo'}
        excluded_names = {r['englishName'] for r in self.rows if r['id'] in self.extinct}
        self.assertTrue(examples <= excluded_names)
        with (ROOT / 'Docs/IllustrationProductionQueue.csv').open() as handle:
            queued = {r['speciesID'] for r in csv.DictReader(handle)}
        self.assertFalse(queued & self.extinct)
        summary = json.loads((ROOT / 'Docs/IllustrationProductionQueue.json').read_text())
        self.assertEqual(summary['catalogRecords'], len(self.rows) - len(self.extinct))
        self.assertEqual(summary['activeRoles'], ['primary', 'dynamic'])

    def test_requested_dutch_names_are_retained(self):
        by_id = {r['id']: r for r in self.rows}
        for species_id, name in self.metadata['dutchNameOverrides'].items():
            self.assertEqual(by_id[species_id]['dutchName'], name)
        self.assertEqual(len(self.metadata['dutchNameOverrides']), 2)


if __name__ == '__main__':
    unittest.main()
