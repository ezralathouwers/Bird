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


def polygonal_geometry(geometry):
    """Keep polygon area from make_valid's possible GeometryCollection output."""
    from shapely import union_all
    if geometry.geom_type in ('Polygon', 'MultiPolygon'):
        return geometry
    if geometry.geom_type != 'GeometryCollection':
        raise ValueError('Geometry repair produced no polygon area')
    parts = []
    for part in geometry.geoms:
        if part.geom_type in ('Polygon', 'MultiPolygon'):
            parts.append(part)
        elif part.geom_type == 'GeometryCollection':
            try:
                parts.append(polygonal_geometry(part))
            except ValueError:
                pass
    if not parts:
        raise ValueError('Geometry repair produced no polygon area')
    return union_all(parts)


def prepare_geometry(geometry, tolerance):
    from shapely import make_valid, union_all
    from shapely.geometry import Polygon
    if geometry.geom_type not in ('Polygon', 'MultiPolygon') or geometry.is_empty:
        raise ValueError('Empty or non-polygon source geometry')
    processing = {'sourceWasValid': bool(geometry.is_valid), 'repairApplied': False,
                  'simplificationApplied': False, 'toleranceDegrees': tolerance}
    if not geometry.is_valid:
        original_parts = [geometry] if geometry.geom_type == 'Polygon' else list(geometry.geoms)
        # Invalid holes outside a shell must never turn into new range islands.
        shells = []
        collapsed = 0
        for part in original_parts:
            shell = make_valid(Polygon(part.exterior))
            if shell.is_empty or shell.area == 0:
                collapsed += 1
                continue
            shells.append(polygonal_geometry(shell))
        if not shells:
            raise ValueError('No polygon area remains in source exterior shells')
        processing['collapsedShellsWithoutArea'] = collapsed
        mask = union_all(shells)
        geometry = polygonal_geometry(make_valid(geometry))
        geometry = polygonal_geometry(geometry.intersection(mask))
        processing['repairApplied'] = True
        processing['repairMethod'] = 'GEOS make_valid, polygon area clipped to original exterior shells'
    if geometry.is_empty or not geometry.is_valid:
        raise ValueError('Geometry could not be repaired into valid polygon area')
    simplified = geometry.simplify(tolerance, preserve_topology=True)
    # Keep a valid unsimplified result if simplification fails, not a missing map.
    if not simplified.is_empty and simplified.is_valid and simplified.geom_type in ('Polygon', 'MultiPolygon'):
        geometry = simplified
        processing['simplificationApplied'] = tolerance > 0
    return geometry, processing


def reusable_export(output, catalog, source, stage):
    """Only reuse ID/hash-verified maps; no regeneration of already good maps."""
    manifest_path = output / 'manifest.json'
    report_path = output / 'conversion-report.json'
    if not manifest_path.is_file() or not report_path.is_file():
        return {}, 0, set()
    manifest = json.loads(manifest_path.read_text())
    previous = json.loads(report_path.read_text())
    if (manifest.get('formatVersion') != 1 or manifest.get('providerID') != 'birdlife-datazone'
            or manifest.get('version') != VERSION or manifest.get('citation') != CITATION
            or manifest.get('license') != LICENSE or previous.get('sourceFile') != source.name):
        raise ValueError('Existing export differs from this source/version; use --full for a fresh export')
    if previous.get('sourceBytes', source.stat().st_size) != source.stat().st_size:
        raise ValueError('Source size changed; use --full to export it as a new source')
    ids = {bird['id'] for bird in catalog}
    retained, count = {}, 0
    for identifier, entry in manifest['files'].items():
        expected = identifier.replace(':', '-') + '-range.geojson'
        if identifier not in ids or entry.get('file') != expected or '/' in expected or '..' in expected:
            continue
        file = output / expected
        if not file.is_file():
            continue
        data = file.read_bytes()
        if hashlib.sha256(data).hexdigest() != entry.get('sha256'):
            continue
        content = json.loads(data)
        if content.get('speciesID') != identifier or content.get('version') != VERSION or not content.get('features'):
            continue
        shutil.copy2(file, stage / expected)
        retained[identifier] = entry
        count += len(content['features'])
    return retained, count, set(manifest['files'])


