import unittest
from collect_wikipedia_spans import collect, extract_ranges


class WikipediaWingspanTests(unittest.TestCase):
    def bounds(self, text, lang='en'):
        return [(r['minimumCM'], r['maximumCM']) for r in extract_ranges(text, lang)]

    def test_explicit_metric_ranges_and_unit_conversion(self):
        examples = [('wingspan of 25–30 cm', 'en', (25, 30)),
                    ('envergure de 2 à 2,5 m', 'fr', (200, 250)),
                    ('Flügelspannweite von 1,5 bis 1,65 Metern', 'de', (150, 165)),
                    ('apertura alare è di 25–33 cm', 'it', (25, 33)),
                    ('envergadura alar de 18-19 cm', 'es', (18, 19)),
                    ('Envergadura: 250-280 mm', 'pt', (25, 28))]
        for text, lang, expected in examples:
            with self.subTest(text=text):
                self.assertEqual(self.bounds(text, lang), [expected])

    def test_imperial_parentheses_and_suffix(self):
        self.assertEqual(self.bounds('Wingspan: 8.7–9.1 inches (22–23 cm)'), [(22, 23)])
        self.assertEqual(self.bounds('a 28–33 cm wingspan'), [(28, 33)])

    def test_does_not_misread_body_length_table_as_wingspan(self):
        self.assertEqual(self.bounds('Length: 15–19 cm (5.9–7.5 in) Wingspan: 26.7–29 cm'), [(26.7, 29)])
        self.assertEqual(self.bounds('Length: 50–54 cm Wingspan: 752–860 mm'), [(75.2, 86)])
        self.assertEqual(self.bounds('Length: 12–13 cm\nWingspan: 22 cm'), [])
        self.assertEqual(self.bounds('22–24 cm long, with a wingspan of 50 cm and weight of 39–52 g'), [])

    def test_does_not_skip_single_value_to_other_measurement(self):
        self.assertEqual(self.bounds('wingspan up to 60 cm, with a wing chord length of 20.3 to 23.4 cm'), [])
        self.assertEqual(self.bounds('apertura alare sui 68 cm e il tarso misura 85-103 mm', 'it'), [])
        self.assertEqual(self.bounds('Flügelspannweite von 44,5 cm, 16,5 bis 26,7 cm lang', 'de'), [])

    def test_inferred_values_are_excluded(self):
        self.assertEqual(self.bounds('estimated wingspan of 60–65 cm'), [])
        self.assertEqual(self.bounds('apertura alare è equiparabile ad altri columbidi, quindi sui 60–65 cm', 'it'), [])

    def test_only_exact_species_and_licensed_wikipedia_descriptions(self):
        world = [dict(id='id', birdnetID='bn', scientificName='Exact bird')]
        details = [dict(speciesID='id', wingspan=None)]
        source = dict(birdnet_id='bn', scientific_name='Exact bird',
                      descriptions={'en': 'wingspan of 25–30 cm'},
                      description_sources={'en': 'wikipedia'},
                      wikipedia_urls={'en': 'https://en.wikipedia.org/wiki/Exact_bird'})
        self.assertEqual(len(collect(world, details, [source])), 1)
        for field, value in [('scientific_name', 'Other bird'),
                             ('description_sources', {'en': 'llm'}),
                             ('wikipedia_urls', {'en': 'https://example.org/bird'})]:
            with self.subTest(field=field):
                self.assertEqual(collect(world, details, [dict(source, **{field: value})]), [])
        self.assertEqual(collect(world, [dict(speciesID='id', wingspan={})], [source]), [])


if __name__ == '__main__':
    unittest.main()
