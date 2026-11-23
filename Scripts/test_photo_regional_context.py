"""Check positive photo-location data against its source inventory and taxonomy."""
import csv
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class PhotoRegionalContextTests(unittest.TestCase):
    def test_positive_belgian_context_matches_regular_source_records(self):
        context = json.loads((ROOT / 'BirdingCompanion/Resources/PhotoRegionalContext.json').read_text())
        with (ROOT / 'Docs/BelgiumArtworkInventory.csv').open() as handle:
            inventory = list(csv.DictReader(handle))
        expected = {r['catalogID'] for r in inventory
                    if r['decision'] in ['queued', 'available_existing_or_pilot']
                    and not any(flag in r['sourceStatus'] for flag in
                                ['Zeldzaam', 'Dwaalgast', 'Onzekere', 'BRBC accepted'])}
        self.assertEqual(set(context['countries']['BE']), expected)
        self.assertEqual(len(context['countries']['BE']), len(expected))
        self.assertEqual(context['version'], 1)

    def test_raven_supported_without_promoting_distant_raven_species(self):
        resources = ROOT / 'BirdingCompanion/Resources'
        context = json.loads((resources / 'PhotoRegionalContext.json').read_text())
        world = json.loads((resources / 'WorldSpeciesCatalog.json').read_text())
        by_name = {r['scientificName']: r for r in world}
        regular = set(context['countries']['BE'])
        self.assertIn(by_name['Corvus corax']['id'], regular)
        for name in ['Corvus albicollis', 'Corvus crassirostris', 'Corvus ruficollis']:
            self.assertNotIn(by_name[name]['id'], regular)
        by_id = {r['id']: r for r in world}
        for identifier in regular:
            self.assertIn(identifier, by_id)
            self.assertNotEqual((by_id[identifier].get('extinction') or '').lower().strip('() '), 'extinct')


if __name__ == '__main__':
    unittest.main()
