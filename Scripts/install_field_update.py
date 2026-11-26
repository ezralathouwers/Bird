#!/usr/bin/env python3
"""Apply the field update in place, preserving artwork, private maps and signing."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import uuid
from field_update_project import update_project

ROOT=Path(__file__).resolve().parents[1]


def sha(blob):return hashlib.sha256(blob).hexdigest()


def atomic(path,blob):
    path.parent.mkdir(parents=True,exist_ok=True)
    fd,name=tempfile.mkstemp(dir=path.parent,prefix='.field-update-')
    try:
        with os.fdopen(fd,'wb') as handle:handle.write(blob);handle.flush();os.fsync(handle.fileno())
        os.replace(name,path)
    finally:Path(name).unlink(missing_ok=True)


def recover(project):
    project=Path(project).resolve();journal=project/'.artwork-api/pending-field-update.json'
    if not journal.exists():raise ValueError('Geen onderbroken veldupdate gevonden.')
    data=json.loads(journal.read_text());backup=Path(data['backup']).resolve()
    if not backup.is_relative_to(project/'.artwork-api/field-update-backups'):raise ValueError('Onveilig herstelpad.')
    for row in data['entries']:
        rel=Path(row['path'])
        if rel.is_absolute() or '..' in rel.parts:raise ValueError('Onveilig herstelbestand.')
        target=project/rel
        actual=sha(target.read_bytes()) if target.is_file() else None
        if actual not in (row['oldSHA256'],row['newSHA256']):raise ValueError('Bestand is nadien gewijzigd: '+str(rel))
        if row['oldSHA256'] is not None and sha((backup/rel).read_bytes())!=row['oldSHA256']:raise ValueError('Herstelkopie wijkt af: '+str(rel))
    for row in reversed(data['entries']):
        target=project/row['path']
        if row['oldSHA256'] is None:target.unlink(missing_ok=True)
        else:atomic(target,(backup/row['path']).read_bytes())
    journal.unlink()


def apply(project, after_write=None):
    project=Path(project).resolve();folder=project/'.artwork-api';folder.mkdir(exist_ok=True)
    with (folder/'field-update.lock').open('a') as lock:
        try:fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        except BlockingIOError:raise ValueError('Er loopt al een veldupdate.') from None
        return _apply(project,after_write)


def _apply(project, after_write=None):
    project=Path(project).resolve();config=ROOT/'Docs/FieldUpdateFiles20261126.json'
    plan=json.loads(config.read_text());journal=project/'.artwork-api/pending-field-update.json'
    if journal.exists():raise ValueError('Update onderbroken. Kies eerst optie 2 om terug te draaien.')
    changes={}
    for rel,record in plan['files'].items():
        path=Path(rel)
        if path.is_absolute() or '..' in path.parts:raise ValueError('Onveilig bestand in update.')
        new=(ROOT/rel).read_bytes()
        if sha(new)!=record['sha256']:raise ValueError('Downloadbestand gewijzigd: '+rel)
        target=project/rel
        if target.is_symlink() or not target.parent.resolve().is_relative_to(project):raise ValueError('Onveilig doelpad: '+rel)
        old=target.read_bytes() if target.exists() else None
        if old==new:continue
        if old is not None and sha(old) not in record['knownOld']:
            raise ValueError('Onbekende of lokaal aangepaste broncode: '+rel+'. Niets geïnstalleerd.')
        if old is None and record.get('requiredExisting',bool(record['knownOld'])):
            raise ValueError('Ontbrekend appbronbestand: '+rel)
        changes[rel]=(old,new)
    project_rel='BirdingCompanion.xcodeproj/project.pbxproj';path=project/project_rel
    if path.is_symlink() or not path.resolve().is_relative_to(project):raise ValueError('Onveilig projectpad.')
    original=path.read_bytes();updated=update_project(original.decode()).encode()
    if updated!=original:changes[project_rel]=(original,updated)
    info_rel='BirdingCompanion/Resources/Info.plist';path=project/info_rel
    if path.is_symlink() or not path.resolve().is_relative_to(project):raise ValueError('Onveilig Info.plist-pad.')
    original=path.read_bytes();info=plistlib.loads(original)
    info['UIBackgroundModes']=list(dict.fromkeys(info.get('UIBackgroundModes',[])+['audio']))
    info['NSSupportsLiveActivities']=True
    urls=info.get('CFBundleURLTypes',[])
    if not any('birder' in row.get('CFBundleURLSchemes',[]) for row in urls):urls.append(dict(CFBundleURLName='Birder',CFBundleURLSchemes=['birder']))
    info['CFBundleURLTypes']=urls
    if plistlib.loads(original)!=info:changes[info_rel]=(original,plistlib.dumps(info,sort_keys=False))
    if not changes:return 0
    backup=project/'.artwork-api/field-update-backups'/uuid.uuid4().hex;backup.mkdir(parents=True)
    entries=[]
    for rel,(old,new) in changes.items():
        if old is not None:
            target=backup/rel;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(old)
        entries.append(dict(path=rel,oldSHA256=sha(old) if old is not None else None,newSHA256=sha(new)))
    atomic(journal,json.dumps(dict(backup=str(backup),entries=entries),indent=2).encode())
    try:
        for rel,(_,new) in changes.items():
            atomic(project/rel,new)
            if after_write:after_write()
        journal.unlink()
    except BaseException:
        recover(project);raise
    print('Herstelkopie:',backup)
    return len(changes)


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--recover',action='store_true');parser.add_argument('--project',type=Path);args=parser.parse_args()
    project=args.project
    if project is None:
        code='on run argv\nreturn POSIX path of (choose folder with prompt (item 1 of argv))\nend run'
        project=Path(subprocess.check_output(['osascript','-e',code,'Kies je HUIDIGE app-projectmap met alle geïmporteerde illustraties en PrivateBirdLifeRanges.'],text=True).strip())
    if not (project/'BirdingCompanion.xcodeproj/project.pbxproj').is_file():raise ValueError('Kies de volledige app-projectmap.')
    if args.recover:
        folder=project/'.artwork-api';folder.mkdir(exist_ok=True)
        with (folder/'field-update.lock').open('a') as lock:
            fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB);recover(project)
        print('Onderbroken update teruggedraaid.');return
    count=apply(project)
    print(count,'bestanden bijgewerkt. Illustraties, privékaarten en appgegevens behouden.')
    print('Open deze projectmap in Xcode. Controleer dezelfde Team bij BirderAudioActivity als bij de app. Bouw de app opnieuw.')


if __name__=='__main__':
    try:main()
    except (ValueError,OSError,KeyError,subprocess.CalledProcessError) as error:raise SystemExit('Update gestopt: '+str(error))
