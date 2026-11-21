#!/usr/bin/env python3
"""Cache public sources for wingspan review; never modify app data.

Resume by running with the same cache. Requests are serial, at least six seconds
apart; HTTP Retry-After is honored. A long server cooldown stops the run.
Full-text revisions allow 50 pages/request; full-article extracts allow only one.
"""
import argparse
import gzip
import hashlib
import json
import pathlib
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile

from collect_wikipedia_spans import ROOT, SNAPSHOT_SHA256
from collect_wikimedia_live_spans import values

AGENT = 'BirdingCompanionSpeciesResearch/1.0 (personal bird guide; source verification)'
QUERY = 'SELECT ?item ?name ?span ?unit WHERE { ?item wdt:P225 ?name; p:P2050/psv:P2050 ?v. ?v wikibase:quantityAmount ?span; wikibase:quantityUnit ?unit. }'


class Downloader:
    def __init__(self):
        self.last_request = 0

    def get(self, url):
        for attempt in range(4):
            time.sleep(max(0, 6 - (time.monotonic() - self.last_request)))
            self.last_request = time.monotonic()
            req = urllib.request.Request(url, headers={'User-Agent': AGENT,
                'Accept-Encoding': 'gzip', 'Accept': 'application/json, application/sparql-results+json'})
            try:
                with urllib.request.urlopen(req, timeout=45) as response:
                    blob = response.read()
                    if response.headers.get('Content-Encoding') == 'gzip':
                        blob = gzip.decompress(blob)
                result = json.loads(blob)
                if 'error' in result:
                    raise ValueError(result['error'])
                return result
            except urllib.error.HTTPError as error:
                if error.code not in [429, 503] or attempt == 3:
                    raise
                # Do not retry before the server's stated cooldown or change
                # hosts/User-Agent to evade it. Unparseable cooldowns stop too.
                delay = max(10, int(error.headers.get('Retry-After', '30')))
                if delay > 60:
                    raise RuntimeError(f'Server requests {delay}s cooldown; resume later') from error
                print(f'HTTP {error.code}; honoring Retry-After: {delay}s', flush=True)
                time.sleep(delay)
        raise RuntimeError('Download did not complete')


def write_json(path, value):
    temporary = path.with_suffix('.partial')
    temporary.write_text(json.dumps(value, ensure_ascii=False) + '\n')
    temporary.replace(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('snapshot', type=pathlib.Path)
    parser.add_argument('cache', type=pathlib.Path)
    parser.add_argument('--language', choices=['en', 'it', 'de', 'fr', 'es', 'pt', 'nl'], default='en')
    parser.add_argument('--max-batches', type=int, default=0, help='Limit Wikipedia batches this run (0 = all remaining)')
    args = parser.parse_args()
    if args.max_batches < 0:
        parser.error('--max-batches cannot be negative')
    if hashlib.sha256(args.snapshot.read_bytes()).hexdigest() != SNAPSHOT_SHA256:
        raise ValueError('Unexpected taxonomy snapshot')
    args.cache.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(args.snapshot) as archive:
        taxonomy = json.loads(archive.read('BirdNET+_Taxonomy_v0.5-Nov2026.json'))
    by_birdnet = {r['birdnet_id']: r for r in taxonomy}
    res = ROOT / 'BirdingCompanion/Resources'
    world = json.loads((res / 'WorldSpeciesCatalog.json').read_text())
    details = {r['speciesID']: r for r in json.loads((res / 'SpeciesDetails.json').read_text())}
    missing = {r['scientificName'] for r in world if details[r['id']]['wingspan'] is None}
    download = Downloader()
    query_path = args.cache / 'wikidata-query.json'
    if not query_path.exists():
        write_json(query_path, download.get('https://query.wikidata.org/sparql?' + urllib.parse.urlencode({'query': QUERY, 'format': 'json'})))
    matches = [r for r in json.loads(query_path.read_text())['results']['bindings'] if r['name']['value'] in missing]
    ids = sorted({r['item']['value'].rsplit('/', 1)[-1] for r in matches})
    entities = {}
    for path in args.cache.glob('wikidata-entities-*.json'):
        entities.update(json.loads(path.read_text())['entities'])
    remaining_ids = [qid for qid in ids if qid not in entities]
    for start in range(0, len(remaining_ids), 40):
        batch = '|'.join(remaining_ids[start:start + 40])
        path = args.cache / f'wikidata-entities-{hashlib.sha256(batch.encode()).hexdigest()}.json'
        if not path.exists():
            url = 'https://www.wikidata.org/w/api.php?' + urllib.parse.urlencode(dict(
                action='wbgetentities', ids=batch, props='claims|sitelinks|info', format='json'))
            write_json(path, download.get(url))
        entities.update(json.loads(path.read_text())['entities'])
    target_path = args.cache / f'{args.language}-targets.json'
    if not target_path.exists():
        targets = []
        for species in world:
            source = by_birdnet.get(species['birdnetID'])
            if species['scientificName'] not in missing or not source or source['scientific_name'] != species['scientificName']:
                continue
            url = source.get('wikipedia_urls', {}).get(args.language, '')
            if url.startswith(f'https://{args.language}.wikipedia.org/wiki/'):
                targets.append(dict(speciesID=species['id'], scientificName=species['scientificName'], sourceURL=url,
                    title=urllib.parse.unquote(url.split('/wiki/')[1]).replace('_', ' ')))
        write_json(target_path, targets)
    targets = json.loads(target_path.read_text())
    wd_names = {name for entity in entities.values() for name in values(entity, 'P225')}
    priority = {r['title'] for r in targets if r['scientificName'] in wd_names}
    titles = sorted({r['title'] for r in targets}, key=lambda t: (t not in priority, t))
    revisions = args.cache / 'revisions' if args.language == 'en' else args.cache / args.language / 'revisions'
    revisions.mkdir(parents=True, exist_ok=True)
    count = 0
    for start in range(0, len(titles), 50):
        params = dict(action='query', titles='|'.join(titles[start:start + 50]), redirects=1,
            prop='revisions|info|pageprops', rvprop='ids|content', rvslots='main', inprop='url', format='json', maxlag=5)
        url = f'https://{args.language}.wikipedia.org/w/api.php?' + urllib.parse.urlencode(params)
        path = revisions / (hashlib.sha256(url.encode()).hexdigest() + '.json')
        if path.exists():
            continue
        data = download.get(url)
        pages = list(data['query']['pages'].values())
        if any(not p.get('revisions') or '*' not in p['revisions'][0].get('slots', {}).get('main', {})
               for p in pages if 'missing' not in p):
            raise ValueError('Incomplete content response; not caching as successful')
        write_json(path, dict(requestURL=url, retrieved=time.strftime('%Y-%m-%d', time.gmtime()), response=data))
        count += 1
        print(f'{args.language}: cached full revisions {start + 1}–{start + len(pages)} / {len(titles)}', flush=True)
        if args.max_batches and count >= args.max_batches:
            break


if __name__ == '__main__':
    main()
