#!/usr/bin/env python3
"""Patch only the known repair importer; preserve PNGs, plans and checkpoints."""
import argparse
import ast
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

KNOWN_OLD = {'361c88c763ce830533e1147af16728e4a2138b8353dde3a01bc269402e0ef7ae'}


def patch(folder, payload, allowed_old=None):
    folder = Path(folder).resolve()
    target = folder/'Scripts/artwork_api_repairs.py'
    if (not target.is_file() or target.is_symlink() or not target.parent.resolve().is_relative_to(folder)
        or not (folder/'Scripts/Start-Illustratieherstel.command').is_file()
        or not (folder/'Docs/ArtworkRepairPlan20261125.json').is_file()):
        raise ValueError('Kies de bestaande Birder-Illustratieherstel-map met Scripts en Docs, niet de app-projectmap.')
    if json.loads((folder/'Docs/ArtworkRepairPlan20261125.json').read_text()).get('batchID') != 'api-repairs-20261125':
        raise ValueError('Deze map bevat een andere herstelopdracht. Niets gewijzigd.')
    old = target.read_bytes(); new = Path(payload).read_bytes()
    ast.parse(new)
    if old == new: return False
    digest = hashlib.sha256(old).hexdigest()
    if digest not in (KNOWN_OLD if allowed_old is None else allowed_old):
        raise ValueError('Het bestaande script heeft een onbekende/aangepaste versie. Niets gewijzigd; stuur deze melding door.')
    backup = folder/'.artwork-api/script-backups'/('artwork_api_repairs.'+digest+'.py.bak')
    backup.parent.mkdir(parents=True, exist_ok=True)
    if backup.exists() and backup.read_bytes() != old: raise ValueError('Herstelkopie wijkt af. Niets gewijzigd.')
    if not backup.exists():
        with backup.open('xb') as handle: handle.write(old)
    descriptor, temporary = tempfile.mkstemp(dir=target.parent, prefix='.repair-import-fix-')
    try:
        with os.fdopen(descriptor, 'wb') as handle:
            handle.write(new);handle.flush();os.fsync(handle.fileno())
        shutil.copymode(target, temporary)
        os.replace(temporary, target)
    finally: Path(temporary).unlink(missing_ok=True)
    return True


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--folder',type=Path)
    args=parser.parse_args()
    folder=args.folder
    if folder is None:
        script='on run argv\nreturn POSIX path of (choose folder with prompt (item 1 of argv))\nend run'
        folder=Path(subprocess.check_output(['osascript','-e',script,'Kies je bestaande Birder-Illustratieherstel-map, waarin de 77 gemaakte beelden staan.'],text=True).strip())
    changed=patch(folder,Path(__file__).with_name('artwork_api_repairs.py'))
    print('Installatiescript bijgewerkt.' if changed else 'Het installatiescript is al bijgewerkt.')
    print('Alle beelden, state.json en de vaste opdracht zijn behouden. Geen API-aanvragen of kosten.')
    print('Open nu het oorspronkelijke Start-Illustratieherstel.command en kies optie 4.')


if __name__=='__main__':
    try:main()
    except (OSError,ValueError,SyntaxError,subprocess.CalledProcessError) as error:raise SystemExit('Update gestopt: '+str(error))
