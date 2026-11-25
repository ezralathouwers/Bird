#!/usr/bin/env python3
"""Offline, recoverable import of logbook artwork followed by exact approved repairs."""
import argparse
import fcntl
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import uuid
import artwork_api_repairs as repairs
import local_artwork_import as local
import install_artwork_batch as installer

PLAN = Path(__file__).resolve().parents[1]/'Docs/ArtworkRepairPlan20261125.json'


def output_folder(source, name):
    source = Path(source).resolve()
    result = source if (source/'state.json').is_file() else source/'.artwork-api'/name
    if not (result/'state.json').is_file():
        raise ValueError('Geen gemaakte beelden gevonden in: '+str(result))
    return result


def skeleton(project, target, empty=False):
    res = target/'BirdingCompanion/Resources'
    (res/'Assets.xcassets').mkdir(parents=True)
    (target/'BirdingCompanion.xcodeproj').mkdir()
    shutil.copy2(project/'BirdingCompanion.xcodeproj/project.pbxproj',target/'BirdingCompanion.xcodeproj/project.pbxproj')
    shutil.copy2(project/'BirdingCompanion/Resources/WorldSpeciesCatalog.json',res/'WorldSpeciesCatalog.json')
    if empty: repairs.api.write_json(res/'ArtworkManifest.json',[])
    else: shutil.copy2(project/'BirdingCompanion/Resources/ArtworkManifest.json',res/'ArtworkManifest.json')
    return res


