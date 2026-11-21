#!/usr/bin/env python3
"""Apply reviewed, exact-species supplements; never overwrite existing content.
Evidence is retained in Docs, not exposed in ordinary guide screens.
"""
import collections, hashlib, json, pathlib, re, urllib.parse
ROOT = pathlib.Path(__file__).resolve().parents[1]
RES = ROOT / 'BirdingCompanion/Resources'

def merge(rows, supplements):
    result = [dict(row) for row in rows]
    by_id = {row['speciesID']: row for row in result}
    seen = set()
    for item in supplements:
        target = by_id[item['speciesID']]
        if target['scientificName'] != item['scientificName'] or not item.get('evidence', {}).get('checked'):
            raise ValueError('Species identity and reviewed evidence are required')
        for field in ['bio', 'wingspan']:
            if field not in item:
                continue
            key = (item['speciesID'], field)
            if key in seen:
                raise ValueError('Duplicate supplement field')
            seen.add(key)
            if target[field] is not None:
                if target[field] != item[field]:
                    raise ValueError('Refusing to overwrite existing content')
                continue
            if field == 'bio':
                if not item[field].strip() or len(item[field]) > 1000 or item['bioMethod'] != 'source-summary-nl' or not item['bioSourceURLs'] or not all(u.startswith('https://') for u in item['bioSourceURLs']):
                    raise ValueError('Invalid sourced biography')
                target.update({k: item[k] for k in ['bio', 'bioMethod', 'bioSourceURLs']})
            else:
                span = item[field]
                if not (0 < span['minimumCM'] <= span['maximumCM'] < 500) or span['method'] not in ['source-checked-guide', 'source-reported-wikidata'] or span['sourceScientificName'] != item['scientificName'] or not span['sourceURL'].startswith('https://'):
                    raise ValueError('Invalid reported guide measurement')
                if span['method'] == 'source-reported-wikidata':
                    from collect_wikimedia_live_spans import WD_FACTORS, has_reference
                    url = urllib.parse.urlparse(span['sourceURL'])
                    if span['minimumCM'] != span['maximumCM'] or url.hostname != 'www.wikidata.org' or not re.fullmatch(r'/wiki/Q[0-9]+', url.path):
                        raise ValueError('Wikidata supplements must be single values with an entity source')
                    statement = item['evidence'].get('wikidataStatement', {})
                    if statement.get('mainsnak', {}).get('property') != 'P2050' or not has_reference(statement):
                        raise ValueError('Referenced Wikidata wingspan statement required')
                    quantity = statement['mainsnak'].get('datavalue', {}).get('value', {})
                    unit = quantity.get('unit', '').rsplit('/', 1)[-1]
                    if statement.get('rank') == 'deprecated' or statement.get('qualifiers') or 'lowerBound' in quantity or 'upperBound' in quantity or unit not in WD_FACTORS:
                        raise ValueError('Unscoped single quantity required, without uncertainty bounds')
                    if round(float(quantity['amount']) * WD_FACTORS[unit], 6) != span['minimumCM']:
                        raise ValueError('Wikidata statement and displayed value disagree')
                target[field] = span
    return result

def main():
    path = RES / 'SpeciesDetails.json'
    supplements_path = ROOT / 'Docs/SpeciesDetailsSupplements.json'
    supplements = json.loads(supplements_path.read_text())
    rows = merge(json.loads(path.read_text()), supplements)
    path.write_text('[\n' + ',\n'.join(json.dumps(x, ensure_ascii=False, separators=(',', ':')) for x in rows) + '\n]\n')
    provenance_path = RES / 'SpeciesDetailsProvenance.json'
    provenance = json.loads(provenance_path.read_text())
    provenance.update(records=len(rows), sha256=hashlib.sha256(path.read_bytes()).hexdigest(), supplementsSHA256=hashlib.sha256(supplements_path.read_bytes()).hexdigest())
    if any(r['wingspan'] and r['wingspan']['method'] == 'source-reported-wikidata' for r in rows):
        if 'Wikidata CC0' not in provenance['license']:
            provenance['license'] += '; Wikidata CC0'
        if not any(s['url'] == 'https://www.wikidata.org/wiki/Property:P2050' for s in provenance['sources']):
            provenance['sources'].append(dict(name='Wikidata P2050 source-reported single quantities; revisions and original citations retained in supplement evidence',
                url='https://www.wikidata.org/wiki/Property:P2050', license='CC0'))
    article_hosts = {urllib.parse.urlparse(r['wingspan']['sourceURL']).hostname for r in supplements
                     if 'articleRevisionID' in r.get('evidence', {}) and r.get('wingspan')}
    for host in sorted(h for h in article_hosts if h and re.fullmatch(r'[a-z]{2,3}\.wikipedia\.org', h)):
        url = f'https://{host}/'
        if not any(s['url'] == url for s in provenance['sources']):
            provenance['sources'].append(dict(name=f'Wikipedia full article revisions ({host}); exact revisions retained in supplement evidence',
                url=url, license='CC BY-SA 4.0'))
    provenance_path.write_text(json.dumps(provenance, indent=2) + '\n')
    summary = {'records': len(rows), 'bios': sum(r['bio'] is not None for r in rows), 'bioMethods': dict(collections.Counter(r['bioMethod'] for r in rows if r['bioMethod'])), 'wingspans': sum(r['wingspan'] is not None for r in rows), 'predictedWingspansImported': 0, 'missingBios': [r['speciesID'] for r in rows if r['bio'] is None], 'missingWingspans': [r['speciesID'] for r in rows if r['wingspan'] is None]}
    (ROOT / 'Docs/SpeciesDetailsCoverage.json').write_text(json.dumps(summary, indent=2) + '\n')
    estimates_path = RES / 'SpeciesWingspanEstimates.json'
    estimates_provenance = RES / 'SpeciesWingspanEstimatesProvenance.json'
    if estimates_path.exists() and estimates_provenance.exists():
        from build_wingspan_estimates import effective_coverage
        if hashlib.sha256(estimates_path.read_bytes()).hexdigest() != json.loads(estimates_provenance.read_text())['sha256']:
            raise ValueError('Estimate hash mismatch; reported data preserved, fallback coverage not refreshed')
        coverage = effective_coverage(rows, json.loads(estimates_path.read_text()))
        (ROOT / 'Docs/SpeciesWingspanCoverage.json').write_text(json.dumps(coverage, indent=2) + '\n')
    print({k: v for k, v in summary.items() if not k.startswith('missing')})

if __name__ == '__main__':
    main()
