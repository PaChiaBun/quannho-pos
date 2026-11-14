# Tổng hợp điểm do CLAUDE chấm: python3 cham_tu_van/tong_hop.py <tra_loi.json> <diem.json> [<diem2.json> …]
# diem.json: [{"id": "D01", "diem": {"thang":0-2,…8 tiêu chí}, "van_de_tim_ra": [...], "loi_chinh": "..."}]
import json, sys, statistics as st
K = ['thang', 'dung_so', 'tim_van_de', 'ly_le', 'viec_lam', 'dung_quan', 'than_trong', 'gon']
tl = {x['id']: x for x in json.load(open(sys.argv[1], encoding='utf-8'))}
d = {}
for f in sys.argv[2:]:
    for x in json.load(open(f, encoding='utf-8')):
        d[x['id']] = x
miss = [k for k in tl if k not in d]
assert not miss, f'thiếu điểm: {miss}'
rows = []
for k, x in tl.items():
    g = d[k]['diem']
    assert set(g) == set(K) and all(v in (0, 1, 2) for v in g.values()), k
    rows.append({**x, 'diem': g, 'tong': sum(g.values()), 'van_de_tim_ra': d[k].get('van_de_tim_ra', []), 'loi_chinh': d[k].get('loi_chinh', '')})
out = sys.argv[1].replace('.json', '_claude.json')
json.dump(rows, open(out, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
m = lambda xs: st.mean(xs) if xs else 0
print(f'ĐIỂM TRUNG BÌNH (Claude chấm) {m([r["tong"] for r in rows]):.2f}/16 trên {len(rows)} câu')
print('Theo tiêu chí: ' + ' · '.join(f'{k} {m([r["diem"][k] for r in rows]):.2f}' for k in K))
print('Theo loại câu: ' + ' · '.join(f'{l} {m([r["tong"] for r in rows if r["loai"] == l]):.1f}' for l in dict.fromkeys(r['loai'] for r in rows)))
can = sum(len(r['van_de']) for r in rows); tim = sum(len(set(r['van_de']) & set(r['van_de_tim_ra'])) for r in rows)
print(f'Vấn đề cài sẵn tìm ra: {tim}/{can}. Chi tiết: {out}')
