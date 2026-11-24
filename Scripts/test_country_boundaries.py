"""Independent checks of the shipped binary and known geographic positions.
These execute the dataset/reference lookup, not the native Swift implementation.
"""
import hashlib
import json
from pathlib import Path
import struct
import unittest

ROOT = Path(__file__).resolve().parents[1]


def load():
    data = (ROOT / 'BirdingCompanion/Resources/CountryBoundaries.bin').read_bytes()
    offset = 8
    def unpack(fmt):
        nonlocal offset
        result = struct.unpack_from('<' + fmt, data, offset)
        offset += struct.calcsize('<' + fmt)
        return result
    assert data[:8] == b'BIRDCTR1'
    count, = unpack('I')
    polygons = []
    for _ in range(count):
        code = data[offset:offset+2].decode('ascii');offset += 2
        x0, y0, x1, y1, rings = unpack('4fI')
        coordinates = []
        for _ in range(rings):
            n, = unpack('I')
            coordinates.append([unpack('2f') for _ in range(n)])
        polygons.append((code, (x0,y0,x1,y1), coordinates))
    assert offset == len(data)
    return polygons


def contains(ring, x, y):
    inside = False
    previous = ring[-1]
    for point in ring:
        if (point[1] > y) != (previous[1] > y) and x < (previous[0]-point[0])*(y-point[1])/(previous[1]-point[1])+point[0]:
            inside = not inside
        previous = point
    return inside


def lookup(polygons, lat, lon):
    countries = set()
    for code, (x0,y0,x1,y1), rings in polygons:
        if x0<=lon<=x1 and y0<=lat<=y1 and contains(rings[0],lon,lat) and not any(contains(r,lon,lat) for r in rings[1:]):
            countries.add(code)
    return next(iter(countries)) if len(countries)==1 else None


class CountryBoundariesTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.polygons = load()

    def test_resource_hash_and_polygon_counts(self):
        meta=json.loads((ROOT/'BirdingCompanion/Resources/CountryBoundaries.json').read_text())
        blob=(ROOT/'BirdingCompanion/Resources/CountryBoundaries.bin').read_bytes()
        self.assertEqual(hashlib.sha256(blob).hexdigest(),meta['binarySHA256'])
        self.assertEqual(len(self.polygons),meta['polygonParts'])
        self.assertEqual(sum(len(r) for _,_,rings in self.polygons for r in rings),meta['vertices'])

    def test_known_cities_countries_and_islands(self):
        for lat,lon,country in [(51.2194,4.4025,'BE'),(52.52,13.405,'DE'),(28.6139,77.2090,'IN'),
            (23.1136,-82.3666,'CU'),(-20.93,55.30,'RE'),(48.85,2.35,'FR'),(59.91,10.75,'NO'),
            (51.507,-0.127,'GB'),(37.5665,126.978,'KR'),(27.70,85.32,'NP'),(35.68,139.69,'JP'),(-33.92,18.42,'ZA'),
            (-17.71,178.06,'FJ'),(-16.84,-179.97,'FJ'),(37.76,-25.67,'PT'),(52.367,4.904,'NL')]:
            self.assertEqual(lookup(self.polygons,lat,lon),country,(lat,lon))

    def test_enclave_is_not_counted_as_surrounding_country(self):
        self.assertEqual(lookup(self.polygons,-29.316,27.486),'LS')
        self.assertEqual(lookup(self.polygons,41.903,12.453),'VA')
        self.assertEqual(lookup(self.polygons,43.936,12.447),'SM')

    def test_ocean_and_unresolved_areas_remain_unknown(self):
        self.assertIsNone(lookup(self.polygons,0,0))
        self.assertIsNone(lookup(self.polygons,35,-30))


if __name__ == '__main__':
    unittest.main()
