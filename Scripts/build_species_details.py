#!/usr/bin/env python3
"""Import licensed bio excerpts and reported wingspans, never predicted spans.
Usage: build_species_details.py birdbase.xlsx fox-wingspan.xlsx taxonomy.zip
Maintenance dependency: openpyxl. Scientific aliases must already be in catalog.
"""
import collections,hashlib,json,math,pathlib,re,sys,zipfile
import openpyxl
from import_birdbase_habitats import resolve
ROOT=pathlib.Path(__file__).resolve().parents[1];RES=ROOT/'BirdingCompanion/Resources'
HABITATS={'Forest':'bosgebieden','Woodland':'open bossen','Shrub':'struweel en andere lage begroeiing','Grassland':'graslanden','Wetland':'waterrijke gebieden','Coastal':'kustgebieden','Sea':'de open zee','Savanna':'savannes','Riparian':'gebieden langs beken en rivieren','Rocky':'rotsachtige gebieden','Plains':'open vlaktes','Artificial':'door mensen gevormde landschappen','Desert':'woestijnen en halfwoestijnen','Bamboo':'bamboebegroeiing'}
DIETS={'Invertebrate':'Het voedsel bestaat vooral uit ongewervelde dieren.','Fruit':'Het voedsel bestaat vooral uit vruchten.','Omnivore':'Op het menu staan zowel plantaardig als dierlijk voedsel.','Seed':'Het voedsel bestaat vooral uit zaden.','Nectar':'Het voedsel bestaat vooral uit nectar.','Herbivore':'De soort eet voornamelijk plantaardig voedsel.','Vertebrate':'Het voedsel bestaat vooral uit gewervelde dieren.','Fish':'Het voedsel bestaat vooral uit vis.','Carnivore':'De soort eet voornamelijk dierlijk voedsel.','Plant':'Het voedsel is vooral van plantaardige oorsprong.','Scavenger':'De soort voedt zich vooral met aas.','Beeswax':'Bijenwas vormt een belangrijk onderdeel van het voedsel.','Ovivore':'Eieren vormen een belangrijk onderdeel van het voedsel.'}

def excerpt(text):
 text=re.sub(r'\s+',' ',text).strip()
 # Preserve complete sentences, not arbitrary mid-word character cuts.
 sentences=re.split(r'(?<=[.!?])\s+(?=[A-ZÀ-ÖØ-Þ])',text)
 selected=[]
 for sentence in sentences[:3]:
  if selected and len(' '.join(selected+[sentence]))>550:break
  selected.append(sentence)
 result=' '.join(selected)
 return result if result and len(result)<=1000 else None

def reported_span(row):
 if row['needs_prediction'] != False or row['model_used']!='empirical':return None
 def number(key):
  v=row[key]
  return float(v) if isinstance(v,(float,int)) and not isinstance(v,bool) and math.isfinite(v) and 0<v<500 else None
 mid=number('wingspan_reported_mid_all');lo=number('wingspan_reported_min_all');hi=number('wingspan_reported_max_all')
 if mid is None:return None
 if lo is not None and hi is not None and lo<=mid<=hi:return {'minimumCM':lo,'maximumCM':hi}
 return {'minimumCM':mid,'maximumCM':mid}

