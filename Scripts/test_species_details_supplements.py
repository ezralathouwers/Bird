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

if __name__ == '__main__':
    unittest.main()
