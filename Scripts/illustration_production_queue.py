#!/usr/bin/env python3
"""Build the full catalog artwork work queue; never claim generation is running.
Only existing, manifest-backed asset files count as completed image roles.
"""
import collections,csv,json,pathlib
ROOT=pathlib.Path(__file__).resolve().parents[1];RES=ROOT/'BirdingCompanion/Resources'
ROLES=['primary','dynamic','front','rear','flight']
def build():
 world=json.loads((RES/'WorldSpeciesCatalog.json').read_text())
 scenes=json.loads((RES/'HabitatScenes.json').read_text());names={s['id']:s['name'] for s in scenes}
 assignments={a['speciesID']:a['primarySceneID'] for a in json.loads((RES/'SpeciesHabitatAssignments.json').read_text()) if a['reviewStatus'] in ['source-checked','source-derived']}
 artwork=json.loads((RES/'ArtworkManifest.json').read_text());available=collections.defaultdict(set)
 for a in artwork:
  folder=RES/'Assets.xcassets'/(a['asset']+'.imageset');meta=folder/'Contents.json'
  if not meta.exists():continue
  if not any((folder/i.get('filename','')).is_file() for i in json.loads(meta.read_text()).get('images',[])):continue
  if a['view']=='flight' and a.get('projection')!='centered-ventral-spread':continue
  available[a['speciesID']].add(a['view'])
 priority=['gardens-parks','temperate-woodland','forest-general','woodland-general','farmland','rivers-streams','lakes-ponds','reedbeds-marsh']
 priority += [s['id'] for s in scenes if s['id'] not in priority]
 ordered=sorted(world,key=lambda b:(priority.index(assignments[b['id']]) if b['id'] in assignments else len(priority), (b['dutchName'] or b['englishName']).casefold(),b['id']))
 rows=[]
 for bird in ordered:
  done=[r for r in ROLES if r in available[bird['id']]];missing=[r for r in ROLES if r not in done];habitat=assignments.get(bird['id'],'unassigned')
  rows.append({'speciesID':bird['id'],'scientificName':bird['scientificName'],'name':bird['dutchName'] or bird['englishName'],'habitatID':habitat,'habitat':names.get(habitat,'Nog te bepalen'),'completedRoles':';'.join(done),'missingRoles':';'.join(missing),'state':'complete-assets' if not missing else 'queued','expertReview':'pending','flightProjection':'centered-ventral-spread'})
 with (ROOT/'Docs/IllustrationProductionQueue.csv').open('w',newline='') as f:
  writer=csv.DictWriter(f,fieldnames=list(rows[0]),lineterminator='\n');writer.writeheader();writer.writerows(rows)
 groups=collections.Counter(r['habitatID'] for r in rows if r['missingRoles'])
 summary={'catalogRecords':len(world),'targetImageRoles':len(world)*5,'availableImageRoles':sum(len(available[b['id']]) for b in world),'completeSpeciesAssets':sum(r['state']=='complete-assets' for r in rows),'queuedSpecies':sum(r['state']=='queued' for r in rows),'missingImageRoles':sum(len(r['missingRoles'].split(';')) if r['missingRoles'] else 0 for r in rows),'queuedByHabitat':dict(groups),'execution':'Inventory only. No autonomous background worker, scheduled job or image-generation service has been started by this script.'}
 (ROOT/'Docs/IllustrationProductionQueue.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps({k:v for k,v in summary.items() if k!='queuedByHabitat'},indent=2))
 return rows,summary
if __name__=='__main__':build()