def main(birdbase,fox,taxonomy):
 assert hashlib.sha256(pathlib.Path(fox).read_bytes()).hexdigest()=='6b55747a5761c08356d92c7a0b524b4e586c28a25316b0a6c1de3738db1d8eda'
 assert hashlib.md5(pathlib.Path(birdbase).read_bytes()).hexdigest()=='36d53d59af1e449db1fc4c30062d9d1f'
 assert hashlib.sha256(pathlib.Path(taxonomy).read_bytes()).hexdigest()=='433f0d19aabdd5c67a26501d05b8826ad23af4c33149771b5d908c7efa7e4fd1'
 rows=list(openpyxl.load_workbook(birdbase,read_only=True,data_only=True)['Data'].values)[2:];idx=collections.defaultdict(list)
 for r in rows:
  for name in set(str(x).strip() for x in r[2:7] if x):idx[name].append(r)
 f=list(openpyxl.load_workbook(fox,read_only=True,data_only=True)['wingspan data'].values);spans={}
 for r in f[1:]:
  v=dict(zip(f[0],r));span=reported_span(v)
  if span:spans.setdefault(str(v['Avibase.ID1']).lower(),[]).append((v,span))
 with zipfile.ZipFile(taxonomy) as z:t=json.loads(z.read('BirdNET+_Taxonomy_v0.5-Nov2026.json'))
 by_id={r['birdnet_id']:r for r in t};world=json.loads((RES/'WorldSpeciesCatalog.json').read_text());output=[]
 for bird in world:
  row={'speciesID':bird['id'],'scientificName':bird['scientificName'],'bio':None,'bioMethod':None,'bioSourceURLs':[],'wingspan':None}
  original=by_id.get(bird['birdnetID'])
  if original and original['scientific_name'] in [bird['scientificName']]+bird['aliases']:
   if original.get('description_sources',{}).get('nl')=='wikipedia':
    text=excerpt(original.get('descriptions',{}).get('nl',''));url=original.get('wikipedia_urls',{}).get('nl')
    if text and isinstance(url,str) and url.startswith('https://nl.wikipedia.org/'):
     row.update(bio=text,bioMethod='wikipedia-nl-excerpt',bioSourceURLs=[url,'https://birdnet.cornell.edu/taxonomy/about'])
  if row['bio'] is None:
   match=resolve(bird,idx)
   if match:
    records,habitat,method=match;diets={r[50] for r in records}
    text=f"Deze soort {'leefde' if bird['extinction'] in ['Extinct','(extinct)'] else 'leeft'} vooral in {HABITATS[habitat]}."
    if len(diets)==1:
     diet=DIETS.get(next(iter(diets)),'')
     if bird['extinction'] in ['Extinct','(extinct)']:
      for present,past in [('bestaat','bestond'),('staan','stonden'),('eet','at'),('vormen','vormden'),('voedt','voedde')]:diet=diet.replace(present,past)
     text+=' '+diet
    row.update(bio=text.strip(),bioMethod='birdbase-habitat-diet',bioSourceURLs=['https://doi.org/10.6084/m9.figshare.27051040.v1'])
  # Concept-ID agreement is required; a familiar name alone is insufficient.
  matches=spans.get(bird['avibaseID'].lower(),[])
  if len(matches)==1:
   source,span=matches[0];row['wingspan']={**span,'method':'reported','sourceScientificName':source['Species1'],'sourceURL':'https://doi.org/10.6084/m9.figshare.32089083.v1'}
  # Independently checked pilot value takes precedence over a conflicting aggregate.
  if bird['id']=='sample-alcedo-atthis':
   row['wingspan']={'minimumCM':24,'maximumCM':26,'method':'source-checked-guide','sourceScientificName':'Alcedo atthis','sourceURL':'https://www.vogelbescherming.nl/ontdek-vogels/kennis-over-vogels/vogelgids/vogel/ijsvogel'}
  output.append(row)
 (RES/'SpeciesDetails.json').write_text('[\n'+',\n'.join(json.dumps(x,ensure_ascii=False,separators=(',',':')) for x in output)+'\n]\n')
 provenance_path=RES/'SpeciesDetailsProvenance.json'
 provenance=json.loads(provenance_path.read_text()) if provenance_path.exists() else {'version':'species-details-2026-11-20'}
 provenance.update(records=len(output),sha256=hashlib.sha256((RES/'SpeciesDetails.json').read_bytes()).hexdigest())
 provenance_path.write_text(json.dumps(provenance,indent=2)+'\n')
 summary={'records':len(output),'bios':sum(r['bio'] is not None for r in output),'bioMethods':dict(collections.Counter(r['bioMethod'] for r in output if r['bioMethod'])),'wingspans':sum(r['wingspan'] is not None for r in output),'predictedWingspansImported':0,'missingBios':[r['speciesID'] for r in output if r['bio'] is None],'missingWingspans':[r['speciesID'] for r in output if r['wingspan'] is None]}
 (ROOT/'Docs/SpeciesDetailsCoverage.json').write_text(json.dumps(summary,indent=2)+'\n');print({k:v for k,v in summary.items() if not k.startswith('missing')})
if __name__=='__main__':main(*sys.argv[1:])
