#!/usr/bin/env python3
"""Extract candidate numeric facts from cached ADW/Oiseaux species accounts.

Only explicit species-level wingspan fields are read. Never use AVONET wing
length or a subspecies card as a fallback. No prose/images enter the app.
"""
import argparse
import hashlib
import html
from html.parser import HTMLParser
import json
import pathlib
import re

from collect_wikipedia_spans import ROOT


class Text(HTMLParser):
    def __init__(self):
        super().__init__()
        self.parts = []
    def handle_data(self, data):
        self.parts.append(data)


def plain(fragment):
    parser = Text()
    parser.feed(fragment)
    return ' '.join(html.unescape(' '.join(parser.parts)).split())


def quantity(text):
    number = r'\d+(?:[.,]\d+)?'
    match = re.fullmatch(rf'({number})(?:\s*(?:to|à|[–−—-])\s*({number}))?\s*(mm|cm|m)', text.strip(), re.I)
    if not match:
        return None
    factor = {'mm': .1, 'cm': 1, 'm': 100}[match[3].lower()]
    low = round(float(match[1].replace(',', '.')) * factor, 6)
    high = low if match[2] is None else round(float(match[2].replace(',', '.')) * factor, 6)
    return dict(minimumCM=low, maximumCM=high) if 0 < low <= high < 500 else None


def adw_fields(source, scientific_name):
    heading = re.search(r'<h1\b[^>]*class="[^"]*rank--Species[^"]*"[^>]*>(.*?)</h1>', source, re.S | re.I)
    if not heading or plain(heading[1]) != scientific_name:
        return []
    section = re.search(r'<h2\b[^>]*id="physical_description"[^>]*>(.*?)</section>', source, re.S | re.I)
    if not section:
        return []
    result = []
    for match in re.finditer(r'<dt\b[^>]*>(.*?)</dt>\s*<dd\b[^>]*>(.*?)</dd>', section[1], re.S | re.I):
        label, value = plain(match[1]), plain(match[2])
        if label not in ['Range wingspan', 'Average wingspan']:
            continue
        parsed = quantity(value)
        if parsed:
            result.append(dict(**parsed, field=label, caption=value, identity='Exact rank--Species h1 scientific name'))
    return result


def oiseaux_fields(source, scientific_name):
    title = re.search(r'<title>(.*?)</title>', source, re.S | re.I)
    if not title or plain(title[1]).split(' - ')[-2:] != [scientific_name, 'Oiseaux.net']:
        return []
    field = re.search(r'<li\b[^>]*\btitle="Envergure"[^>]*>(.*?)</li>', source, re.S | re.I)
    if not field:
        return []
    value = re.search(r'<span\b[^>]*class="[^"]*v3b-morph-val[^"]*"[^>]*>(.*?)</span>', field[1], re.S | re.I)
    if not value:
        return []
    text = plain(value[1])
    parsed = quantity(text)
    return [dict(**parsed, field='Envergure', caption=text, identity='Exact scientific-name title; first primary Envergure card only')] if parsed else []


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('cache', type=pathlib.Path)
    parser.add_argument('--output', type=pathlib.Path, default=pathlib.Path('/tmp/regional-span-candidates.json'))
    args = parser.parse_args()
    plan = json.loads((ROOT / 'Docs/RegionalWingspanTargets.json').read_text())
    world = {r['id']: r for r in json.loads((ROOT / 'BirdingCompanion/Resources/WorldSpeciesCatalog.json').read_text())}
    existing = {r['speciesID']: r for r in json.loads((ROOT / 'BirdingCompanion/Resources/SpeciesDetails.json').read_text())}
    rows, stats = [], dict(targets=len(plan['targets']), downloaded=0, noField=[], unavailable=[])
    for target in plan['targets']:
        provider = target.get('provider', 'adw')
        sid, name = target['speciesID'], target['scientificName']
        if world[sid]['scientificName'] != name:
            raise ValueError('Target no longer matches catalog')
        if existing[sid]['wingspan'] is not None:
            continue
        path = args.cache / provider / (name.replace(' ', '_') + '.html')
        if not path.exists():
            stats['unavailable'].append(dict(speciesID=sid, provider=provider))
            continue
        stats['downloaded'] += 1
        source = path.read_text()
        candidates = (adw_fields if provider == 'adw' else oiseaux_fields)(source, name)
        if not candidates:
            stats['noField'].append(dict(speciesID=sid, provider=provider))
        for item in candidates:
            rows.append(dict(target, provider=provider, **item, sourceHTMLSHA256=hashlib.sha256(path.read_bytes()).hexdigest()))
    args.output.write_text(json.dumps(dict(candidates=rows, statistics=stats), ensure_ascii=False, indent=2)+'\n')
    print({k: len(v) if isinstance(v, list) else v for k, v in stats.items()}, 'candidate fields', len(rows))


if __name__ == '__main__':
    main()
