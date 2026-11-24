#!/usr/bin/env python3
"""Offline review/import for locally generated API artwork. No API calls or keys."""
import argparse
import copy
import datetime
import fcntl
import hashlib
import html
import json
from pathlib import Path
import shutil
import subprocess
import sys
import uuid
import webbrowser
from PIL import Image
import install_artwork_batch as installer

FORMAT = 'birder-artwork-review-v1'


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8'))


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def resources(project):
    res = Path(project).resolve() / 'BirdingCompanion/Resources'
    if not (Path(project) / 'BirdingCompanion.xcodeproj/project.pbxproj').is_file() or not (res / 'WorldSpeciesCatalog.json').is_file() or not (res / 'ArtworkManifest.json').is_file() or not (res / 'Assets.xcassets').is_dir():
        raise ValueError('Kies de volledige Birder-projectmap met BirdingCompanion.xcodeproj, niet het productie-/scriptpakket.')
    return res


def installed(row, res, index=None):
    asset = row['id'].replace(':', '-') + '-' + row['role']
    folder = res / 'Assets.xcassets' / (asset + '.imageset')
    records = index.get(asset, []) if index is not None else [r for r in read(res / 'ArtworkManifest.json') if r['asset'] == asset]
    if not records and not folder.exists():
        return False
    if len(records) == 1 and records[0].get('sha256') == row['anatomyReview']['sha256'] and (folder / 'Contents.json').is_file():
        images = read(folder / 'Contents.json').get('images', [])
        if any(i.get('filename') and (folder / i['filename']).is_file() and digest(folder / i['filename']) == records[0]['sha256'] for i in images):
            return True
    raise ValueError(f'{asset}: er bestaat al een ander of onvolledig beeld. Niets wordt overschreven.')


def candidates(source, project):
    source = Path(source).resolve()
    folders = [source] if (source / 'state.json').is_file() else [source / '.artwork-api' / n for n in ['pilot-medium', 'belgium-medium', 'logbook-medium']]
    res = resources(project)
    catalog = {r['id']: r for r in read(res / 'WorldSpeciesCatalog.json')}
    index = {}
    for record in read(res / 'ArtworkManifest.json'):
        index.setdefault(record['asset'], []).append(record)
    rows, seen, skipped = [], set(), 0
    for folder in folders:
        if not (folder / 'state.json').is_file():
            continue
        state = read(folder / 'state.json')
        template = read(folder / 'review-template.json')
        if len({(r['id'], r['role']) for r in template}) != len(template):
            raise ValueError('Dubbele soort/rol in review-template.json.')
        for original in template:
            row = copy.deepcopy(original)
            key = row['id'].replace(':', '-') + '-' + row['role']
            if row['role'] not in ['primary', 'dynamic'] or row['id'] not in catalog:
                raise ValueError(f'Onbekende soort of rol: {key}')
            if key in seen:
                raise ValueError(f'Dubbele kandidaat in de geselecteerde mappen: {key}')
            seen.add(key)
            job = state.get('jobs', {}).get(key, {})
            if job.get('status') != 'generated_unreviewed':
                raise ValueError(f'{key}: geen voltooide generatie in state.json.')
            filename = job.get('file', '')
            if not filename or Path(filename).name != filename or not filename.endswith('.png'):
                raise ValueError(f'{key}: onveilige of ontbrekende PNG-bestandsnaam.')
            path = folder / filename
            sha = digest(path)
            if sha != job.get('outputSHA256') or sha != row['anatomyReview'].get('sha256') or sha != row.get('generationProvenance', {}).get('outputSHA256'):
                raise ValueError(f'{key}: bestandshash wijkt af van API-registratie/review.')
            with Image.open(path) as image:
                image.load()
                if image.mode != 'RGBA' or min(image.size) < 1024 or image.getchannel('A').getextrema()[0] != 0 or image.getchannel('A').getextrema()[1] < 220:
                    raise ValueError(f'{key}: ongeldige afmetingen of transparantie.')
            row['path'] = str(path)
            row['previewURL'] = path.as_uri()
            row['sourceFolder'] = str(folder)
            row['displayName'] = catalog[row['id']].get('dutchName') or catalog[row['id']]['englishName']
            # Metadata/file checks never constitute visual approval.
            row['anatomyReview'] = dict(sha256=sha, twoWings=False, singleHeadAndBill=False, poseAndFraming=False, noProps=False)
            row['visualReview'] = dict(speciesPlumage=False, styleMatch=False, transparency=False, notes='')
            if installed(row, res, index):
                skipped += 1
            else:
                rows.append(row)
            if len(seen) % 50 == 0:
                print(f'{len(seen)} bestanden gecontroleerd…', flush=True)
        completed = {k for k, v in state.get('jobs', {}).items() if v.get('status') == 'generated_unreviewed'}
        template_keys = {r['id'].replace(':', '-') + '-' + r['role'] for r in template}
        if completed - template_keys:
            raise ValueError('review-template.json mist voltooide beelden. Bewaar de hele productiemap en laat dit eerst nakijken.')
    if not seen:
        raise ValueError('Geen productiemap gevonden. Kies de map met Start-Belgie-illustraties.command of de map met state.json en PNG’s.')
    return rows, skipped


