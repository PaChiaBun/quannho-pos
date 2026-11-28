"""09/11: mở khoá và tổng hợp điểm chấm mù (mới − cũ, khoảng tin cậy 95%). python3 tong.py <thư mục chấm>"""
import json, sys, glob, math, collections
d = sys.argv[1]
khoa = json.load(open(f"{d}/khoa.json"))
diem = [x for f in sorted(glob.glob(f"{d}/diem_p*.json")) for x in json.load(open(f))]
TC = ['thang', 'dung_so', 'tim_van_de', 'ly_le', 'viec_lam', 'dung_quan', 'than_trong', 'gon']
nhom = collections.defaultdict(list)
tc = collections.defaultdict(lambda: [0, 0, 0])
muc = collections.defaultdict(lambda: collections.Counter())
for x in diem:
    k = khoa.get(x['id'])
    if not k:
        continue
    s = {k[c]: x[c] for c in ('A', 'B')}
    tong = {b: sum(s[b].get(t, 0) for t in TC) for b in s}
    for g in ('tat_ca', k['bo'], f"{k['bo']}:{k['loai']}", f"loai:{k['loai']}"):
        nhom[g].append((tong['cu'], tong['moi']))
    for t in TC:
        tc[t][0] += s['cu'].get(t, 0); tc[t][1] += s['moi'].get(t, 0); tc[t][2] += 1
    for b in ('cu', 'moi'):
        m = 'dung_duoc' if tong[b] >= 13 and min(s[b].get(t, 0) for t in ('dung_so', 'dung_quan')) == 2 else 'hong' if tong[b] <= 8 or s[b].get('dung_so', 0) == 0 else 'tam'
        muc[(k['bo'], b)][m] += 1
def ci(v):
    dd = [m - c for c, m in v]; n = len(dd); tb = sum(dd) / n
    sd = math.sqrt(sum((x - tb) ** 2 for x in dd) / (n - 1)) if n > 1 else 0
    return tb, 1.96 * sd / math.sqrt(n) if n else 0
print(f"chấm {len(diem)} cặp / khoá {len(khoa)}")
for g in sorted(nhom, key=lambda g: (g.count(':'), g)):
    v = nhom[g]; tb, e = ci(v)
    print(f"{g:28} n={len(v):3}  cũ {sum(c for c, _ in v) / len(v):5.2f}  mới {sum(m for _, m in v) / len(v):5.2f}  mới−cũ {tb:+.2f} ± {e:.2f}")
print('tiêu chí (TB /2, cũ → mới):', ', '.join(f"{t} {a / n:.2f}→{b / n:.2f}" for t, (a, b, n) in tc.items()))
for (bo, b), c in sorted(muc.items()):
    print(f"{bo:4} {b:4} dùng được {c['dung_duoc']:3}  tạm {c['tam']:3}  hỏng {c['hong']:3}")
