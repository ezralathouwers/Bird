import copy
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch
from PIL import Image
import restore_previous_artwork as restore
import artwork_api_repairs as repairs


class PreviousArtworkTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name);self.old=self.root/'old';self.new=self.root/'new'
        for project in [self.old,self.new]:
            (project/'BirdingCompanion.xcodeproj').mkdir(parents=True)
            (project/'BirdingCompanion.xcodeproj/project.pbxproj').write_text('synthetic')
            res=project/'BirdingCompanion/Resources';(res/'Assets.xcassets').mkdir(parents=True)
            repairs.api.write_json(res/'ArtworkManifest.json',[])
            repairs.api.write_json(res/'WorldSpeciesCatalog.json',[dict(id='bird:test'),dict(id='bird:other')])
        self.add(self.old,'test',(50,40,30,255));self.add(self.old,'other',(100,120,80,255))

    def res(self,project):return project/'BirdingCompanion/Resources'
    def add(self,project,name,color):
        asset='bird-'+name+'-primary';folder=self.res(project)/'Assets.xcassets'/(asset+'.imageset');folder.mkdir()
        im=Image.new('RGBA',(1024,1024));im.putpixel((500,500),color);im.save(folder/'primary.png')
        repairs.api.write_json(folder/'Contents.json',dict(images=[dict(filename='primary.png')]))
        rows=repairs.read(self.res(project)/'ArtworkManifest.json')
        rows.append(dict(speciesID='bird:'+name,asset=asset,view='primary',sha256=repairs.digest(folder/'primary.png'),anatomyReview=dict(twoWings=False)))
        repairs.api.write_json(self.res(project)/'ArtworkManifest.json',rows)

    def test_restores_missing_but_preserves_newer_repair_and_old_source(self):
        self.add(self.new,'test',(255,0,0,255))
        old={p.relative_to(self.old):p.read_bytes() for p in self.old.rglob('*') if p.is_file()}
        newer=(self.res(self.new)/'Assets.xcassets/bird-test-primary.imageset/primary.png').read_bytes()
        result=restore.restore(self.old,self.new);self.assertEqual(result['restored'],1);self.assertEqual(result['kept'],1)
        self.assertEqual((self.res(self.new)/'Assets.xcassets/bird-test-primary.imageset/primary.png').read_bytes(),newer)
        self.assertEqual({p.relative_to(self.old):p.read_bytes() for p in self.old.rglob('*') if p.is_file()},old)
        record=next(r for r in repairs.read(self.res(self.new)/'ArtworkManifest.json') if r['speciesID']=='bird:other')
        self.assertFalse(record['anatomyReview']['twoWings'])
        before=(self.res(self.new)/'ArtworkManifest.json').read_bytes()
        self.assertEqual(restore.restore(self.old,self.new)['restored'],0)
        self.assertEqual((self.res(self.new)/'ArtworkManifest.json').read_bytes(),before)

    def test_changed_source_hash_or_incomplete_destination_never_overwritten(self):
        source=self.res(self.old)/'Assets.xcassets/bird-test-primary.imageset/primary.png';source.write_bytes(source.read_bytes()+b'changed')
        with self.assertRaisesRegex(ValueError,'wijkt af'):restore.restore(self.old,self.new)
        self.assertEqual(repairs.read(self.res(self.new)/'ArtworkManifest.json'),[])
        shutil.copy2(source,self.root/'changed.png')
        self.add(self.new,'test',(200,0,0,255));(self.res(self.new)/'Assets.xcassets/bird-test-primary.imageset/primary.png').unlink()
        result=restore.restore(self.old,self.new)
        self.assertEqual(result['restored'],1);self.assertEqual(len(result['warnings']),1)
        self.assertFalse((self.res(self.new)/'Assets.xcassets/bird-test-primary.imageset/primary.png').exists())

    def test_legacy_destination_without_hash_does_not_block_other_missing_roles(self):
        self.add(self.new,'test',(255,0,0,255))
        mp=self.res(self.new)/'ArtworkManifest.json';rows=repairs.read(mp);rows[0].pop('sha256');repairs.api.write_json(mp,rows)
        image=self.res(self.new)/'Assets.xcassets/bird-test-primary.imageset/primary.png';before=image.read_bytes()
        result=restore.restore(self.old,self.new)
        self.assertEqual(result['restored'],1);self.assertEqual(result['warnings'],[])
        self.assertEqual(image.read_bytes(),before)
        self.assertNotIn('sha256',repairs.read(mp)[0])

    def test_missing_legacy_source_without_hash_gets_technical_hash_only(self):
        mp=self.res(self.old)/'ArtworkManifest.json';rows=repairs.read(mp)
        rows[0].pop('sha256');repairs.api.write_json(mp,rows)
        result=restore.restore(self.old,self.new);self.assertEqual(result['restored'],2)
        row=repairs.read(self.res(self.new)/'ArtworkManifest.json')[0]
        self.assertFalse(row['carryoverTechnicalVerification']['sourceHashWasRecorded'])
        self.assertFalse(row['anatomyReview']['twoWings'])
        self.assertEqual(row['sha256'],repairs.digest(self.res(self.old)/'Assets.xcassets/bird-test-primary.imageset/primary.png'))

    def test_exception_mid_commit_restores_all_destination_files(self):
        before=(self.res(self.new)/'ArtworkManifest.json').read_bytes()
        def fail():raise RuntimeError('synthetic')
        with self.assertRaises(RuntimeError):restore.restore(self.old,self.new,after_swap=fail)
        self.assertEqual((self.res(self.new)/'ArtworkManifest.json').read_bytes(),before)
        self.assertEqual(list((self.res(self.new)/'Assets.xcassets').iterdir()),[])
        self.assertFalse((self.new/'.artwork-api/pending-repair-install.json').exists())

    def test_session_update_preserves_backup_and_refuses_unknown_user_edit(self):
        relative=Path('BirdingCompanion/Features/Sessions/SessionEnhancements.swift')
        target=self.new/relative;target.parent.mkdir(parents=True);target.write_bytes(b'synthetic released source')
        original=target.read_bytes()
        with patch.object(restore,'KNOWN_SESSION_SOURCES',{repairs.api.sha(original)}):
            self.assertTrue(restore.update_sessions(self.new));self.assertFalse(restore.update_sessions(self.new))
        backup=self.new/'.artwork-api/session-view-backups'/(repairs.api.sha(original)+'.swift')
        self.assertEqual(backup.read_bytes(),original)
        target.write_bytes(b'local user edit')
        with self.assertRaises(ValueError):restore.update_sessions(self.new)
        self.assertEqual(target.read_bytes(),b'local user edit')

    def test_identical_project_or_unknown_species_are_not_silently_corrupted(self):
        with self.assertRaises(ValueError):restore.restore(self.old,self.old)
        repairs.api.write_json(self.res(self.new)/'WorldSpeciesCatalog.json',[])
        result=restore.restore(self.old,self.new)
        self.assertEqual(result['unknown'],2);self.assertEqual(result['restored'],0)


if __name__=='__main__':unittest.main()