def review_page(rows, destination):
    destination = Path(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    data = json.dumps(rows, ensure_ascii=True).replace('<', '\\u003c')
    cards = []
    for i, row in enumerate(rows):
        name = html.escape(row['displayName'] + ' — ' + ('standaard' if row['role'] == 'primary' else 'dynamisch'))
        uri = html.escape(Path(row['path']).as_uri(), quote=True)
        cards.append(f'<article><h2>{name}</h2><img loading="lazy" src="{uri}" alt="{name}"><button onclick="inspect({i})">Open origineel op volle grootte</button><label><input id="c{i}" type="checkbox" disabled onchange="approve({i},this.checked)">Ik heb dit origineel gecontroleerd en keur het goed.</label><p id="s{i}">Nog niet gecontroleerd</p></article>')
    page = '''<!doctype html><meta charset="utf-8"><title>Birder — illustraties controleren</title>
<style>body{background:#f5f2eb;color:#4c4b46;font:16px system-ui;margin:24px}header{position:sticky;top:0;background:#f5f2eb;padding:12px;z-index:1}main{display:flex;flex-wrap:wrap;gap:24px}article{width:340px;padding:16px;border:1px solid #d1c7ba;border-radius:16px}article img{width:100%;height:440px;object-fit:contain}label{display:block;margin-top:16px}button{padding:12px;border-radius:12px;cursor:pointer}dialog{max-width:95vw;max-height:95vh;background:#f5f2eb}dialog img{display:block;max-width:none}dialog section{position:sticky;top:0;background:#f5f2eb;padding:12px}h2{font-size:18px}</style>
<header><h1>Controleer je illustraties</h1><p>Open elk origineel. Controleer juiste soort/verenkleed, stijl, één kop en snavel, twee vleugels zonder extra gevouwen vleugel, natuurlijke poten, transparantie en volledige vogel. Standaard: alleen de vogel naar rechts, zonder attributen of schaduw. Dynamisch: bovenrand eindigt natuurlijk of vervaagt.</p><p>Vink alleen goedgekeurde beelden aan; laat twijfelgevallen leeg. Deze controle blijft lokaal, er worden geen beelden gegenereerd.</p><strong id="count"></strong> <button onclick="save()">Bewaar goedgekeurde selectie</button></header>
<main>CARDS</main><dialog id="full"><section><button onclick="document.getElementById('full').close()">Sluiten</button><span id="caption"></span></section><img id="original"></dialog>
<script>const rows=DATA;const selected=new Set();const inspected=new Set();
function key(i){return 'birder-review-v1:'+rows[i].id+':'+rows[i].role+':'+rows[i].anatomyReview.sha256}
function update(){document.getElementById('count').textContent=selected.size+' van '+rows.length+' goedgekeurd';}
function inspect(i){inspected.add(i);document.getElementById('c'+i).disabled=false;document.getElementById('original').src=rows[i].previewURL;document.getElementById('caption').textContent=rows[i].displayName;document.getElementById('full').showModal();}
function approve(i,yes){if(yes&&!inspected.has(i))return;if(yes)selected.add(i);else selected.delete(i);document.getElementById('s'+i).textContent=yes?'Goedgekeurd':'Niet goedgekeurd';try{localStorage.setItem(key(i),yes?'yes':'no')}catch(e){}update();}
function save(){const accepted=[...selected].sort((a,b)=>a-b).map(i=>{let r=structuredClone(rows[i]);for(const k of ['twoWings','singleHeadAndBill','poseAndFraming'])r.anatomyReview[k]=true;if(r.role==='primary')r.anatomyReview.noProps=true;for(const k of ['speciesPlumage','styleMatch','transparency'])r.visualReview[k]=true;r.visualReview.notes='Afzonderlijk visueel gecontroleerd door de eigenaar op '+new Date().toISOString();return r;});const blob=new Blob([JSON.stringify({format:'birder-artwork-review-v1',rows:accepted},null,2)],{type:'application/json'});const a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download='Birder-goedgekeurde-illustraties.json';a.click();setTimeout(()=>URL.revokeObjectURL(a.href),1000);}
rows.forEach((r,i)=>{try{if(localStorage.getItem(key(i))==='yes'){inspected.add(i);document.getElementById('c'+i).disabled=false;document.getElementById('c'+i).checked=true;approve(i,true)}}catch(e){}});update();</script>'''
    destination.write_text(page.replace('CARDS', ''.join(cards)).replace('DATA', data), encoding='utf-8')
    return destination


def accept_all(rows):
    accepted = copy.deepcopy(rows)
    date = datetime.datetime.now(datetime.timezone.utc).isoformat()
    for row in accepted:
        row['ownerAcceptance'] = dict(method='bulk-user-accepted-unreviewed',
            sha256=row['anatomyReview']['sha256'], acceptedAt=date)
        # Owner acceptance is not an anatomy attestation. Keep all flags false.
        row['anatomyReview'] = dict(sha256=row['anatomyReview']['sha256'],
            twoWings=False, singleHeadAndBill=False, poseAndFraming=False, noProps=False)
        row['visualReview'] = dict(speciesPlumage=False, styleMatch=False,
            transparency=False, notes='Door de eigenaar in bulk geaccepteerd; niet individueel visueel gecontroleerd.')
    return dict(format=FORMAT, rows=accepted)


def import_review(review_file, project):
    res = resources(project)
    document = read(review_file)
    if document.get('format') != FORMAT or not document.get('rows'):
        raise ValueError('Kies het JSON-bestand dat je via de controlepagina hebt bewaard, met minstens één goedgekeurd beeld.')
    selected = document['rows']
    # Re-read source checkpoints; bind approvals to exact files and metadata.
    known = {}
    skipped = 0
    for source in sorted({r['sourceFolder'] for r in selected}):
        available, already = candidates(source, project)
        skipped += already
        for r in available:
            known[(r['id'], r['role'])] = r
    accepted, seen = [], set()
    index = {}
    for record in read(res / 'ArtworkManifest.json'):
        index.setdefault(record['asset'], []).append(record)
    for decision in selected:
        key = (decision['id'], decision['role'])
        if key in seen:
            raise ValueError('Dubbele goedkeuring in het importbestand.')
        seen.add(key)
        if installed(decision, res, index):
            continue
        current = known.get(key)
        if current is None or current['anatomyReview']['sha256'] != decision.get('anatomyReview', {}).get('sha256'):
            raise ValueError('Bronbestand of registratie is gewijzigd. Maak de controlepagina opnieuw.')
        if decision.get('ownerAcceptance'):
            installer.validate_owner_acceptance(decision, Path(current['path']).read_bytes())
            normalized = accept_all([current])['rows'][0]
            current['anatomyReview'] = normalized['anatomyReview']
            current['visualReview'] = normalized['visualReview']
            current['ownerAcceptance'] = decision['ownerAcceptance']
        else:
            installer.validate_anatomy_review(decision, Path(current['path']).read_bytes())
            flags = ['speciesPlumage', 'styleMatch', 'transparency']
            if any(decision.get('visualReview', {}).get(k) is not True for k in flags):
                raise ValueError('Visuele goedkeuring ontbreekt.')
            if decision['role'] == 'primary' and decision['anatomyReview'].get('noProps') is not True:
                raise ValueError('Standaardbeeld moet zonder attributen zijn gecontroleerd.')
            current['anatomyReview'] = decision['anatomyReview']
            current['visualReview'] = decision['visualReview']
        accepted.append(current)
    if not accepted:
        return 0, skipped
    backup = Path(project) / '.artwork-api/import-backups' / (datetime.datetime.now().strftime('%Y%m%d-%H%M%S') + '-' + uuid.uuid4().hex[:8])
    backup.mkdir(parents=True)
    shutil.copy2(res / 'ArtworkManifest.json', backup / 'ArtworkManifest.json')
    mapping = backup / 'reviewed-import.json'
    mapping.write_text(json.dumps(accepted, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    targets = [res / 'Assets.xcassets' / (r['id'].replace(':', '-') + '-' + r['role'] + '.imageset') for r in accepted]
    if any(target.exists() for target in targets):
        raise ValueError('Een doelmap is ondertussen gewijzigd; er is niets overschreven.')
    old_res = installer.RES
    try:
        installer.RES = res
        installer.install(mapping, 'local-api-' + backup.name)
    except BaseException:
        # Only these new asset directories can be removed; preflight proved absence.
        for target in targets:
            if target.exists():
                shutil.rmtree(target)
        shutil.copy2(backup / 'ArtworkManifest.json', res / 'ArtworkManifest.json')
        raise
    finally:
        installer.RES = old_res
    return len(accepted), skipped


def choose(prompt, file=False):
    expression = 'POSIX path of (choose ' + ('file' if file else 'folder') + ' with prompt ' + json.dumps(prompt) + ')'
    return Path(subprocess.check_output(['osascript', '-e', expression], text=True).strip())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path)
    parser.add_argument('--source', type=Path)
    parser.add_argument('--review', type=Path)
    parser.add_argument('--accept-all', action='store_true', help='Owner accepts all primary/dynamic candidates without individual visual review')
    args = parser.parse_args()
    if args.accept_all and args.review:
        parser.error('--accept-all kan niet gecombineerd worden met --review')
    project = args.project or choose('Kies de Birder-projectmap met BirdingCompanion.xcodeproj waarin je de beelden wilt installeren.')
    resources(project)
    lock_folder = project / '.artwork-api'
    lock_folder.mkdir(exist_ok=True)
    with (lock_folder / 'local-import.lock').open('w') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise ValueError('Er loopt al een lokale illustratie-import. Sluit die eerst af.')
        mode = '3' if args.accept_all else '2' if args.review else '1' if args.source else input('1: controlepagina maken\n2: goedgekeurde selectie installeren\n3: alle beelden accepteren en direct installeren\nKies 1, 2 of 3: ').strip()
        if mode == '1':
            source = args.source or choose('Kies de productiemap met Start-Belgie-illustraties.command of Start-Logboek-illustraties.command (of de proefprojectmap).')
            rows, skipped = candidates(source, project)
            print(f'{len(rows)} nieuwe beelden beschikbaar; {skipped} identieke beelden al geïnstalleerd.')
            if rows:
                page = review_page(rows, lock_folder / 'local-review/controle.html')
                webbrowser.open(page.resolve().as_uri())
                print('Controleer de beelden en bewaar je selectie. Start daarna dit bestand opnieuw en kies 2.')
        elif mode in ['2', '3']:
            if mode == '3':
                source = args.source or choose('Kies de productiemap met Start-Belgie-illustraties.command of Start-Logboek-illustraties.command (of de proefprojectmap).')
                rows, skipped = candidates(source, project)
                if not rows:
                    print(f'Klaar: alle {skipped} beelden zijn al geïnstalleerd.')
                    return
                review = lock_folder / 'local-review/alles-geaccepteerd.json'
                review.parent.mkdir(parents=True, exist_ok=True)
                review.write_text(json.dumps(accept_all(rows), ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
                print(f'{len(rows)} beelden in bulk geaccepteerd; technische bestandscontrole uitgevoerd. Geen individuele anatomiecontrole geregistreerd.', flush=True)
            else:
                review = args.review or choose('Kies Birder-goedgekeurde-illustraties.json uit je Downloads.', file=True)
            count, skipped = import_review(review, project)
            queue = project / 'Scripts/illustration_production_queue.py'
            if count and queue.is_file():
                result = subprocess.run([sys.executable, str(queue)], capture_output=True, text=True)
                if result.returncode:
                    print('Beelden geïnstalleerd, maar de inventaris kon niet bijgewerkt worden:', result.stderr[-500:])
            print(f'Klaar: {count} beelden geïnstalleerd. Bestaande beelden behouden. Bouw de app opnieuw in Xcode.')
        else:
            raise ValueError('Kies 1, 2 of 3.')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, KeyError, OSError, AssertionError, subprocess.CalledProcessError) as error:
        print('Import niet voltooid:', error)
        raise SystemExit(1)
