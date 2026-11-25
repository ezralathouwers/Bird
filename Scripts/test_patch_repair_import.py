import hashlib
import json
from pathlib import Path
import tempfile
import unittest
import patch_repair_import as patcher

class RepairPatcherTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name);self.folder=self.root/'bestaande-map'
        (self.folder/'Scripts').mkdir(parents=True);(self.folder/'Docs').mkdir()
        (self.folder/'Docs/ArtworkRepairPlan20261125.json').write_text(json.dumps({'batchID':'api-repairs-20261125'}))
        (self.folder/'Scripts/Start-Illustratieherstel.command').write_text('#!/bin/bash\n')
        self.target=self.folder/'Scripts/artwork_api_repairs.py';self.old=b'print("old")\n';self.target.write_bytes(self.old)
        self.target.chmod(0o755)
        data=self.folder/'.artwork-api/repairs-20261125';data.mkdir(parents=True)
        (data/'state.json').write_bytes(b'{"jobs":{"untouched":true}}')
        (data/'original.png').write_bytes(b'unchanged image')
        self.payload=self.root/'new.py';self.payload.write_bytes(b'print("new")\n')
        self.hash=hashlib.sha256(self.old).hexdigest()
    def test_updates_once_backs_up_exact_script_and_never_touches_generated_data(self):
        before={p.name:p.read_bytes() for p in (self.folder/'.artwork-api/repairs-20261125').iterdir()}
        self.assertTrue(patcher.patch(self.folder,self.payload,{self.hash}))
        self.assertEqual(self.target.read_bytes(),self.payload.read_bytes())
        self.assertEqual(self.target.stat().st_mode & 0o777,0o755)
        self.assertFalse(patcher.patch(self.folder,self.payload,{self.hash}))
        backups=list((self.folder/'.artwork-api/script-backups').iterdir())
        self.assertEqual(len(backups),1);self.assertEqual(backups[0].read_bytes(),self.old)
        after={p.name:p.read_bytes() for p in (self.folder/'.artwork-api/repairs-20261125').iterdir()}
        self.assertEqual(before,after)
    def test_unknown_script_wrong_folder_or_broken_payload_never_overwrites(self):
        with self.assertRaises(ValueError):patcher.patch(self.folder,self.payload)
        with self.assertRaises(ValueError):patcher.patch(self.root,self.payload,{self.hash})
        self.payload.write_bytes(b'def broken(')
        with self.assertRaises(SyntaxError):patcher.patch(self.folder,self.payload,{self.hash})
        self.assertEqual(self.target.read_bytes(),self.old)
    def test_accepts_only_original_known_production_version(self):
        import subprocess
        repo=Path(__file__).resolve().parents[1]
        blob=subprocess.check_output(['git','show','41c5358:Scripts/artwork_api_repairs.py'],cwd=repo)
        self.target.write_bytes(blob)
        self.assertTrue(patcher.patch(self.folder,self.payload))

if __name__=='__main__':unittest.main()
