import json
import os
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest
import install_field_update as update
import test_field_update_project as project_fixture
from field_update_project import block,uid

BASE='e3b45d08a483d7a6e4d6120479273357c73fea49'


class FieldInstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.project=Path(self.temp.name)/'app';self.project.mkdir()
        plan=json.loads((update.ROOT/'Docs/FieldUpdateFiles20261126.json').read_text())
        files=list(plan['files'])+['BirdingCompanion.xcodeproj/project.pbxproj','BirdingCompanion/Resources/Info.plist']
        for relative in files:
            result=subprocess.run(['git','show',BASE+':'+relative],cwd=update.ROOT,capture_output=True)
            if result.returncode:continue
            target=self.project/relative;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(result.stdout)
        self.sentinel=self.project/'BirdingCompanion/Resources/PrivateBirdLifeRanges/private.geojson'
        self.sentinel.parent.mkdir(parents=True);self.sentinel.write_bytes(b'private range sentinel')
        self.asset=self.project/'BirdingCompanion/Resources/Assets.xcassets/local.imageset/picture.png'
        self.asset.parent.mkdir(parents=True);self.asset.write_bytes(b'locally imported artwork sentinel')
        self.manifest=self.project/'BirdingCompanion/Resources/ArtworkManifest.json';self.manifest.write_bytes(b'local artwork manifest sentinel')
        self.pbx=self.project/'BirdingCompanion.xcodeproj/project.pbxproj'
        source=self.pbx.read_text().replace('org.example.BirdingCompanion"','com.test.PrivateBirder"').replace('ASSETCATALOG_COMPILER_APPICON_NAME','DEVELOPMENT_TEAM = MYTEAM; ASSETCATALOG_COMPILER_APPICON_NAME')
        self.pbx.write_text(source)

    def snapshot(self):
        return {str(p.relative_to(self.project)):p.read_bytes() for p in self.project.rglob('*') if p.is_file() and '.artwork-api' not in p.parts}

    def test_install_preserves_private_assets_signing_and_is_repeatable(self):
        old=block(self.pbx.read_text(),'E9B2E96ABC5F6856F2BE79CF')
        self.assertGreater(update.apply(self.project),0)
        self.assertEqual(block(self.pbx.read_text(),'E9B2E96ABC5F6856F2BE79CF'),old)
        self.assertIn('com.test.PrivateBirder.AudioActivity',block(self.pbx.read_text(),uid('widget-config-Debug')))
        self.assertEqual(self.sentinel.read_bytes(),b'private range sentinel')
        self.assertEqual(self.asset.read_bytes(),b'locally imported artwork sentinel')
        self.assertEqual(self.manifest.read_bytes(),b'local artwork manifest sentinel')
        info=plistlib.loads((self.project/'BirdingCompanion/Resources/Info.plist').read_bytes())
        self.assertIn('audio',info['UIBackgroundModes']);self.assertTrue(info['NSSupportsLiveActivities'])
        self.assertEqual(update.apply(self.project),0)

    def test_xcode_reformatted_project_installs_and_remains_repeatable(self):
        formatted=project_fixture.FieldProjectTests().xcode_formatted().replace('org.example.BirdingCompanion"','com.test.PrivateBirder"')
        self.pbx.write_text(formatted)
        original=block(formatted,'E9B2E96ABC5F6856F2BE79CF')
        self.assertGreater(update.apply(self.project),0)
        self.assertEqual(block(self.pbx.read_text(),'E9B2E96ABC5F6856F2BE79CF'),original)
        self.assertEqual(update.apply(self.project),0)
        self.assertEqual(self.sentinel.read_bytes(),b'private range sentinel')

    def test_installed_field_version_receives_only_activity_build_fix(self):
        plan=json.loads((update.ROOT/'Docs/FieldUpdateFiles20261126.json').read_text())
        revision='1e38b351b05acc944e261c9bad361b51880b1baa'
        for relative in list(plan['files'])+['BirdingCompanion.xcodeproj/project.pbxproj','BirdingCompanion/Resources/Info.plist']:
            result=subprocess.run(['git','show',revision+':'+relative],cwd=update.ROOT,capture_output=True)
            self.assertEqual(result.returncode,0)
            path=self.project/relative;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(result.stdout)
        before=self.snapshot()
        self.assertEqual(update.apply(self.project),1)
        after=self.snapshot()
        changed={name for name in after if after[name]!=before.get(name)}
        self.assertEqual(changed,{'BirdingCompanion/Features/Identification/AudioRecordingActivity.swift'})
        self.assertEqual(update.apply(self.project),0)

    def test_unknown_source_refused_before_any_changes(self):
        path=self.project/'BirdingCompanion/Features/Identification/SoundIdentificationModel.swift';path.write_text('local user code')
        before=self.snapshot()
        with self.assertRaisesRegex(ValueError,'aangepaste broncode'):update.apply(self.project)
        self.assertEqual(self.snapshot(),before)

    def test_caught_failure_rolls_back_sources_and_project(self):
        before=self.snapshot()
        def fail():raise RuntimeError('synthetic write failure')
        with self.assertRaises(RuntimeError):update.apply(self.project,after_write=fail)
        self.assertEqual(self.snapshot(),before)
        self.assertFalse((self.project/'.artwork-api/pending-field-update.json').exists())

    def test_hard_process_exit_can_be_recovered_without_touching_data(self):
        before=self.snapshot()
        code='import os,sys;from pathlib import Path;import install_field_update as f;f.apply(Path(sys.argv[1]),after_write=lambda:os._exit(7))'
        result=subprocess.run([sys.executable,'-c',code,str(self.project)],env=dict(os.environ,PYTHONPATH=str(update.ROOT/'Scripts')),capture_output=True)
        self.assertEqual(result.returncode,7,result.stderr.decode())
        with self.assertRaisesRegex(ValueError,'onderbroken'):update.apply(self.project)
        update.recover(self.project);self.assertEqual(self.snapshot(),before)
        self.assertGreater(update.apply(self.project),0)


if __name__=='__main__':unittest.main()
