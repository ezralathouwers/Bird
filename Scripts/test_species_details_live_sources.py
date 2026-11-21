import copy
import json
import pathlib
import tempfile
import unittest

from collect_wikimedia_live_spans import normalize_wikitext, extract_singles, taxobox_name, same_avibase, wikidata_candidates
from collect_wikipedia_spans import extract_ranges


class LiveSourceTests(unittest.TestCase):
    def test_convert_templates_preserve_explicit_metric_range(self):
        for markup in ['{{convert|25|–|30|cm|in|abbr=on}}', '{{cvt|25-30|cm|in}}']:
            normalized = normalize_wikitext('[[wingspan]] of ' + markup)
            values = extract_ranges(normalized, 'en')
            self.assertEqual([(v['minimumCM'], v['maximumCM']) for v in values], [(25, 30)])
        self.assertEqual(normalize_wikitext('{{convert|1|to|2|m|ft}}'), '100–200 cm')
        self.assertEqual(normalize_wikitext('{{cvt|10|to|20|in|cm}}'), '25.4–50.8 cm')

    def test_reference_contents_and_weight_cannot_become_a_span(self):
        source = 'wingspan {{cvt|50|cm}}<ref>wingspan 200–300 cm</ref>; weight {{cvt|2|to|4|kg}}'
        self.assertEqual(extract_ranges(normalize_wikitext(source), 'en'), [])
        self.assertIn('{{cvt|2|to|4|kg}}', normalize_wikitext(source))

    def test_single_parser_never_uses_one_end_of_a_range(self):
        for text in ['wingspan between 18 cm – 22.5 cm', 'wingspan of 19–22 cm', 'a 19–22 cm wingspan', 'wingspan of 27 cm (10.6 in) to 28 cm (11.0 in)']:
            self.assertEqual(extract_singles(text), [])
        self.assertEqual(extract_singles('maximum wingspan of 55 cm'), [])
        normalized = normalize_wikitext('wingspan between 18 cm – 22.5 cm')
        self.assertEqual([(r['minimumCM'], r['maximumCM']) for r in extract_ranges(normalized, 'en')], [(18, 22.5)])
        self.assertEqual(extract_singles('wingspan of 50 cm')[0]['minimumCM'], 50)

    def test_taxobox_identity_is_not_inferred_from_body_mentions(self):
        self.assertEqual(taxobox_name('{{Speciesbox\n| taxon = Exact bird\n}}'), 'Exact bird')
        self.assertEqual(taxobox_name('{{Speciesbox\n| genus = Exact\n| species = bird\n}}'), 'Exact bird')
        self.assertEqual(taxobox_name('{{Speciesbox\n| taxon = Other bird\n}}\nRelated to Exact bird'), 'Other bird')
        self.assertIsNone(taxobox_name('Exact bird\n==Taxonomy==\n| taxon = Exact bird'))

    def test_avibase_concepts_require_an_exact_stored_identifier(self):
        self.assertTrue(same_avibase('avibase-1234ABCD', ['1234ABCD567890AB']))
        self.assertFalse(same_avibase('avibase-1234ABCD', ['1234ABCE567890AB']))
        self.assertFalse(same_avibase('avibase-1234ABCD', []))

    def test_wikidata_uncertainty_and_qualified_values_are_deferred(self):
        entity = {'lastrevid': 123, 'claims': {}}
        def claim(value):
            return {'rank': 'normal', 'mainsnak': {'snaktype': 'value', 'datavalue': {'value': value}}}
        entity['claims'] = {'P225': [claim('Exact bird')], 'P2026': [claim('1234ABCD567890AB')],
                            'P105': [claim({'id': 'Q7432'})],
                            'P2050': [dict(claim({'amount': '+0.5', 'unit': 'http://www.wikidata.org/entity/Q11573'}), references=[{'snaks': {'P248': [{'snaktype': 'value', 'datavalue': {'value': {'id': 'Q456'}}}]}}])]}
        world = [dict(id='id', scientificName='Exact bird', avibaseID='avibase-1234ABCD')]
        details = [dict(speciesID='id', wingspan=None)]
        with tempfile.TemporaryDirectory() as directory:
            cache = pathlib.Path(directory)
            def run(item):
                (cache / 'wikidata-entities-test.json').write_text(json.dumps({'entities': {'Q123': item}}))
                return wikidata_candidates(cache, world, details)
            candidates, deferred = run(entity)
            self.assertEqual(len(candidates), 1)
            self.assertEqual(candidates[0]['minimumCM'], 50)
            self.assertEqual(deferred, [])
            for mutate in ['bounds', 'scope', 'unreferenced', 'concept', 'multiple']:
                item = copy.deepcopy(entity)
                span = item['claims']['P2050'][0]
                if mutate == 'bounds': span['mainsnak']['datavalue']['value']['lowerBound'] = '+0.4'
                elif mutate == 'scope': span['qualifiers'] = {'P21': [{'snaktype': 'value'}]}
                elif mutate == 'unreferenced': span['references'] = []
                elif mutate == 'concept': item['claims']['P2026'] = [claim('DEADBEEF01234567')]
                elif mutate == 'multiple': item['claims']['P2050'].append(copy.deepcopy(span))
                with self.subTest(case=mutate):
                    found, rejected = run(item)
                    self.assertEqual(found, [])
                    self.assertEqual(len(rejected), 1)


if __name__ == '__main__':
    unittest.main()
