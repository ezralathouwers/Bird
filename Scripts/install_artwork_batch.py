#!/usr/bin/env python3
"""Install reviewed generated originals without overwriting existing assets.
Input JSON rows: id, role, path, optional referenceURL and representativePlumage.
Flight rows require projection: centered-ventral-spread.
Reviewed rows require anatomyReview with sha256 of the inspected original and
twoWings, singleHeadAndBill, poseAndFraming all true. This is a visual-review
attestation, not automatic anatomical detection. Explicit owner bulk acceptance
may instead install primary/dynamic candidates as UNREVIEWED, preserving false
review flags and a hash-bound ownerAcceptance record.
Usage: install_artwork_batch.py mapping.json batch-id
Requires Pillow for maintenance-time image inspection, never at app runtime.
"""
import datetime,hashlib,json,pathlib,shutil,sys
from PIL import Image
ROOT=pathlib.Path(__file__).resolve().parents[1];RES=ROOT/'BirdingCompanion/Resources'

def validate_anatomy_review(row,blob):
 review=row.get('anatomyReview',{})
 if review.get('sha256')!=hashlib.sha256(blob).hexdigest() or any(review.get(k) is not True for k in ['twoWings','singleHeadAndBill','poseAndFraming']):
  raise ValueError('Full-image visual anatomy review required for this exact PNG: two wings, one head/bill, pose and framing')
 return dict(review)

def validate_owner_acceptance(row,blob):
 acceptance=row.get('ownerAcceptance',{})
 if row.get('role') not in ['primary','dynamic'] or acceptance.get('method')!='bulk-user-accepted-unreviewed' or acceptance.get('sha256')!=hashlib.sha256(blob).hexdigest():
  raise ValueError('Explicit owner bulk acceptance must match this exact primary/dynamic PNG')
 try:
  date=datetime.datetime.fromisoformat(acceptance['acceptedAt'].replace('Z','+00:00'))
  if date.tzinfo is None:raise ValueError('Timezone required')
 except (KeyError,ValueError,TypeError):
  raise ValueError('Owner acceptance timestamp must include a timezone')
 return dict(acceptance)

def install(mapping,batch):
 rows=json.loads(pathlib.Path(mapping).read_text());catalog={r['id']:r for r in json.loads((RES/'WorldSpeciesCatalog.json').read_text())}
 mp=RES/'ArtworkManifest.json';manifest=json.loads(mp.read_text());prepared=[];seen=set()
 for r in rows:
  assert r['id'] in catalog and r['role'] in ['primary','dynamic','front','rear','flight']
  if r['role']=='flight':assert r.get('projection')=='centered-ventral-spread', 'Flight must use the approved centered underside view'
  asset=r['id'].replace(':','-')+'-'+r['role'];folder=RES/'Assets.xcassets'/(asset+'.imageset')
  assert asset not in seen and not folder.exists() and not any(m['asset']==asset for m in manifest),asset
  seen.add(asset);source=pathlib.Path(r['path']);blob=source.read_bytes()
  owner_acceptance=validate_owner_acceptance(r,blob) if r.get('ownerAcceptance') else None
  if owner_acceptance:
   anatomy_review=dict(sha256=hashlib.sha256(blob).hexdigest(),twoWings=False,singleHeadAndBill=False,poseAndFraming=False,noProps=False)
  else:anatomy_review=validate_anatomy_review(r,blob)
  if r['role']=='primary' and (r.get('composition')!='bird-only' or (not owner_acceptance and anatomy_review.get('noProps') is not True)):
   raise ValueError('Classic portraits must show only the bird: composition bird-only and visual noProps review required')
  with Image.open(source) as image:
   image.load();assert image.mode=='RGBA'
   # Accept both square originals and wide flight compositions without upscaling.
   assert min(image.size)>=1024 or (r['role']=='flight' and image.width>=1536 and image.height>=768)
   low,high=image.getchannel('A').getextrema();assert low==0 and high>=220
   size=image.size
  facing={'front':'front','rear':'rear','flight':'up'}.get(r['role'],'right')
  record={'speciesID':r['id'],'asset':asset,'view':r['role'],'mediaType':'illustration','version':1,'sourceFile':source.name,'source':'Original OpenAI-generated illustration for this project','created':r.get('created',datetime.date.today().isoformat()),'reviewStatus':'Visual review of role, framing, facing and main species markings performed; independent expert and native/user review pending','rights':'Generated output subject to applicable OpenAI terms; no third-party copied media','sourceFacing':facing,'displayFacing':facing,'displayTransform':'none','sha256':hashlib.sha256(blob).hexdigest(),'pixelWidth':size[0],'pixelHeight':size[1],'background':'transparent','batch':batch,'representativePlumage':r.get('representativePlumage','adult'),'referenceURLs':[r['referenceURL']] if r.get('referenceURL') else []}
  if owner_acceptance:
   record['reviewStatus']='Owner accepted in bulk; individual visual/anatomy review not performed, corrections may follow'
   record['ownerAcceptance']=owner_acceptance
   record['visualReview']=dict(speciesPlumage=False,styleMatch=False,transparency=False,notes='Technical file checks only; no individual visual approval claimed')
  if r.get('generationProvenance'):
   provenance=r['generationProvenance']
   assert provenance.get('outputSHA256')==record['sha256'], 'Generation provenance must match the exact original'
   record['generationProvenance']=dict(provenance)
  if r['role']=='flight':record['projection']='centered-ventral-spread'
  record['anatomyReview']=anatomy_review
  if r['role']=='primary':record['composition']='bird-only'
  prepared.append((r,source,folder,record))
 for r,source,folder,record in prepared:
  folder.mkdir();filename=r['role']+'.png';shutil.copy2(source,folder/filename)
  (folder/'Contents.json').write_text(json.dumps({'images':[{'filename':filename,'idiom':'universal'}],'info':{'author':'xcode','version':1}},indent=2)+'\n')
  manifest.append(record)
 mp.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
 print(f'Installed {len(prepared)} original assets for {batch}; existing assets and species IDs preserved.')

if __name__=='__main__':install(*sys.argv[1:])
