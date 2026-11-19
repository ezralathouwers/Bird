#!/usr/bin/env python3
"""Validate shared habitat scenes and report actual species assignment/art coverage."""
import json,csv,pathlib,collections
root=pathlib.Path(__file__).resolve().parents[1];resources=root/'BirdingCompanion/Resources'
scenes=json.loads((resources/'HabitatScenes.json').read_text())
assignments=json.loads((resources/'SpeciesHabitatAssignments.json').read_text())
world=json.loads((resources/'WorldSpeciesCatalog.json').read_text())
scene_ids={x['id'] for x in scenes};world_by_id={x['id']:x for x in world}
assert len(scene_ids)==len(scenes)==24
by_id={x['speciesID']:x for x in assignments};assert len(by_id)==len(assignments)
for row in assignments:
 assert world_by_id[row['speciesID']]['scientificName']==row['scientificName']
 assert row['primarySceneID'] in scene_ids
 assert all(x in scene_ids and x!=row['primarySceneID'] for x in row['secondarySceneIDs'])
 assert len(set(row['secondarySceneIDs']))==len(row['secondarySceneIDs'])
 assert row['reviewStatus'] in ['source-checked','draft'] and row['sourceURLs']
counts=collections.Counter(x['primarySceneID'] for x in assignments if x['reviewStatus']=='source-checked')
summary={'sceneTypes':len(scenes),'sourceCheckedAssignments':sum(counts.values()),
 'unassignedSpeciesRecords':len(world)-sum(counts.values()),
 'assetReadyScenes':[x['id'] for x in scenes if (resources/'Assets.xcassets'/(x['assetName']+'.imageset')/'Contents.json').exists()],
 'primaryAssignmentsByScene':{x['id']:counts[x['id']] for x in scenes}}
(root/'Docs/HabitatCoverage.json').write_text(json.dumps(summary,indent=2)+'\n')
with (root/'Docs/HabitatAssignmentInventory.csv').open('w',newline='') as out:
 writer=csv.writer(out);writer.writerow(['speciesID','scientificName','name','primaryScene','secondaryScenes','reviewStatus'])
 for bird in sorted(world,key=lambda x:x['scientificName']):
  assigned=by_id.get(bird['id'],{})
  writer.writerow([bird['id'],bird['scientificName'],bird['dutchName'] or bird['englishName'],
    assigned.get('primarySceneID',''),';'.join(assigned.get('secondarySceneIDs',[])),assigned.get('reviewStatus','unassigned')])
print(json.dumps(summary,indent=2))
