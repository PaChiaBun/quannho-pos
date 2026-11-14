import json,sys,collections,re
import os
S=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))+'/'
rows=[json.loads(l) for l in open(S+sys.argv[2]+'/kq_'+sys.argv[1]+'.jsonl')]
OK={'SO_LIEU':{'so_lieu_nhanh','so_lieu_muc','tu_van_so_lieu','chuoi'},'TU_VAN_SO':{'tu_van_so_lieu','so_lieu_muc','chuoi'},'HUONG_DAN':{'huong_dan'},'TU_VAN':{'tu_van','tu_van_so_lieu','huong_dan','so_lieu_muc','chuoi'},'LAC_DE':{'tu_van','khac'}}
st=collections.defaultdict(lambda:[0,0,0])
for r in rows:
  d=r['duong'] in OK[r['loai']]
  ctx=r['lich_su'] is not None or (r['loader'] is not None and len(r['loader'])>len(r['q'])+3)
  if r['noi_tiep'] and r['duong']=='so_lieu_nhanh' and r['ky_dung_nhan'] and r['ky']==r['ky_dung_nhan']: ctx=True
  # câu hướng dẫn: máy chủ tự nhớ lượt trước (sổ hỏi đáp) → chấm theo GPT có nhận đoạn đúng không
  if r['loai']=='HUONG_DAN': ctx = bool(r.get('doan')) and any(x in r['expect'] for x in r['doan']); c = ctx
  else: c= ctx if r['noi_tiep'] else not ctx
  k= (r['ky_dung_nhan'] is None) or r['ky']==r['ky_dung_nhan']
  key='%s/%s'%(r['loai'],'tiep' if r['noi_tiep'] else 'moi')
  g=d and c and k
  st[key][0]+=g; st[key][1]+=1
  if len(sys.argv)>2 and not g: print('  [%s %s] %s [%s] ⇒ %s | đường %s%s ngữ cảnh %s%s kỳ %s/%s'%(r['loai'],'tiếp' if r['noi_tiep'] else 'mới',r['q1'],r.get('duong1','?'),r['q'],r['duong'],'' if d else '✗',ctx,'' if c else '✗',r['ky'],r['ky_dung_nhan']))
print(sys.argv[1],'ĐÚNG CẢ (đường + ngữ cảnh + kỳ): %d/%d'%(sum(v[0] for v in st.values()),len(rows)),{k:'%d/%d'%(v[0],v[1]) for k,v in sorted(st.items())})
