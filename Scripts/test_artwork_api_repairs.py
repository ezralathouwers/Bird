import base64
import copy
import io
import json
import os
import subprocess
import sys
from pathlib import Path
import shutil
import tempfile
import unittest
from PIL import Image
import artwork_api_pilot as api
import artwork_api_repairs as repairs


class ArtworkRepairTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name);self.project=self.root/'app';self.res=self.project/'BirdingCompanion/Resources'
        (self.res/'Assets.xcassets').mkdir(parents=True)
        for file in ['WorldSpeciesCatalog.json','ArtworkManifest.json']:
            shutil.copy2(api.ROOT/'BirdingCompanion/Resources'/file,self.res/file)
        self.plan=json.loads(repairs.PLAN.read_text())
        for relative in self.plan['referenceAssets'].values():
            path=self.project/relative;path.parent.mkdir(parents=True,exist_ok=True)
            path.write_bytes((api.ROOT/relative).read_bytes())
        self.output=self.root/'output';self.calls=[]
        self.jobs=repairs.repair_jobs(self.plan,self.project)

    def sender(self,blob,key):
        payload=json.loads(blob);self.calls.append(payload)
        image=Image.new('RGBA',tuple(map(int,payload['size'].split('x'))))
        image.putpixel((500,500),(20,30,40,255));buffer=io.BytesIO();image.save(buffer,'PNG')
        return dict(data=[dict(b64_json=base64.b64encode(buffer.getvalue()).decode())],usage=dict(input_tokens_details=dict(text_tokens=100,image_tokens=200),output_tokens=300)), 'fake-request'

    def generate(self,count=1):
        return api.run(self.plan,self.jobs,self.output,'fake-key',count,5,sender=self.sender)

    def prepare_old(self,count=1):
        # Bind the synthetic rejected originals to a synthetic plan, not real QA.
        for target in self.plan['targets'][:count]:
            folder=self.res/'Assets.xcassets'/(target['key']+'.imageset');folder.mkdir()
            image=Image.new('RGBA',(1024,1024));image.putpixel((450,450),(200,100,50,255));image.save(folder/'old.png')
            target['originalSHA256']=repairs.digest(folder/'old.png')
            api.write_json(folder/'Contents.json',dict(images=[dict(filename='old.png')]))
            manifest=json.loads((self.res/'ArtworkManifest.json').read_text())
            manifest.append(dict(speciesID=target['id'],view=target['role'],asset=target['key'],sha256=target['originalSHA256'],version=3))
            api.write_json(self.res/'ArtworkManifest.json',manifest)
        self.plan['targetsSHA256']=api.sha(json.dumps(self.plan['targets'],sort_keys=True,separators=(',',':')).encode())
        self.jobs=repairs.repair_jobs(self.plan,self.project)

    def test_fixed_target_count_pilot_and_preserved_good_primary_roles(self):
        self.assertEqual(len(self.jobs),77)
        self.assertEqual(len({j['id'] for j in self.jobs}),62)
        self.assertEqual(len(self.plan['pilotKeys']),6)
        self.assertFalse(set(self.plan['preservedKeys']) & {j['key'] for j in self.jobs})
        for job in self.jobs:self.assertIn(api.COMPOSITION_RULES,job['prompt'])
        tampered=copy.deepcopy(self.plan);tampered['targets'].pop()
        with self.assertRaises(ValueError):repairs.repair_jobs(tampered,self.project)

    def test_pilot_and_full_run_share_checkpoints_without_duplicate_calls(self):
        state=self.generate(1)
        self.generate(1)
        self.assertEqual(len(self.calls),2)
        self.assertEqual(len(json.loads((self.output/'state.json').read_text())['jobs']),2)
        repairs.refresh_review(self.jobs,state,self.output)
        self.assertFalse(json.loads((self.output/'framing-report.json').read_text())[0]['anatomyAssessed'])

    def test_exact_replacements_preserve_backups_unrelated_assets_and_real_review_flags(self):
        self.prepare_old();old=(self.res/'ArtworkManifest.json').read_bytes()
        key=self.plan['targets'][0]['key'];folder=self.res/'Assets.xcassets'/(key+'.imageset');old_png=(folder/'old.png').read_bytes()
        self.generate();self.assertEqual(repairs.install_completed(self.plan,self.project,self.output,accept=True),1)
        record=next(r for r in json.loads((self.res/'ArtworkManifest.json').read_text()) if r['asset']==key)
        self.assertEqual(record['version'],4)
        old_unrelated=[r for r in json.loads(old) if r['asset']!=key]
        new_unrelated=[r for r in json.loads((self.res/'ArtworkManifest.json').read_text()) if r['asset']!=key]
        self.assertEqual(old_unrelated,new_unrelated)
        self.assertEqual(record['replacesSHA256'],api.sha(old_png))
        self.assertFalse(record['anatomyReview']['twoWings']);self.assertFalse(record['visualReview']['speciesPlumage'])
        backups=list((self.project/'.artwork-api/repair-import-backups').iterdir());self.assertEqual(len(backups),1)
        self.assertEqual((backups[0]/'ArtworkManifest.json').read_bytes(),old)
        self.assertEqual((backups[0]/(key+'.imageset')/'old.png').read_bytes(),old_png)
        self.assertEqual(repairs.install_completed(self.plan,self.project,self.output,accept=True),0)
        self.assertEqual(len(self.calls),1)

    def test_wrong_old_hash_refuses_overwrite(self):
        self.prepare_old();self.generate()
        folder=self.res/'Assets.xcassets'/(self.plan['targets'][0]['key']+'.imageset')
        (folder/'old.png').write_bytes(b'changed externally')
        before=(self.res/'ArtworkManifest.json').read_bytes()
        with self.assertRaises(ValueError):repairs.install_completed(self.plan,self.project,self.output,accept=True)
        self.assertEqual((folder/'old.png').read_bytes(),b'changed externally')
        self.assertEqual((self.res/'ArtworkManifest.json').read_bytes(),before)

    def test_mid_install_failure_restores_all_old_assets_and_manifest(self):
        self.prepare_old(count=2);self.generate(count=2)
        before=(self.res/'ArtworkManifest.json').read_bytes()
        def crash():raise RuntimeError('synthetic interruption')
        with self.assertRaises(RuntimeError):repairs.install_completed(self.plan,self.project,self.output,accept=True,after_swap=crash)
        self.assertEqual((self.res/'ArtworkManifest.json').read_bytes(),before)
        for target in self.plan['targets'][:2]:
            folder=self.res/'Assets.xcassets'/(target['key']+'.imageset')
            self.assertEqual(repairs.image_hashes(folder),{target['originalSHA256']})
        self.assertFalse((self.project/'.artwork-api/pending-repair-install.json').exists())

    def test_process_crash_leaves_journal_and_explicit_recovery_restores_sources(self):
        self.prepare_old(count=2);self.generate(count=2)
        before=(self.res/'ArtworkManifest.json').read_bytes()
        plan_file=self.root/'fixed-plan.json';api.write_json(plan_file,self.plan)
        code="import os,sys,json; from pathlib import Path; import artwork_api_repairs as r; r.install_completed(json.load(open(sys.argv[1])),Path(sys.argv[2]),Path(sys.argv[3]),accept=True,after_swap=lambda:os._exit(7))"
        result=subprocess.run([sys.executable,'-c',code,str(plan_file),str(self.project),str(self.output)],env=dict(os.environ,PYTHONPATH=str(Path(repairs.__file__).parent)),capture_output=True)
        self.assertEqual(result.returncode,7)
        self.assertTrue((self.project/'.artwork-api/pending-repair-install.json').exists())
        with self.assertRaisesRegex(ValueError,'onderbroken'):
            repairs.install_completed(self.plan,self.project,self.output,accept=True)
        with repairs.project_lock(self.project) as journal:repairs.recover(self.project,journal)
        self.assertEqual((self.res/'ArtworkManifest.json').read_bytes(),before)
        for target in self.plan['targets'][:2]:
            self.assertEqual(repairs.image_hashes(self.res/'Assets.xcassets'/(target['key']+'.imageset')),{target['originalSHA256']})

    def test_positive_margin_below_six_percent_can_be_owner_accepted_without_altering_png(self):
        self.prepare_old();state=self.generate()
        key=self.jobs[0]['key'];path=self.output/state['jobs'][key]['file']
        image=Image.new('RGBA',tuple(map(int,self.jobs[0]['size'].split('x'))))
        image.putpixel((image.width-12,500),(20,30,40,255));image.save(path)
        original=path.read_bytes();new_sha=api.sha(original)
        state['jobs'][key]['outputSHA256']=new_sha;api.write_json(self.output/'state.json',state)
        with self.assertRaises(ValueError):repairs.install_completed(self.plan,self.project,self.output)
        self.assertEqual(repairs.install_completed(self.plan,self.project,self.output,accept=True),1)
        report=json.loads((self.output/'framing-report.json').read_text())[0]
        self.assertFalse(report['passesRightClearance']);self.assertFalse(report['touchesRightEdge'])
        record=next(r for r in json.loads((self.res/'ArtworkManifest.json').read_text()) if r['asset']==key)
        warning=record['ownerAcceptance']['rightMarginWarningAcknowledged']
        self.assertEqual(warning['sha256'],new_sha)
        self.assertAlmostEqual(warning['measuredClearance'],11/image.width)
        self.assertFalse(record['anatomyReview']['twoWings'])
        installed=self.res/'Assets.xcassets'/(key+'.imageset')/(self.jobs[0]['role']+'.png')
        self.assertEqual(installed.read_bytes(),original)

    def test_refuses_missing_acceptance_changed_output_and_insufficient_right_margin(self):
        self.prepare_old();state=self.generate()
        with self.assertRaises(ValueError):repairs.install_completed(self.plan,self.project,self.output)
        key=self.jobs[0]['key'];path=self.output/state['jobs'][key]['file']
        original=path.read_bytes();path.write_bytes(original+b'changed')
        with self.assertRaises(ValueError):repairs.install_completed(self.plan,self.project,self.output,accept=True)
        path.write_bytes(original)
        image=Image.new('RGBA',tuple(map(int,self.jobs[0]['size'].split('x'))));image.putpixel((image.width-1,500),(30,40,50,255));image.save(path)
        state['jobs'][key]['outputSHA256']=repairs.digest(path);api.write_json(self.output/'state.json',state)
        before=(self.res/'ArtworkManifest.json').read_bytes()
        with self.assertRaisesRegex(ValueError,'rechterrand'):repairs.install_completed(self.plan,self.project,self.output,accept=True)
        self.assertEqual((self.res/'ArtworkManifest.json').read_bytes(),before)


if __name__=='__main__':unittest.main()
