# Phân tích & kế hoạch làm Boom thông minh hơn — 26/10/2026

> Chủ Quán yêu cầu: "phân tích nghiên cứu cải thiện sự thông minh của AI Boom". Chỉ đọc + đo, CHƯA sửa gì.

## 1. Hiện trạng (số đo thật)

**Dùng thật rất ít** (production, chỉ đọc):
- Từ 23/10: 20 câu đi qua GPT, chi phí 7 ngày ≈ 0,015 USD; 0 lượt 👍/👎.
- Lịch sử đầy đủ (từ 25/10 tối): 1 câu; chỉ 1 quán dùng (KAY-Rạch Giá — chính Chủ Quán thử).
- Chủ Quán chấm 1 câu "sai": "Gọi chế xưng bé" bị từ chối — ghi chú "Thay đổi cấu trúc Xưng hô thôi".
- Bộ nhớ câu đã duyệt: 9 câu (áp hôm nay), chưa có lượt dùng.
→ Không đủ dữ liệu thật để "học" từ người dùng; phải dựa vào bộ câu kiểm + mời thêm quán dùng.

**Bộ câu kiểm tra (trên máy)** — tìm đúng bài hướng dẫn:

| Bộ | Số câu | Đúng bài đầu | Có trong 3 bài đầu | Trả lời thẳng đúng | Trả lời SAI |
|---|---|---|---|---|---|
| Bộ chính | 103 | 83% | 99% | 68% | 8 câu |
| Bộ theo module | 117 | 69% | 95% | 42% | — |
| Bộ độc lập (người khác soạn) | 59 | 78% | 93% | 47% | 3 câu |

Chấm GPT thật trước đây (24/10, 94 câu): ĐÚNG 63 / THIẾU 23 / SAI 8 — lỗi chủ yếu do GPT chép máy móc bước không hợp tình huống, nói "chưa thấy" dù có đoạn đúng, bỏ sót lưu ý.

**Lỗi đã thấy trong câu thật**
- "Lên kế hoạch quảng cáo tháng 11" → GPT nói "tháng 11 có Giáng sinh". Nguyên nhân gốc: **GPT không được biết hôm nay là ngày nào** (lời nhắn gửi GPT không có ngày giờ) → "tháng sau", "cuối tuần này", "mùa này" đều đoán.
- "Gọi chế xưng bé" bị từ chối — Boom chỉ biết gọi Anh / Chị.
- "Thêm hàng vào kho" → GPT trả thiếu bước bật phiếu nhập nâng cao (đã vá bằng câu mẫu).

## 2. Cách Boom chạy hiện nay (tóm tắt)
1. App tìm bài hướng dẫn bằng **từ khoá** (không hiểu nghĩa) trong 341 đoạn → chắc thì gửi 1–3 đoạn cùng bài, chưa chắc thì gửi 3 đoạn đầu.
2. Câu số liệu: app tự đọc số (chỉ đọc, theo quyền) rồi gửi kèm cho GPT tư vấn.
3. Máy chủ: bộ nhớ câu đã duyệt (trùng hệt → trả ngay, 0 đồng) → không có thì gọi gpt-4o-mini (nhiệt độ 0,2) với lời dặn + đoạn hướng dẫn + trí nhớ 5 giờ.

## 3. Đề xuất (xếp theo lợi / công)

### Đợt 1 — nhanh, rủi ro thấp
1. **Cho GPT biết hôm nay**: thứ, ngày/tháng/năm giờ Việt Nam, mùa, các ngày lễ trong 45 ngày tới (theo danh sách có sẵn). Sửa tận gốc lỗi "Giáng sinh tháng 11" và mọi câu "tháng sau / cuối tuần".
2. **Xưng hô tuỳ chọn**: người dùng nói "gọi tôi là chế / cô / chú / em / anh Giang…" → Boom nhớ và dùng (đang chỉ có Anh / Chị). Đúng câu Chủ Quán chấm sai.
3. **Thêm câu mẫu vào bộ nhớ** từ bộ 160 câu thường gặp (qua quy trình duyệt) → nhiều câu trả lời đúng ngay, 0 đồng.

### Đợt 2 — tìm đúng bài hơn
4. **Gửi GPT 5 đoạn khi chưa chắc + GPT tự chọn đoạn** (trả mã đoạn đã dùng): bài đúng nằm trong 3 đầu 93–99% nhưng trả lời thẳng đúng chỉ 42–68% → để GPT chọn thay vì bộ tìm từ khoá.
5. **Tìm theo nghĩa** (embedding) phía máy chủ, kết hợp từ khoá: chi phí rất nhỏ (tính sẵn 341 đoạn vài xu; mỗi câu ~0,00002 USD). Chỉ làm nếu (4) chưa đủ.
6. Sửa 11 câu "trả lời sai" cụ thể (từ đồng nghĩa, viết lại đoạn).

### Đo & học (chạy song song)
7. **Bộ chấm tự động**: chạy bộ câu giữ riêng qua GPT thật, chấm ĐÚNG / THIẾU / SAI trước và sau mỗi thay đổi (≈ 0,1–0,3 USD / lần). Không đạt thì không áp.
8. **Khuyến khích chấm 👍/👎** trong app (đang 0 lượt) để có dữ liệu thật.

### Sau
9. Đọc thêm số: doanh thu theo nhân viên, chi tiết hoá đơn, lượt dùng mã giảm giá tại quầy, công nợ.
10. Mô hình mạnh hơn cho câu tư vấn số liệu — chỉ khi bộ chấm chứng minh lợi rõ (chi phí tăng nhiều lần).

## 4. Đề xuất làm trước
Đợt 1 (mục 1–3) + bộ chấm tự động (mục 7) để có thước đo, rồi mới tới đợt 2. Mỗi đợt: test + QC độc lập + hỏi Chủ Quán trước khi áp.
