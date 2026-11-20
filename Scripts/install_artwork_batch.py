#!/usr/bin/env python3
"""Install reviewed generated originals without overwriting existing assets.
Input JSON rows: id, role, path, optional referenceURL and representativePlumage.
Usage: install_artwork_batch.py mapping.json batch-id
Requires Pillow for maintenance-time image inspection, never at app runtime.
"""
import hashlib,json,pathlib,shutil,sys
from PIL import Image
ROOT=pathlib.Path(__file__).resolve().parents[1];RES=ROOT/'BirdingCompanion/Resources'

def install(mapping,batch):
 rows=json.loads(pathlib.Path(mapping).read_text());catalog={r['id']:r for r in json.loads((RES/'WorldSpeciesCatalog.json').read_text())}
 mp=RES/'ArtworkManifest.json';manifest=json.loads(mp.read_text());prepared=[];seen=set()
 for r in rows:
  assert r['id'] in catalog and r['role'] in ['primary','dynamic','front','rear','flight']
  asset=r['id'].replace(':','-')+'-'+r['role'];folder=RES/'Assets.xcassets'/(asset+'.imageset')
  assert asset not in seen and not folder.exists() and not any(m['asset']==asset for m in manifest),asset
  seen.add(asset);source=pathlib.Path(r['path']);blob=source.read_bytes()
  with Image.open(source) as image:
   image.load();assert image.mode=='RGBA' and min(image.size)>=1024
   low,high=image.getchannel('A').getextrema();assert low==0 and high>=220
   size=image.size
  facing={'front':'front','rear':'rear'}.get(r['role'],'right')
  record={'speciesID':r['id'],'asset':asset,'view':r['role'],'mediaType':'illustration','version':1,'sourceFile':source.name,'source':'Original OpenAI-generated illustration for this project','created':'2026-11-20','reviewStatus':'Visual review of role, framing, facing and main species markings performed; independent expert and native/user review pending','rights':'Generated output subject to applicable OpenAI terms; no third-party copied media','sourceFacing':facing,'displayFacing':facing,'displayTransform':'none','sha256':hashlib.sha256(blob).hexdigest(),'pixelWidth':size[0],'pixelHeight':size[1],'background':'transparent','batch':batch,'representativePlumage':r.get('representativePlumage','adult'),'referenceURLs':[r['referenceURL']] if r.get('referenceURL') else []}
  prepared.append((r,source,folder,record))
 for r,source,folder,record in prepared:
  folder.mkdir();filename=r['role']+'.png';shutil.copy2(source,folder/filename)
  (folder/'Contents.json').write_text(json.dumps({'images':[{'filename':filename,'idiom':'universal'}],'info':{'author':'xcode','version':1}},indent=2)+'\n')
  manifest.append(record)
 mp.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
 print(f'Installed {len(prepared)} original assets for {batch}; existing assets and species IDs preserved.')

if __name__=='__main__':install(*sys.argv[1:])
