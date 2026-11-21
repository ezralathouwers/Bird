import copy
import unittest

from build_wingspan_estimates import build, game_point, fox_point, concept, effective_coverage


class EstimatedFallbackTests(unittest.TestCase):
    def setUp(self):
        self.world = [dict(id='id', scientificName='Current bird', avibaseID='avibase-1234ABCD')]
        self.details = [dict(speciesID='id', scientificName='Current bird', wingspan=None)]
        self.card = {'Scientific name': 'Current bird', 'Wingspan': 42, 'CardType': 'Bird', 'id': 1, 'Set': 'asia'}
        self.fox = dict(Species1='Oldgenus bird', **{'Avibase.ID1': 'AVIBASE-1234ABCD'},
                        needs_prediction=True, model_used='order_model', wingspan_predicted_order=45,
                        wingspan_predicted_global=50, wingspan_predicted_min_order=35, wingspan_predicted_max_order=55)

    def test_game_sentinels_and_mini_cards_are_never_biological_values(self):
        for value in [0, '*', None, True, float('nan'), float('inf'), -3, 500]:
            self.assertIsNone(game_point(dict(self.card, Wingspan=value)))
        self.assertIsNone(game_point(dict(self.card, CardType='Hummingbird', Wingspan=10)))

    def test_existing_reported_value_is_preserved_without_mutation(self):
        self.details[0]['wingspan'] = {'minimumCM': 35, 'maximumCM': 40, 'method': 'reported'}
        original = copy.deepcopy(self.details)
        rows, proof, coverage = build(self.world, self.details, [self.card], [self.fox])
        self.assertEqual(rows, [])
        self.assertEqual(self.details, original)
        self.assertEqual(coverage['reportedWingspans'], 1)

    def test_game_priority_is_explicitly_estimated_not_measured(self):
        rows, proof, coverage = build(self.world, self.details, [self.card], [self.fox])
        self.assertEqual(rows[0]['wingspan']['method'], 'estimated-wingspan-game')
        self.assertEqual(rows[0]['wingspan']['minimumCM'], 42)
        self.assertEqual(rows[0]['wingspan']['maximumCM'], 42)
        self.assertEqual(coverage['gameEstimates'], 1)

    def test_model_selector_uses_its_published_point_never_its_bounds(self):
        self.assertEqual(fox_point(self.fox), (45, 'wingspan_predicted_order'))
        self.assertEqual(fox_point(dict(self.fox, model_used='global_model')), (50, 'wingspan_predicted_global'))
        for bad in [dict(self.fox, needs_prediction=False), dict(self.fox, model_used='empirical'), dict(self.fox, wingspan_predicted_order=float('nan'))]:
            self.assertIsNone(fox_point(bad))
        rows, proof, _ = build(self.world, self.details, [], [self.fox])
        self.assertEqual((rows[0]['wingspan']['minimumCM'], rows[0]['wingspan']['maximumCM']), (45, 45))
        self.assertEqual(rows[0]['scientificName'], 'Current bird')
        self.assertEqual(rows[0]['wingspan']['sourceScientificName'], 'Oldgenus bird')

    def test_concept_match_is_exact_and_duplicates_or_name_only_matches_are_rejected(self):
        self.assertEqual(concept('AVIBASE-1234ABCD'), '1234abcd')
        self.assertIsNone(concept('not-a-concept'))
        bad = dict(self.fox, Species1='Current bird', **{'Avibase.ID1': 'avibase-DEADBEEF'})
        for cards, fox in [([], [bad]), ([], [self.fox, self.fox]), ([self.card, self.card], [])]:
            self.assertEqual(build(self.world, self.details, cards, fox)[0], [])

    def test_later_reported_data_takes_priority_over_saved_fallbacks(self):
        estimates, _, _ = build(self.world, self.details, [self.card], [])
        self.details[0]['wingspan'] = {'minimumCM': 40, 'maximumCM': 44}
        coverage = effective_coverage(self.details, estimates)
        self.assertEqual(coverage['reportedWingspans'], 1)
        self.assertEqual(coverage['estimates'], 0)
        self.assertEqual(coverage['displayableWingspans'], 1)
        self.assertEqual(coverage['missingWingspans'], [])

    def test_fallback_coverage_rejects_biological_ranges_and_unknown_sources(self):
        estimates, _, _ = build(self.world, self.details, [self.card], [])
        for field, value in [('maximumCM', 60), ('minimumCM', 0), ('method', 'reported'), ('sourceURL', 'https://example.org/')]:
            changed = copy.deepcopy(estimates)
            changed[0]['wingspan'][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                effective_coverage(self.details, changed)


if __name__ == '__main__':
    unittest.main()
