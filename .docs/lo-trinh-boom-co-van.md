# Lộ trình: Bé Boom thành cố vấn và người bạn của chủ quán — từ 03/11/2026

Thay cho cách dạy "thêm dòng tính sẵn theo từ khoá" (lần 1–103). Mỗi bước có đầu ra, cách đo, và chỗ cần Chủ Quán duyệt.
Áp máy chủ / database / web / app đều hỏi trước như cũ.

## Vì sao đổi cách

| Số đo 03/11 | Ý nghĩa |
|---|---|
| Hỏi thật ~20 câu trên web: gần một nửa hỏng ở **app** (chọn sai đường, sai kỳ, không gửi số) | Dạy ở máy chủ không chữa được; phải sửa đường số liệu |
| Lần 96, 97 chưa từng chạy trên app thật (nhãn kỳ app khác bộ đề) | Bộ đề mẫu không đủ; phải đo bằng quán thật |
| Lời nhắc hệ thống ~8.300 token, 30 dòng luật, 34 chữ KHÔNG / CẤM; câu cấm vẫn lọt khi hỏi thật | gpt-4o-mini quá tải luật; thêm luật nữa không giúp |
| Bộ định tuyến bằng GPT: đúng 15/30, nhầm năm 2023, +2,4 giây | Không dùng GPT để chọn kỳ / mục |
| Boom nhớ 5 giờ / 4 lượt; không biết lời khuyên có hiệu quả | Không có cách tự khôn lên theo thời gian |
| gpt-4o hơn mini ~0,8 điểm, đắt gấp 16 lần (01/11) | Chưa đổi mô hình; cái thiếu là số liệu và trí nhớ |

**Dừng**: dạy kiểu thêm dòng tính sẵn theo từ khoá. **Còn làm**: sửa lỗi thấy được khi hỏi thật.

---

## Chặng 1 — Đường số liệu (nền cho mọi thứ) · ~1–2 tuần

Thiết kế chi tiết: `.docs/thiet-ke-boom-may-chu-lay-so.md`.

| # | Việc | Đầu ra | Đo / duyệt |
|---|---|---|---|
| 1.0 | Đo "gửi đủ 5 mục" có làm Boom kém đi | Điểm chấm kín: mục liên quan vs đủ mục | Kém → lọc mục bằng luật ở máy chủ |
| 1.1 | Máy chủ `mode 'ask'`: đọc kỳ bằng luật (giờ VN), kiểm quyền vai trò, đọc đủ 5 mục song song, đệm | Hàm mới chạy song song đường cũ | Test 30 câu kỳ; đối chiếu quyền từng vai trò với bản Dart · **duyệt áp máy chủ** |
| 1.2 | RPC `boom_sales_facts_v1` tổng hợp bán hàng trong Postgres | Migration + ROLLBACK | Số khớp app (lệch 0), đo thời gian · **duyệt migration** |
| 1.3 | Web bật cờ `boom_server_route` | Bản web `quannho.lpm.vn/pos` | Hỏi thật lại các câu 03/11 trên Chrome · **duyệt đưa web** |
| 1.4 | Ổn 1–2 tuần → bật cho app | Bản app sau | **duyệt phát hành** |

**Xong chặng khi**: ≥ 90% câu hỏi thật về quán có số đi kèm; không còn câu "chỉ cách bấm" cho câu hỏi số; thời gian trả lời ≤ đường cũ.

## Chặng 2 — Lời nhắc gọn, kiểm bằng code · ~1 tuần

