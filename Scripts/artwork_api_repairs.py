#!/usr/bin/env python3
"""Targeted, resumable repair generation; explicit installation with exact old hashes."""
import argparse
import copy
import contextlib
import datetime
import fcntl
import getpass
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import uuid
import webbrowser
import artwork_api_pilot as api
import install_artwork_batch as installer

ROOT = Path(__file__).resolve().parents[1]
PLAN = ROOT / 'Docs/ArtworkRepairPlan20261125.json'
OUTPUT = ROOT / '.artwork-api/repairs-20261125'


def read(path): return json.loads(Path(path).read_text())
def digest(path): return api.sha(Path(path).read_bytes())


def choose_project():
    script = 'on run argv\nreturn POSIX path of (choose folder with prompt (item 1 of argv))\nend run'
    return Path(subprocess.check_output(['osascript', '-e', script, 'Kies de huidige app-projectmap met je illustraties.'], text=True).strip())


def repair_jobs(plan, project):
    project = Path(project).resolve()
    res = project / 'BirdingCompanion/Resources'
    catalog = {r['id']: r for r in read(res / 'WorldSpeciesCatalog.json')}
    if plan.get('scope') != 'repair' or plan.get('model') != 'gpt-image-2.5-sunburst-2026-09-08' or plan.get('quality') != 'medium':
        raise ValueError('Onbekend herstelplan/model/kwaliteit.')
    targets = plan['targets']
    if api.sha(json.dumps(targets, sort_keys=True, separators=(',', ':')).encode()) != plan.get('targetsSHA256'):
        raise ValueError('De vaste herstelinventaris is gewijzigd.')
    if not targets or len({t['key'] for t in targets}) != len(targets): raise ValueError('Dubbele/lege herstelopdracht.')
    jobs = []
    for target in targets:
        key = target['id'].replace(':', '-') + '-' + target['role']
        if (target['role'] not in ('primary','dynamic') or target['key'] != key or not re.fullmatch(r'[0-9a-f]{64}', target['originalSHA256'])
            or catalog[target['id']]['scientificName'] != target['scientificName']):
            raise ValueError('Onbekende of onveilige soort/rol: ' + key)
        if not target['sourceURLs'] or not target['fieldMarks']: raise ValueError('Diagnostiek/bron ontbreekt: ' + key)
        reference = project / plan['referenceAssets'][target['role']]
        prompt = '\n\n'.join([plan['style'],
            f"Rebuild an accurate original illustration of {target['englishName']} ({target['scientificName']}), {target['representativePlumage']}.",
            'Diagnostic features: ' + target['fieldMarks'], plan['roles'][target['role']]['direction'],
            'Correction: ' + target['correction'],
            'Scene: ' + target['dynamicScene'] if target['role'] == 'dynamic' else 'Bird only, naturally standing upright, facing RIGHT, both wings closed; no props.',
            'Do not reproduce the rejected anatomical template or substitute a similar species. The attached kingfisher is STYLE ONLY.', api.COMPOSITION_RULES])
        jobs.append(dict(key=key,id=target['id'],role=target['role'],prompt=prompt,
            size=plan['roles'][target['role']]['size'],reference=str(reference),referenceSHA256=digest(reference),
            representativePlumage=target['representativePlumage'],referenceURL=target['sourceURLs'][-1],dutchName=target['dutchName']))
    if not set(plan['pilotKeys']).issubset({j['key'] for j in jobs}): raise ValueError('Proefselectie ontbreekt.')
    return jobs


