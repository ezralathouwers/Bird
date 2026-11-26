from pathlib import Path
import re
import subprocess
import unittest
from field_update_project import update_project, block, uid

ROOT=Path(__file__).resolve().parents[1]


class FieldProjectTests(unittest.TestCase):
    def original(self):return subprocess.check_output(['git','show','e3b45d08a483d7a6e4d6120479273357c73fea49:BirdingCompanion.xcodeproj/project.pbxproj'],cwd=ROOT).decode()
    def test_app_settings_preserved_widget_added_and_second_update_identical(self):
        old=self.original().replace('CURRENT_PROJECT_VERSION = "1"','CURRENT_PROJECT_VERSION = "12"').replace('MARKETING_VERSION = "0.1"','MARKETING_VERSION = "1.4"').replace('org.example.BirdingCompanion"','com.example.MyBirder"').replace('ASSETCATALOG_COMPILER_APPICON_NAME', 'DEVELOPMENT_TEAM = MYTEAM; ASSETCATALOG_COMPILER_APPICON_NAME')
        new=update_project(old)
        self.assertEqual(block(old,'E9B2E96ABC5F6856F2BE79CF'),block(new,'E9B2E96ABC5F6856F2BE79CF'))
        widget=block(new,uid('widget-config-Debug'))
        self.assertIn('com.example.MyBirder.AudioActivity',widget);self.assertIn('MYTEAM',widget)
        self.assertIn('CURRENT_PROJECT_VERSION = "12"',widget);self.assertIn('MARKETING_VERSION = "1.4"',widget)
        self.assertIn(uid('widget-embed-phase'),block(new,'F75109BEB4DD8800DA6B45F8'))
        self.assertIn(uid('widget-target'),block(new,'98F54143AB4E86B28C3AFEE0'))
        self.assertEqual(update_project(new),new)
        definitions=re.findall(r'^([A-F0-9]{24})\s*=',new,re.M)
        self.assertEqual(len(definitions),len(set(definitions)))
    def test_widget_and_app_compile_same_attributes_but_not_widget_entrypoint(self):
        new=update_project(self.original())
        widget=block(new,uid('widget-sources'))
        self.assertIn(uid('shared-widget'),widget);self.assertIn(uid('widget-build'),widget)
        app=block(new,'949D493B91791558E87BC5D7')
        self.assertIn(uid('BirdingCompanion/Models/AudioRecordingAttributes.swift-app'),app)
        self.assertNotIn(uid('widget-build'),app)
    def test_malformed_or_wrong_project_fails_before_output(self):
        with self.assertRaises(ValueError):update_project('objects = {};')


if __name__=='__main__':unittest.main()
