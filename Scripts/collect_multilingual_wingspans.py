#!/usr/bin/env python3
"""Collect review candidates from complete Italian/German/French revisions.

No app data is changed. Uses cached responses produced by the Wikimedia
downloader, exact species-level taxobox identities and known-concept exclusions.
"""
import argparse
import hashlib
import json
import pathlib
import re
import urllib.parse

from collect_wikipedia_spans import ROOT, NUMBER, RANGE, TERMS
from collect_wikimedia_live_spans import normalize_wikitext, values, same_avibase

CONNECTORS = {
    'it': r"[\s:;,]*(?:(?:di|è|tra|fra|e|circa|compresa|attorno|ai|media|in|si|aggira|sui|misura)\b[\s:;,]*)*",
    'de': r"[\s:;,]*(?:(?:von|beträgt|liegt|bei|im|Bereich|etwa|rund|zwischen|ungefähr|bis)\b[\s:;,]*)*",
    'fr': r"[\s:;,]*(?:(?:de|est|et|varie|variant|comprise|entre|environ|d'environ|d'une|moyenne|pour|une|s'étend|d'aile)\b[\s:;,()]*)*",
}
UNIT_WORDS = {
    'de': {'Millimeter': 'mm', 'Millimetern': 'mm', 'Zentimeter': 'cm', 'Zentimetern': 'cm', 'Meter': 'm', 'Metern': 'm'},
    'it': {'millimetri': 'mm', 'centimetri': 'cm', 'metri': 'm'},
    'fr': {'millimètres': 'mm', 'centimètres': 'cm', 'mètres': 'm'},
}


def taxon_name(raw, language):
    lead = re.split(r'^==', re.sub(r'<!--.*?-->', '', raw, flags=re.S), maxsplit=1, flags=re.M)[0][:6000]
    if language == 'it':
        if re.search(r'^\s*\|\s*trinome\s*=[^\S\n]*\S', lead, re.M | re.I):
            return None
        match = re.search(r'^\s*\|\s*binome\s*=\s*([^\n|{}<>]+)', lead, re.M | re.I)
    elif language == 'de':
        if not re.search(r'^\s*\|\s*Taxon_Rang\s*=\s*Art\s*(?:\n|\||$)', lead, re.M | re.I):
            return None
        match = re.search(r'^\s*\|\s*Taxon_WissName\s*=\s*([^\n|{}<>]+)', lead, re.M | re.I)
    elif language == 'fr':
        match = re.search(r'\{\{Taxobox taxon\s*\|\s*animal\s*\|\s*espèce\s*\|\s*([^\n|{}<>]+)', lead, re.I)
    else:
        raise ValueError('Unsupported language')
    return match[1].strip().strip("'").strip() if match else None


def normalize(raw, language):
    if language == 'fr':
        # Basic unité templates encode explicit numbers/units. Leave nested or
        # unsupported formats untouched, rather than guessing their meaning.
        def unite(match):
            args = [v.strip() for v in match[1].split('|')]
            numeric = r'\d+(?:[.,]\d+)?'
            if len(args) >= 4 and re.fullmatch(numeric, args[0]) and args[1] in ['à', '–', '-', 'et'] and re.fullmatch(numeric, args[2]) and args[3] in ['cm', 'mm', 'm']:
                return f'{args[0]}–{args[2]} {args[3]}'
            if len(args) >= 2 and re.fullmatch(numeric, args[0]) and args[1] in ['cm', 'mm', 'm']:
                return f'{args[0]} {args[1]}'
            return match[0]
        raw = re.sub(r'\{\{(?:unité|unite)\|([^{}]+)\}\}', unite, raw, flags=re.I)
    text = normalize_wikitext(raw)
    for word, unit in UNIT_WORDS[language].items():
        text = re.sub(rf'\b{word}\b', unit, text, flags=re.I)
    return text