def install(project, logbook, repair_source, plan, after_swap=None):
    project=Path(project).resolve(); res=local.resources(project)
    logbook=output_folder(logbook,'logbook-medium'); repair_source=output_folder(repair_source,'repairs-20261125')
    lock_dir=project/'.artwork-api'; lock_dir.mkdir(exist_ok=True)
    with (lock_dir/'local-import.lock').open('a') as lock, repairs.project_lock(project) as journal:
        try: fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        except BlockingIOError: raise ValueError('Er loopt al een illustratie-import.') from None
        if journal.exists(): raise ValueError('Een vorige import is onderbroken. Start dit hulpmiddel opnieuw en kies 2 om die eerst terug te draaien.')
        manifest_snapshot=(res/'ArtworkManifest.json').read_bytes()
        stage=Path(tempfile.mkdtemp(prefix='repair-stage-',dir=lock_dir))
        try:
            # Validate every logbook candidate against an empty catalog before filtering
            # superseded originals. Old absolute paths in templates are never trusted.
            validation=stage/'validation'; skeleton(project,validation,empty=True)
            print('Logboekbeelden en checkpoints controleren…',flush=True)
            rows,_=local.candidates(logbook,validation)
            targets={t['key']:t for t in plan['targets']}
            state=repairs.read(repair_source/'state.json')
            if any(state.get('jobs',{}).get(key,{}).get('status')!='generated_unreviewed' for key in targets):
                raise ValueError('De herstelbatch is nog niet volledig. Geen beelden geïnstalleerd.')
            superseded=0; normal=[]
            for row in rows:
                key=row['id'].replace(':','-')+'-'+row['role']
                if key in targets:
                    if row['anatomyReview']['sha256'] not in (targets[key]['originalSHA256'],state['jobs'][key]['outputSHA256']):
                        raise ValueError('Logboekbeeld wijkt af van de geplande herstelversie: '+key)
                    superseded+=1
                else: normal.append(row)
            # Only touched imagesets and style references are copied. Unrelated app
            # assets stay in place, and their manifest records remain unchanged.
            app=stage/'app'; staged_res=skeleton(project,app)
            keys=set(targets)|{r['id'].replace(':','-')+'-'+r['role'] for r in normal}
            original={}
            for key in sorted(keys):
                folder=res/'Assets.xcassets'/(key+'.imageset')
                original[key]=repairs.image_hashes(folder) if folder.exists() else None
                if folder.exists():shutil.copytree(folder,staged_res/'Assets.xcassets'/folder.name)
            for relative in plan['referenceAssets'].values():
                source=project/relative; dest=app/relative
                dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,dest)
            available=[]
            for row in normal:
                if not local.installed(row,staged_res):available.append(row)
            if available:
                mapping=stage/'logbook-accepted.json'
                repairs.api.write_json(mapping,local.accept_all(available)['rows'])
                previous=installer.RES
                try:
                    installer.RES=staged_res
                    installer.install(mapping,'combined-logbook-'+uuid.uuid4().hex[:8])
                finally:installer.RES=previous
            print('Herstelbeelden controleren en klaarmaken…',flush=True)
            repaired=repairs.install_completed(plan,app,repair_source,accept=True)
            entries=[]
            for key in sorted(keys):
                folder=staged_res/'Assets.xcassets'/(key+'.imageset')
                hashes=repairs.image_hashes(folder)
                if hashes!=original[key]:
                    if len(hashes)!=1:raise ValueError('Onverwachte meerdere beeldversies: '+key)
                    entries.append(dict(asset=key,oldSHA256=next(iter(original[key])) if original[key] else '',newSHA256=next(iter(hashes)),existed=original[key] is not None))
            if not entries:
                print('Alles is al correct geïnstalleerd.');return dict(logbook=0,repairs=0,changed=0,superseded=superseded)
            old=(res/'ArtworkManifest.json').read_bytes()
            # Guard against external edits during preflight.
            for key,hashes in original.items():
                folder=res/'Assets.xcassets'/(key+'.imageset')
                if (repairs.image_hashes(folder) if folder.exists() else None)!=hashes:raise ValueError('App-beelden veranderden tijdens controle. Start opnieuw.')
            if old!=manifest_snapshot:raise ValueError('App-manifest veranderde tijdens controle. Start opnieuw.')
            backup=lock_dir/'repair-import-backups'/('repair-combined-'+uuid.uuid4().hex)
            backup.mkdir(parents=True);(backup/'ArtworkManifest.json').write_bytes(old)
            new=stage/'new-manifest.json';shutil.copy2(staged_res/'ArtworkManifest.json',new)
            repairs.api.write_json(journal,dict(backup=str(backup),stage=str(stage),oldManifestSHA256=repairs.api.sha(old),newManifestSHA256=repairs.digest(new),entries=entries))
            try:
                for entry in entries:
                    name=entry['asset']+'.imageset';folder=res/'Assets.xcassets'/name
                    if folder.exists():folder.rename(backup/name)
                    (staged_res/'Assets.xcassets'/name).rename(folder)
                    if after_swap:after_swap()
                os.replace(new,res/'ArtworkManifest.json');journal.unlink()
            except BaseException:
                repairs.recover(project,journal);raise
            print('Herstelkopie:',backup)
            return dict(logbook=len(available),repairs=repaired,changed=len(entries),superseded=superseded)
        finally:
            if not journal.exists():shutil.rmtree(stage,ignore_errors=True)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project',type=Path);parser.add_argument('--logbook',type=Path);parser.add_argument('--repairs',type=Path)
    parser.add_argument('--recover',action='store_true');args=parser.parse_args()
    project=args.project or local.choose('Kies je huidige Xcode-app-projectmap met BirdingCompanion.xcodeproj.')
    local.resources(project)
    if args.recover:
        (project/'.artwork-api').mkdir(exist_ok=True)
        with (project/'.artwork-api/local-import.lock').open('a') as lock, repairs.project_lock(project) as journal:
            fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB);repairs.recover(project,journal)
        print('De onderbroken import is teruggedraaid. Start de gewone import opnieuw.');return
    logbook=args.logbook or local.choose('Kies de bestaande Birder-Logboek-illustraties-map met je gemaakte beelden.')
    repair_source=args.repairs or local.choose('Kies de bestaande Birder-Illustratieherstel-map met de 77 goedgekeurde beelden.')
    print('Dit installeert de logboekbatch en daarna de goedgekeurde vervangingen. Geen generatie of API-kosten.\nAlleen de opgegeven rollen worden aangepast; bronbeelden en checkpoints blijven behouden.\nJA accepteert de beelden in bulk, inclusief positieve marges onder 6%; dit claimt geen individuele anatomiecontrole.')
    if input('Typ JA om beide batches te installeren: ').strip()!='JA':print('Niets geïnstalleerd.');return
    result=install(project,logbook,repair_source,repairs.read(PLAN))
    print('Klaar:',result['logbook'],'logboekbeelden toegevoegd;',result['repairs'],'herstelbeelden verwerkt.')
    print(result['superseded'],'afgekeurde logboekbeelden rechtstreeks vervangen door hun goedgekeurde herstelversie.')
    print('Bouw nu deze app-projectmap opnieuw in Xcode.')


if __name__=='__main__':
    try:main()
    except (ValueError,KeyError,OSError,AssertionError,subprocess.CalledProcessError) as error:raise SystemExit('Import gestopt: '+str(error))
