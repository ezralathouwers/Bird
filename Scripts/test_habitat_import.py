"""Portable checks for taxonomic matching; run with unittest."""
import unittest
from import_birdbase_habitats import resolve, MAPPING

def row(name, habitat):
    r = [None] * 49
    r[2] = name
    r[48] = habitat
    return r

class HabitatImportTests(unittest.TestCase):
    def test_current_name_takes_precedence_over_alias(self):
        result = resolve({'scientificName':'Current bird','aliases':['Old bird']},
                         {'Current bird':[row('Current bird','Forest')], 'Old bird':[row('Old bird','Sea')]})
        self.assertEqual(result[1:], ('Forest','exact-scientific-name'))
    def test_conflicting_aliases_are_unresolved(self):
        self.assertIsNone(resolve({'scientificName':'New bird','aliases':['Old bird']},
                         {'Old bird':[row('Old bird','Forest'),row('Old bird','Sea')]}))
    def test_unknown_species_is_not_inferred_from_name(self):
        self.assertIsNone(resolve({'scientificName':'Forest bird','aliases':[]}, {}))
    def test_missing_habitat_cannot_silently_select_other_record(self):
        self.assertIsNone(resolve({'scientificName':'New bird','aliases':['Old bird']},
                         {'Old bird':[row('Old bird','Forest'),row('Old bird',None)]}))
    def test_forest_is_not_assumed_tropical(self):
        self.assertEqual(MAPPING['Forest'],'forest-general')

if __name__ == '__main__':
    unittest.main()
