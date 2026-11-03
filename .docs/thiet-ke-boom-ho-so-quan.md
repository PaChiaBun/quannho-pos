# Thiết kế: Hồ sơ quán cho Boom (lộ trình chặng 3.1) — 03/11/2026

## ĐO LẠI TRÊN gpt-6-luna (03/11) — vẫn DỪNG, Chủ Quán chọn bỏ 3.1

60 câu × 2 lượt = 120 cặp (4 người chấm Claude): bản có hồ sơ 14,82 vs không 14,63 / 16; chênh +0,19 ± 0,09 (sai số chuẩn) — dưới
ngưỡng +0,5. "Đúng quán" 1,87 → 1,90, "việc làm" 1,69 → 1,71; 42 câu hơn, 27 kém, 51 bằng. Rõ nhất D30_1 (13 → 16: bản không hồ sơ
hỏi "nếu gần trường"). gpt-6-luna đã tự đoán đúng quán từ số (đúng quán 1,87 khi KHÔNG có hồ sơ) nên hồ sơ còn ít chỗ để thêm.
Kết quả: `cham_tu_van/ket_qua/l6_ho_so_quan_claude_20261103.json`.

## KẾT QUẢ BƯỚC 0 (03/11) — DỪNG, chưa làm database

Chấm kín 60 câu × 3 lượt = 180 cặp (6 người chấm Claude), bản có dòng "HỒ SƠ QUÁN (chủ quán tự khai…)" lấy từ mô tả quán mẫu vs bản đang chạy:
- Chung 12,50 → 12,34 / 16; chênh trung bình −0,16 ± 0,14 (sai số chuẩn) → KHÔNG tăng. 59 câu hơn, 65 kém, 56 bằng.
- "Đúng quán" 1,75 → 1,79, "việc làm" 1,24 → 1,32 (nhỉnh); "thận trọng" 1,81 → 1,69. So sánh +0,4; chẩn đoán −0,5.
- Người chấm vẫn thấy lời khuyên trái hồ sơ ở CẢ hai bản (trà sữa cho ki-ốt cà phê, ưu đãi Thứ 7 cho quán văn phòng): gpt-4o-mini
  có hồ sơ cũng không dùng. Kết quả: `cham_tu_van/ket_qua/c31_ho_so_quan_claude_20261103.json`.

→ Không làm bảng / RPC hồ sơ lúc này. Ba lần thêm thông tin vào lời nhắc (2.1 gọn, 2.3 điểm chú ý, 3.1.0 hồ sơ) đều không đo ra lợi ích;
chỉ hai việc đổi CẤU TRÚC có lợi: đường số liệu ở máy chủ (chặng 1) và kiểm bằng code (2.2). Chỗ nghẽn còn lại nằm ở khả năng suy luận
của mô hình — xem lộ trình.

## Vì sao

Boom chỉ biết những gì suy được từ số: loại quán (theo nhóm món), giá trung bình, giờ có bán. Boom KHÔNG biết quán ở đâu, khách chính là ai,
chủ quán đang muốn gì. Lỗi lặp lại qua nhiều lần chấm:
- D30 "20/11 quán bún nên làm gì": nhắm khách giáo viên dù quán ở gần chợ / công trình.
- D23, D03: khuyên "trà sữa", "bánh ngọt" cho ki-ốt cà phê mang đi.
- D21: "mua 2 món chính" ở quán cà phê.
- Lời khuyên không theo mục tiêu (quán muốn đỡ việc vẫn được khuyên mở thêm ca, chạy khuyến mãi).

Chặng 2 cho thấy đưa lại số Boom đã có không đo ra lợi ích. Hồ sơ quán là thông tin Boom CHƯA có → kỳ vọng hiệu quả rõ hơn mức nhiễu đo (±0,5).

## Hồ sơ gồm gì