| # | Việc | Đầu ra | Đo / duyệt |
|---|---|---|---|
| 2.1 | Tách lời nhắc: lõi ~2.000 token (vai, giọng, khung 4 phần, cấm số giả) + phần riêng theo loại câu chỉ gửi khi cần | `ADVICE_PROMPT` mới | Chấm kín toàn bộ đề: không tụt; token / câu giảm ≥ 40% |
| 2.2 | Chuyển luật "CẤM câu X" thành bước kiểm sau trả lời: câu cấm, số không có trong khối, câu sáo → viết lại 1 lần (mở rộng `kiemTraLoi`) | Danh sách cấm trong code + test | Hỏi thật: 0 câu cấm lọt trên 20 câu |
| 2.3 | Bộ phân tích chạy mọi câu thay dòng tính sẵn theo từ khoá: tính các phát hiện (tăng / giảm do đâu, giờ / thứ yếu, món chưa bán, giá vốn cao, hao hụt, cài đặt sai), xếp mức quan trọng, gửi 3–5 phát hiện liên quan | Hàm `phatHien()` + test | Chấm kín: ≥ mốc hiện tại; câu hỏi lạ vẫn có phát hiện đúng |

**Xong chặng khi**: điểm chấm kín không tụt, token giảm, câu cấm không lọt khi hỏi thật. · **duyệt áp máy chủ**

**Kết quả 03/11:**
- **2.1 bỏ.** Lời nhắc gọn (lõi cố định + dòng theo chủ đề / khối số) bớt 29% token nhưng chấm kín 60 câu 12,38 → 12,27 (so sánh 13,6 → 12,5).
  Giả thuyết "bớt luật thì mini khôn hơn" không đúng — lỗi nằm ở lập luận, không ở độ dài lời nhắc (`ket_qua/c21_loi_nhac_gon_claude_20261103.json`).
- **2.2 áp.** `loiLapLuan()` trong bước tự kiểm: việc chung chung không gắn số, dòng đầu ngược số tính sẵn ("nghiêng về cắt / đóng"),
  mã giảm giá "hiệu quả hơn" vì bớt nhiều, thu − chi gọi là lãi ròng, % tổng chi so mốc doanh thu, gọi mọi khách có điểm là "lâu chưa ghé"
  → bắt viết lại 1 lần. Chấm kín 12 câu hay lỗi × 3: 11,53 → 11,78 (D37 10,3 → 12,3; D18 10,3 → 12,3; D03 10,7 → 12,0; D58 11,7 → 10,0);
  câu còn lỗi 10/36 → 6/36 (`ket_qua/c22_kiem_lap_luan_claude_20261103.json`). Còn: số cộng dồn gọi là "tháng này", bỏ sót vấn đề trong khối → 2.3.
  Đã áp 03/11 `db-fix/boom_c22_ap_dung.sh` (TS 20261103_054631).
- **2.3 bỏ.** Dòng "ĐIỂM CẦN CHÚ Ý VỀ BÁN HÀNG" (khung giờ vắng, combo đắt hơn lẻ, giá vốn cao, món rẻ chiếm phần lớn nhóm, nhóm / món giảm,
  món chưa bán) + kho "dưới mức tối thiểu". Chấm kín 60 câu: gửi mọi câu 12,28 → 12,22 (dự báo 12,4 → 10,8); bỏ ở câu dự báo 12,38 → 12,40.
  Mini vẫn bỏ sót các điểm dù đã đưa sẵn. Bài học đo: 1 lượt sinh + 1 người chấm dao động ~±0,5 điểm mỗi loại câu (cùng 60 câu bản cũ
  chấm 2 lần: 12,28 và 12,38) → thay đổi nhỏ không đo ra được; cần nhiều lượt hơn hoặc thay đổi lớn hơn
  (`ket_qua/c23_*.json`, `c23b_*.json`).

## Thử mô hình mới (03/11) — LỢI LỚN NHẤT TỪ TRƯỚC TỚI NAY

Sau 3 lần thêm nội dung không ăn thua, thử thay mô hình (bộ đề 60 câu, chấm kín Claude, so gpt-4o-mini cùng code):

| Mô hình | Chênh / 16 (± sai số) | Câu hơn / kém | Giá vào / ra (USD / 1M token) | Thời gian / câu |
|---|---|---|---|---|
| gpt-4o-mini (đang dùng) | — | — | 0,15 / 0,60 | ~3 giây |
| gpt-6-luna (mặc định) | +3,23 ± 0,24 | 58 / 0 | 0,10 / 0,50 | ~8,4 giây (có câu 13,9 > mức chờ 12 giây) |
| gpt-6-luna, `reasoning_effort: low` | +3,40 ± 0,30 | 54 / 2 | như trên | ~5,7 giây |
| **gpt-6-luna, `reasoning_effort: none`** | **+3,33 ± 0,26** | **56 / 1** | **như trên** | **~3,4 giây** |
| gpt-5.6-luna | +3,12 ± 0,25 | 56 / 3 | 0,20 / 1,20 | ~9 giây |
| gpt-6.1-terra | +3,10 ± 0,26 | 55 / 1 | 1,00 / 5,00 | ~7 giây |

