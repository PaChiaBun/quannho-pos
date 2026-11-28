# so_duong.py <nhãn mới> <bộ...>: so đường đi từng câu với bản cũ gần nhất (không phải nhãn mới)
import json,sys,glob,os
import os
S=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))+'/'
nh=sys.argv[1]
for b in sys.argv[2:]:
    fs=sorted(glob.glob(S+b+'/duong_*.jsonl'),key=os.path.getmtime)
    new=S+b+'/duong_'+nh+'.jsonl'
    if not os.path.exists(new): continue
    olds=[f for f in fs if not os.path.basename(f).startswith('duong_'+nh)]
    if not olds: continue
    old=olds[-1]
    load=lambda f:{(r:=json.loads(l))['q']:r for l in open(f)}
    a,c=load(old),load(new)
    ok=lambda r:None
    ch=[q for q in a if q in c and a[q]['duong']!=c[q]['duong']]
    print('%s: %s → %s, đổi đường %d/%d'%(b,os.path.basename(old),os.path.basename(new),len(ch),len(c)))
    for q in ch: print('   [%s] %s | %s → %s'%(c[q].get('loai'),q,a[q]['duong'],c[q]['duong']))
