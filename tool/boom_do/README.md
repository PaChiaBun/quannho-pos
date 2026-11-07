# Bộ đo Boom (chọn đường, tìm bài, hội thoại)

Các bộ câu dùng để kiểm Boom sau mỗi lần dạy. Đo bằng GPT giả, không gọi mạng.
Kế hoạch dạy: `.docs/ke-hoach-day-boom-thong-minh.md`.
Chấm chất lượng tư vấn bằng GPT thật nằm riêng ở `supabase/functions/boom-chat/cham_tu_van.ts` và thư mục `cham_tu_van/`.

| Thư mục | Nội dung |
|---|---|
| `bo_c` … `bo_k`, `bo_moi`, `qc10` … `qc13` | Câu một lượt: tìm bài hướng dẫn + chọn đường (`do2.sh`, chấm `cham_f.py`) |
| `bo_so`, `bo_so_d`, `bo_so_e`, `qc_so2` (100 câu ngược) | Câu hỏi số liệu một lượt (`hoi_quy.sh`) |
| `bo_l` … `bo_p`, `qc14`, `qc15` | Hội thoại 2 lượt (`hoi_thoai.sh`, chấm `cham_l2.py`). **Bộ P là bộ kín**: không sửa theo câu sai của bộ này |

Mỗi thư mục giữ `bo_cau.json` (đề) và kết quả mốc mới nhất (`duong_*.jsonl`, `tim_*.jsonl`, `kq_*.jsonl`).

## Chạy (từ thư mục `quan_nho`)

```bash
bash tool/boom_do/do_tam/hoi_thoai.sh <nhãn> bo_o bo_n bo_m bo_l bo_p qc15
bash tool/boom_do/do_tam/hoi_quy.sh <nhãn>
bash tool/boom_do/do_tam/do2.sh bo_h <nhãn>
python3 tool/boom_do/do_tam/cham_f.py bo_h <nhãn> x
python3 tool/boom_do/do_tam/so_duong.py <nhãn> bo_so bo_h bo_j
```

- Các script tạm chép file `zz_*_tam_test.dart` vào `test/features/ai_assistant/`, chạy xong thì xoá. Không chạy hai script cùng lúc.
- `so_duong.py` so đường đi từng câu của bản mới với kết quả gần nhất trước đó.
