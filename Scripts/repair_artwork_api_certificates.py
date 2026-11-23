#!/usr/bin/env python3
"""Repair this pilot's Python CA setup, then probe HTTPS without generation."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

FILES = ('artwork_api_pilot.py', 'Start-API-illustratieproef.command')


def validate_project(project):
    project = Path(project).resolve()
    recipe = project / 'Docs/ArtworkAPIPilot.json'
    if not recipe.is_file() or json.loads(recipe.read_text()).get('batchID') != 'api-pilot-20261123':
        raise ValueError('Selecteer de uitgepakte Bird-projectmap met Docs en Scripts, niet de losse controlemap.')
    if any(not (project / 'Scripts' / name).is_file() for name in FILES):
        raise ValueError('De API-proefscripts ontbreken in deze projectmap.')
    return project


def update_scripts(project, bundle):
    project = validate_project(project)
    bundle = Path(bundle)
    # Validate the complete repair bundle before changing any project files.
    blobs = {name: (bundle / name).read_bytes() for name in FILES}
    backup = project / '.artwork-api/certificate-repair-backup'
    for name, data in blobs.items():
        target = project / 'Scripts' / name
        old = target.read_bytes()
        if old == data:
            continue
        backup.mkdir(parents=True, exist_ok=True)
        saved = backup / (name + '.' + hashlib.sha256(old).hexdigest()[:12] + '.bak')
        if not saved.exists():
            saved.write_bytes(old)
        # Replace through a sibling file, retaining the original script mode.
        staged = target.with_name(target.name + '.certificate-repair.tmp')
        staged.write_bytes(data)
        shutil.copymode(target, staged)
        staged.replace(target)
    return project


def repair(project, bundle):
    project = validate_project(project)
    python = project / '.artwork-api/venv/bin/python3'
    if not python.is_file():
        subprocess.check_call([sys.executable, '-m', 'venv', str(python.parent.parent)])
    # pip succeeded for Pillow on the user's Mac. Use its normal verified PyPI
    # connection; never add --trusted-host or disable TLS verification.
    subprocess.check_call([str(python), '-m', 'pip', 'install', '--disable-pip-version-check', '--quiet', 'certifi>=2025.1'])
    update_scripts(project, bundle)
    result = subprocess.run([str(python), str(project / 'Scripts/artwork_api_pilot.py'), '--diagnose'],
                            capture_output=True, text=True, timeout=30)
    if result.returncode != 0:
        print('De controle kon niet worden uitgevoerd. Er zijn geen beelden aangevraagd.')
        return 1
    try:
        status = json.loads(result.stdout)
    except ValueError:
        print('Onverwacht antwoord van de verbindingscontrole. Er zijn geen beelden aangevraagd.')
        return 1
    print(json.dumps(status, ensure_ascii=False, indent=2))
    if status.get('ok') is not True:
        print('De verbinding werkt nog niet; stuur bovenstaande uitkomst door.')
        return 1
    print('Certificaatcontrole werkt voor de API-proef. Geen sleutel gebruikt, geen beelden aangevraagd.')
    print('Je bestaande state.json en afbeeldingen zijn behouden. Start de proef nog niet opnieuw: de oude aanvraag moet eerst worden nagekeken.')
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('project', type=Path)
    args = parser.parse_args()
    try:
        return repair(args.project, Path(__file__).resolve().parent)
    except (OSError, ValueError, subprocess.SubprocessError):
        print('Herstel is niet voltooid. Er zijn geen beelden aangevraagd. Stuur een screenshot van dit venster.')
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
