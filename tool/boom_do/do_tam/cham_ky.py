import json,sys,collections
import os
S=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))+'/'
rows=[json.loads(l) for l in open(S+'bo_i/ky_'+sys.argv[1]+'.jsonl')]
ok=0;n=0;st=collections.Counter();tot=collections.Counter()
for r in rows:
  if r['loai'] not in ('SO_LIEU','TU_VAN_SO') or not r.get('ky'): continue
  want=None if r['ky']=='none' else r['ky']
  got=r['boom']; g=want.split(':')[0] if want else 'none'
  good= got==want
  tot[g]+=1; st[g]+=good; n+=1; ok+=good
  if len(sys.argv)>2 and not good: print('  [%s] %s → %s'%(r['ky'],r['q'],got))
print(sys.argv[1],'KỲ ĐÚNG %d/%d'%(ok,n),{k:'%d/%d'%(st[k],tot[k]) for k in tot})
