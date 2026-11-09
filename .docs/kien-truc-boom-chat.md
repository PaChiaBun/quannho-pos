# Cấu trúc AI Boom (hàm `boom-chat`) — hiện trạng lần 165 (09/11/2026)

Tài liệu này mô tả Boom **đang chạy** để người sau biết sửa ở đâu, đo thế nào, mở rộng ra sao. Kế hoạch và lịch sử từng lần sửa:
`.docs/ke-hoach-boom-bo-nho-thoi-tiet.md`. Thiết kế cũ (để biết vì sao): `thiet-ke-boom-may-chu-lay-so.md` (đường ask),
`thiet-ke-boom-mo-rong-ngang.md`, `ke-hoach-day-boom-thong-minh.md`. Nhật ký từng lần áp: bảng `boom_changelog` (xem ở /admin).

## 1. Một câu hỏi đi qua đâu

```
App / web ──► boom-chat (Deno, Supabase Edge Function, máy chủ azvn-vps)
              1. kiểm vé, thành viên quán, hạn mức (boom_ai_reserve_v1), bộ nhớ câu đã duyệt (cache)
              2. ĐỌC SỐ
                 - đường "ask" (web; app từ 1.0.7): máy chủ tự đọc kỳ (ky.ts) và số theo quyền người hỏi (hoi.ts → lay_so.ts, ban_hang.ts)
                 - đường "advice" (app ≤ 1.0.6): app tự gửi số lên
              3. GHÉP LỜI NHẮC (logic.ts buildMessages): luật Boom + khối số liệu + các dòng TÍNH SẴN
                 + thời tiết (thoi_tiet.ts) + bộ nhớ quán (bo_nho_quan.ts) + kết quả lời khuyên cũ (loi_khuyen.ts) + sổ tay (so_tay.ts)
              4. GỌI gpt-6-luna (reasoning none)
              5. KIỂM câu trả lời bằng mã (kiemTraLoi) → có lỗi thì bắt viết lại ĐÚNG 1 lần (noteKiem)
              6. CHỐT bằng mã: gonKhiKhongDon, ghiKy (ghi kỳ số), ghiApTay, ghiNguonThoiTiet
              7. trả lời; chạy nền: rút ghi nhớ quán, ghi lời khuyên đo được, ghi "có làm / không làm"
```

Nguyên tắc đã đo nhiều lần: **thêm lời dặn cho AI gần như không giúp** (đã chạm trần); thứ làm Boom khá lên là
**mã tính sẵn con số** (bước 3) và **mã kiểm bắt lỗi** (bước 5–6). Hình thức kiểm được bằng mã thì làm bằng mã.

## 2. Các tệp (`supabase/functions/boom-chat/`)

| Tệp | Việc |
|---|---|
| `index.ts` | Cửa vào: vé, quyền, hạn mức, các chế độ (`ask`, `advice`, `answer` hướng dẫn, `thoi_tiet`, `feedback`, `transcript`, `admin_prompt`), gọi AI, kiểm, chốt, chạy nền |
| `logic.ts` | Não: luật Boom (lời nhắc), đọc / định dạng số (`parseFacts`, `formatFacts`, `changeLine`), các dòng tính sẵn, các mã kiểm, `soLieuGoc` (khối gốc để kiểm số) |
| `ky.ts` | Đọc kỳ trong câu hỏi bằng luật (giờ VN): hôm nay, tuần, tháng, quý, "30 ngày qua / tới", so với… |
| `hoi.ts` | Đường ask: đọc kỳ → lấy số đúng quyền người hỏi, đệm; kỳ mặc định ít đơn thì đọc lại 30 ngày qua |
| `lay_so.ts`, `ban_hang.ts` | Đọc số các mục (thu chi, kho, nhân viên, khách, khuyến mãi…) và bán hàng (RPC `boom_sales_raw_v1`) bằng vé người hỏi (RLS) |
| `thoi_tiet.ts` | Apple WeatherKit: vé ES256, đệm theo khu vực ≤ 3 giờ trong bộ nhớ (điều khoản Apple: KHÔNG lưu lâu), khối dự báo, ghi nguồn. Trả `gio` (12 giờ tới — Boom chỉ đọc phần này), `ngay` (7 ngày), `gio_tuan` (mọi giờ tới hết ngày thứ 7, cho màn xem từng ngày của app; lần 166, cùng một lần gọi Apple nhờ `hourlyEnd`) |
| `bo_nho_quan.ts` | Bộ nhớ riêng từng quán: lọc điều nên nhớ, chủ đề (vị trí, giờ, ngày nghỉ, khách chính), hỏi lại khi trái nhau, khối đưa Boom, câu "nhớ gì" |
| `loi_khuyen.ts` | Rút việc đo được từ "Việc tuần này", đo lại sau ~2 tuần, đọc "có / chưa làm" |
| `so_tay.ts` | Sổ tay tiếp thị 14 bài, chỉ mở cho câu tiếp thị, tối đa 2 bài |
| `cham_tu_van.ts`, `cham_gpt.ts`, `cham_tu_van/` | Bộ đo cũ và 4 quán mẫu A–D (`quan_*.json`), bộ kín `de_kin_v2.json` (CHỈ người chấm đọc) |

