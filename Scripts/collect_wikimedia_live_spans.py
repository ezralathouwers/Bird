#!/usr/bin/env python3
"""Review candidates from cached full Wikipedia revisions and Wikidata entities.

This maintenance tool never modifies app data. Downloads stay outside the repo.
Wikipedia templates are normalized conservatively; unsupported templates remain
unparsed. Wikidata uncertainty bounds are NOT treated as biological ranges.
"""
import argparse
import hashlib
import html
import json
import pathlib
import re
import urllib.parse

from collect_wikipedia_spans import CONNECTOR, NUMBER, extract_ranges

ROOT = pathlib.Path(__file__).resolve().parents[1]
FACTORS = {'cm': 1, 'mm': .1, 'm': 100, 'in': 2.54, 'inch': 2.54,
           'inches': 2.54, 'ft': 30.48, 'feet': 30.48}
WD_FACTORS = {'Q174728': 1, 'Q174789': .1, 'Q11573': 100,
              'Q218593': 2.54, 'Q3710': 30.48}


def normalize_wikitext(text):
    """Normalize only simple convert templates; do not infer any missing value."""
    text = re.sub(r'<!--.*?-->', '', text, flags=re.S)
    text = re.sub(r'<ref\b[^>]*?/>|<ref\b[^>]*>.*?</ref\s*>', '', text, flags=re.S | re.I)

    def convert(match):
        args = [a.strip() for a in match[1].split('|') if '=' not in a]
        if not args:
            return match[0]
        # Both {{cvt|15|–|20|cm}} and {{convert|15–20|cm|in}}.
        if re.fullmatch(r'\d+(?:\.\d+)?\s*[–-]\s*\d+(?:\.\d+)?', args[0]):
            lo, hi = re.split(r'\s*[–-]\s*', args[0])
            unit = args[1] if len(args) > 1 else ''
        elif len(args) >= 4 and args[1] in ['to', 'to(-)', 'and', '-', '–', '−', '—']:
            lo, hi, unit = args[0], args[2], args[3]
        elif len(args) >= 2:
            lo, hi, unit = args[0], None, args[1]
        else:
            return match[0]
        if unit not in FACTORS or not re.fullmatch(r'\d+(?:\.\d+)?', lo):
            return match[0]
        if hi is not None and not re.fullmatch(r'\d+(?:\.\d+)?', hi):
            return match[0]
        factor = FACTORS[unit]
        low = float(lo) * factor
        if hi is None:
            return f'{low:.6g} cm'
        return f'{low:.6g}–{float(hi) * factor:.6g} cm'

    text = re.sub(r'\{\{(?:convert|cvt)\s*\|([^{}]+)\}\}', convert, text, flags=re.I)
    text = re.sub(r'\[\[[^\]|]+\|([^\]]+)\]\]', r'\1', text)
    text = re.sub(r'\[\[([^\]]+)\]\]', r'\1', text)
    text = re.sub(r"'{2,5}", '', text)
    text = html.unescape(text).replace('\xa0', ' ')
    text = re.sub(r'(\d+(?:\.\d+)?)\s*(cm|mm|m)\s*[–−—-]\s*(\d+(?:\.\d+)?)\s*\2\b',
                  r'\1–\3 \2', text)
    return re.sub(r'\bwing[ -]?spans?\b', 'wingspan', text, flags=re.I)


def extract_singles(text):
    # Only forward attachment. A suffix scan could pick the upper end of a
    # range, e.g. "19–22 cm wingspan", as a false single value of 22 cm.
    pattern = rf'wingspan{CONNECTOR}(?P<value>{NUMBER})\s*(?P<unit>cm|mm|m|inches|in|ft)\b(?!\s*(?:[–−—-]|\bto\b|\band\b))'
    result = []
    for match in re.finditer(pattern, text, re.I):
        if re.match(r'\s*(?:\([^)]{0,50}\))?\s*(?:[–−—-]|\bto\b|\band\b)', text[match.end():match.end() + 70], re.I):
            continue
        context = text[max(0, match.start() - 100):match.end() + 150]
        if re.search(r'estimat|\bmax(?:imum)?\b|\bmin(?:imum)?\b|record|largest|smallest|up to', context, re.I):
            continue
        cm = round(float(match['value'].replace(',', '.')) * FACTORS[match['unit'].lower()], 6)
        if 0 < cm < 500:
            result.append(dict(minimumCM=cm, maximumCM=cm,
                               measurementPhrase=match[0], context=context))
    return result


