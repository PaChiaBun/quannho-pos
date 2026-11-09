# Kế hoạch dạy + đo AI Boom sau đợt thời tiết (lập 09/11/2026)

Lập sau khi kiểm tổng 09/11: loạt 169–199 làm Boom khá hơn **+0,59 ± 0,57 / 16** trên bộ kín độc lập (dùng được 36 → 46 / 80), trong khi các số đo trên bộ tự viết lớn hơn nhiều (+1,3 … +4,6). Sổ thật: **0 lượt hỏi thật từ 06/11**. Kế hoạch này sửa CÁCH ĐO trước, rồi mới dạy, và đặt việc lấy câu hỏi thật lên ngang hàng với dạy.

Bản đang chạy khi lập: Boom máy chủ lần 199 (commit `4456b60`, TS `20261109_202635`); app có lối vào Boom theo thời tiết ở commit `d42ca0a`, CHƯA phát hành.

## Nguyên tắc (rút từ 09/11)

1. **Chỉ tin bộ kín độc lập.** Bộ do Claude viết chỉ dùng để thử nhanh khi đang làm, KHÔNG dùng để quyết áp. Mỗi bộ kín dùng để quyết đúng MỘT lần; đã xem lỗi của bộ nào thì bộ đó hết kín.
2. **Đếm trước khi viết mã.** Lời người chấm là gợi ý; mỗi lỗi định sửa phải đếm trên câu trả lời thật đã sinh (kho ~2.000 câu ở scratchpad + bộ mới) — dưới ~2% thì chỉ làm khi sửa được bằng mã kiểm số rẻ, có độ chính xác ≥ 90%.
3. **Mã trước lời dặn; thay vế, không cộng vế.** Lần 188–189: thêm vế vào dòng tính sẵn thì mất điểm gọn; lần 190: thay vế thì được.
4. **Đo gộp theo lô** (≤ 5 lần dạy / lô), không đo từng lần trừ mã kiểm số (đo độ chính xác trên kho câu).
5. Mọi lần áp production: Chủ Quán duyệt ("Cho phép áp"), kịch bản `db-fix/boom_lNNN_ap_dung.sh` chạy `KHO=1` trước, ghi `boom_changelog`.

## Giai đoạn 0 — hạ tầng đo (làm 1 lần, trước lô 1)

- **Kho bộ kín:** nhờ 3 trợ lý độc lập (mỗi người không đọc bộ của người khác, không đọc mã Boom) viết sẵn `de_kin5`, `de_kin6`, `de_kin7` — mỗi bộ 24 câu, trộn: 12 câu thời tiết, 12 câu tư vấn chung (doanh thu, món, giá vốn, khuyến mãi, người làm, kho), một nửa không dấu / viết tắt, 4 câu bẫy. Bộ nào dùng để quyết lô nào ghi vào bảng ở cuối tệp này.
- **Công cụ đo chung** `tool/boom_do/do_09_11/do_thoi_tiet.ts` đã nhận `KIN=` / `CHI_KIN=1`; thêm câu không thời tiết dùng chung đường (`thoiTiet` rỗng). Chấm: 3–4 người chấm mù (Claude), 8 tiêu chí, `tron.py` / `tron_gop.py` + `tong.py`.
- ~~Mốc riêng~~ bỏ (09/11): mỗi lô đã đo A/B bản đang chạy vs bản mới trên cùng bộ kín, không cần điểm gốc riêng.
- Chi phí ước: ~3 lượt viết đề + 1 lượt đo (≈ 100 lần gọi Boom) + 3 người chấm.

## Giai đoạn song song — lấy câu hỏi thật (không phải dạy)

- Phát hành bản có lối vào Boom (build 32: web `/pos`, APK, Windows; `app_versions` hỏi trước) — Chủ Quán quyết thời điểm.
- Nhờ 2–3 quán quen dùng Boom 1 tuần.
- Mỗi tuần (Chủ Quán cho phép từng lần) đọc `boom_qa_full` ngoài Demo: đếm lượt, loại câu, câu Boom trả lời sai → thành **bộ câu thật** (viết lại không tên quán, không nguyên văn) — bộ này đứng trên mọi bộ giả khi quyết.