Bảng (migration `20261107_boom_bo_nho_quan_v1`, RLS bật không policy, chỉ hàm máy chủ đọc ghi): `boom_quan_ho_so`,
`boom_quan_ghi_nho` (≤ 200 điều còn hiệu lực / quán), `boom_quan_loi_khuyen`. Chủ quán xem / sửa / xoá / tắt qua 4 hàm `boom_bo_nho_*_v1`.
Sổ hỏi đáp: `boom_qa_log` (cột `model` ghi nhãn lượt: `+so_lieu`, `+ask`, `+so_tay`, `+thoi_tiet`, `+bo_nho`, `+kiem_so`, `+do_ket_qua`…).

## 3. Công tắc (tệp bí mật `/root/quannho-secrets/boom-ai.env`, sửa xong phải tạo lại container `functions`)

| Biến | Hiện tại | Ý nghĩa |
|---|---|---|
| `BOOM_AI_ENABLED` | bật | tắt hẳn AI (chỉ còn câu nguyên văn) |
| `BOOM_OPENAI_MODEL`, `BOOM_REASONING` | gpt-6-luna, none | mô hình trả lời |
| `BOOM_SO_TAY` | 1 (từ 09/11) | sổ tay tiếp thị |
| `BOOM_BO_NHO` | 1 (từ 09/11) | bộ nhớ quán + tự đo lời khuyên |
| `BOOM_BO_NHO_BO_QUA` | mã quán Demo | quán không dùng bộ nhớ |
| `BOOM_ASK_TAT_APP` | không đặt | =1: app (không phải web) bị 503 ở đường ask → tự quay về đường cũ, không cần phát hành lại |
| `WEATHERKIT_*` (4 biến) | có (từ 09/11) | thiếu biến nào thì thời tiết tự tắt |

Quán chọn khu vực thời tiết: `app_settings` khoá `thoi_tiet_vi_tri` (toạ độ làm tròn 0,05°). App chọn ở thẻ thời tiết (từ 1.0.7).

## 4. Dòng tính sẵn (bước 3) — thêm khả năng mới thường là thêm một dòng ở đây

Trong `formatFacts` / `changeLine`: doanh thu, so kỳ trước (quy về cùng số ngày mở bán), tăng giảm ở giờ / thứ / nhóm / món,
xếp thứ (thứ của hôm nay chia n−1 ngày trọn ở MỌI dòng), dự báo cả tháng, **XẾP MÓN THEO TIỀN LỜI** (lời mỗi phần; tổng cả kỳ
không dùng để nói "lời hơn"), **BÁN QUA SÀN** (phí theo câu hỏi, không có thì giả sử 25–30%), kỳ ít đơn / kỳ chưa có đơn.

Trong `buildMessages`: `baiToanTiepThi` (tăng 10% = bao nhiêu đơn, ngưỡng mã giảm, hướng xếp theo tiền, mua X tặng Y — cả theo
giá vốn của đúng món, combo), `caBan` (ca theo khối giờ có bán; khối < 3% doanh thu là đơn lẻ), `kichBanGia` (tăng giá X thì
hoà vốn), `giaKhacMenu` (giá chủ quán nói khác menu; `monKhop` khớp tên gọi tắt), `ngayHoi`, `uuDaiTrongBai`, `viecTiepThiTrongApp`…

Thời tiết (lần 167–175): `thoiTietChoBoom` (dự báo + khung giờ mưa mỗi ngày `khungMua`), `thoiTietVoiSoQuan` (THỜI TIẾT × SỐ
QUÁN: khung mưa đè bao nhiêu % doanh thu ngày, mức bán thường của thứ làm mốc nhập hàng, nắng nóng ≥ 35° → % nhóm đồ uống, ngày
đáng chuẩn bị nhất; nhãn sổ `+tt_so`). Câu hướng dẫn chỉ có dự báo khi có chữ rõ (`HOI_THOI_TIET_RO`); câu chỉ hỏi thời tiết không
gắn lời dặn kỳ chưa có đơn (`chiHoiThoiTiet`). Kế hoạch: `.docs/ke-hoach-boom-tu-van-thoi-tiet.md`.

Cách viết một dòng tính sẵn: tính bằng mã, ghi số cụ thể, **nói rõ thước đo đúng** (bài học K18: ghi "lời nhiều nhất cả kỳ" như đáp
án làm Boom kết luận sai), chỉ bật khi câu hỏi cần (từ khoá), có kiểm thử trong `logic_test.ts`.

## 5. Mã kiểm (bước 5) và chốt (bước 6)