→ **ĐÃ ÁP 03/11 (`db-fix/boom_mo_hinh_ap_dung.sh`, TS 20261103_065907)** — hỏi thật trên web: 5,8 giây, 0,0014 USD / câu.
→ **gpt-6-luna, reasoning none**: điểm ~11,6 → ~14,9 / 16, RẺ hơn gpt-4o-mini, nhanh ngang. Mức tăng gấp ~10 lần cả 100 lần dạy cộng lại.
Áp: đổi `BOOM_OPENAI_MODEL` trên máy chủ + gọi API bằng `max_completion_tokens`, `reasoning_effort` (mô hình mới không nhận
`max_tokens`, `temperature`) + giá trong `PRICES`. Kết quả: `cham_tu_van/ket_qua/mo_hinh_moi_claude_20261103.json`.

## Chặng 3 — Hiểu quán và nhớ lâu · ~2 tuần

> **03/11 — bước đo 3.1.0 không đạt** (`.docs/thiet-ke-boom-ho-so-quan.md`): dòng hồ sơ quán 12,50 → 12,34 (−0,16 ± 0,14, 180 cặp). Chưa làm DB.
> Ba lần thêm nội dung vào lời nhắc (2.1, 2.3, 3.1.0) đều không có lợi đo được với gpt-4o-mini; chỉ đổi cấu trúc (chặng 1, 2.2) có lợi.

| # | Việc | Đầu ra | Đo / duyệt |
|---|---|---|---|
| 3.1 | **Hồ sơ quán**: tự suy (loại quán, giờ mở thật, ngày nghỉ, giá trung bình, mùa vụ riêng) + chủ quán khai một lần (mục tiêu: tăng khách / tăng lãi / đỡ việc; khu vực: chợ / văn phòng / trường / dân cư; khách chính) — Boom hỏi khi phù hợp, không hỏi dồn | Bảng `boom_store_profile` + 2–3 dòng đầu khối số | Câu "20/11 nên làm gì" ở quán gần chợ không còn nhắm giáo viên · **duyệt migration** |
| 3.2 | **Trí nhớ dài có chọn lọc**: tóm tắt điều đáng nhớ (mục tiêu, việc đã khuyên, chuyện chủ quán kể: "mới mở chi nhánh", "đang thiếu người"), không lưu số tiền / thông tin cá nhân; chủ quán xem / xoá được | Bảng `boom_memory` + màn xem / xoá | Hỏi lại sau 1 tuần: Boom nhắc đúng chuyện cũ · **duyệt migration + app** |

## Chặng 4 — Vòng "khuyên → làm → đo → học" (Boom tự khôn lên) · ~2 tuần

| # | Việc | Đầu ra | Đo / duyệt |
|---|---|---|---|
| 4.1 | Lưu lời khuyên có cấu trúc: việc, món / giờ / ngày, mốc đo (số + ngưỡng), ngày bắt đầu, thời hạn | Bảng `boom_viec` | — |
| 4.2 | Nút "Em sẽ làm" / "Không hợp" dưới câu tư vấn | App | **duyệt app** |
| 4.3 | Hết hạn → máy chủ tự so số trước / sau theo mốc đo; lần mở app tới Boom báo kết quả ("Combo chiều 34 phần, 14–16h +12% → nên giữ") | Hàm đo + câu báo | Kết quả khớp tính tay trên 5 việc thật |
| 4.4 | Sổ "việc đã hiệu quả / không" của từng quán → đưa vào khối số; Boom ưu tiên việc từng thành công, tránh việc đã thất bại | Dòng "Đã thử" trong khối | Sau 1 tháng: tỉ lệ việc "hiệu quả" tăng |
| 4.5 | Gộp ẩn danh nhiều quán (≥ 5 quán / loại) → loại việc nào thường hiệu quả với quán bún, quán cà phê… | Bảng thống kê gộp | **duyệt riêng (riêng tư)** |