def refresh_review(jobs, state, output):
    from PIL import Image
    output = Path(output)
    api.review_files(jobs, state, output)
    report = []
    for job in jobs:
        status = state.get('jobs', {}).get(job['key'], {})
        if status.get('status') != 'generated_unreviewed': continue
        with Image.open(output / status['file']) as image:
            bounds = image.getchannel('A').point(lambda a: 255 if a > 16 else 0).getbbox()
            margin = (image.width - bounds[2]) / image.width if bounds else 0
        report.append(dict(key=job['key'], rightClearance=margin, minimumRightClearance=0.06,
                           passesRightClearance=margin >= 0.06, anatomyAssessed=False, plumageAssessed=False))
    api.write_json(output/'framing-report.json', report)
    failed = [r['key'] for r in report if not r['passesRightClearance']]
    if failed:
        page = output/'review.html'
        banner = '<div style="padding:20px;background:#f5dfc3">Rechterrandcontrole afgekeurd: ' + ', '.join(failed) + '. Deze beelden kunnen niet worden geïnstalleerd. Geen automatische hergeneratie.</div>'
        page.write_text(banner+page.read_text())
    return report


def completed_rows(plan, project, output):
    jobs = repair_jobs(plan, project)
    state = read(Path(output)/'state.json')
    if state['recipeSHA256'] != api.sha(json.dumps(plan, sort_keys=True).encode()): raise ValueError('Checkpoint hoort bij een ander herstelplan.')
    refresh_review(jobs, state, output)
    rows = read(Path(output)/'review-template.json')
    targets = {t['id']+':'+t['role']: t for t in plan['targets']}
    for row in rows:
        key = row['id'].replace(':','-')+'-'+row['role']; status = state['jobs'][key]
        if digest(row['path']) != status['outputSHA256']: raise ValueError('Nieuw beeld is gewijzigd: ' + key)
        row['repairOfSHA256'] = targets[row['id']+':'+row['role']]['originalSHA256']
    if not rows: raise ValueError('Er zijn nog geen voltooide herstelbeelden.')
    return rows


def image_hashes(folder):
    names = {row['filename'] for row in read(folder/'Contents.json').get('images',[]) if row.get('filename')}
    if not names or any(Path(n).name != n for n in names): raise ValueError('Onvolledige imageset: ' + str(folder))
    return {digest(folder/n) for n in names}


@contextlib.contextmanager
def project_lock(project):
    folder = Path(project)/'.artwork-api'; folder.mkdir(exist_ok=True)
    with (folder/'repair-install.lock').open('a') as handle:
        try: fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError: raise ValueError('Er loopt al een herstelimport in deze app-map.') from None
        try: yield folder/'pending-repair-install.json'
        finally: fcntl.flock(handle, fcntl.LOCK_UN)


def recover(project, journal):
    project = Path(project).resolve(); journal = Path(journal)
    if not journal.exists(): raise ValueError('Geen onderbroken herstelinstallatie gevonden.')
    data = read(journal); backup = Path(data['backup']).resolve()
    if not backup.is_relative_to(project/'.artwork-api/repair-import-backups'): raise ValueError('Onveilig herstelpad.')
    res = project/'BirdingCompanion/Resources'; mp = res/'ArtworkManifest.json'
    if digest(mp) not in (data['oldManifestSHA256'], data['newManifestSHA256']):
        raise ValueError('Manifest is buiten deze import gewijzigd; herstel eerst handmatig met de bewaarde kopie.')
    for entry in data['entries']:
        asset = entry['asset']
        if Path(asset).name != asset: raise ValueError('Onveilig assetpad.')
        folder = res/'Assets.xcassets'/(asset+'.imageset'); old = backup/(asset+'.imageset')
        if folder.exists() and entry['newSHA256'] not in image_hashes(folder):
            # A folder not yet swapped is still the exact rejected source.
            if entry['oldSHA256'] in image_hashes(folder) and not old.exists(): continue
            raise ValueError('Een afbeelding is buiten deze import gewijzigd: ' + asset)
        if folder.exists(): shutil.rmtree(folder)
        if old.exists(): old.rename(folder)
        elif entry['existed']: raise ValueError('De originele herstelkopie ontbreekt: ' + asset)
    temporary = mp.with_suffix('.repair-restore.tmp')
    shutil.copy2(backup/'ArtworkManifest.json',temporary); os.replace(temporary,mp)
    journal.unlink()
    stage = Path(data.get('stage', '')).resolve()
    if stage.is_relative_to(project/'.artwork-api') and stage.name.startswith('repair-stage-'):
        shutil.rmtree(stage, ignore_errors=True)


