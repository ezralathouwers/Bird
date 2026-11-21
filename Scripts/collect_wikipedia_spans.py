#!/usr/bin/env python3
"""Collect candidate facts from a pinned, licensed snapshot, never mutate the app.

Output requires review before adding it to SpeciesDetailsSupplements.json.
Exact names and Wikipedia flags are required; a source label alone does not
establish that its measurement is really a wingspan. See the review ledger.
"""
import argparse
import collections
import hashlib
import json
import pathlib
import re
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
SNAPSHOT_SHA256 = '433f0d19aabdd5c67a26501d05b8826ad23af4c33149771b5d908c7efa7e4fd1'
TERMS = {'en': 'wingspan', 'nl': 'spanwijdte', 'de': 'spannweite',
         'fr': 'envergure', 'es': 'envergadura', 'it': 'apertura alare', 'pt': 'envergadura'}
NUMBER = r'\d+(?:[.,]\d+)?'
RANGE = rf'(?P<lo>{NUMBER})\s*(?:[–−—-]|\bto\b|\band\b|\bet\b|\ba\b|\bà\b|\bbis\b|\be\b)\s*(?P<hi>{NUMBER})\s*(?P<unit>mm|cm|m|Metern|Zentimetern)\b'
# Only grammatical connectors: never skip past another measurement or sentence.
CONNECTOR = r"[\s:;,]*(?:(?:of|is|between|from|ranges|range|can|in|adult|birds|length|approximately|about|de|est|et|varie|variant|comprise|entre|s'étend|d'aile|wingspan|von|beträgt|liegt|bei|im|Bereich|bis|di|è|tra|attorno|ai|circa|e|alar|alas|es|va|das|asas|varia|cerca|do|dos|a|da|média|met|een|van)\b[\s:;,()'-]*)*"
IMPERIAL = rf'{NUMBER}\s*(?:[–-]|to)\s*{NUMBER}\s*(?:inches|inch|in|pol\.?|polegadas)\s*\('


def extract_ranges(text, language):
    """Return explicit metric ranges immediately attached to the span term."""
    term = TERMS[language]
    patterns = [rf'{term}{CONNECTOR}(?:{IMPERIAL})?{RANGE}']
    if language == 'en':
        patterns.append(rf'{RANGE}[^\S\n]*(?:\([^)]{{0,40}}\))?[^\S\n]*(?:in\s+)?wingspan\b(?!\s*:)')
    found = []
    for pattern in patterns:
        for match in re.finditer(pattern, text, re.I):
            low, high = [float(match[k].replace(',', '.')) for k in ['lo', 'hi']]
            factor = {'mm': .1, 'cm': 1, 'm': 100, 'metern': 100, 'zentimetern': 1}[match['unit'].lower()]
            low, high = round(low * factor, 4), round(high * factor, 4)
            if not 0 < low <= high < 500:
                continue
            context = text[max(0, match.start() - 100):match.end() + 150]
            if re.search(r'estimat|geschätzt|schatting|estimé|stimata|equiparabile', context, re.I):
                continue
            found.append({'minimumCM': low, 'maximumCM': high,
                          'measurementPhrase': match[0], 'context': context})
    return found


def collect(world, details, taxonomy):
    by_birdnet = {r['birdnet_id']: r for r in taxonomy}
    existing = {r['speciesID']: r for r in details}
    result = []
    for species in world:
        if existing[species['id']]['wingspan'] is not None:
            continue
        source = by_birdnet.get(species['birdnetID'])
        if not source or source['scientific_name'] != species['scientificName']:
            continue
        for lang in TERMS:
            if source.get('description_sources', {}).get(lang) != 'wikipedia':
                continue
            url = source.get('wikipedia_urls', {}).get(lang, '')
            if not url.startswith(f'https://{lang}.wikipedia.org/wiki/'):
                continue
            for value in extract_ranges(source.get('descriptions', {}).get(lang, ''), lang):
                result.append(dict(speciesID=species['id'], scientificName=species['scientificName'],
                                   language=lang, sourceURL=url, **value))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('snapshot', type=pathlib.Path)
    parser.add_argument('--output', type=pathlib.Path, default=pathlib.Path('/tmp/wikipedia-span-candidates.json'))
    args = parser.parse_args()
    if hashlib.sha256(args.snapshot.read_bytes()).hexdigest() != SNAPSHOT_SHA256:
        raise ValueError('Unexpected taxonomy snapshot')
    with zipfile.ZipFile(args.snapshot) as archive:
        taxonomy = json.loads(archive.read('BirdNET+_Taxonomy_v0.5-Nov2026.json'))
    res = ROOT / 'BirdingCompanion/Resources'
    rows = collect(json.loads((res / 'WorldSpeciesCatalog.json').read_text()),
                   json.loads((res / 'SpeciesDetails.json').read_text()), taxonomy)
    args.output.write_text(json.dumps(rows, ensure_ascii=False, indent=2) + '\n')
    grouped = collections.defaultdict(set)
    for row in rows:
        grouped[row['speciesID']].add((row['minimumCM'], row['maximumCM']))
    print(f'{len(rows)} candidate phrases, {len(grouped)} species; '
          f'{sum(len(v) > 1 for v in grouped.values())} conflicting species; review required')


if __name__ == '__main__':
    main()