## Chặng 5 — Chủ động, phần "người bạn" · ~1–2 tuần

| # | Việc | Đầu ra | Đo / duyệt |
|---|---|---|---|
| 5.1 | Bản tin sáng thứ Hai, 5 dòng: doanh thu tuần, 1 điểm bất thường, kết quả việc đang thử, 1 việc nên làm | Thẻ trên Trang chủ khi mở app | Tỉ lệ mở / 👍 · **duyệt app** |
| 5.2 | Cảnh báo sớm: ngày tụt mạnh so cùng thứ, hàng sắp hết theo tốc độ bán, chi vượt mức thường | Thông báo trong app | Không quá 2 cảnh báo / tuần |
| 5.3 | Nhắc cài đặt làm số sai: món chưa giá vốn, mức tồn tối thiểu bất thường (vd 1.000 phần), tháng chưa ghi phiếu chi, mục Khách hàng tắt | Thẻ "Để Boom tư vấn đúng hơn" | Số quán sửa cài đặt |
| 5.4 | Giọng bạn bè: chúc mừng ngày bán tốt / kỷ lục, hỏi thăm khi tụt, nhớ cách xưng hô, không sáo | Mẫu câu + luật nhỏ | Chủ Quán đọc duyệt mẫu |

## Chặng 6 — Học từ người dùng thật (chạy mãi)

| # | Việc | Nhịp |
|---|---|---|
| 6.1 | Lưu câu hỏi thật + câu trả lời + 👍/👎 + loại lỗi (che thông tin cá nhân) | luôn |
| 6.2 | "Duyệt Boom" hằng tuần: câu 👎, câu không có số, câu cấm lọt → sửa ở máy chủ (quy trình duyệt đã có) | hằng tuần |
| 6.3 | Bộ đề lấy từ câu thật + số thật (ẩn danh) thay dần 3 quán mẫu | hằng tháng |
| 6.4 | Hỏi thật trên web ~20 câu (như 03/11) sau mỗi lần áp lớn | mỗi lần áp |
| 6.5 | Xem lại mô hình khi số đo cho thấy mô hình là chỗ nghẽn (chỉ cho câu kế hoạch / quyết định, ~10–15% câu) | mỗi quý |

---

## Thứ tự và phụ thuộc

```
Chặng 1 (số liệu) ──▶ Chặng 2 (lời nhắc gọn) ──▶ Chặng 3 (hồ sơ, trí nhớ) ──▶ Chặng 4 (khuyên → đo → học) ──▶ Chặng 5 (chủ động)
                                     Chặng 6 chạy song song từ Chặng 1
```

- Chặng 4 cần Chặng 1 (máy chủ tự đọc số để đo trước / sau) và 3.1 (biết mục tiêu quán).
- Chặng 5.1 dùng lại 4.3 (kết quả việc đang thử) và 2.3 (phát hiện).

## Chi phí ước (gpt-4o-mini)

| Khoản | Mỗi câu |
|---|---|
| Hiện tại | ~13.000 token vào ≈ 0,002 USD |
| Sau Chặng 1 (đủ 5 mục) | +~1.500 token |
| Sau Chặng 2 (lời nhắc gọn) | −~4.000 token → rẻ hơn hiện tại |
| Bản tin tuần / đo kết quả việc | 1 lần gọi / quán / tuần |

## Cần Chủ Quán duyệt

| Khi | Việc |
|---|---|
| 1.1, 2.x | Áp hàm boom-chat |
| 1.2, 3.1, 3.2, 4.1 | Migration database (có ROLLBACK) |
| 1.3 | Đưa web |
| 1.4, 3.2, 4.2, 5.x | Bản app |
| 4.5 | Dùng số gộp nhiều quán (riêng tư) |
