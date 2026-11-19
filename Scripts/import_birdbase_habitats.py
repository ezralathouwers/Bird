#!/usr/bin/env python3
"""Import pinned CC BY BIRDBASE habitat facts; never infer across taxonomic splits.
Usage: python Scripts/import_birdbase_habitats.py /path/to/birdbase.xlsx
Requires openpyxl for this offline maintenance command only.
"""
import collections, hashlib, json, pathlib, sys
import openpyxl
ROOT = pathlib.Path(__file__).resolve().parents[1]
RES = ROOT / 'BirdingCompanion/Resources'
SOURCE = 'https://doi.org/10.6084/m9.figshare.27051040.v1'
MAPPING = {
 'Forest': 'forest-general', 'Woodland': 'woodland-general',
 'Shrub': 'scrub-general', 'Grassland': 'grassland-steppe',
 'Wetland': 'wetland-general', 'Coastal': 'coast-general',
 'Sea': 'open-ocean', 'Savanna': 'savanna', 'Riparian': 'rivers-streams',
 'Rocky': 'rockland-general', 'Plains': 'plains-general',
 'Artificial': 'cultivated-general', 'Desert': 'desert', 'Bamboo': 'bamboo',
}

def resolve(bird, index):
    # A current scientific name takes precedence. Synonyms are accepted only if
    # every matched record agrees on primary habitat. No fuzzy/family matching.
    matches = index.get(bird['scientificName'], [])
    method = 'exact-scientific-name'
    if not matches:
        matches = [r for alias in bird['aliases'] for r in index.get(alias, [])]
        method = 'catalog-scientific-alias'
    habitats = {r[48] for r in matches if r[48]}
    if not matches or any(not r[48] for r in matches) or len(habitats) != 1:
        return None
    return matches, next(iter(habitats)), method

def main(path):
    blob = pathlib.Path(path).read_bytes()
    assert hashlib.md5(blob).hexdigest() == '36d53d59af1e449db1fc4c30062d9d1f', 'Unexpected source version'
    rows = list(openpyxl.load_workbook(path, read_only=True, data_only=True)['Data'].values)
    assert rows[1][48] == 'Primary Habitat' and rows[1][6] == 'AviList v1 2025'
    index = collections.defaultdict(list)
    for row in rows[2:]:
        for name in {str(x).strip() for x in row[2:7] if x}:
            index[name].append(row)
    world = json.loads((RES/'WorldSpeciesCatalog.json').read_text())
    assignments_path = RES/'SpeciesHabitatAssignments.json'
    pilots = [r for r in json.loads(assignments_path.read_text()) if r['reviewStatus']=='source-checked']
    assignments = {r['speciesID']: r for r in pilots}
    unresolved = []
    for bird in world:
        if bird['id'] in assignments:
            continue
        result = resolve(bird, index)
        if result is None:
            unresolved.append({'speciesID':bird['id'], 'scientificName':bird['scientificName'],
                               'reason':'No unambiguous scientific-name match in BIRDBASE v2025.1'})
            continue
        matches, habitat, method = result
        assignments[bird['id']] = {
            'speciesID':bird['id'], 'scientificName':bird['scientificName'],
            'primarySceneID':MAPPING[habitat], 'secondarySceneIDs':[],
            'reviewStatus':'source-derived', 'reviewedAt':'2026-11-19', 'sourceURLs':[SOURCE],
            'sourceDataset':'BIRDBASE v2025.1', 'sourcePrimaryHabitat':habitat,
            'sourceScientificNames':sorted({r[2] for r in matches}), 'matchMethod':method,
        }
    assignments_path.write_text('[\n'+',\n'.join(json.dumps(r,ensure_ascii=False,separators=(',', ':')) for r in sorted(assignments.values(),key=lambda r:r['speciesID']))+'\n]\n')
    provenance = {'dataset':'BIRDBASE v2025.1', 'sourceURL':SOURCE,
        'downloadURL':'https://ndownloader.figshare.com/files/55634729',
        'license':'CC BY 4.0', 'sourceMD5':hashlib.md5(blob).hexdigest(),
        'sourceSHA256':hashlib.sha256(blob).hexdigest(), 'mapping':MAPPING,
        'sourceDerivedAssignments':sum(r['reviewStatus']=='source-derived' for r in assignments.values()),
        'individuallyCheckedAssignments':len(pilots), 'unresolved':unresolved}
    (ROOT/'Docs/BIRDBASEHabitatImport.json').write_text(json.dumps(provenance,ensure_ascii=False,indent=2)+'\n')
    print(f'{len(assignments)} assigned; {len(unresolved)} unresolved')

if __name__ == '__main__':
    main(sys.argv[1])
