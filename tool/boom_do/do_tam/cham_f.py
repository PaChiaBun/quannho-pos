import json,collections,sys
import os
S=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))+'/'
bo,nhan=sys.argv[1],sys.argv[2]; chi=len(sys.argv)>3
t=[json.loads(l) for l in open(S+bo+'/tim_'+nhan+'.jsonl')]
h=[r for r in t if r['loai']=='HUONG_DAN']
print('%s/%s TÌM BÀI: nhận đúng %d/%d; thẳng sai bài %d'%(bo,nhan,sum(r['got'] for r in h),len(h),sum(1 for r in h if r['sure'] and r['top'] not in r['expect'])))
if chi:
  for r in h:
    if not r['got']: print('  LỌT:',r['q'],'| top',r['top'])
d=[json.loads(l) for l in open(S+bo+'/duong_'+nhan+'.jsonl')]
OK={'SO_LIEU':{'so_lieu_nhanh','so_lieu_muc','tu_van_so_lieu','chuoi'},'TU_VAN_SO':{'tu_van_so_lieu','so_lieu_muc','chuoi'},'HUONG_DAN':{'huong_dan'},'TU_VAN':{'tu_van','tu_van_so_lieu','huong_dan','so_lieu_muc','chuoi'},'LAC_DE':{'tu_van','khac'}}
st=collections.defaultdict(lambda:[0,0])
for r in d:
  ok=r['duong'] in OK[r['loai']]; st[r['loai']][0]+=ok; st[r['loai']][1]+=1
  if chi and not ok: print('  [%s → %s] %s'%(r['loai'],r['duong'],r['q']))
print('   ĐƯỜNG:',{k:'%d/%d'%tuple(v) for k,v in st.items()}, 'tổng %d/%d'%(sum(v[0] for v in st.values()),len(d)))
