#!/usr/bin/env python3
"""Build the offline country index from public-domain Natural Earth 1:10m data.
No user coordinates are included. Usage: build_country_boundaries.py source.geojson
"""
import hashlib
import json
from pathlib import Path
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
RESOURCE = ROOT / 'BirdingCompanion/Resources'
SOURCE = 'https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_10m_admin_0_map_units.geojson'


def build(source, output=RESOURCE / 'CountryBoundaries.bin'):
    blob = Path(source).read_bytes()
    data = json.loads(blob)
    polygons, excluded = [], []
    for feature in data['features']:
        code = feature['properties']['ISO_A2_EH']
        if len(code) != 2 or not code.isascii() or not code.isalpha() or not code.isupper():
            excluded.append(feature['properties'].get('GEOUNIT') or feature['properties']['ADMIN'])
            continue
        geometry = feature['geometry']
        parts = geometry['coordinates'] if geometry['type'] == 'MultiPolygon' else [geometry['coordinates']]
        for rings in parts:
            assert all(len(r) >= 4 and r[0] == r[-1] for r in rings)
            points = [p for ring in rings for p in ring]
            bounds = (min(p[0] for p in points), min(p[1] for p in points), max(p[0] for p in points), max(p[1] for p in points))
            polygons.append((code, bounds, rings))
    result = bytearray(b'BIRDCTR1' + struct.pack('<I', len(polygons)))
    vertices = 0
    for code, bounds, rings in polygons:
        result.extend(code.encode('ascii'))
        result.extend(struct.pack('<4fI', *bounds, len(rings)))
        for ring in rings:
            result.extend(struct.pack('<I', len(ring)))
            for point in ring:
                result.extend(struct.pack('<2f', *point))
                vertices += 1
    output = Path(output)
    output.write_bytes(result)
    metadata = dict(format='BIRDCTR1', source=SOURCE, sourceSHA256=hashlib.sha256(blob).hexdigest(),
        binarySHA256=hashlib.sha256(result).hexdigest(), license='Public domain',
        licenseURL='https://www.naturalearthdata.com/about/terms-of-use/', scale='1:10 million',
        codeProperty='ISO_A2_EH', polygonParts=len(polygons), vertices=vertices,
        countryCodes=len({p[0] for p in polygons}), excludedWithoutISOCode=excluded,
        notes='Offline approximate cartographic country lookup, not a legal boundary authority. Float32 coordinates; source vertices and polygon holes retained. Unknown/offshore or disputed areas without ISO codes remain unresolved.')
    output.with_suffix('.json').write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + '\n')
    return metadata


if __name__ == '__main__':
    print(json.dumps(build(sys.argv[1]), indent=2))
