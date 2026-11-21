#!/usr/bin/env python3
"""Build user-authorized estimated fallbacks, separately from reported facts.

Priority: existing reported data, exact-name numeric Wingspan card, then the
Fox model selected by the source for an exact unique Avibase concept. Never
display game sentinels or model-derived bounds as an observed biological range.
"""
import argparse
import collections
import hashlib
import json
import math
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[1]
FOX_SHA = '6b55747a5761c08356d92c7a0b524b4e586c28a25316b0a6c1de3738db1d8eda'
GAME_SHA = '64f22ae0c2e69e07983e6580c7f9f400b7361f05c53c9a202412afc9f841c6b9'
GAME_TREE = '43e5036de9e68fa9c4fabaf4c760412a887adf05'
GAME_SOURCE = 'https://navarog.github.io/wingsearch/'
FOX_SOURCE = 'https://doi.org/10.6084/m9.figshare.32089083.v1'


def number(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value) and 0 < value < 500


def concept(value):
    if not isinstance(value, str):
        return None
    value = value.lower().removeprefix('avibase-')
    return value if re.fullmatch(r'[0-9a-f]{8}(?:[0-9a-f]{8})?', value) else None


def game_point(row):
    value = row.get('Wingspan')
    # The separate Americas mini-card file uses 0 for a game mechanic. This
    # builder accepts standard Bird cards only, never hummingbird mini cards.
    if row.get('CardType') != 'Bird' or not number(value):
        return None
    return float(value)


def fox_point(row):
    column = {'order_model': 'wingspan_predicted_order',
              'global_model': 'wingspan_predicted_global'}.get(row.get('model_used'))
    if row.get('needs_prediction') is not True or not column or not number(row.get(column)):
        return None
    return float(row[column]), column


def effective_coverage(details, estimates):
    by_id = {r['speciesID']: r for r in details}
    if len({r['speciesID'] for r in estimates}) != len(estimates):
        raise ValueError('Duplicate estimate identity')
    for row in estimates:
        if row['speciesID'] not in by_id or row['scientificName'] != by_id[row['speciesID']]['scientificName']:
            raise ValueError('Estimate no longer matches catalog')
        span = row['wingspan']
        expected_url = {'estimated-wingspan-game': GAME_SOURCE, 'estimated-fox-model': FOX_SOURCE}.get(span.get('method'))
        if not expected_url or span.get('sourceURL') != expected_url or not number(span.get('minimumCM')) or span.get('maximumCM') != span['minimumCM'] or not span.get('sourceScientificName'):
            raise ValueError('Invalid single-point estimate/source')
    active = [r for r in estimates if by_id[r['speciesID']]['wingspan'] is None]
    counts = collections.Counter(r['wingspan']['method'] for r in active)
    covered = {r['speciesID'] for r in active}
    reported = sum(r['wingspan'] is not None for r in details)
    return dict(records=len(details), reportedWingspans=reported,
        gameEstimates=counts['estimated-wingspan-game'], foxModelEstimates=counts['estimated-fox-model'],
        estimates=len(active), displayableWingspans=reported + len(active),
        missingWingspans=[r['speciesID'] for r in details if r['wingspan'] is None and r['speciesID'] not in covered])


def build(world, details, cards, fox_rows):
    by_id = {r['speciesID']: r for r in details}
    if len(by_id) != len(details) or {r['id'] for r in world} != set(by_id):
        raise ValueError('Catalog/detail identity mismatch')
    by_name, by_concept = collections.defaultdict(list), collections.defaultdict(list)
    for row in cards:
        if game_point(row) is not None:
            by_name[row['Scientific name']].append(row)
    for row in fox_rows:
        key = concept(row.get('Avibase.ID1'))
        if key:
            by_concept[key].append(row)
    output, evidence = [], []
    for bird in world:
        details_row = by_id[bird['id']]
        if details_row['scientificName'] != bird['scientificName']:
            raise ValueError('Scientific identity mismatch')
        if details_row['wingspan'] is not None:
            continue
        game = by_name.get(bird['scientificName'], [])
        source_name, value, method, url, proof = None, None, None, None, None
        if len(game) == 1:
            row = game[0]
            value, source_name = game_point(row), row['Scientific name']
            method, url = 'estimated-wingspan-game', GAME_SOURCE
            proof = dict(speciesID=bird['id'], source='wingspan-game',
                         gameCardID=row.get('id'), gameSet=row.get('Set'),
                         sourceScientificName=source_name, pointCM=value,
                         classification='Card value conservatively treated as an estimate; no per-card measured flag supplied')
        else:
            matches = by_concept.get(concept(bird.get('avibaseID')), [])
            if len(matches) == 1 and fox_point(matches[0]) is not None:
                row = matches[0]
                value, column = fox_point(row)
                source_name = row['Species1']
                method, url = 'estimated-fox-model', FOX_SOURCE
                proof = dict(speciesID=bird['id'], source='fox-model',
                             sourceScientificName=source_name, sourceAvibaseID=row['Avibase.ID1'],
                             appAvibaseID=bird['avibaseID'], model=row['model_used'], column=column,
                             pointCM=value)
        if value is None:
            continue
        output.append(dict(speciesID=bird['id'], scientificName=bird['scientificName'], wingspan=dict(
            minimumCM=value, maximumCM=value, method=method,
            sourceScientificName=source_name, sourceURL=url)))
        evidence.append(proof)
    coverage = effective_coverage(details, output)
    return output, evidence, coverage


