"""09/11: chia đề chấm mù theo cặp. A/B ngẫu nhiên mỗi cặp; khoá riêng. Không in nội dung câu.
python3 tron.py <kq.json> <thư mục ra> <số phần>"""
import json, random, sys, os
kq, ra, n = json.load(open(sys.argv[1])), sys.argv[2], int(sys.argv[3])
os.makedirs(ra, exist_ok=True)
random.seed(20261109)
cap = {}
for x in kq:
    cap.setdefault(f"{x['bo']}{x['id']}#{x['r']}", {})[x['ban']] = x
khoi, ten_khoi, cau, khoa = {}, {}, [], {}
for ma, p in cap.items():
    if 'A' not in p or 'B' not in p:
        continue
    a, b = p['A'], p['B']
    # khối số liệu của bản B (mới): có đủ số gốc của bản A cộng dòng tính sẵn mới; lấy khối A thì số Boom mới dẫn từ dòng mới bị chấm là bịa (sửa 09/11)
    k = b['kh']
    if k not in ten_khoi:
        ten_khoi[k] = f"K{len(ten_khoi) + 1}"
        khoi[ten_khoi[k]] = k
    dao = random.random() < 0.5
    tl = {'A': b['a'] if dao else a['a'], 'B': a['a'] if dao else b['a']}
    khoa[ma] = {'A': 'moi' if dao else 'cu', 'B': 'cu' if dao else 'moi', 'bo': a['bo'], 'loai': a['loai']}
    cau.append({'ma': ma, 'ho_so': a['ho_so'], 'cau_truoc': a['cau_truoc'], 'cau_hoi': a['q'], 'khoi_so_lieu': ten_khoi[k],
                'van_de_can_tim': a['van_de'], 'y_chinh': a['y_chinh'], 'can_tranh': a['can_tranh'], 'tra_loi_A': tl['A'], 'tra_loi_B': tl['B']})
random.shuffle(cau)
for i in range(n):
    phan = cau[i::n]
    dung = sorted({c['khoi_so_lieu'] for c in phan})
    json.dump({'khoi': {t: khoi[t] for t in dung}, 'cau': phan}, open(f"{ra}/p{i + 1}.json", 'w'), ensure_ascii=False)
json.dump(khoa, open(f"{ra}/khoa.json", 'w'), ensure_ascii=False)
print('cặp:', len(cau), '| phần:', [len(cau[i::n]) for i in range(n)], '| khối:', len(khoi))
