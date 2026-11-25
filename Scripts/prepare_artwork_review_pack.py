#!/usr/bin/env python3
"""Local, non-generating inspection pack. Never changes originals or calls an API."""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import tempfile
import zipfile
from PIL import Image, features

MAX_IMAGE_BYTES = 64 * 1024 * 1024
MAX_IMAGES = 400
MAX_PACK_BYTES = 24 * 1024 * 1024
EXTRA_SPECIES = ['birdnet-v3:BN06072', 'birdnet-v3:BN06289', 'birdnet-v3:BN01170',
                 'birdnet-v3:BN02171', 'birdnet-v3:BN02172', 'birdnet-v3:BN03921']
KEY = re.compile(r'(birdnet-v3-BN\d+)-(primary|dynamic|front|rear|flight)(?:\.|$)')


def choose(prompt, folder=False):
    script = 'on run argv\nreturn POSIX path of (choose ' + ('folder' if folder else 'file') + ' with prompt (item 1 of argv))\nend run'
    return Path(subprocess.check_output(['osascript', '-e', script, prompt], text=True).strip())


def safe_member(name):
    path = PurePosixPath(name)
    if path.is_absolute() or '..' in path.parts or '\\' in name:
        raise ValueError('Onveilige archiefnaam: ' + name)
    return path


def inputs(archive, project=None):
    sources = []
    seen_names = set()
    with zipfile.ZipFile(archive) as z:
        for item in z.infolist():
            path = safe_member(item.filename)
            if item.is_dir() or any(part.startswith('.') or part == '__MACOSX' for part in path.parts):
                continue
            if path.suffix.lower() not in ('.png', '.webp', '.jpg', '.jpeg'): continue
            if item.filename in seen_names: raise ValueError('Dubbele archiefnaam: ' + item.filename)
            seen_names.add(item.filename)
            if item.file_size > MAX_IMAGE_BYTES: raise ValueError('Afbeelding is te groot: ' + item.filename)
            sources.append(('zip', item.filename))
    if project:
        resources = Path(project) / 'BirdingCompanion/Resources'
        if not (resources / 'WorldSpeciesCatalog.json').is_file():
            raise ValueError('Kies de projectmap waarin BirdingCompanion.xcodeproj staat.')
        for species in EXTRA_SPECIES:
            for role in ('primary', 'dynamic'):
                asset = resources / 'Assets.xcassets' / (species.replace(':', '-') + '-' + role + '.imageset')
                contents = asset / 'Contents.json'
                if not contents.is_file(): continue
                files = list(dict.fromkeys(row['filename'] for row in json.loads(contents.read_text()).get('images', []) if row.get('filename')))
                # API imports have one original. Include all scale variants if present.
                for name in files:
                    if Path(name).name != name: raise ValueError('Ongeldige imageset-bestandsnaam.')
                    target = asset / name
                    if not target.is_file() or target.stat().st_size > MAX_IMAGE_BYTES:
                        raise ValueError('Ontbrekend of te groot origineel: ' + str(target))
                    sources.append(('project', str(target.relative_to(project))))
    if not sources: raise ValueError('Geen afbeeldingen gevonden in dit archief.')
    if len(sources) > MAX_IMAGES: raise ValueError('Meer dan 400 beelden; gebruik een kleiner selectiearchief.')
    return sources


def image_info(data, name):
    with Image.open(io.BytesIO(data)) as source:
        if source.width * source.height > 40_000_000: raise ValueError('Afbeelding bevat te veel pixels: ' + name)
        source.load()
        alpha_present = 'A' in source.getbands() or 'transparency' in source.info
        image = source.convert('RGBA')
    bounds = image.getchannel('A').point(lambda a: 255 if a > 16 else 0).getbbox() if alpha_present else None
    edges = None if bounds is None else dict(left=bounds[0] <= 1, top=bounds[1] <= 1,
        right=bounds[2] >= image.width - 1, bottom=bounds[3] >= image.height - 1)
    return image, dict(originalSHA256=hashlib.sha256(data).hexdigest(), originalBytes=len(data),
        width=image.width, height=image.height, hasAlpha=alpha_present, alphaBounds=bounds,
        edgeContact=edges, edgeContactMeaning='Signal only; not proof of truncation or a completed visual review.')


