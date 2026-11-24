#!/usr/bin/env python3
"""Prepare/resume primary+dynamic API production from a local Birder backup.
History is processed locally; prompts contain public species information only.
No billable generation without --execute (the double-click launcher uses it).
"""
import argparse
import base64
import copy
import csv
import hashlib
import io
import json
from pathlib import Path
import subprocess
import sys
import webbrowser
import artwork_api_pilot as api

ROOT = Path(__file__).resolve().parents[1]


def normalized(value):
    return ' '.join(value.lower().split())


def history_ids(path, catalog):
    path = Path(path)
    if path.stat().st_size > 128 * 1024 * 1024:
        raise ValueError('De export is groter dan 128 MB.')
    raw = path.read_bytes()
    if path.suffix.lower() == '.csv':
        names = {}
        for bird in catalog.values():
            for name in [bird['scientificName']] + [p for alias in bird.get('aliases', []) for p in alias.split('|')]:
                names.setdefault(normalized(name), set()).add(bird['id'])
        ids = set()
        for row in csv.DictReader(io.StringIO(raw.decode('utf-8-sig'))):
            scientific = (row.get('scientificName') or '').strip()
            matched = names.get(normalized(scientific), set())
            if not scientific or len(matched) != 1:
                raise ValueError(f'CSV-soort is niet eenduidig gekoppeld: {scientific}')
            ids.update(matched)
    else:
        data = json.loads(raw)
        if isinstance(data, dict) and 'payload' in data:
            if data.get('format') != 'BirderBackup' or data.get('version') != 1:
                raise ValueError('Niet-ondersteunde back-up.')
            payload = base64.b64decode(data['payload'], validate=True)
            if hashlib.sha256(payload).hexdigest() != data.get('sha256'):
                raise ValueError('De back-upcontrole klopt niet. Er zijn geen beelden aangevraagd.')
            data = json.loads(payload)
        logs = data.get('observations') if isinstance(data, dict) else data
        if not isinstance(logs, list) or any(not isinstance(r, dict) or not isinstance(r.get('speciesID'), str) for r in logs):
            raise ValueError('Kies een Birder-back-up, waarnemingenexport of Birda-CSV.')
        ids = {r['speciesID'] for r in logs}
    if not ids:
        raise ValueError('De export bevat geen gelogde vogelsoorten.')
    unknown = ids - catalog.keys()
    if unknown:
        raise ValueError('Soort-ID ontbreekt in dit app-project: ' + ', '.join(sorted(unknown)))
    return ids, hashlib.sha256(raw).hexdigest()


def prepare(project, history):
    project = Path(project).resolve()
    res = project / 'BirdingCompanion/Resources'
    if not (project / 'BirdingCompanion.xcodeproj').is_dir():
        raise ValueError('Kies je volledige app-projectmap met BirdingCompanion.xcodeproj.')
    catalog = {r['id']: r for r in json.loads((res / 'WorldSpeciesCatalog.json').read_text())}
    logged, history_sha = history_ids(history, catalog)
    manifest = json.loads((res / 'ArtworkManifest.json').read_text())
    installed = {(r['speciesID'], r['view']) for r in manifest}
    hashes = {(r['speciesID'], r['view']): r.get('sha256') for r in manifest}
    missing = {}
    for species_id in sorted(logged):
        roles = []
        for role in ['primary', 'dynamic']:
            folder = res / 'Assets.xcassets' / (species_id.replace(':', '-') + '-' + role + '.imageset')
            if (species_id, role) in installed or folder.exists():
                metadata = folder / 'Contents.json'
                if not metadata.exists() or not any(i.get('filename') and (folder / i['filename']).is_file() for i in json.loads(metadata.read_text()).get('images', [])):
                    raise ValueError(f'Onvolledig bestaand beeld: {species_id} {role}. Eerst herstellen; geen vervanging of betaalde generatie gestart.')
                expected = hashes.get((species_id, role))
                if expected and not any(i.get('filename') and (folder / i['filename']).is_file() and api.sha((folder / i['filename']).read_bytes()) == expected for i in json.loads(metadata.read_text()).get('images', [])):
                    raise ValueError(f'Bestandshash van bestaand beeld wijkt af: {species_id} {role}. Eerst herstellen.')
            else: roles.append(role)
        if roles: missing[species_id] = roles
    plan = copy.deepcopy(json.loads((ROOT / 'Docs/ArtworkAPIPilot.json').read_text()))
    pilot_species = {r['id']: r for r in plan['species']}
    details = {r['speciesID']: r for r in json.loads((res / 'SpeciesDetails.json').read_text())} if (res / 'SpeciesDetails.json').exists() else {}
    assignments = {r['speciesID']: r for r in json.loads((res / 'SpeciesHabitatAssignments.json').read_text())} if (res / 'SpeciesHabitatAssignments.json').exists() else {}
    habitats = {r['id']: r for r in json.loads((res / 'HabitatScenes.json').read_text())} if (res / 'HabitatScenes.json').exists() else {}
    plan.update(scope='logbook', batchID='logbook-primary-dynamic', scopeSpeciesIDs=sorted(missing),
                scopeIDsSHA256=api.sha(json.dumps(sorted(missing), separators=(',', ':')).encode()),
                sourceHistorySHA256=history_sha, species=[])
    for species_id in missing:
        bird = catalog[species_id]
        if species_id in pilot_species:
            row = copy.deepcopy(pilot_species[species_id])
        else:
            detail = details.get(species_id, {})
            habitat = habitats.get(assignments.get(species_id, {}).get('primarySceneID'), {})
            brief = habitat.get('illustrationBrief', 'Minimal natural habitat appropriate to this exact bird species.')
            family = bird.get('family', '')
            if family in ['Apodidae', 'Hirundinidae']: action = 'Catching an insect in natural flight; two open wings and no extra folded wing silhouette.'
            elif family == 'Spheniscidae': action = 'Swimming underwater with exactly two extended flippers and a few subtle bubbles.'
            elif family == 'Anatidae': action = 'Floating naturally on a small patch of water with restrained ripples.'
            elif family == 'Picidae': action = 'Foraging on a short naturally ending tree trunk; upper trunk fades to transparent before the canvas edge.'
            elif family in ['Accipitridae', 'Falconidae']: action = 'Species-correct hunting flight or alert natural perch; exactly two wings, no retained folded wing beside an open wing.'
            elif family == 'Alcedinidae': action = 'Alert on a short branch watching for prey appropriate to this exact kingfisher species.'
            else: action = 'Natural species-specific foraging or alert posture; choose characteristic behaviour for this exact species.'
            bio = detail.get('bio', '')[:900]
            row = dict(id=species_id, dutchName=bird.get('dutchName') or bird['englishName'], englishName=bird['englishName'],
                scientificName=bird['scientificName'], representativePlumage='adult male, typical full plumage; same sex and plumage in both roles',
                fieldMarks='Render the diagnostic markings and proportions of this exact scientific species, not a similar relative. Public catalog background: ' + bio,
                dynamicScene=action + ' Minimal habitat reference: ' + brief,
                referenceURL=(detail.get('bioSourceURLs') or ['https://birdnet.cornell.edu/taxonomy/about'])[0])
        plan['species'].append(row)
    summary = dict(loggedSpecies=len(logged), speciesNeedingArtwork=len(missing), missingImages=sum(map(len, missing.values())),
                   missingRoles=missing, existingSpeciesComplete=len(logged)-len(missing))
    return plan, summary


