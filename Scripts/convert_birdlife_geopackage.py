#!/usr/bin/env python3
"""Local-only BOTW_2025 → private per-species GeoJSON for Xcode. Requires Shapely 2.
Never downloads or uploads data. Reads the source SQLite database read-only.
"""
import argparse
from collections import defaultdict
import hashlib
import json
import math
from pathlib import Path
import shutil
import sqlite3
import struct
import tempfile
import uuid

VERSION = '2025.2'
SOURCE = 'BirdLife International and Handbook of the Birds of the World'
CITATION = SOURCE + ' (2025) Bird species distribution maps of the world. Version 2025.2. Available at http://datazone.birdlife.org/species/requestdis.'
LICENSE = 'BirdLife International Data Terms of Use. Personal non-commercial use under granted approval; redistribution is not permitted without written permission.'


def geopackage_wkb(blob):
    if len(blob) < 8 or blob[:2] != b'GP' or blob[2] != 0:
        raise ValueError('Invalid GeoPackage geometry header')
    flags = blob[3]
    if flags & 0x30:  # Empty or extended geometries are not ordinary polygons.
        raise ValueError('Empty/extended GeoPackage geometry')
    envelope = (flags >> 1) & 7
    sizes = {0: 0, 1: 32, 2: 48, 3: 48, 4: 64}
    if envelope not in sizes:
        raise ValueError('Unknown envelope')
    srs = struct.unpack('<i' if flags & 1 else '>i', blob[4:8])[0]
    offset = 8 + sizes[envelope]
    if srs != 4326 or len(blob) <= offset:
        raise ValueError('Expected nonempty WGS84 geometry')
    return blob[offset:]


def resolve_names(catalog, available):
    exact, aliases = defaultdict(set), defaultdict(set)
    for bird in catalog:
        exact[bird['scientificName']].add(bird['id'])
        for name in bird.get('aliases', []):
            aliases[name].add(bird['id'])
    candidates = defaultdict(list)
    for name in available:
        ids = exact.get(name) or aliases.get(name, set())
        if len(ids) == 1:
            candidates[next(iter(ids))].append(name)
    by_id = {bird['id']: bird for bird in catalog}
    result = {}
    for identifier, names in candidates.items():
        current = by_id[identifier]['scientificName']
        # Do not union several BirdLife taxa into a lump, or reuse a lump for
        # several app splits. Exact available names trump aliases.
        if current in names:
            result[current] = identifier
        elif len(names) == 1:
            result[names[0]] = identifier
    return result


