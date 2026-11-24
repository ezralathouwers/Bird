import base64
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from PIL import Image
import prepare_logbook_artwork as prepare
import artwork_api_pilot as api


class LogbookArtworkTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.project = self.root / 'app'
        (self.project / 'BirdingCompanion.xcodeproj').mkdir(parents=True)
        self.res = self.project / 'BirdingCompanion/Resources'
        self.res.mkdir(parents=True)
        plan = json.loads(api.DEFAULT_PLAN.read_text())
        world = json.loads((api.ROOT / 'BirdingCompanion/Resources/WorldSpeciesCatalog.json').read_text())
        ids = [r['id'] for r in plan['species'][:3]]
        self.birds = {r['id']: r for r in world if r['id'] in ids}
        self.ids = ids
        (self.res / 'WorldSpeciesCatalog.json').write_text(json.dumps(list(self.birds.values())))
        (self.res / 'ArtworkManifest.json').write_text('[]')
        for path in plan['referenceAssets'].values():
            target = self.project / path; target.parent.mkdir(parents=True, exist_ok=True)
            image = Image.new('RGBA', (1024, 1024)); image.putpixel((10,10),(1,2,3,255)); image.save(target)
        self.history = self.root / 'history.json'
        self.history.write_text(json.dumps({'observations': [{'speciesID': ids[0]}, {'speciesID': ids[1]}, {'speciesID': ids[0]}]}))

    def existing(self, species, role):
        folder = self.res / 'Assets.xcassets' / (species.replace(':','-')+'-'+role+'.imageset')
        folder.mkdir()
        image = Image.new('RGBA',(1024,1024)); image.putpixel((10,10),(1,2,3,255)); image.save(folder/'original.png')
        (folder/'Contents.json').write_text(json.dumps({'images':[{'filename':'original.png'}]}))
        manifest = json.loads((self.res/'ArtworkManifest.json').read_text())
        manifest.append({'speciesID':species,'view':role,'asset':folder.stem})
        (self.res/'ArtworkManifest.json').write_text(json.dumps(manifest))

    def test_scope_only_logged_species_and_missing_roles(self):
        self.existing(self.ids[0],'primary')
        before = (self.res/'ArtworkManifest.json').read_bytes()
        plan, summary = prepare.prepare(self.project, self.history)
        self.assertEqual(summary['loggedSpecies'],2)
        self.assertEqual(summary['missingImages'],3)
        self.assertEqual(set(plan['scopeSpeciesIDs']),set(self.ids[:2]))
        self.assertNotIn(self.ids[2],plan['scopeSpeciesIDs'])
        jobs = api.jobs(plan,root=self.project)
        self.assertEqual(len(jobs),3)
        self.assertEqual({r['role'] for r in jobs},{'primary','dynamic'})
        self.assertEqual((self.res/'ArtworkManifest.json').read_bytes(),before)

    def test_all_existing_art_produces_no_new_work(self):
        for species in self.ids[:2]:
            for role in ['primary','dynamic']:self.existing(species,role)
        plan, summary = prepare.prepare(self.project,self.history)
        self.assertEqual(summary['missingImages'],0)
        self.assertEqual(plan['species'],[])

    def test_backup_checksum_and_raw_exports(self):
        payload = self.history.read_bytes()
        backup = self.root/'backup.json'
        doc = dict(format='BirderBackup',version=1,payload=base64.b64encode(payload).decode(),sha256=hashlib.sha256(payload).hexdigest())
        backup.write_text(json.dumps(doc))
        self.assertEqual(prepare.history_ids(backup,self.birds)[0],set(self.ids[:2]))
        doc['sha256']='wrong';backup.write_text(json.dumps(doc))
        with self.assertRaisesRegex(ValueError,'back-upcontrole'):prepare.history_ids(backup,self.birds)
        self.history.write_text(json.dumps([{'speciesID':self.ids[0]}]))
        self.assertEqual(prepare.history_ids(self.history,self.birds)[0],{self.ids[0]})

    def test_csv_matching_and_unknown_species_fail_before_api(self):
        csv = self.root/'birda.csv'
        csv.write_text('scientificName\n'+self.birds[self.ids[0]]['scientificName']+'\n')
        self.assertEqual(prepare.history_ids(csv,self.birds)[0],{self.ids[0]})
        csv.write_text('scientificName\nUnknown bird\n')
        with self.assertRaises(ValueError):prepare.history_ids(csv,self.birds)
        self.history.write_text('[{"speciesID":"unknown-id"}]')
        with self.assertRaises(ValueError):prepare.prepare(self.project,self.history)

    def test_broken_existing_asset_and_changed_scope_block(self):
        self.existing(self.ids[0],'primary')
        folder = self.res/'Assets.xcassets'/(self.ids[0].replace(':','-')+'-primary.imageset')
        (folder/'original.png').unlink()
        with self.assertRaisesRegex(ValueError,'Onvolledig'):prepare.prepare(self.project,self.history)
        (folder/'original.png').write_bytes(b'fixture')
        plan,_ = prepare.prepare(self.project,self.history)
        plan['scopeSpeciesIDs'].append(self.ids[2])
        with self.assertRaises(ValueError):api.jobs(plan,root=self.project)

    def test_cli_prepares_offline_and_resume_does_not_rewrite_scope(self):
        output = self.root/'out'
        args=[sys.executable,str(Path(prepare.__file__).resolve()),'--project',str(self.project),'--history',str(self.history),'--output',str(output)]
        result=subprocess.run(args,capture_output=True,text=True,check=True)
        self.assertIn('OFFLINE',result.stdout)
        frozen=(output/'plan.json').read_bytes()
        self.history.write_text('[{"speciesID":"unknown-new-record"}]')
        result=subprocess.run(args,capture_output=True,text=True,check=True)
        self.assertIn('hervat',result.stdout)
        self.assertEqual((output/'plan.json').read_bytes(),frozen)
        self.assertFalse((output/'state.json').exists())


if __name__=='__main__':unittest.main()
