#!/usr/bin/env python3
"""Freeze this owner's local rejected originals, then reuse the resumable repair pipeline."""
import argparse
import copy
import getpass
import json
import os
from pathlib import Path
import shutil
import webbrowser
import artwork_api_pilot as api
import artwork_api_repairs as repairs

ROOT = Path(__file__).resolve().parents[1]
SPEC = ROOT / 'Docs/ArtworkFollowup20261126.json'
OUTPUT = ROOT / '.artwork-api/followup-20261126'


def prepare(project, output, spec_path=SPEC):
    """Never rebind an existing checkpoint to a newer/different rejected original."""
    project = Path(project).resolve(); output = Path(output).resolve()
    spec_path = Path(spec_path)
    spec = repairs.read(spec_path)
    frozen = output / 'plan.json'
    if frozen.exists():
        plan = repairs.read(frozen)
        if plan.get('intakeSHA256') != repairs.digest(spec_path):
            raise ValueError('De opdracht is gewijzigd. Bewaar deze resultaten; gebruik een aparte vervolgronde.')
        repairs.repair_jobs(plan, project)
        return plan
    if (output / 'state.json').exists():
        raise ValueError('Checkpoint zonder bijbehorend lokaal plan; niets opnieuw gemaakt.')
    res = project / 'BirdingCompanion/Resources'
    catalog = {r['id']: r for r in repairs.read(res / 'WorldSpeciesCatalog.json')}
    manifest = repairs.read(res / 'ArtworkManifest.json')
    plan = copy.deepcopy(spec)
    plan['intakeSHA256'] = repairs.digest(spec_path)
    snapshots = []
    for target in plan['targets']:
        species = catalog[target['id']]
        if species['scientificName'] != target['scientificName']:
            raise ValueError('Taxonomie wijkt af: ' + target['id'])
        target['englishName'] = species['englishName']
        target['dutchName'] = species['dutchName']
        asset = target['id'].replace(':', '-') + '-' + target['role']
        target['key'] = asset
        folder = res / 'Assets.xcassets' / (asset + '.imageset')
        records = [r for r in manifest if r['asset'] == asset]
        if any(r.get('speciesID') == target['id'] and r.get('view') == target['role'] and r['asset'] != asset for r in manifest):
            raise ValueError('Conflicterende soort/rol: ' + asset)
        if len(records) > 1:
            raise ValueError('Dubbele manifestregistratie: ' + asset)
        if target['operation'] == 'create':
            if folder.exists() or records:
                raise ValueError('Nieuwe rol bestaat al; niet overschreven: ' + asset)
            target['originalSHA256'] = None
        else:
            if not folder.is_dir() or len(records) != 1:
                raise ValueError('Kies de huidige volledige appmap. Afgekeurd origineel ontbreekt: ' + asset)
            hashes = repairs.image_hashes(folder)
            if len(hashes) != 1:
                raise ValueError('Meerdere bronversies voor dezelfde rol: ' + asset)
            target['originalSHA256'] = next(iter(hashes))
            if records[0].get('sha256') not in (None, target['originalSHA256']):
                raise ValueError('Manifest en PNG verschillen: ' + asset)
            names = [r['filename'] for r in repairs.read(folder / 'Contents.json')['images'] if r.get('filename')]
            snapshots.append((asset, folder / names[0]))
    plan['targetsSHA256'] = api.sha(json.dumps(plan['targets'], sort_keys=True, separators=(',', ':')).encode())
    plan['referenceSHA256'] = {role: repairs.digest(project / path) for role, path in plan['referenceAssets'].items()}
    repairs.repair_jobs(plan, project)
    output.mkdir(parents=True, exist_ok=True)
    originals = output / 'originals'; originals.mkdir(exist_ok=True)
    for asset, path in snapshots:
        saved = originals / (asset + '.png')
        if saved.exists() and repairs.digest(saved) != repairs.digest(path):
            raise ValueError('Bewaard origineel verschilt; niets overschreven: ' + asset)
        if not saved.exists():
            shutil.copy2(path, saved)
    # Written last; an interrupted intake can safely repeat the same copies.
    api.write_json(frozen, plan)
    return plan


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path)
    parser.add_argument('--spec', type=Path, default=SPEC)
    parser.add_argument('--output', type=Path, default=OUTPUT)
    parser.add_argument('--menu', action='store_true')
    parser.add_argument('--execute', action='store_true')
    parser.add_argument('--install', action='store_true')
    parser.add_argument('--recover', action='store_true')
    args = parser.parse_args()
    spec = repairs.read(args.spec)
    count = len(spec['targets'])
    if args.menu:
        print(f'1. Maak de {count} correctie/nieuwe beelden (bestaande resultaten overslaan)\n2. Bekijk tussentijdse resultaten\n3. Installeer gemaakte beelden na controle\n4. Herstel onderbroken installatie')
        choice = input('Keuze [1]: ').strip() or '1'
        if choice not in ['1', '2', '3', '4']:
            raise ValueError('Ongeldige keuze.')
        args.execute = choice == '1'; args.install = choice == '3'; args.recover = choice == '4'
        if choice == '2':
            review = args.output / 'review.html'
            if not review.exists():
                raise ValueError('Nog geen resultaten. Start eerst optie 1.')
            print('Resultaten:', review.resolve()); webbrowser.open(review.resolve().as_uri()); return
    project = args.project or repairs.choose_project()
    if args.recover:
        with repairs.project_lock(project) as journal:
            repairs.recover(project, journal)
        print('Vorige installatie hersteld.'); return
    plan = prepare(project, args.output, args.spec)
    jobs = repairs.repair_jobs(plan, project)
    if args.install:
        print('Bekijk alle originelen in review.html: soortkenmerken, twee vleugels en vrije boven/rechterrand. Geen automatische anatomiegoedkeuring.')
        if input('Typ JA om alle gemaakte beelden te accepteren en installeren: ').strip() != 'JA':
            print('Niets geïnstalleerd.'); return
        print('Geïnstalleerd:', repairs.install_completed(plan, project, args.output, accept=True)); return
    if not args.execute:
        replacements = sum(t['operation'] == 'replace' for t in plan['targets'])
        print(f'Offline voorbereid: {replacements} vervangingen en {count - replacements} nieuwe rollen. Geen API-aanvragen.'); return
    if (args.output / 'state.json').exists():
        state = repairs.read(args.output / 'state.json')
        if all(state.get('jobs', {}).get(j['key'], {}).get('status') == 'generated_unreviewed' for j in jobs):
            repairs.completed_rows(plan, project, args.output)
            print(f'Alle {count} beelden bestaan al. Geen nieuwe API-aanvragen.')
            webbrowser.open((args.output / 'review.html').resolve().as_uri()); return
    print(f'{count} mediumbeelden, raming circa ${count * 0.027:.2f}–${count * 0.04:.2f} excl. btw/hergeneraties. Lokale kostenstop $2, geen harde factureringslimiet.')
    with api.production_lock():
        key = os.environ.get('OPENAI_API_KEY') or getpass.getpass('OpenAI API-sleutel (verborgen, niet bewaard): ')
        if not key.strip():
            raise ValueError('Geen sleutel: geen API-aanvraag.')
        state = api.run(plan, jobs, args.output, key.strip(), len(jobs), 2,
                        after_save=lambda s: repairs.refresh_review(jobs, s, args.output))
        repairs.refresh_review(jobs, state, args.output)
    print('Resultaten:', (args.output / 'review.html').resolve())
    webbrowser.open((args.output / 'review.html').resolve().as_uri())


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, RuntimeError, KeyError) as error:
        raise SystemExit('Illustratiecorrectie gestopt: ' + str(error))
