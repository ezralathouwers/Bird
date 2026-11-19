#!/usr/bin/env python3
"""Report real illustration coverage for every available species page."""
import csv,json,pathlib,collections
root=pathlib.Path(__file__).resolve().parents[1]
resources=root/'BirdingCompanion/Resources'
records=json.loads((resources/'WorldSpeciesCatalog.json').read_text())
art=json.loads((resources/'ArtworkManifest.json').read_text())
roles=['primary','dynamic','front','rear','flight']
available={(x['speciesID'],x['view']) for x in art if (resources/'Assets.xcassets'/(x['asset']+'.imageset')/'Contents.json').exists()}
summary={'records':len(records),'checklistSpecies':sum(x['checklistSpecies'] for x in records),
 'withSound':sum(x['soundIndex'] is not None for x in records),
 'withoutSound':sum(x['soundIndex'] is None for x in records),
 'illustrationsByRole':{role:sum((x['id'],role) in available for x in records) for role in roles},
 'fullyIllustrated':sum(all((x['id'],role) in available for role in roles) for x in records),
 'note':'Pages exist through one shared SwiftUI template. Missing content is not generated scientific data. Artwork still requires anatomical/user review.'}
out=root/'Docs/SpeciesContentInventory.csv'
with out.open('w',newline='') as dst:
 writer=csv.writer(dst);writer.writerow(['id','DutchOrEnglishName','scientificName','family','checklistSpecies','soundID',*roles])
 for record in sorted(records,key=lambda x:x['scientificName']):
  writer.writerow([record['id'],record['dutchName'] or record['englishName'],record['scientificName'],record['family'],record['checklistSpecies'],record['soundIndex'] is not None,*[(record['id'],role) in available for role in roles]])
(root/'Docs/SpeciesContentCoverage.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary,indent=2))
