import json
import os
import subprocess
import sys
from pathlib import Path
import shutil
import unittest
import artwork_api_repairs as repairs
import artwork_api_pilot as api
import import_logbook_and_repairs as combined
import local_artwork_import as local
import test_artwork_api_repairs as fixture


class CombinedImportTests(unittest.TestCase):
    sender=fixture.ArtworkRepairTests.sender
    generate=fixture.ArtworkRepairTests.generate
    prepare_old=fixture.ArtworkRepairTests.prepare_old

    def setUp(self):
        fixture.ArtworkRepairTests.setUp(self)
        self.plan['targets']=self.plan['targets'][:2]
        self.plan['pilotKeys']=[t['key'] for t in self.plan['targets']]
        api.write_json(self.res/'ArtworkManifest.json',[])
        self.prepare_old(count=2)
        (self.project/'BirdingCompanion.xcodeproj').mkdir()
        (self.project/'BirdingCompanion.xcodeproj/project.pbxproj').write_text('synthetic')
        self.logbook=self.root/'logbook/.artwork-api/logbook-medium';self.logbook.mkdir(parents=True)
        self.rows=[];state={'jobs':{}}
        for target in self.plan['targets']:
            key=target['key'];source=self.res/'Assets.xcassets'/(key+'.imageset')/'old.png'
            shutil.copy2(source,self.logbook/(key+'.png'))
            self.add_candidate(target['id'],target['role'],key,state)
        target=self.plan['targets'][0];key=target['id'].replace(':','-')+'-primary'
        shutil.copy2(self.logbook/(target['key']+'.png'),self.logbook/(key+'.png'))
        self.add_candidate(target['id'],'primary',key,state)
        api.write_json(self.logbook/'state.json',state)
        api.write_json(self.logbook/'review-template.json',self.rows)
        for target in self.plan['targets']:
            shutil.rmtree(self.res/'Assets.xcassets'/(target['key']+'.imageset'))
        api.write_json(self.res/'ArtworkManifest.json',[])
        self.generate(count=2)

    def add_candidate(self,id,role,key,state):
        sha=repairs.digest(self.logbook/(key+'.png'))
        state['jobs'][key]=dict(status='generated_unreviewed',file=key+'.png',outputSHA256=sha)
        self.rows.append(dict(id=id,role=role,path='/old/path',composition='bird-only',anatomyReview=dict(sha256=sha),generationProvenance=dict(outputSHA256=sha)))

    def run_import(self,**kw):
        return combined.install(self.project,self.logbook.parents[1],self.output,self.plan,**kw)

    def assert_final(self):
        manifest=repairs.read(self.res/'ArtworkManifest.json')
        self.assertEqual(len(manifest),3)
        state=repairs.read(self.output/'state.json')
        for target in self.plan['targets']:
            record=next(r for r in manifest if r['asset']==target['key'])
            self.assertEqual(record['sha256'],state['jobs'][target['key']]['outputSHA256'])
            self.assertEqual(record['replacesSHA256'],target['originalSHA256'])
            self.assertFalse(record['anatomyReview']['twoWings'])

    def test_missing_big_batch_installs_final_replacements_and_rerun_is_noop(self):
        before={p:p.read_bytes() for p in self.logbook.iterdir()}
        result=self.run_import();self.assertEqual(result['changed'],3);self.assertEqual(result['superseded'],2)
        self.assert_final()
        self.assertEqual({p:p.read_bytes() for p in self.logbook.iterdir()},before)
        manifest=(self.res/'ArtworkManifest.json').read_bytes()
        self.assertEqual(self.run_import()['changed'],0)
        self.assertEqual((self.res/'ArtworkManifest.json').read_bytes(),manifest)

    def test_previously_installed_old_batch_gets_repaired_with_original_backups(self):
        available,_=local.candidates(self.logbook,self.project)
        mapping=self.root/'accepted.json';api.write_json(mapping,local.accept_all(available)['rows'])
        previous=combined.installer.RES
        try:
            combined.installer.RES=self.res;combined.installer.install(mapping,'test-old')
        finally:combined.installer.RES=previous
        self.assertEqual(self.run_import()['changed'],2);self.assert_final()
        backup=list((self.project/'.artwork-api/repair-import-backups').iterdir())[0]
        for target in self.plan['targets']:
            self.assertEqual(repairs.image_hashes(backup/(target['key']+'.imageset')),{target['originalSHA256']})

    def test_corrupt_repair_or_unrelated_existing_asset_changes_nothing(self):
        state=repairs.read(self.output/'state.json');path=self.output/next(iter(state['jobs'].values()))['file']
        blob=path.read_bytes();path.write_bytes(blob+b'changed')
        before=(self.res/'ArtworkManifest.json').read_bytes()
        folders=set((self.res/'Assets.xcassets').iterdir())
        with self.assertRaises(ValueError):self.run_import()
        self.assertEqual((self.res/'ArtworkManifest.json').read_bytes(),before)
        self.assertEqual(set((self.res/'Assets.xcassets').iterdir()),folders)
        path.write_bytes(blob)
        row=self.rows[-1];folder=self.res/'Assets.xcassets'/(row['id'].replace(':','-')+'-primary.imageset')
        folder.mkdir();(folder/'Contents.json').write_text('{"images":[]}')
        with self.assertRaises(ValueError):self.run_import()
        self.assertTrue(folder.exists());self.assertEqual((self.res/'ArtworkManifest.json').read_bytes(),before)

    def test_incomplete_repairs_rejected_before_any_real_install(self):
        state=repairs.read(self.output/'state.json');state['jobs'].pop(next(iter(state['jobs'])))
        api.write_json(self.output/'state.json',state)
        with self.assertRaisesRegex(ValueError,'niet volledig'):self.run_import()
        self.assertEqual(repairs.read(self.res/'ArtworkManifest.json'),[])

    def test_failure_mid_commit_rolls_back_both_batches_then_can_retry(self):
        before=(self.res/'ArtworkManifest.json').read_bytes()
        def crash():raise RuntimeError('synthetic crash')
        with self.assertRaises(RuntimeError):self.run_import(after_swap=crash)
        self.assertEqual((self.res/'ArtworkManifest.json').read_bytes(),before)
        for row in self.rows:
            self.assertFalse((self.res/'Assets.xcassets'/(row['id'].replace(':','-')+'-'+row['role']+'.imageset')).exists())
        self.assertFalse((self.project/'.artwork-api/pending-repair-install.json').exists())
        self.run_import();self.assert_final()

    def test_hard_process_stop_recovers_both_batches(self):
        plan_file=self.root/'plan.json';api.write_json(plan_file,self.plan)
        before=(self.res/'ArtworkManifest.json').read_bytes()
        code="import os,sys;from pathlib import Path;import import_logbook_and_repairs as c; c.install(Path(sys.argv[1]),Path(sys.argv[2]),Path(sys.argv[3]),c.repairs.read(sys.argv[4]),after_swap=lambda:os._exit(7))"
        result=subprocess.run([sys.executable,'-c',code,str(self.project),str(self.logbook),str(self.output),str(plan_file)],env=dict(os.environ,PYTHONPATH=str(Path(combined.__file__).parent)),capture_output=True)
        self.assertEqual(result.returncode,7,result.stderr.decode())
        journal=self.project/'.artwork-api/pending-repair-install.json'
        self.assertTrue(journal.exists())
        with self.assertRaisesRegex(ValueError,'onderbroken'):self.run_import()
        with repairs.project_lock(self.project) as locked:repairs.recover(self.project,locked)
        self.assertEqual((self.res/'ArtworkManifest.json').read_bytes(),before)
        self.assertFalse(journal.exists())
        self.run_import();self.assert_final()


if __name__=='__main__':unittest.main()
