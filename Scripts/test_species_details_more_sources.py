import unittest

from collect_multilingual_wingspans import taxon_name, normalize, measurements
from collect_regional_wingspans import adw_fields, oiseaux_fields, quantity


class MultilingualSourceTests(unittest.TestCase):
    def test_species_taxobox_identity_is_language_specific(self):
        self.assertEqual(taxon_name('{{Tassobox\n|binome = Exact bird\n|trinome = \n|tridata = \n}}', 'it'), 'Exact bird')
        self.assertIsNone(taxon_name('{{Tassobox\n|binome = Exact bird\n|trinome = Exact bird minor\n}}', 'it'))
        self.assertEqual(taxon_name('{{Taxobox\n|Taxon_WissName = Exact bird\n|Taxon_Rang = Art\n}}', 'de'), 'Exact bird')
        self.assertIsNone(taxon_name('{{Taxobox\n|Taxon_WissName = Exact bird\n|Taxon_Rang = Unterart\n}}', 'de'))
        self.assertEqual(taxon_name('{{Taxobox taxon | animal | espèce | Exact bird | Author}}', 'fr'), 'Exact bird')
        self.assertIsNone(taxon_name('{{Taxobox taxon | animal | sous-espèce | Exact bird minor | Author}}', 'fr'))

    def test_explicit_ranges_and_locale_units(self):
        cases = [('it', "L'apertura alare è di 1,3–1,5 metri.", (130, 150)),
                 ('de', 'Flügelspannweite zwischen 25 und 30 Zentimetern.', (25, 30)),
                 ('fr', 'Envergure de {{unité|25|à|30|cm}}.', (25, 30)),
                 ('it', 'apertura alare di circa 23,5 cm.', (23.5, 23.5))]
        for language, text, expected in cases:
            with self.subTest(text=text):
                got = measurements(normalize(text, language), language)
                self.assertEqual([(r['minimumCM'], r['maximumCM']) for r in got], [expected])

    def test_partial_range_and_other_measurement_are_not_single_spans(self):
        for language, text in [('de', 'Spannweite von 25 cm bis 30 cm'), ('it', 'apertura alare 25 cm e 30 cm')]:
            self.assertEqual(measurements(normalize(text, language), language), [])
        self.assertEqual(measurements('apertura alare di 50 cm; tarso 15–20 mm', 'it')[0]['minimumCM'], 50)
        self.assertEqual(measurements('apertura alare stimata di 50–60 cm', 'it'), [])


class RegionalGuideTests(unittest.TestCase):
    def test_unit_conversion_is_strict(self):
        self.assertEqual(quantity('1.2 to 1.5 m'), dict(minimumCM=120, maximumCM=150))
        for value in ['unknown', '-', '40 to 30 cm', '15 kg', '20 cm estimated', 'nan cm']:
            self.assertIsNone(quantity(value))

    def test_adw_requires_species_identity_and_exact_wingspan_field(self):
        source = '<h1 class="rank--Species">Exact bird</h1><section><h2 id="physical_description">Physical</h2><dt>Range length</dt><dd>10 to 20 cm</dd><dt>Range wingspan</dt><dd>25 to 30 cm</dd><dd class="english">9.8 to 11.8 in</dd></section>'
        values = adw_fields(source, 'Exact bird')
        self.assertEqual([(r['minimumCM'], r['maximumCM']) for r in values], [(25, 30)])
        self.assertEqual(adw_fields(source, 'Different bird'), [])
        self.assertEqual(adw_fields(source.replace('rank--Species', 'rank--Genus'), 'Exact bird'), [])

    def test_oiseaux_never_substitutes_wing_chord_or_subspecies_card(self):
        source = '<title>Bird - Exact bird - Oiseaux.net</title><li title="Envergure"><span class="v3b-morph-val">-</span></li><li title="Aile (AVONET)"><span class="v3b-morph-val">80 mm</span></li><li title="Envergure"><span class="v3b-morph-val">25 cm</span></li>'
        self.assertEqual(oiseaux_fields(source, 'Exact bird'), [])
        self.assertEqual(oiseaux_fields(source.replace('>-</span>', '>25 à 30 cm</span>'), 'Exact bird')[0]['maximumCM'], 30)
        self.assertEqual(oiseaux_fields(source, 'Exact bird minor'), [])


if __name__ == '__main__':
    unittest.main()