## Lô 1 — đọc đúng câu hỏi (lần 201–203)

Lỗi đếm được trên bộ độc lập: câu không dấu "mua sang ca tuan", "mua sang hoai" không nhận là mưa (2 / 20 câu de_kin2, 1 / 20 de_kin4); "dông" đọc thành "đông khách"; "t5", "cn" chưa hiểu ở mọi chỗ.
- 201: nhận "mưa" không dấu (phần 1 của bản thử 198, `l198_bo.patch`) — mã + test nhận diện, đo độ chính xác trên mọi câu đã có (câu thời tiết nhận được / câu mua hàng bắt nhầm).
- 202: "dông / giông" và "đông khách" — chuẩn hoá trước khi gửi Boom một dòng "câu hỏi nói về trời dông" khi có `\bdong\b` + từ trời; test.
- 203: thứ / ngày viết tắt dùng chung một hàm cho `thoiTietVoiSoQuan`, `ky.ts`.
- Đo cuối lô: bản 199 vs lô 1 trên `de_kin6`. Áp nếu không âm (đây là sửa đọc sai, không kỳ vọng tăng lớn) và không bắt nhầm câu mua hàng nào trong kho câu.

## Lô 2 — số mỗi ngày đúng (lần 204–206)

Lỗi: tự chia số cả kỳ sai số ngày (420 ÷ 4, 21.873.000 ÷ 6), gán số cả kỳ là "toàn tuần", không tự quy ra mỗi ngày khi hỏi lượng.
- 204: đưa "Mốc số phần / ngày" (lần 193) ra khỏi nhánh thời tiết: câu hỏi lượng (nấu / nhập / pha / đặt bao nhiêu) ở mọi chế độ đều có mốc theo thứ được hỏi.
- 205: kiểm bằng mã "phép chia tự làm": số trong câu = số cả kỳ ÷ k mà k ≠ số ngày mở bán / số ngày của thứ đó → viết lại.
- 206: "cả kỳ" gọi là "tuần / tháng" sai — kiểm bằng mã theo nhãn kỳ trong khối.
- Đo cuối lô trên `de_kin7`; áp nếu ≥ +0,3 và cận dưới khoảng tin cậy > −0,2.

## Lô 3 — đúng trọng tâm, gọn (lần 207–209)

Lỗi: chen chuyện kho / giá vốn không liên quan câu hỏi làm dài; câu "đóng / nghỉ ca" không tính tiền khung (phần 2 bản thử 198).
- 207: dòng "Kho trước …" chỉ giữ mặt hàng dùng cho món được hỏi / buổi được hỏi (khớp tên món ↔ công thức nếu có; không có công thức thì giữ hàng ĐÃ HẾT).
- 208: thử lại "Đóng / nghỉ (tính sẵn)" — chỉ khi câu ghi giờ hoặc "ca …".
- 209: dồn: một dòng tính sẵn mới phải THAY một vế cũ cùng chủ đề.
- Đo trên bộ câu thật nếu đã có ≥ 20 câu; không thì xin trợ lý viết `de_kin8`.

## Sau lô 3

- Kiểm tổng: bản 199 vs bản sau lô 3 trên một bộ kín mới hoàn toàn + bộ câu thật. Ghi vào tài liệu này và bộ nhớ.
- Nếu kiểm tổng < +0,3 hoặc bộ câu thật vẫn trống: dừng dạy, chuyển sức sang việc có người dùng (lối vào, gợi ý câu, hướng dẫn trong app).

## Bảng dùng bộ kín (điền khi dùng)

