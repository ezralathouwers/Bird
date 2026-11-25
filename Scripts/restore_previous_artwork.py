#!/usr/bin/env python3
"""Restore missing artwork from an old app project; keep every newer destination image."""
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

ROOT=Path(__file__).resolve().parents[1]
REPORTED_NAMES={'Slangenarend','Steenarend','Vale gier','Zwarte wouw','Grauwe fitis','Humes bladkoning','Witkeelgors','Zanggors','Papegaaiduiker','Monniksparkiet'}
# Released source versions, before/after the optional thumbnail fallback.
KNOWN_SESSION_SOURCES={'7b4523e62d97bd6c192316adc6d97179d3d0961ce156d458771f09c789b18230', 'c5845aa21b96360fd14b1fb61c0c3fee2f8912cbb2f7466f2226ddad175dd340'}


def update_sessions(project):
    relative=Path('BirdingCompanion/Features/Sessions/SessionEnhancements.swift')
    target=Path(project)/relative;payload=ROOT/relative
    old=target.read_bytes();new=payload.read_bytes()
    if old==new:return False
    if repairs.api.sha(old) not in KNOWN_SESSION_SOURCES:
        raise ValueError('Onbekende versie van SessionEnhancements.swift; niets aan deze broncode gewijzigd.')
    backup=Path(project)/'.artwork-api/session-view-backups'/(repairs.api.sha(old)+'.swift')
    backup.parent.mkdir(parents=True,exist_ok=True)
    if backup.exists() and backup.read_bytes()!=old:raise ValueError('Herstelkopie wijkt af.')
    if not backup.exists():backup.write_bytes(old)
    fd,name=tempfile.mkstemp(dir=target.parent,prefix='.session-fix-')
    try:
        with os.fdopen(fd,'wb') as handle:handle.write(new)
        shutil.copymode(target,name);os.replace(name,target)
    finally:Path(name).unlink(missing_ok=True)
    return True