| Trường | Ví dụ | Nguồn |
|---|---|---|
| Khu vực | gần chợ / công trình; văn phòng; trường học; khu dân cư; khu du lịch; ven đường lớn | chủ quán nói |
| Khách chính | công nhân, người đi chợ; nhân viên văn phòng; học sinh sinh viên; gia đình | chủ quán nói |
| Mục tiêu hiện tại | tăng khách; tăng lãi mỗi đơn; đỡ việc / giữ ổn định | chủ quán nói |
| Hình thức | ngồi tại chỗ / mang đi / giao hàng | chủ quán nói (app không biết) |
| Ghi chú tự do | "mới mở chi nhánh 2", "đang thiếu người" — ≤ 300 ký tự | chủ quán nói |

Không lưu tiền, số điện thoại, tên người. Chủ quán xem / sửa / xoá được bằng lời ("Boom, quán em giờ bán mang đi là chính").

## Cách điền — qua trò chuyện, không cần ra bản app

1. Câu kế hoạch / quyết định / khuyến mãi / giữ khách mà hồ sơ còn trống → cuối câu trả lời Boom hỏi ĐÚNG MỘT câu
   ("Quán mình gần chợ, văn phòng hay trường học, khách chính là ai ạ? Bé Boom nhớ để lần sau khuyên sát hơn.") — tối đa 1 lần / 7 ngày.
2. Lượt kế tiếp của người hỏi: máy chủ tách trường bằng luật từ khoá (chợ, công trình, văn phòng, trường, sinh viên, dân cư, du lịch,
   mang đi, giao hàng, tăng khách, tăng lãi, đỡ việc…) + giữ nguyên câu trả lời làm ghi chú (cắt 300 ký tự, đã che số / tên như hiện nay).
3. Chỉ chủ quán / quản lý được ghi (nhân viên trả lời thì không lưu). Câu "quán em …" chủ động nói ra cũng được ghi (luật từ khoá).
4. Mỗi câu tư vấn: thêm dòng `HỒ SƠ QUÁN (chủ quán khai, ngày …)` cạnh dòng tự suy.

Sau 1–2 tuần ổn trên web có thể thêm ô sửa hồ sơ trong Cài đặt (bản app), không bắt buộc.

## Database

- Bảng `boom_store_profile(store_id PK, khu_vuc, khach_chinh, muc_tieu, hinh_thuc, ghi_chu, updated_by, updated_at, asked_at)`, RLS:
  thành viên quán đọc; chỉ ghi qua RPC.
- `boom_profile_get_v1(p_store)`, `boom_profile_set_v1(p_store, …)` `SECURITY DEFINER` kiểm chủ quán / quản lý (như các RPC Boom có sẵn).
- Migration + ROLLBACK; máy chủ đọc / ghi bằng vé người hỏi.

## Các bước (mỗi bước hỏi duyệt trước khi áp)

0. **Đo giá trị trước khi làm DB** (chỉ tốn gpt-4o-mini): bộ đề đã có mô tả quán (`quan_a/b/c.json → mo_ta`: "quán bún gần chợ và công trình,
   4 người làm, mở 6–14h, 16–20h…"). Chấm kín 60 câu: bản có dòng hồ sơ (từ mo_ta) vs không, **3 lượt sinh / câu** để vượt mức nhiễu ±0,5.
   Tăng rõ (≥ +0,5, nhất là tiêu chí "đúng quán" và "việc làm") mới làm tiếp.
1. Migration bảng + 2 RPC; máy chủ đọc hồ sơ trong chế độ 'ask' và thêm dòng vào khối số.
2. Hỏi 1 câu khi hồ sơ trống + tách trường từ câu trả lời; test luật từ khoá trên câu thật.
3. Hỏi thật trên web (quán KAY-Rạch Giá): điền hồ sơ qua trò chuyện, hỏi lại các câu kế hoạch / khuyến mãi.

## Rủi ro

- Boom hỏi làm phiền → chỉ 1 câu, chỉ ở loại câu cần, 7 ngày / lần, người hỏi bỏ qua được.
- Tách sai từ khoá → giữ cả câu gốc làm ghi chú; GPT đọc ghi chú; chủ quán sửa bằng lời.
- Hồ sơ cũ sai thực tế → ghi ngày khai; quá 90 ngày Boom hỏi xác nhận lại.