| Bộ | Người viết | Dùng để quyết | Ngày | Ghi chú |
|---|---|---|---|---|
| de_kin | trợ lý độc lập | lô A–D, 166–197 | 09/11 | K13 / K17 / K20 ý chính lệch dự báo |
| de_kin2 | trợ lý độc lập | QC 182 → 197 | 09/11 | đã xem 4 câu (N02, N14, N18, N19) — hết kín |
| de_kin3 | trợ lý độc lập | lần 198; kiểm tổng 168 → 199 | 09/11 | đã đọc nhận xét lỗi — hết kín |
| de_kin4 | trợ lý độc lập | kiểm tổng 168 → 199 | 09/11 | đã đọc nhận xét lỗi — hết kín |
| de_kin5 | trợ lý độc lập (09/11) | lô 1 | 09/11 | chỉ Q07 đổi khối; đã đọc nhận xét Q07 |
| de_kin6 | trợ lý độc lập (09/11) | lô 2 | 09/11 | chỉ R01 đổi khối; đã đọc nhận xét R01 (dùng để sửa 205) |
| de_kin7 | trợ lý độc lập (09/11) | lô 3 / kiểm tổng | | |

## Kết quả

- **Lô 1 (ĐÃ ÁP 09/11, TS `20261109_221036`):** 201 nhận "mưa" không dấu (+14 câu trên 2.412, 0 bắt nhầm "mua hàng"); 202 BỎ ("dông" → "đông khách" đếm 0 câu); 203 thứ viết tắt t2–t7 trong dòng THỜI TIẾT × SỐ QUÁN (bỏ sót ngày 8 / 13 → 0 / 13). de_kin5: 1 / 24 câu đổi khối (Q07), chạy riêng 6 lượt chấm mù **+4,00 ± 1,01**. Demo "t7 mua chieu…": hiểu Thứ Bảy, vẫn "chưa có số bán riêng Thứ Bảy" (lô 2). Người chấm thấy: gọi Thứ Bảy "cao nhất tuần" sai (cả hai bản); một câu bản 199 lẫn chữ Do Thái.
- **Lô 2 (ĐÃ ÁP 09/11, TS `20261109_222548`):** 204 tách `mocSoPhan` dùng chung; câu hỏi lượng KHÔNG nói trời cũng có mốc số phần / ngày theo mai / hôm nay / tối nay / thứ / t7 / cn, báo ngày quán nghỉ; mẫu câu hỏi lượng thêm đặt, lấy, mấy ổ. 205 (thay việc cũ): câu nhắc tên nhóm món ≥ 2 món → cộng cả nhóm ("bánh mì" ~30 ổ / ngày). Kiểm phép chia sai số ngày (~3 / 2.110 câu) và gọi số cả kỳ là "tuần" (~1) BỎ vì quá hiếm. de_kin6: 1 / 24 câu đổi khối (R01); 204 riêng +0,50 ± 0,84; thêm 205 theo nhận xét người chấm rồi đo lại R01: +3,33 ± 0,83 (ưu ái — cùng câu). Demo "t7 pha bao nhiêu ly cà phê sữa đá": "~40 ly" (đúng trung bình 359 / 9 ngày) nhưng mở đầu "thứ 7 quán bán" khi kỳ mới có 1 Thứ Bảy (bán 30).
- **Lô 3 (ĐÃ ÁP 09/11, TS `20261109_223609`):** 207 mốc số phần ghi "Thứ Bảy (kỳ mới có 1 Thứ Bảy — chưa đủ để tính riêng, dùng trung bình mọi ngày)" (cả nhánh thời tiết và câu chung); Demo nói đúng "kỳ này mới có 1 ngày Thứ 7 nên chưa đủ dữ liệu riêng". 208 (tiền khung khi hỏi đóng / nghỉ ca) KHÔNG áp — chưa có bằng chứng (scratchpad `l208_bo.ts`). 209 bỏ — không có công thức món để biết hàng kho nào liên quan. de_kin7: 0 / 24 câu đổi khối so với lô 2 → không đo được, bộ vẫn kín.