def taxobox_name(wikitext):
    # The first taxon/binomial or genus+species fields belong to the lead box.
    lead = re.split(r'^==', wikitext, maxsplit=1, flags=re.M)[0][:6000]
    lead = re.sub(r'<!--.*?-->', '', lead, flags=re.S)
    fields = {}
    for m in re.finditer(r'^\s*\|\s*(taxon|binomial|genus|species)\s*=\s*([^\n|{}<>]+)', lead, re.M | re.I):
        fields.setdefault(m[1].lower(), m[2].strip().strip("'"))
    if fields.get('taxon') or fields.get('binomial'):
        return fields.get('taxon') or fields['binomial']
    if fields.get('genus') and fields.get('species'):
        return fields['genus'] + ' ' + fields['species']
    return None


def wikipedia_candidates(cache, world, details):
    targets = json.loads((cache / 'en-targets.json').read_text())
    expected = {r['id']: r for r in world}
    existing = {r['speciesID']: r for r in details}
    pages, redirects, entities = {}, {}, {}
    for path in sorted(cache.glob('wikidata-entities-*.json')):
        entities.update(json.loads(path.read_text())['entities'])
    for path in sorted((cache / 'revisions').glob('*.json')):
        wrapper = json.loads(path.read_text())
        query = wrapper['response']['query']
        for r in query.get('normalized', []) + query.get('redirects', []):
            redirects[r['from']] = r['to']
        for r in query['pages'].values():
            if 'missing' not in r:
                pages[r['title']] = (r, path)
    candidates, stats = [], dict(targets=len(targets), downloadedPages=len(pages), exactTaxoboxPages=0, knownConceptExclusions=[])
    for target in targets:
        sid = target['speciesID']
        if sid not in expected or expected[sid]['scientificName'] != target['scientificName']:
            raise ValueError('Target no longer matches catalog')
        if existing[sid]['wingspan'] is not None:
            continue
        title = target['title']
        visited = set()
        while title in redirects and title not in visited:
            visited.add(title)
            title = redirects[title]
        if title not in pages:
            continue
        page, path = pages[title]
        revision = page.get('revisions', [{}])[0]
        raw = revision.get('slots', {}).get('main', {}).get('*', '')
        if page.get('ns') != 0 or 'disambiguation' in page.get('pageprops', {}) or taxobox_name(raw) != target['scientificName']:
            continue
        entity = entities.get(page.get('pageprops', {}).get('wikibase_item'))
        if entity and values(entity, 'P2026') and not same_avibase(expected[sid]['avibaseID'], values(entity, 'P2026')):
            stats['knownConceptExclusions'].append(dict(speciesID=sid, scientificName=target['scientificName'],
                reason='Linked Wikidata entity has a different Avibase concept; full-article taxobox name alone cannot resolve the scope.'))
            continue
        stats['exactTaxoboxPages'] += 1
        normalized = normalize_wikitext(raw)
        for value in extract_ranges(normalized, 'en') + extract_singles(normalized):
            candidates.append(dict(speciesID=sid, scientificName=target['scientificName'],
                sourceURL=page['fullurl'], revisionID=revision['revid'], language='en',
                permanentURL='https://en.wikipedia.org/w/index.php?' + urllib.parse.urlencode({'title': title, 'oldid': revision['revid']}),
                responseSHA256=hashlib.sha256(path.read_bytes()).hexdigest(), **value))
    return candidates, stats


def values(entity, property_id):
    return [c['mainsnak']['datavalue']['value'] for c in entity.get('claims', {}).get(property_id, [])
            if c.get('rank') != 'deprecated' and c['mainsnak'].get('snaktype') == 'value' and 'datavalue' in c['mainsnak']]


def has_reference(statement):
    return any(snak.get('snaktype') == 'value' and bool(snak.get('datavalue', {}).get('value'))
               for ref in statement.get('references', []) for prop in ['P248', 'P854']
               for snak in ref.get('snaks', {}).get(prop, []))


