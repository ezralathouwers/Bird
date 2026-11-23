#!/usr/bin/env python3
"""Build a pinned world catalog from official AviList data + licensed BirdNET names.
No photos, descriptions or sound recordings are imported. Input downloads are separate.
"""
import argparse, csv, hashlib, io, json, pathlib, zipfile

FIELDS = 'sequence.rank.order.family.familyEn.sciName.authority.citation.name.nameClements.nameBirdLife.proposalNumber.decisionSummary.range.extinct.iucn.birdLifeUrl.cornellCode.bowUrl.avibaseId.genusGender.typeSpecies.typeLocality.originalDescriptionTitle.originalDescriptionUrl.protonym'.split('.')
DUTCH_NAME_OVERRIDES = {'birdnet-v3:BN09928': 'Zwartkopvlagstaartijsvogel', 'avilist:93d88f0a': 'Norfolkbrilvogel'}

SAMPLE_IDS = {'Turdus merula':'sample-turdus-merula','Parus major':'sample-parus-major',
 'Erithacus rubecula':'sample-erithacus-rubecula','Cyanistes caeruleus':'sample-cyanistes-caeruleus',
 'Dendrocopos major':'sample-dendrocopos-major','Alcedo atthis':'sample-alcedo-atthis'}

def sentence(value):
    value = (value or '').strip()
    return value[:2].upper()+value[2:].lower() if value.startswith('IJ') else value[:1].upper()+value[1:].lower()

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()

def build(avilist, taxonomy, labels, output):
    assert sha(avilist) == '0f00995c819903e35eaee65cf5313193868362f1a6383e05949fe3d3600a8b39', 'Review a changed AviList source.'
    assert sha(taxonomy) == '433f0d19aabdd5c67a26501d05b8826ad23af4c33149771b5d908c7efa7e4fd1', 'Review a changed BirdNET source.'
    raw = json.loads(avilist.read_bytes())
    official = [dict(zip(FIELDS, values)) for values in raw if values[1] == 'species']
    assert len(official) == 11172, 'Pinned AviList v2026 coverage changed; review the source/version.'
    with zipfile.ZipFile(taxonomy) as archive:
        csv_name = next(n for n in archive.namelist() if n.endswith('.csv'))
        extra = [x for x in csv.DictReader(io.StringIO(archive.read(csv_name).decode('utf-8-sig')))
                 if x['taxon_group']=='Aves' and x['record_type']=='species']
    assert len(extra) == 11022
    by_name = {x['scientific_name']:x for x in extra}
    sound = json.loads(labels.read_bytes())
    sound_by_id = {x['birdnetID']: x for x in sound}
    assert len(sound_by_id) == 9788
    records = []
    matched = set()
    for bird in official:
        scientific = bird['sciName']
        names = by_name.get(scientific)
        bn = names['birdnet_id'] if names else None
        if names: matched.add(scientific)
        avibase = bird['avibaseId']
        assert avibase and bird['family'] and scientific and bird['name']
        identifier = SAMPLE_IDS.get(scientific) or ('birdnet-v3:'+bn if bn else 'avilist:'+avibase.removeprefix('avibase-').lower())
        aliases = []
        if names:
            for field in ['scientific_name_aliases','common_name_aliases']:
                aliases.extend(n.strip() for n in names[field].split(';') if n.strip())
        original_english = names['common_name_en'] if names else ''
        if original_english and original_english != bird['name']: aliases.append(original_english)
        records.append(dict(id=identifier, birdnetID=bn, scientificName=scientific,
            dutchName=sentence(names['common_name_nl']) if names else '', englishName=bird['name'],
            family=bird['family'], familyEnglish=bird['familyEn'], order=bird['order'],
            avibaseID=avibase, ebirdCode=bird['cornellCode'], aliases=sorted(set(aliases)),
            extinction=bird['extinct'], checklistSpecies=True,
            soundIndex=sound_by_id[bn]['index'] if bn in sound_by_id else None))
    # Preserve the pre-existing model-specific Hooded Crow concept; never silently merge logs.
    legacy = [x for x in extra if x['scientific_name'] not in matched]
    assert [x['scientific_name'] for x in legacy] == ['Corvus cornix']
    for bird in legacy:
        bn = bird['birdnet_id']
        family_source = next(x for x in official if x['sciName']=='Corvus corone')
        records.append(dict(id='birdnet-v3:'+bn, birdnetID=bn, scientificName=bird['scientific_name'],
            dutchName=sentence(bird['common_name_nl']), englishName=bird['common_name_en'] or bird['common_name'],
            family=family_source['family'], familyEnglish=family_source['familyEn'], order=family_source['order'],
            avibaseID=bird['avibase_id'], ebirdCode=bird['ebird_code'], aliases=[], extinction=None,
            checklistSpecies=False, soundIndex=sound_by_id[bn]['index'] if bn in sound_by_id else None))
    assert len({r['id'] for r in records}) == len(records) == 11173
    assert {r['birdnetID'] for r in records if r['soundIndex'] is not None} == set(sound_by_id)
    for model in sound:
        record = next(r for r in records if r['birdnetID']==model['birdnetID'])
        assert record['scientificName']==model['scientificName'], 'Review a taxonomy/model mismatch.'
    for record in records:
        if record["id"] in DUTCH_NAME_OVERRIDES:
            record["dutchName"] = DUTCH_NAME_OVERRIDES[record["id"]]
    output.mkdir(parents=True,exist_ok=True)
    data = (json.dumps(records, ensure_ascii=False, separators=(',',':'))+'\n').encode()
    (output/'WorldSpeciesCatalog.json').write_bytes(data)
    provenance = dict(version='AviList-v2026_BirdNET-v0.5-Nov2026', checklistSpecies=11172, records=len(records),
        soundSpecies=9788, withoutSound=sum(r['soundIndex'] is None for r in records),
        missingDutch=sum(not r['dutchName'] for r in records), catalogSHA256=hashlib.sha256(data).hexdigest(),
        license='CC BY-SA 4.0 (derived catalog); AviList source CC BY 4.0',
        sources=[dict(url='https://explore.avilist.org/data/avilist-2026.json',sha256=sha(avilist)),
          dict(url='https://zenodo.org/records/24362980',file=taxonomy.name,sha256=sha(taxonomy))],
        changes='Species-only AviList core; BirdNET Dutch names/aliases; sentence-case display; fixed existing app IDs; separate sound coverage. No images or descriptions imported.',
        dutchNameOverrides=DUTCH_NAME_OVERRIDES,
        compatibilityRecords=['Corvus cornix: retained BirdNET-specific concept, not counted as another AviList checklist species.'])
    (output/'WorldSpeciesCatalogProvenance.json').write_text(json.dumps(provenance,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({k:v for k,v in provenance.items() if k not in ['sources','changes','compatibilityRecords']},indent=2))

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--avilist-json',type=pathlib.Path,required=True)
    parser.add_argument('--taxonomy-zip',type=pathlib.Path,required=True)
    parser.add_argument('--labels',type=pathlib.Path,default=pathlib.Path('BirdingCompanion/Resources/BirdNETLabels.json'))
    parser.add_argument('--output',type=pathlib.Path,default=pathlib.Path('BirdingCompanion/Resources'))
    args=parser.parse_args();build(args.avilist_json,args.taxonomy_zip,args.labels,args.output)