def restore(previous,project,after_swap=None):
    previous=Path(previous).resolve();project=Path(project).resolve()
    if previous==project:raise ValueError('Kies twee verschillende app-projectmappen: oud als bron, nieuw als bestemming.')
    old_res=local.resources(previous);res=local.resources(project)
    (project/'.artwork-api').mkdir(exist_ok=True)
    with (project/'.artwork-api/local-import.lock').open('a') as lock, repairs.project_lock(project) as journal:
        try:fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        except BlockingIOError:raise ValueError('Er loopt al een illustratie-import.') from None
        if journal.exists():raise ValueError('Onderbroken import gevonden. Kies eerst optie 3 om terug te draaien.')
        snapshot=(res/'ArtworkManifest.json').read_bytes();manifest=repairs.read(res/'ArtworkManifest.json')
        old_manifest=repairs.read(old_res/'ArtworkManifest.json')
        catalog={r['id'] for r in repairs.read(res/'WorldSpeciesCatalog.json')}
        index={}
        for row in manifest:index.setdefault(row['asset'],[]).append(row)
        seen=set();selected=[];kept=0;unknown=0
        for row in old_manifest:
            asset=row['asset']
            if asset in seen:raise ValueError('Dubbel oud manifestrecord: '+asset)
            seen.add(asset)
            if row.get('speciesID') not in catalog:unknown+=1;continue
            role=row.get('view')
            expected=row['speciesID'].replace(':','-')+'-'+str(role)
            if role not in ['primary','dynamic','front','rear','flight'] or asset!=expected:
                # Legacy sample artwork has custom names and is already in the download.
                if row['speciesID'].startswith('sample-'):continue
                raise ValueError('Onverwachte oude assetnaam: '+asset)
            dest=res/'Assets.xcassets'/(asset+'.imageset')
            if dest.exists() or asset in index:
                records=index.get(asset,[])
                if not dest.exists() or len(records)!=1 or records[0].get('sha256') not in repairs.image_hashes(dest):
                    raise ValueError('Onvolledige bestemming, niet overschreven: '+asset)
                kept+=1;continue
            source=old_res/'Assets.xcassets'/(asset+'.imageset')
            if not source.is_dir() or source.is_symlink() or not source.resolve().is_relative_to(old_res.resolve()):raise ValueError('Ontbrekende/onveilige bronmap: '+asset)
            names={x.get('filename') for x in repairs.read(source/'Contents.json').get('images',[]) if x.get('filename')}
            if any((source/name).is_symlink() for name in names):raise ValueError('Symlink in bronafbeelding: '+asset)
            hashes=repairs.image_hashes(source)
            if not row.get('sha256') or hashes!={row['sha256']}:
                raise ValueError('Oude afbeelding wijkt af van het manifest: '+asset)
            selected.append((row,source,dest))
        if not selected:return dict(restored=0,kept=kept,unknown=unknown)
        stage=Path(tempfile.mkdtemp(prefix='repair-stage-',dir=project/'.artwork-api'))
        try:
            entries=[]
            for row,source,dest in selected:
                shutil.copytree(source,stage/dest.name)
                if repairs.image_hashes(stage/dest.name)!={row['sha256']}:raise ValueError('Bron veranderde tijdens kopiëren: '+row['asset'])
                entries.append(dict(asset=row['asset'],oldSHA256='',newSHA256=row['sha256'],existed=False))
            if (res/'ArtworkManifest.json').read_bytes()!=snapshot or any(dest.exists() for _,_,dest in selected):
                raise ValueError('Bestemming veranderde tijdens controle. Niets geïnstalleerd.')
            backup=project/'.artwork-api/repair-import-backups'/('repair-carryover-'+uuid.uuid4().hex)
            backup.mkdir(parents=True);(backup/'ArtworkManifest.json').write_bytes(snapshot)
            new=stage/'new-manifest.json';repairs.api.write_json(new,manifest+[row for row,_,_ in selected])
            repairs.api.write_json(journal,dict(backup=str(backup),stage=str(stage),oldManifestSHA256=repairs.api.sha(snapshot),newManifestSHA256=repairs.digest(new),entries=entries))
            try:
                for _,_,dest in selected:
                    (stage/dest.name).rename(dest)
                    if after_swap:after_swap()
                os.replace(new,res/'ArtworkManifest.json');journal.unlink()
            except BaseException:
                repairs.recover(project,journal);raise
            print('Herstelkopie van manifest:',backup)
            return dict(restored=len(selected),kept=kept,unknown=unknown)
        finally:
            if not journal.exists():shutil.rmtree(stage,ignore_errors=True)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mode',choices=['both','sessions','recover'],default='both')
    args=parser.parse_args()
    project=local.choose('Kies je NIEUWE app-projectmap: die waarin je net de logboek- en herstelbeelden importeerde.')
    local.resources(project)
    if args.mode=='recover':
        (project/'.artwork-api').mkdir(exist_ok=True)
        with (project/'.artwork-api/local-import.lock').open('a') as lock, repairs.project_lock(project) as journal:
            fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB);repairs.recover(project,journal)
        print('Onderbroken import teruggedraaid.');return
    if update_sessions(project):print('Laadweergave van sessie-leefomgevingen bijgewerkt; broncodeherstelkopie bewaard.')
    else:print('Laadweergave van sessie-leefomgevingen was al bijgewerkt.')
    if args.mode=='both':
        previous=local.choose('Kies je OUDE volledige app-projectmap van voor deze update, met eerder geïmporteerde illustraties.')
        result=restore(previous,project)
        print(result['restored'],'ontbrekende illustraties overgenomen;',result['kept'],'bestaande/nieuwere versies behouden.')
        res=local.resources(project);missing=[]
        for bird in repairs.read(res/'WorldSpeciesCatalog.json'):
            if bird.get('dutchName') in REPORTED_NAMES:
                asset=bird['id'].replace(':','-')+'-primary'
                if not (res/'Assets.xcassets'/(asset+'.imageset')).is_dir():missing.append(bird['dutchName'])
        repairs.api.write_json(project/'.artwork-api/artwork-overname-rapport.json',dict(**result,missingReportedExamples=sorted(missing)))
        if missing:print('Deze voorbeelden ontbreken ook in de gekozen oude projectmap:',', '.join(sorted(missing)),'. Bewaar ook je eerdere Belgische productiemap; laat dit rapport nakijken.')
        if result['unknown']:print(result['unknown'],'oude records met onbekende soort-ID niet overgenomen.')
    print('Bouw nu deze NIEUWE projectmap opnieuw in Xcode. Geen API-aanvragen of beeldgeneratie.')


if __name__=='__main__':
    try:main()
    except (OSError,ValueError,KeyError,subprocess.CalledProcessError) as error:raise SystemExit('Herstel gestopt: '+str(error))