def prepare(archive, project=None, output=None, preview_side=960):
    archive = Path(archive).resolve()
    project = Path(project).resolve() if project else None
    if not features.check('webp'): raise ValueError('Deze Pillow-installatie mist WebP-ondersteuning.')
    sources = inputs(archive, project)
    output = Path(output) if output else archive.with_name(archive.stem + '-controle.zip')
    if output.exists(): raise ValueError('Controlebestand bestaat al. Hernoem het of kies --output; niets is overschreven.')
    if output.resolve() == archive: raise ValueError('De originele zip mag niet worden overschreven.')
    output.parent.mkdir(parents=True, exist_ok=True)
    manifest = dict(format='BirderArtworkReviewPack', version=1, sourceArchive=archive.name,
        originalsChanged=False, generationsRequested=0, previewMaxSide=preview_side, entries=[], extraSpeciesRequested=EXTRA_SPECIES,
        extraSpeciesFound=[], extraSpeciesMissing=[])
    catalog = {}
    if project:
        catalog = {row['id']: row for row in json.loads((project / 'BirdingCompanion/Resources/WorldSpeciesCatalog.json').read_text())}
    fd, temporary = tempfile.mkstemp(dir=output.parent, suffix='.tmp')
    os.close(fd)
    try:
        with zipfile.ZipFile(archive) as source_zip, zipfile.ZipFile(temporary, 'w', zipfile.ZIP_DEFLATED) as packed:
            for index, (kind, name) in enumerate(sources):
                if kind == 'zip':
                    with source_zip.open(name) as handle: data = handle.read(MAX_IMAGE_BYTES + 1)
                else: data = (project / name).read_bytes()
                if len(data) > MAX_IMAGE_BYTES: raise ValueError('Afbeelding is te groot: ' + name)
                image, row = image_info(data, name)
                matched = KEY.search(name)
                if matched:
                    species = matched[1].replace('birdnet-v3-', 'birdnet-v3:')
                    row.update(speciesID=species, role=matched[2])
                    if species in catalog:
                        row.update(dutchName=catalog[species]['dutchName'], scientificName=catalog[species]['scientificName'])
                    if kind == 'project': manifest['extraSpeciesFound'].append(species)
                row.update(source=kind, originalName=name, preview=f'previews/{index+1:04d}.webp')
                image.thumbnail((preview_side, preview_side), Image.Resampling.LANCZOS)
                preview = io.BytesIO(); image.save(preview, 'WEBP', quality=88, method=4, exact=True)
                packed.writestr(row['preview'], preview.getvalue())
                manifest['entries'].append(row)
                image.close()
            manifest['extraSpeciesFound'] = sorted(set(manifest['extraSpeciesFound']))
            manifest['extraSpeciesMissing'] = sorted(set(EXTRA_SPECIES) - set(manifest['extraSpeciesFound']))
            packed.writestr('inventory.json', json.dumps(manifest, ensure_ascii=False, indent=2))
            packed.writestr('LEESMIJ.txt', 'Compacte voorbeelden voor controle. Originele afbeeldingen ongewijzigd.\nGeen beelden gegenereerd of geïnstalleerd.\n')
        if Path(temporary).stat().st_size > MAX_PACK_BYTES:
            if preview_side > 480:
                return prepare(archive, project, output, preview_side=max(480, preview_side - 240))
            raise ValueError('Controlezip is groter dan 24 MB; maak twee groepen. Originele beelden zijn behouden.')
        os.replace(temporary, output)
    finally:
        Path(temporary).unlink(missing_ok=True)
    return output, manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', nargs='?', type=Path)
    parser.add_argument('--project', type=Path)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--choose', action='store_true')
    args = parser.parse_args()
    archive = args.archive or choose('Kies Archief.zip met de illustraties die hersteld moeten worden.')
    project = args.project
    if args.choose and project is None:
        project = choose('Kies je huidige app-projectmap. Daarin zoeken we ook de zes rechts afgesneden soorten.', folder=True)
    output, manifest = prepare(archive, project, args.output)
    print(f"Klaar: {len(manifest['entries'])} controlebeelden, {output.stat().st_size/1024/1024:.1f} MB.")
    print('Upload dit bestand in de chat:', output)
    print('Originele bestanden zijn niet gewijzigd. Geen API-aanvragen of kosten.')
    if project and manifest['extraSpeciesMissing']:
        print('Niet alle zes extra soorten stonden in de gekozen app-map; dit is vastgelegd in inventory.json.')
    if args.choose: subprocess.run(['open', '-R', str(output)], check=False)


if __name__ == '__main__':
    try: main()
    except (OSError, ValueError, zipfile.BadZipFile, subprocess.CalledProcessError) as error:
        raise SystemExit('Controlepakket niet gemaakt: ' + str(error))