def convert(source, catalog_path, output, tolerance=0.01, resume=True):
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
    report = {'formatVersion': 2, 'converterVersion': 2, 'sourceFile': source.name,
              'sourceBytes': source.stat().st_size, 'version': VERSION,
              'simplificationDegrees': tolerance, 'inputFeatures': 0, 'exportedFeatures': 0,
              'failedSpeciesIDs': [], 'failedFeatures': [], 'repairedFeatures': 0,
              'reusedSpecies': 0, 'addedSpecies': 0, 'recoveredSpecies': 0,
              'unmatchedSourceNames': [], 'exportedSpecies': 0}
    paths, counts, failed = {}, defaultdict(int), set()
    try:
        retained, retained_features, previous_ids = reusable_export(output, catalog, source, stage) if resume else ({}, 0, set())
        report['reusedSpecies'] = len(retained)
        if retained:
            print(str(len(retained)) + ' bestaande soortkaarten gecontroleerd; alleen ontbrekende kaarten opnieuw verwerken.', flush=True)
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
            print('Ontbrekende kaarten omzetten; bronvlakken worden zo nodig geometrisch hersteld…', flush=True)
            # Geometry is only selected for missing species. Scientific-name
            # scans still examine the read-only source without reprocessing maps.
            for row in db.execute('SELECT sci_name, rowid AS source_row FROM all_species'):
                report['inputFeatures'] += 1
                identifier = matches.get(row['sci_name'])
                if not identifier or identifier in retained or identifier in failed:
                    continue
                if not all(c.isalnum() or c in ':-_' for c in identifier):
                    raise ValueError('Unsafe catalog ID')
                record = db.execute('SELECT * FROM all_species WHERE rowid = ?', (row['source_row'],)).fetchone()
                try:
                    properties = {key: record[key] for key in record.keys() if key != 'geom'}
                    if (properties['presence'] not in range(1, 7) or properties['origin'] not in range(1, 7)
                            or properties['seasonal'] not in range(1, 6)):
                        raise ValueError('Unknown distribution codes: presence=' + str(properties['presence'])
                                         + ', origin=' + str(properties['origin']) + ', seasonal=' + str(properties['seasonal']))
                    geometry, processing = prepare_geometry(from_wkb(geopackage_wkb(record['geom'])), tolerance)
                    feature = {'type': 'Feature', 'properties': properties, 'geometry': mapping(geometry),
                               'appGeometryProcessing': processing}
                    payload = json.dumps(feature, ensure_ascii=False, separators=(',', ':'), allow_nan=False)
                    if processing['repairApplied']:
                        report['repairedFeatures'] += 1
                except (ValueError, TypeError, KeyError, ShapelyError) as error:
                    failed.add(identifier)
                    report['failedFeatures'].append({'speciesID': identifier, 'scientificName': row['sci_name'],
                        'sourceRow': row['source_row'], 'errorType': type(error).__name__, 'reason': str(error)[:250]})
                    continue
                if identifier not in paths:
                    path = stage / (identifier.replace(':', '-') + '-range.geojson')
                    paths[identifier] = path
                    header = {'type': 'FeatureCollection', 'providerID': 'birdlife-datazone',
                              'speciesID': identifier, 'source': SOURCE, 'license': LICENSE,
                              'citation': CITATION, 'version': VERSION,
                              'simplificationDegrees': tolerance, 'converterVersion': 2}
                    path.write_text(json.dumps(header, ensure_ascii=False)[:-1] + ',"features":[', encoding='utf-8')
                with paths[identifier].open('a', encoding='utf-8') as stream:
                    if counts[identifier]:
                        stream.write(',')
                    stream.write(payload)
                counts[identifier] += 1
                if report['inputFeatures'] % 500 == 0:
                    print(str(report['inputFeatures']) + ' bronvlakken gecontroleerd…', flush=True)
        manifest = {'formatVersion': 1, 'providerID': 'birdlife-datazone', 'version': VERSION,
                    'citation': CITATION, 'license': LICENSE, 'files': dict(retained)}
        report['exportedFeatures'] = retained_features
        for identifier, path in paths.items():
            if identifier in failed:
                path.unlink()
                continue
            with path.open('a', encoding='utf-8') as stream:
                stream.write(']}\n')
            manifest['files'][identifier] = {'file': path.name, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
            report['exportedFeatures'] += counts[identifier]
            report['addedSpecies'] += 1
            if previous_ids and identifier not in previous_ids:
                report['recoveredSpecies'] += 1
        if not manifest['files']:
            raise ValueError('Geen geldige soortkaarten gemaakt; bestaande bestanden blijven behouden. Redenen: '
                             + json.dumps(report['failedFeatures'][:3], ensure_ascii=False))
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
        print('Klaar: ' + str(report['exportedSpecies']) + ' soortkaarten, ' + str(report['addedSpecies'])
              + ' extra, ' + str(len(failed)) + ' nog niet omgezet.', flush=True)
        if failed:
            print('Exacte afwijsredenen staan in conversion-report.json.', flush=True)
        print('Bouw hetzelfde project opnieuw in Xcode.', flush=True)
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
    parser.add_argument('--full', action='store_true', help='Ook reeds geslaagde kaarten opnieuw verwerken')
    args = parser.parse_args()
    catalog = args.project / 'BirdingCompanion/Resources/WorldSpeciesCatalog.json'
    if not catalog.is_file() or not (args.project / 'BirdingCompanion.xcodeproj').is_dir():
        parser.exit(1, 'Kies de uitgepakte Bird-projectmap met BirdingCompanion.xcodeproj.\n')
    project_file = args.project / 'BirdingCompanion.xcodeproj/project.pbxproj'
    if not project_file.is_file() or 'BirdingCompanion/Resources/PrivateBirdLifeRanges' not in project_file.read_text():
        parser.exit(1, 'Dit is een oudere appversie. Download en pak eerst de nieuwste appcode uit en kies die nieuwe projectmap.\n')
    try:
        convert(args.geopackage, catalog, args.project / 'BirdingCompanion/Resources/PrivateBirdLifeRanges', args.tolerance, resume=not args.full)
    except Exception as error:
        parser.exit(1, 'Omzetting niet gelukt: ' + str(error) + '\n')


if __name__ == '__main__':
    main()
