import copy
import unittest
from supplement_species_details import merge

class SupplementSafetyTests(unittest.TestCase):
    def setUp(self):
        self.rows = [{'speciesID': 'stable-id', 'scientificName': 'Example bird', 'bio': None, 'bioMethod': None, 'bioSourceURLs': [], 'wingspan': None}]
        self.item = {'speciesID': 'stable-id', 'scientificName': 'Example bird', 'bio': 'Een gecontroleerde beschrijving.', 'bioMethod': 'source-summary-nl', 'bioSourceURLs': ['https://example.org/species'], 'evidence': {'checked': '2026-11-21'}}

    def test_identity_mismatch_is_rejected_without_mutating_input(self):
        original = copy.deepcopy(self.rows)
        self.item['scientificName'] = 'Different bird'
        with self.assertRaises(ValueError):
            merge(self.rows, [self.item])
        self.assertEqual(self.rows, original)

    def test_existing_content_cannot_be_silently_replaced(self):
        self.rows[0]['bio'] = 'Existing description'
        with self.assertRaises(ValueError):
            merge(self.rows, [self.item])

    def test_repeat_import_is_idempotent(self):
        first = merge(self.rows, [self.item])
        self.assertEqual(merge(first, [self.item]), first)

    def test_unreviewed_and_duplicate_rows_are_rejected(self):
        with self.assertRaises(ValueError):
            merge(self.rows, [self.item, self.item])
        self.item['evidence'] = {}
        with self.assertRaises(ValueError):
            merge(self.rows, [self.item])

    def test_invalid_or_predicted_measurements_are_rejected(self):
        for lo, hi, method in [(30, 20, 'source-checked-guide'), (float('nan'), 20, 'source-checked-guide'), (20, 30, 'predicted')]:
            item = {k: self.item[k] for k in ['speciesID', 'scientificName', 'evidence']}
            item['wingspan'] = {'minimumCM': lo, 'maximumCM': hi, 'method': method, 'sourceScientificName': 'Example bird', 'sourceURL': 'https://example.org/span'}
            with self.assertRaises(ValueError):
                merge(self.rows, [item])

    def test_wikidata_cannot_invent_a_range_or_disagree_with_its_statement(self):
        item = {k: copy.deepcopy(self.item[k]) for k in ['speciesID', 'scientificName', 'evidence']}
        item['wingspan'] = dict(minimumCM=50, maximumCM=50, method='source-reported-wikidata',
            sourceScientificName='Example bird', sourceURL='https://www.wikidata.org/wiki/Q123')
        item['evidence']['wikidataStatement'] = {'rank': 'normal',
            'mainsnak': {'property': 'P2050', 'datavalue': {'value': {'amount': '+0.5', 'unit': 'http://www.wikidata.org/entity/Q11573'}}},
            'references': [{'snaks': {'P248': [{'snaktype': 'value', 'datavalue': {'value': {'id': 'Q456'}}}]}}]}
        self.assertEqual(merge(self.rows, [item])[0]['wingspan']['minimumCM'], 50)
        for change in ['range', 'bounds', 'tampered', 'scope']:
            bad = copy.deepcopy(item)
            if change == 'range': bad['wingspan']['maximumCM'] = 60
            elif change == 'bounds': bad['evidence']['wikidataStatement']['mainsnak']['datavalue']['value']['lowerBound'] = '+0.4'
            elif change == 'tampered': bad['wingspan'].update(minimumCM=60, maximumCM=60)
            elif change == 'scope': bad['evidence']['wikidataStatement']['qualifiers'] = {'P21': []}
            with self.subTest(change=change), self.assertRaises(ValueError):
                merge(self.rows, [bad])

if __name__ == '__main__':
    unittest.main()