def same_avibase(app_id, source_ids):
    if not isinstance(app_id, str):
        return False
    app_id = app_id.removeprefix('avibase-').upper()
    # The app stores the canonical eight-character Avibase ID prefix.
    return bool(re.fullmatch(r'[0-9A-F]{8}(?:[0-9A-F]{8})?', app_id)) and any(
        isinstance(s, str) and re.fullmatch(r'[0-9A-Fa-f]{8}(?:[0-9A-Fa-f]{8})?', s)
        and (s.upper() == app_id or len(app_id) == 8 and s[:8].upper() == app_id) for s in source_ids)


def wikidata_candidates(cache, world, details):
    by_name = {r['scientificName']: r for r in world}
    existing = {r['speciesID']: r for r in details}
    result, deferred = [], []
    for path in sorted(cache.glob('wikidata-entities-*.json')):
        for qid, entity in json.loads(path.read_text())['entities'].items():
            names = values(entity, 'P225')
            if len(set(names)) != 1 or names[0] not in by_name:
                continue
            species = by_name[names[0]]
            if existing[species['id']]['wingspan'] is not None:
                continue
            claims = [c for c in entity.get('claims', {}).get('P2050', []) if c.get('rank') != 'deprecated']
            reason = None
            if not same_avibase(species['avibaseID'], values(entity, 'P2026')):
                reason = 'Avibase concept mismatch or unavailable; name alone is insufficient.'
            elif {v.get('id') for v in values(entity, 'P105')} != {'Q7432'}:
                reason = 'Taxon rank is not unambiguously species.'
            elif len(claims) != 1:
                reason = 'Multiple/absent active wingspan claims require review.'
            if reason:
                deferred.append(dict(speciesID=species['id'], scientificName=names[0], qid=qid, reason=reason))
                continue
            claim = claims[0]
            value = claim['mainsnak'].get('datavalue', {}).get('value', {})
            if claim.get('qualifiers'):
                reason = 'Qualified measurement scope requires review.'
            elif not has_reference(claim):
                reason = 'No stated source or reference URL.'
            elif 'lowerBound' in value or 'upperBound' in value:
                reason = 'Quantity uncertainty bounds are not a biological min/max range.'
            elif value.get('unit', '').rsplit('/', 1)[-1] not in WD_FACTORS:
                reason = 'Unsupported or absent length unit.'
            if reason:
                deferred.append(dict(speciesID=species['id'], scientificName=names[0], qid=qid, reason=reason))
                continue
            cm = round(float(value['amount']) * WD_FACTORS[value['unit'].rsplit('/', 1)[-1]], 6)
            if not 0 < cm < 500:
                deferred.append(dict(speciesID=species['id'], scientificName=names[0], qid=qid, reason='Invalid measurement.'))
                continue
            result.append(dict(speciesID=species['id'], scientificName=names[0],
                qid=qid, revisionID=entity['lastrevid'], minimumCM=cm, maximumCM=cm,
                sourceURL=f'https://www.wikidata.org/wiki/{qid}',
                permanentURL=f'https://www.wikidata.org/w/index.php?title={qid}&oldid={entity["lastrevid"]}',
                sourceAvibaseIDs=values(entity, 'P2026'), appAvibaseID=species['avibaseID'],
                statement=claim, responseSHA256=hashlib.sha256(path.read_bytes()).hexdigest()))
    return result, deferred


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('cache', type=pathlib.Path)
    parser.add_argument('--output', type=pathlib.Path, default=pathlib.Path('/tmp/live-wikimedia-span-candidates.json'))
    args = parser.parse_args()
    res = ROOT / 'BirdingCompanion/Resources'
    world = json.loads((res / 'WorldSpeciesCatalog.json').read_text())
    details = json.loads((res / 'SpeciesDetails.json').read_text())
    wiki, stats = wikipedia_candidates(args.cache, world, details)
    data, deferred = wikidata_candidates(args.cache, world, details)
    args.output.write_text(json.dumps(dict(wikipedia=wiki, wikidata=data, deferredWikidata=deferred, statistics=stats), ensure_ascii=False, indent=2) + '\n')
    print(dict(**{k: v for k, v in stats.items() if k != 'knownConceptExclusions'},
               knownConceptExclusions=len(stats['knownConceptExclusions']),
               wikipediaCandidatePhrases=len(wiki), wikidataCandidateSingles=len(data), deferredWikidata=len(deferred)))


if __name__ == '__main__':
    main()