`kiemTraLoi` hiện có 28 mã kiểm, mỗi mã trả danh sách lỗi; có lỗi thì viết lại 1 lần. Ví dụ: `soLa` (số không có trong khối gốc),
`ngoaiGioBan`, `ngoaiThuBan`, `khuyenTheoKyIt`, `tangGiaKhiTut`, `khuyenLaiDaThu`, `soHuongSaiGio`, `mocCaKy`, `giamQuaGia`,
`lacMon`, `viecAppKhongLam` (app không gửi tin, không giới hạn mã theo giờ…), `maTrung`, `muaTangChuaDung`, `boQuaGiaMenu`,
`kyKhongDonDai`, thời tiết `soTroiSai` (nhiệt độ / % ảnh hưởng của trời không có trong dự báo), `chiTienViTroi` (khuyên chi tiền
chỉ vì dự báo), `doLoiTroi` (đổ doanh thu giảm cho trời khi không có số thời tiết). Chốt bằng mã sau lần viết lại: `gonKhiKhongDon` (kỳ chưa có đơn → 1–2 câu), `ghiKy` (ghi kỳ của số; không gắn
vào bài đăng), `ghiApTay` (ưu đãi theo giờ phải dặn nhân viên áp tay), `ghiNguonThoiTiet`.

**Bẫy hay gặp: bỏ dấu làm chữ khác nhau trùng nhau** — số/so, mua/mưa, bao/bão, nang/nắng, thử/Thứ, hẻm/thêm, sàn/sáng. Luật trên
chữ bỏ dấu phải thử với các từ trùng; chữ không dấu chỉ tính khi đi kèm từ chắc chắn.

## 6. Kiểm thử, đo, áp

- Kiểm thử: `cd supabase/functions/boom-chat && deno test -A` (09/11: 153 bài), `deno check index.ts`.
- **Đo chấm mù** (`tool/boom_do/do_09_11/`): `do.ts` / `do_164.ts` sinh câu trả lời hai bản y như máy chủ (viết lại 1 lần, chốt),
  `tron.py` trộn A/B ngẫu nhiên + khoá riêng (khối số liệu lấy của bản MỚI), giao người chấm (trợ lý Claude, thang
  `THANG_CHAM.md` 8 tiêu chí × 0–2), `tong.py` mở khoá: mới − cũ ± khoảng tin cậy 95%, theo bộ / loại / tiêu chí.
  Bộ câu: QC 07/11 (đã dạy theo, dễ đẹp), `cau_moi.json`, `cau_moi2.json` (trợ lý khác viết, chưa dạy), bộ kín. Chỉ so hai bản
  trong CÙNG một lượt chấm. Giới hạn: quán mẫu chỉ có số cả tháng → câu "hôm nay / trưa nay" không đo được bằng bộ này.
- Áp: `db-fix/boom_lNNN_ap_dung.sh` — chạy test, so tệp trên máy chủ khớp bản đang chạy (`MOC`), đòi tệp đã commit, `KHO=1` chỉ
  kiểm, sao lưu, chép, tạo lại container, kiểm 401, ghi `boom_changelog`, có `ROLLBACK=1 … <TS>`. Bộ nhớ quán: `db-fix/boom_bo_nho_ap_dung.sh`.
- Mọi lần áp production phải hỏi Chủ Quán trước.

## 7. Đã đo được (để biết hướng nào đáng làm)

- 09/11, lần 151 (trước đợt QC 07/11) vs lần 164, 168 cặp trên bộ chưa dạy + kín: **+0,49 ± 0,30** (12,33 → 12,82 / 16); giá
  món +1,88, quyết định +1,04, so sánh +1,83; tiếp thị +0,09; kế hoạch −1,50 (n = 6, chưa chắc).
- Sổ tay tiếp thị (chỉ câu tiếp thị): +0,48 ± 0,42. Cho Boom tự gọi công cụ: −1,19 (bỏ). Thêm lời dặn lý lẽ: ~0.
- Yếu nhất còn lại (người chấm 09/11): né phép tính quyết định (hoà vốn thuê quầy / quảng cáo / thuê người, giá cần đặt trên sàn
  = giá ÷ (1 − phí), tiền mất khi giảm giá giờ cuối), gán số một giờ cho cả khung, chèn số lạc đề, bỏ sót ý thực tế.
- Người dùng thật còn ít (~57 câu / 30 ngày, 0 lượt đánh giá tới 04/11) → con số đáng tin nhất sau này là sổ hỏi đáp thật.

## 8. Hướng mở rộng tiếp

1. Dòng tính sẵn cho hoà vốn (thuê người, quảng cáo, thuê quầy), giá cần đặt trên sàn, tiền mất khi giảm % theo giờ.
2. Tiếp thị: đo vì sao sổ tay chưa đẩy được câu tiếp thị trên bộ mới.
3. Bộ nhớ quán: theo dõi số ghi nhớ, tỉ lệ nhớ sai (đọc nội dung sổ thật phải hỏi Chủ Quán).
4. Lời khuyên đã đo (sau ~2 tuần): xem việc nào có kết quả tốt với loại quán nào (cần nhiều quán, ẩn danh, người duyệt).
5. App 1.0.7: đường ask, thẻ thời tiết + màn xem từng ngày, màn "Bé Boom nhớ gì về quán" (build 30 `0486d6f` đã build, chờ đưa lên).