def install_completed(plan, project, output, accept=False, after_swap=None):
    if not accept: raise ValueError('Controleer de nieuwe beelden en bevestig de installatie expliciet.')
    project = Path(project).resolve(); res = project/'BirdingCompanion/Resources'
    with project_lock(project) as journal:
        if journal.exists(): raise ValueError('Vorige installatie onderbroken. Kies eerst Herstel onderbroken installatie.')
        rows = completed_rows(plan, project, output)
        framing = read(Path(output)/'framing-report.json')
        if any(not row['passesRightClearance'] for row in framing):
            raise ValueError('Een nieuw beeld heeft onvoldoende vrije rechterrand. Bekijk framing-report.json; niets geïnstalleerd en geen automatische hergeneratie.')
        old_manifest = read(res/'ArtworkManifest.json'); old_bytes = (res/'ArtworkManifest.json').read_bytes()
        selected=[]
        for row in rows:
            asset=row['id'].replace(':','-')+'-'+row['role']; folder=res/'Assets.xcassets'/(asset+'.imageset')
            records=[m for m in old_manifest if m['asset']==asset]
            if any(m.get('speciesID')==row['id'] and m.get('view')==row['role'] and m['asset']!=asset for m in old_manifest):
                raise ValueError('Conflicterende soort/rol in manifest: '+asset)
            if len(records)>1: raise ValueError('Dubbele manifestregistratie: '+asset)
            new_sha=digest(row['path'])
            if folder.exists():
                hashes=image_hashes(folder)
                if hashes=={new_sha} and len(records)==1 and records[0].get('sha256')==new_sha:continue
                if hashes!={row['repairOfSHA256']}: raise ValueError('Dit bestaande beeld wijkt af van je afgekeurde origineel: '+asset)
                if records and records[0].get('sha256') not in (None,row['repairOfSHA256']): raise ValueError('Manifest wijkt af van origineel: '+asset)
            elif records: raise ValueError('Manifest/assetmap onvolledig: '+asset)
            row=copy.deepcopy(row)
            row['ownerAcceptance']=dict(method='bulk-user-accepted-unreviewed',sha256=new_sha,acceptedAt=datetime.datetime.now(datetime.timezone.utc).isoformat())
            selected.append((row,folder,asset,records[0] if records else None))
        if not selected:return 0
        backup=project/'.artwork-api/repair-import-backups'/('repair-'+uuid.uuid4().hex)
        backup.mkdir(parents=True); (backup/'ArtworkManifest.json').write_bytes(old_bytes)
        stage=Path(tempfile.mkdtemp(prefix='repair-stage-',dir=project/'.artwork-api'))
        stage_res=stage/'Resources'; (stage_res/'Assets.xcassets').mkdir(parents=True)
        shutil.copy2(res/'WorldSpeciesCatalog.json',stage_res/'WorldSpeciesCatalog.json')
        api.write_json(stage_res/'ArtworkManifest.json',[])
        mapping=stage/'mapping.json';api.write_json(mapping,[r for r,_,_,_ in selected])
        previous=installer.RES
        try:
            installer.RES=stage_res
            installer.install(mapping,'api-repair-'+backup.name)
            new_records=read(stage_res/'ArtworkManifest.json')
            by_asset={r['asset']:r for r in new_records}
            for row,_,asset,old in selected:
                by_asset[asset]['replacesSHA256']=row['repairOfSHA256']
                by_asset[asset]['version']=(old.get('version',1) if old else 0)+1
            assets=set(by_asset)
            combined=[r for r in old_manifest if r['asset'] not in assets]+new_records
            api.write_json(stage/'new-manifest.json',combined)
            entries=[dict(asset=asset,oldSHA256=row['repairOfSHA256'],newSHA256=digest(row['path']),existed=folder.exists()) for row,folder,asset,_ in selected]
            api.write_json(journal,dict(backup=str(backup),stage=str(stage),oldManifestSHA256=api.sha(old_bytes),newManifestSHA256=digest(stage/'new-manifest.json'),entries=entries))
            for row,folder,asset,_ in selected:
                if folder.exists():folder.rename(backup/(asset+'.imageset'))
                (stage_res/'Assets.xcassets'/(asset+'.imageset')).rename(folder)
                if after_swap: after_swap()
            os.replace(stage/'new-manifest.json',res/'ArtworkManifest.json')
            journal.unlink()
        except BaseException:
            if journal.exists():recover(project,journal)
            raise
        finally:
            installer.RES=previous;shutil.rmtree(stage,ignore_errors=True)
        print('Herstelkopie van alle vervangen beelden en manifest:',backup)
        return len(selected)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project',type=Path)
    parser.add_argument('--output',type=Path,default=OUTPUT)
    parser.add_argument('--all',action='store_true')
    parser.add_argument('--execute',action='store_true')
    parser.add_argument('--install',action='store_true')
    parser.add_argument('--recover',action='store_true')
    parser.add_argument('--menu',action='store_true')
    args=parser.parse_args();plan=read(PLAN)
    if args.menu:
        print('1. Maak de proef van 6 beelden\n2. Maak alle 77 herstelbeelden (reeds gemaakte worden overgeslagen)\n3. Bekijk resultaten\n4. Installeer gemaakte beelden na controle\n5. Herstel onderbroken installatie')
        choice=input('Keuze [1]: ').strip() or '1'
        if choice not in ['1','2','3','4','5']:raise ValueError('Ongeldige keuze.')
        args.execute=choice in ['1','2'];args.all=choice=='2';args.install=choice=='4';args.recover=choice=='5'
    project=args.project or choose_project()
    if args.recover:
        with project_lock(project) as journal:recover(project,journal)
        print('Originele installatie hersteld; geen API-aanvragen.');return
    jobs=repair_jobs(plan,project)
    if args.install:
        print('Bekijk eerst review.html. Alleen deze exacte herstelrollen worden vervangen; individuele QA wordt niet automatisch geclaimd.')
        if input('Typ JA om de gemaakte beelden te accepteren en installeren: ').strip()!='JA':print('Niets geïnstalleerd.');return
        print('Geïnstalleerd:',install_completed(plan,project,args.output,accept=True));return
    if args.execute:
        selected=jobs if args.all else [next(j for j in jobs if j['key']==key) for key in plan['pilotKeys']]
        cap = 5 if args.all else 1
        if (args.output/'state.json').exists():
            state = read(args.output/'state.json')
            completed_rows(plan, project, args.output)
            if all(state.get('jobs',{}).get(job['key'],{}).get('status') == 'generated_unreviewed' for job in selected):
                print('Deze selectie is al gemaakt. Geen API-sleutel of nieuwe aanvraag nodig.')
                if args.menu:webbrowser.open((args.output/'review.html').resolve().as_uri())
                return
        print(f'Maximaal {len(selected)} beelden; geen automatische installatie. Lokale kostenstop ${cap}, geen harde factureringslimiet.')
        api.validate_run_limits(plan,len(selected),cap)
        with api.production_lock():
            key=os.environ.get('OPENAI_API_KEY') or getpass.getpass('OpenAI API-sleutel (verborgen, niet bewaard): ')
            if not key.strip():raise ValueError('Geen sleutel: geen API-aanvraag.')
            state=api.run(plan,selected,args.output,key.strip(),len(selected),cap,after_save=lambda s:refresh_review(jobs,s,args.output))
            refresh_review(jobs,state,args.output)
    elif (args.output/'state.json').exists():completed_rows(plan,project,args.output)
    else:
        print(f'OFFLINE: {len(jobs)} rollen voor {len({j["id"] for j in jobs})} soorten; proef {len(plan["pilotKeys"])}. Geen API-aanvragen.');return
    review=args.output/'review.html'; print('Resultaten:',review)
    if args.menu:webbrowser.open(review.resolve().as_uri())


if __name__=='__main__':
    try:main()
    except (OSError,ValueError,RuntimeError,KeyError,subprocess.CalledProcessError) as error:raise SystemExit('Herstel gestopt: '+str(error))
