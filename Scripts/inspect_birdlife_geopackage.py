#!/usr/bin/env python3
"""Read a local BirdLife GeoPackage's schema without reading/exporting polygons.

Uses Python's standard library only. The original is opened read-only and stays
on the user's Mac. The small JSON report is intended for preparing the actual
converter after its schema and accompanying source documents have been reviewed.
"""
import argparse
import json
import os
from pathlib import Path
import sqlite3
import tempfile

MAX_LAYERS = 25
SAMPLE_FIELDS = {
    'sci_name', 'scientific_name', 'scientificname', 'sciname', 'binomial',
    'species', 'species_name', 'id_no', 'sisid', 'sis_id', 'taxonid', 'taxon_id',
    'presence', 'origin', 'seasonal', 'seasonality', 'compiler', 'year',
}


def quoted(name):
    return '"' + name.replace('"', '""') + '"'


def inspect_geopackage(path):
    path = Path(path).resolve(strict=True)
    if not path.is_file():
        raise ValueError('Kies het bestand BOTW_2025.gpkg, niet de map.')
    with path.open('rb') as stream:
        if stream.read(16) != b'SQLite format 3\x00':
            raise ValueError('Dit bestand is geen leesbaar GeoPackage/SQLite-bestand.')
    report = {
        'reportVersion': 1,
        'sourceFile': path.name,
        'sourceBytes': path.stat().st_size,
        'purpose': 'Schema inspection only; no geometry, license or taxonomy conversion performed.',
        'sourceOpenedReadOnly': True,
        'layers': [],
    }
    # URI encoding preserves spaces, #, ? and accented characters in Mac paths.
    with sqlite3.connect(path.as_uri() + '?mode=ro', uri=True) as db:
        db.row_factory = sqlite3.Row
        db.execute('PRAGMA query_only = ON')
        names = {row[0] for row in db.execute("SELECT name FROM sqlite_master WHERE type='table'")}
        if not {'gpkg_contents', 'gpkg_geometry_columns'} <= names:
            raise ValueError('De vereiste GeoPackage-tabellen ontbreken. Kies het .gpkg-bestand.')
        report['geopackageUserVersion'] = db.execute('PRAGMA user_version').fetchone()[0]
        report['applicationID'] = db.execute('PRAGMA application_id').fetchone()[0]
        contents = list(db.execute(
            "SELECT table_name, identifier, data_type, srs_id FROM gpkg_contents "
            "WHERE data_type = 'features' ORDER BY table_name LIMIT ?", (MAX_LAYERS + 1,)))
        report['layerLimitReached'] = len(contents) > MAX_LAYERS
        srs_ids = set()
        for content in contents[:MAX_LAYERS]:
            table = content['table_name']
            columns = list(db.execute('PRAGMA table_info(' + quoted(table) + ')'))
            geometry = [dict(row) for row in db.execute(
                'SELECT column_name, geometry_type_name, srs_id, z, m '
                'FROM gpkg_geometry_columns WHERE table_name = ?', (table,))]
            geometry_names = {g['column_name'] for g in geometry}
            # Never select the geometry/BLOB or dump arbitrary metadata rows.
            fields = [row['name'] for row in columns if row['name'].lower() in SAMPLE_FIELDS
                      and row['name'] not in geometry_names]
            layer = {
                'table': table, 'identifier': content['identifier'],
                'srsID': content['srs_id'], 'geometry': geometry,
                'columns': [{'name': row['name'], 'type': row['type'],
                             'primaryKey': bool(row['pk'])} for row in columns],
                'sampleAttributes': [],
            }
            if fields:
                sql = 'SELECT ' + ', '.join(quoted(field) for field in fields) + ' FROM ' + quoted(table) + ' LIMIT 5'
                for row in db.execute(sql):
                    layer['sampleAttributes'].append({key: str(value)[:160] if value is not None else None
                                                      for key, value in dict(row).items()
                                                      if not isinstance(value, bytes)})
            srs_ids.add(content['srs_id'])
            report['layers'].append(layer)
        report['spatialReferenceSystems'] = []
        if 'gpkg_spatial_ref_sys' in names:
            for srs_id in sorted(s for s in srs_ids if s is not None):
                row = db.execute('SELECT srs_name, srs_id, organization, organization_coordsys_id '
                                 'FROM gpkg_spatial_ref_sys WHERE srs_id = ?', (srs_id,)).fetchone()
                if row:
                    report['spatialReferenceSystems'].append(dict(row))
    if not report['layers']:
        raise ValueError('Er zijn geen vectorlagen in dit GeoPackage gevonden.')
    return report


def write_report(report, destination):
    destination = Path(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    name = None
    try:
        with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir=destination.parent,
                                         prefix='.birdlife-inspect-', delete=False) as stream:
            name = stream.name
            json.dump(report, stream, ensure_ascii=False, indent=2)
            stream.write('\n')
        os.replace(name, destination)
    finally:
        if name and os.path.exists(name):
            os.unlink(name)


def main():
    parser = argparse.ArgumentParser(description='Maak een klein inspectierapport van een lokaal BirdLife GeoPackage.')
    parser.add_argument('geopackage', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    destination = args.output or args.geopackage.resolve().parent / 'BirdLife-inspectie.json'
    if destination.resolve() == args.geopackage.resolve():
        parser.exit(1, 'Het rapport mag het oorspronkelijke GeoPackage niet vervangen.\n')
    try:
        report = inspect_geopackage(args.geopackage)
        write_report(report, destination)
    except (OSError, sqlite3.Error, ValueError) as error:
        parser.exit(1, 'Inspectie niet gelukt: ' + str(error) + '\n')
    print('Klaar. Het oorspronkelijke kaartbestand is niet gewijzigd.')
    print('Upload dit kleine rapport in het gesprek:')
    print(destination)


if __name__ == '__main__':
    main()