def main():
    import openpyxl  # Maintenance only; no dependency added to the iOS app.
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('cards', type=pathlib.Path)
    parser.add_argument('fox', type=pathlib.Path)
    args = parser.parse_args()
    if hashlib.sha256(args.cards.read_bytes()).hexdigest() != GAME_SHA or hashlib.sha256(args.fox.read_bytes()).hexdigest() != FOX_SHA:
        raise ValueError('Unexpected source snapshot')
    res = ROOT / 'BirdingCompanion/Resources'
    world = json.loads((res / 'WorldSpeciesCatalog.json').read_text())
    details = json.loads((res / 'SpeciesDetails.json').read_text())
    sheet = openpyxl.load_workbook(args.fox, read_only=True, data_only=True)['wingspan data']
    iterator = sheet.iter_rows(values_only=True)
    header = next(iterator)
    fox_rows = [dict(zip(header, row)) for row in iterator]
    cards = json.loads(args.cards.read_text())
    rows, evidence, coverage = build(world, details, cards, fox_rows)
    path = res / 'SpeciesWingspanEstimates.json'
    path.write_text('[\n' + ',\n'.join(json.dumps(r, ensure_ascii=False, separators=(',', ':'), allow_nan=False) for r in rows) + '\n]\n')
    sources = [dict(name='Wingsearch numerical standard-card values', url=GAME_SOURCE,
                   gitTreeSHA=GAME_TREE, sha256=GAME_SHA, numericStandardCards=sum(game_point(r) is not None for r in cards),
                   snapshotURL=f'https://raw.githubusercontent.com/navarog/wingsearch/{GAME_TREE}/src/assets/data/master.json',
                   standardCards=len(cards), miniatureHummingbirdCardsExcluded=40,
                   rules='https://wingspan.rulepop.com/#wingspan',
                   policy='All game values treated as estimates. No game code, art, powers or flavor text are distributed.'),
               dict(name='Fox, Brunton & Shephard (2026), selected model point', url=FOX_SOURCE,
                    sha256=FOX_SHA, license='CC BY 4.0',
                    policy='Exact unique Avibase concept; selected order/global midpoint only. No model min/max range used.')]
    provenance = dict(version='wingspan-estimates-2026-11-21', authorized='User explicitly allowed estimated wingspans on 21 November 2026',
                      records=len(rows), sha256=hashlib.sha256(path.read_bytes()).hexdigest(), sources=sources)
    (res / 'SpeciesWingspanEstimatesProvenance.json').write_text(json.dumps(provenance, indent=2)+'\n')
    (ROOT / 'Docs/SpeciesWingspanCoverage.json').write_text(json.dumps(coverage, indent=2)+'\n')
    report = dict(sources=sources, policy=provenance['authorized'],
                  unmatchedGameScientificNames=sorted({r['Scientific name'] for r in cards} - {r['scientificName'] for r in world}),
                  records=evidence)
    records = report.pop('records')
    prefix = json.dumps(report, ensure_ascii=False, indent=2)[:-2]
    (ROOT / 'Docs/WingspanEstimateEvidence.json').write_text(prefix + ',\n  "records":[\n' +
        ',\n'.join(json.dumps(r, ensure_ascii=False, separators=(',', ':')) for r in records) + '\n  ]\n}\n')
    print({k: v for k, v in coverage.items() if k != 'missingWingspans'})


if __name__ == '__main__':
    main()