def measurements(text, language):
    term = TERMS[language]
    prefix = rf'{term}{CONNECTORS[language]}'
    # Include German "zwischen X und Y" without broad number proximity scans.
    interval = RANGE.replace(r'|\be\b', r'|\be\b|\bund\b')
    patterns = [rf'{prefix}{interval}', rf'{prefix}(?P<lo>{NUMBER})\s*(?P<unit>mm|cm|m)\b']
    result = []
    for is_single, pattern in enumerate(patterns):
        for match in re.finditer(pattern, text, re.I):
            if is_single and re.match(r'\s*(?:\([^)]{0,50}\))?\s*(?:[–−—-]|\bto\b|\band\b|\bbis\b|\bund\b|\bà\b|\ba\b|\be\b|\bet\b)', text[match.end():match.end()+70], re.I):
                continue
            context = text[max(0, match.start()-100):match.end()+150]
            if re.search(r'estimat|estimé|stimata|geschätzt|maximum|maximale|minimum|minimale|höchstens|höchste|bis zu|non supera|equiparabile', context, re.I):
                continue
            factor = {'cm': 1, 'mm': .1, 'm': 100}[match['unit'].lower()]
            low = round(float(match['lo'].replace(',', '.')) * factor, 6)
            high = low if is_single else round(float(match['hi'].replace(',', '.')) * factor, 6)
            if 0 < low <= high < 500:
                result.append(dict(minimumCM=low, maximumCM=high, measurementPhrase=match[0], context=context))
    return result


def collect(cache, language, world, details):
    targets = json.loads((cache / f'{language}-targets.json').read_text())
    by_id = {r['id']: r for r in world}
    existing = {r['speciesID']: r for r in details}
    entities, pages, redirects = {}, {}, {}
    for path in cache.glob('wikidata-entities-*.json'):
        entities.update(json.loads(path.read_text())['entities'])
    for path in sorted((cache / language / 'revisions').glob('*.json')):
        query = json.loads(path.read_text())['response']['query']
        for r in query.get('normalized', []) + query.get('redirects', []):
            redirects[r['from']] = r['to']
        for page in query['pages'].values():
            if 'missing' not in page:
                pages[page['title']] = (page, path)
    candidates = []
    stats = dict(targets=len(targets), downloadedPages=len(pages), identityEligiblePages=0, knownConceptExclusions=[])
    for target in targets:
        sid = target['speciesID']
        if by_id[sid]['scientificName'] != target['scientificName']:
            raise ValueError('Target identity no longer matches catalog')
        if existing[sid]['wingspan'] is not None:
            continue
        title, visited = target['title'], set()
        while title in redirects and title not in visited:
            visited.add(title)
            title = redirects[title]
        if title not in pages:
            continue
        page, path = pages[title]
        revision = page.get('revisions', [{}])[0]
        raw = revision.get('slots', {}).get('main', {}).get('*', '')
        if page.get('ns') != 0 or 'disambiguation' in page.get('pageprops', {}) or taxon_name(raw, language) != target['scientificName']:
            continue
        entity = entities.get(page.get('pageprops', {}).get('wikibase_item'))
        if entity and values(entity, 'P2026') and not same_avibase(by_id[sid]['avibaseID'], values(entity, 'P2026')):
            stats['knownConceptExclusions'].append(sid)
            continue
        stats['identityEligiblePages'] += 1
        for value in measurements(normalize(raw, language), language):
            candidates.append(dict(speciesID=sid, scientificName=target['scientificName'], language=language,
                sourceURL=page['fullurl'], articleRevisionID=revision['revid'],
                permanentURL=f'https://{language}.wikipedia.org/w/index.php?' + urllib.parse.urlencode(dict(title=title, oldid=revision['revid'])),
                responseSHA256=hashlib.sha256(path.read_bytes()).hexdigest(), **value))
    return candidates, stats


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('cache', type=pathlib.Path)
    parser.add_argument('--languages', nargs='+', choices=list(CONNECTORS), default=['it', 'de'])
    parser.add_argument('--output', type=pathlib.Path, default=pathlib.Path('/tmp/multilingual-span-candidates.json'))
    args = parser.parse_args()
    res = ROOT / 'BirdingCompanion/Resources'
    world = json.loads((res / 'WorldSpeciesCatalog.json').read_text())
    details = json.loads((res / 'SpeciesDetails.json').read_text())
    all_rows, statistics = [], {}
    for language in args.languages:
        if not (args.cache / f'{language}-targets.json').exists():
            continue
        rows, stats = collect(args.cache, language, world, details)
        all_rows.extend(rows)
        statistics[language] = stats
        print(language, {k: len(v) if isinstance(v, list) else v for k, v in stats.items()}, 'candidate phrases', len(rows))
    args.output.write_text(json.dumps(dict(candidates=all_rows, statistics=statistics), ensure_ascii=False, indent=2)+'\n')


if __name__ == '__main__':
    main()