def convert(source, catalog_path, output, tolerance=0.01):
    from shapely import from_wkb
    from shapely.errors import ShapelyError
    from shapely.geometry import mapping
    source, output = Path(source).resolve(), Path(output).resolve()
    if not math.isfinite(tolerance) or tolerance < 0 or tolerance > 0.05:
        raise ValueError('Simplification tolerance must be between 0 and 0.05 degrees')
    if output == source or output in source.parents:
        raise ValueError('Source must stay outside the export directory')
    catalog = json.loads(Path(catalog_path).read_text())
    output.parent.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix='.birdlife-stage-', dir=output.parent))
    report = {'formatVersion': 1, 'sourceFile': source.name, 'version': VERSION,
              'simplificationDegrees': tolerance, 'inputFeatures': 0, 'exportedFeatures': 0,
              'failedSpeciesIDs': [], 'unmatchedSourceNames': [], 'exportedSpecies': 0}
    paths, counts, failed = {}, defaultdict(int), set()
    try:
        with sqlite3.connect(source.as_uri() + '?mode=ro', uri=True) as db:
            db.row_factory = sqlite3.Row
            db.execute('PRAGMA query_only = ON')
            declared = db.execute("SELECT srs_id, geometry_type_name FROM gpkg_geometry_columns WHERE table_name='all_species' AND column_name='geom'").fetchone()
            if not declared or declared['srs_id'] != 4326 or declared['geometry_type_name'] != 'MULTIPOLYGON':
                raise ValueError('Schema differs from the supplied BOTW_2025 inspection report')
            print('Soortnamen in het lokale bestand controleren…', flush=True)
            available = {row[0] for row in db.execute('SELECT DISTINCT sci_name FROM all_species')}
            matches = resolve_names(catalog, available)
            report['unmatchedSourceNames'] = sorted(available - matches.keys())
            print('Kaarten omzetten; dit kan bij het grote bestand even duren…', flush=True)
            # Stream features rather than loading the 9 GB database into memory.
            for row in db.execute('SELECT * FROM all_species'):
                report['inputFeatures'] += 1
                identifier = matches.get(row['sci_name'])
                if not identifier or identifier in failed:
                    continue
                if not all(c.isalnum() or c in ':-_' for c in identifier):
                    raise ValueError('Unsafe catalog ID')
                try:
                    properties = {key: row[key] for key in row.keys() if key != 'geom'}
                    if (properties['presence'] not in range(1, 7) or properties['origin'] not in range(1, 7)
                            or properties['seasonal'] not in range(1, 6)):
                        raise ValueError('Unknown distribution attribute code')
                    geometry = from_wkb(geopackage_wkb(row['geom']))
                    if geometry.geom_type not in ('Polygon', 'MultiPolygon') or geometry.is_empty or not geometry.is_valid:
                        raise ValueError('Invalid or non-area source geometry')
                    geometry = geometry.simplify(tolerance, preserve_topology=True)
                    if geometry.is_empty or not geometry.is_valid:
                        raise ValueError('Invalid simplified geometry')
                    feature = {'type': 'Feature', 'properties': properties, 'geometry': mapping(geometry)}
                    payload = json.dumps(feature, ensure_ascii=False, separators=(',', ':'), allow_nan=False)
                except (ValueError, TypeError, KeyError, ShapelyError):
                    # One broken feature invalidates this species, never silently
                    # present only its remaining area as a complete map.
                    failed.add(identifier)
                    continue
                if identifier not in paths:
                    path = stage / (identifier.replace(':', '-') + '-range.geojson')
                    paths[identifier] = path
                    header = {'type': 'FeatureCollection', 'providerID': 'birdlife-datazone',
                              'speciesID': identifier, 'source': SOURCE, 'license': LICENSE,
                              'citation': CITATION, 'version': VERSION,
                              'simplificationDegrees': tolerance}
                    path.write_text(json.dumps(header, ensure_ascii=False)[:-1] + ',"features":[', encoding='utf-8')
                with paths[identifier].open('a', encoding='utf-8') as stream:
                    if counts[identifier]:
                        stream.write(',')
                    stream.write(payload)
                counts[identifier] += 1
                if report['inputFeatures'] % 1000 == 0:
                    print(str(report['inputFeatures']) + ' bronvlakken verwerkt…', flush=True)
        manifest = {'formatVersion': 1, 'providerID': 'birdlife-datazone', 'version': VERSION,
                    'citation': CITATION, 'license': LICENSE, 'files': {}}
        for identifier, path in paths.items():
            if identifier in failed:
                path.unlink()
                continue
            with path.open('a', encoding='utf-8') as stream:
                stream.write(']}\n')
            manifest['files'][identifier] = {'file': path.name, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
            report['exportedFeatures'] += counts[identifier]
        if not manifest['files']:
            raise ValueError('Geen geldige soortkaarten gemaakt; bestaande bestanden blijven behouden.')
        report['failedSpeciesIDs'] = sorted(failed)
        report['exportedSpecies'] = len(manifest['files'])
        (stage / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
        (stage / 'conversion-report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
        (stage / 'README.txt').write_text('Private local BirdLife range export. Do not commit or redistribute these files.\n', encoding='utf-8')
        backup = output.with_name('.birdlife-backup-' + uuid.uuid4().hex[:12])
        if output.exists():
            output.rename(backup)
        try:
            stage.rename(output)
        except OSError:
            if backup.exists():
                backup.rename(output)
            raise
        print('Klaar: ' + str(report['exportedSpecies']) + ' soortkaarten. Open het bijgewerkte project en bouw opnieuw in Xcode.', flush=True)
        if backup.exists():
            print('Vorige export bewaard in: ' + str(backup), flush=True)
        return report
    finally:
        if stage.exists():
            shutil.rmtree(stage)


def main():
    parser = argparse.ArgumentParser(description='Zet BirdLife lokaal om naar privékaartbestanden in je Xcode-project.')
    parser.add_argument('geopackage', type=Path)
    parser.add_argument('project', type=Path)
    parser.add_argument('--tolerance', type=float, default=0.01)
    args = parser.parse_args()
    catalog = args.project / 'BirdingCompanion/Resources/WorldSpeciesCatalog.json'
    if not catalog.is_file() or not (args.project / 'BirdingCompanion.xcodeproj').is_dir():
        parser.exit(1, 'Kies de uitgepakte Bird-projectmap met BirdingCompanion.xcodeproj.\n')
    project_file = args.project / 'BirdingCompanion.xcodeproj/project.pbxproj'
    if not project_file.is_file() or 'BirdingCompanion/Resources/PrivateBirdLifeRanges' not in project_file.read_text():
        parser.exit(1, 'Dit is een oudere appversie. Download en pak eerst de nieuwste appcode uit en kies die nieuwe projectmap.\n')
    try:
        convert(args.geopackage, catalog, args.project / 'BirdingCompanion/Resources/PrivateBirdLifeRanges', args.tolerance)
    except Exception as error:
        parser.exit(1, 'Omzetting niet gelukt: ' + str(error) + '\n')


if __name__ == '__main__':
    main()
