"""Collect missing factual span ranges for review; never mutate app data.
Output: /tmp/span_supplements.json. Uses only exact structured scientific names
and dedicated size captions; skips failed/ambiguous pages. No prose/images copied.
"""
import urllib.request,html,re,json,concurrent.futures,pathlib,hashlib
root=pathlib.Path(__file__).resolve().parents[1];res=root/'BirdingCompanion/Resources';world=json.load(open(res/'WorldSpeciesCatalog.json'));details={r['speciesID']:r for r in json.load(open(res/'SpeciesDetails.json'))};base='https://www.vogelbescherming.nl';prefix='/ontdek-vogels/kennis-over-vogels/vogelgids'
def fetch(u):
 try:return urllib.request.urlopen(u,timeout=25).read().decode()
 except Exception:return ''
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as ex:pages=list(ex.map(fetch,[base+prefix+'/?sortorder=titelasc&pag='+str(i) for i in range(1,24)]))
links=sorted({base+html.unescape(u) for s in pages for u in re.findall(r'href=[\"\x27]([^\"\x27]+)',s) if u.startswith(prefix+'/vogel/') and '?' not in u})
print('Species links',len(links),flush=True)
out=[]
def parse(u):
 s=fetch(u)
 if not s:return
 alt=re.search(r'"alternateName"\s*:\s*"([^"\n]+)"',s)
 if not alt or ', ' not in alt[1]:return
 latin=html.unescape(alt[1].split(', ')[-1]).strip();matches=[b for b in world if b['scientificName']==latin]
 if len(matches)!=1 or details[matches[0]['id']]['wingspan'] is not None:return
 # Restrict to dedicated flight/size caption; no incidental prose or wing chord.
 caps=re.findall(r'<p[^>]*class="[^"]*kleed-onderschr[^"]*"[^>]*>(.*?)</p>',s,re.S)
 spans=[]
 for c in caps:
  t=html.unescape(re.sub('<[^>]+>',' ',c));m=re.search(r'spanwijdte\s+(\d+(?:[,.]\d+)?)\s*[-–]\s*(\d+(?:[,.]\d+)?)\s*cm',t,re.I)
  if m:spans.append((float(m[1].replace(',','.')),float(m[2].replace(',','.')),t.strip()))
 if len(set((a,b) for a,b,t in spans))!=1:return
 lo,hi,e=spans[0]
 if not 0<lo<=hi<500:return
 return {'speciesID':matches[0]['id'],'scientificName':latin,'wingspan':{'minimumCM':lo,'maximumCM':hi,'method':'source-checked-guide','sourceScientificName':latin,'sourceURL':u},'evidence':{'checked':'2026-11-21','caption':e,'htmlSHA256':hashlib.sha256(s.encode()).hexdigest(),'identity':'exact structured alternateName scientific name'}}
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as ex:
 for x in ex.map(parse,links):
  if x:out.append(x)
pathlib.Path('/tmp/span_supplements.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n');print('New factual spans',len(out),[(x['scientificName'],x['wingspan']['minimumCM'],x['wingspan']['maximumCM']) for x in out],flush=True)