def choose(prompt, file=False):
    # Pass human text as argv, never as AppleScript source. JSON's \uXXXX
    # escapes (e.g. in geïmporteerd) are not AppleScript string escapes.
    kind = 'file' if file else 'folder'
    expression = ('on run argv\n'
                  'return POSIX path of (choose ' + kind + ' with prompt (item 1 of argv))\n'
                  'end run')
    return Path(subprocess.check_output(['osascript', '-e', expression, prompt], text=True).strip())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path)
    parser.add_argument('--history', type=Path)
    parser.add_argument('--output', type=Path, default=ROOT / '.artwork-api/logbook-medium')
    parser.add_argument('--execute', action='store_true')
    args = parser.parse_args()
    project = args.project or choose('Kies de app-projectmap waarin je alle gemaakte illustraties hebt geïmporteerd.')
    output = args.output.resolve(); output.mkdir(parents=True, exist_ok=True)
    plan_path = output / 'plan.json'
    if plan_path.exists():
        plan = json.loads(plan_path.read_text())
        print('De vastgelegde logboekopdracht wordt hervat. Bestaande beelden/checkpoints blijven bewaard.')
    else:
        history = args.history or choose('Kies je recentste Birder-back-up (.json), of je Birda-export (.csv).', file=True)
        plan, summary = prepare(project, history)
        print(f"{summary['loggedSpecies']} gelogde soorten; {summary['speciesNeedingArtwork']} soorten met ontbrekend werk; {summary['missingImages']} nieuwe beelden.")
        if not summary['missingImages']:
            print('Je gelogde soorten hebben beide illustraties al. Geen API-aanvragen.'); return
        api.write_json(plan_path, plan)
        api.write_json(output / 'summary.json', summary)
    planned = api.jobs(plan, root=project)
    if not planned:
        print('Alle geplande beelden staan al in je app. Geen API-aanvragen.'); return
    print(f"Maximaal {len(planned)} ontbrekende rollen; raming circa ${len(planned)*0.026:.2f}, exclusief btw/hergeneraties.")
    print('Lokale verbruiksstop $25, geen harde factureringslimiet. Je sleutel wordt alleen verborgen in het geheugen gebruikt.')
    if not args.execute:
        print('OFFLINE: opdracht voorbereid, geen API-aanvragen.'); return
    command = [sys.executable, str(ROOT / 'Scripts/artwork_api_pilot.py'), '--project-root', str(project), '--plan', str(plan_path),
               '--output', str(output), '--execute', '--max-requests', str(len(planned)), '--spend-stop-usd', '25']
    result = subprocess.run(command)
    if (output / 'review.html').exists(): webbrowser.open((output / 'review.html').as_uri())
    raise SystemExit(result.returncode)


if __name__ == '__main__':
    try: main()
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        print('Opdracht niet gestart/afgerond:', error)
        raise SystemExit(1)
