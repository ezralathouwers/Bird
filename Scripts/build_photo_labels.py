#!/usr/bin/env python3
"""Map a pinned CC0 BioCLIP label pack to existing IDs; never fuzzy-match taxa."""
import collections,hashlib,json,pathlib,struct,sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
RES=ROOT/'BirdingCompanion/Resources'
def build(path):
 data=pathlib.Path(path).read_bytes()
 assert hashlib.sha256(data).hexdigest()=='f12ad9a5c5cca37f00fe2a19a085df8b6e60882e1b8f113bcb947d7d36d3af43'
 assert data[:4]==b'FPK1'
 size=struct.unpack('<I',data[4:8])[0];header=json.loads(data[8:8+size])
 assert header['dim']==768 and header['rows']==15331 and len(data)-8-size==15331*768*2
 world=json.loads((RES/'WorldSpeciesCatalog.json').read_text());exact={r['scientificName']:r['id'] for r in world};aliases=collections.defaultdict(set)
 for r in world:
  for n in r['aliases']:aliases[n].add(r['id'])
 ids=[]
 for r in header['labels']:
  name=' '.join(r[5:7]);matches={exact[name]} if name in exact else aliases[name]
  ids.append(next(iter(matches)) if r[2]=='Aves' and len(matches)==1 else None)
 (RES/'BioCLIPLabels.json').write_text(json.dumps(ids,separators=(',',':'))+'\n')
 known=set(x for x in ids if x)
 summary={'rows':len(ids),'mappedRows':sum(x is not None for x in ids),'mappedSpecies':len(known),
 'unmappedCatalogSpecies':[{'id':r['id'],'scientificName':r['scientificName']} for r in world if r['id'] not in known],
 'mapping':'Exact scientific names, otherwise unambiguous existing scientific aliases; unknown bird and non-bird rows remain rejection competitors.'}
 (ROOT/'Docs/PhotoIDCoverage.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
 print({k:v for k,v in summary.items() if k!='unmappedCatalogSpecies'})
if __name__=='__main__':build(sys.argv[1])
