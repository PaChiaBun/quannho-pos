# Kế hoạch dạy Boom tư vấn theo dự báo thời tiết (09/11/2026)

Chủ Quán 09/11: "lên kế hoạch dạy cho AI Boom về việc dùng phần dự báo thời tiết để tư vấn cho chủ quán".
Làm theo cách dạy đã chốt (`ke-hoach-day-boom-thong-minh.md`): kiểm một lần, làm lần lượt theo kế hoạch, đo gộp theo lô, chấm mù A/B, Claude chấm, mỗi lần áp hỏi Chủ Quán trước.

## Boom đang có gì (sau lần 168)

- Khối dự báo đưa Boom khi câu hỏi liên quan (`thoiTietChoBoom`, `thoi_tiet.ts`): bây giờ, giờ có khả năng mưa ≥ 40% trong 12 giờ tới, 7 ngày (cao / thấp / % mưa cả ngày / khung giờ mưa tính sẵn).
- Lời dặn chung: nói "dự báo", "khả năng"; không khuyên việc tốn tiền chỉ vì dự báo; không lấy thời tiết che vấn đề của quán.
- Số quán Boom đã có để ghép với thời tiết: doanh thu theo giờ (`by_hour`), theo thứ (`by_weekday`), theo ngày (`by_day`), theo nhóm món (`groups`), món bán chạy theo buổi (`by_band`), kỳ trước.
- Chưa có: đơn mang đi / giao hàng / tại chỗ; lịch sử thời tiết những ngày đã qua.

## Boom đang yếu ở đâu (thử máy ảo 09/11, 4 câu)

1. Lời khuyên còn chung chung ("chuẩn bị mái che, bao bì"), gần như giống nhau cho mọi quán. Chỉ 1/4 câu tự nối với số quán ("bán chạy lúc 20h"), và do mô hình tự nghĩ ra, không phải mã tính.
2. Không nói được mưa đè lên **bao nhiêu phần doanh thu** của ngày (khung mưa × giờ bán).
3. Không biết **ngày mưa quán mình thường giảm bao nhiêu**, vì không có lịch sử thời tiết (điều khoản Apple cấm lưu).
4. Nắng nóng: chưa nối với nhóm đồ uống / món lạnh của quán.
5. Chưa có cách kiểm bằng mã: số % mưa có đúng khối không, có khuyên tốn tiền vì dự báo không, có đổ lỗi cho trời khi không có bằng chứng không.

## Nguyên tắc (rút từ các lần dạy trước)

- **Tính bằng mã, không thêm lời dặn.** Mỗi dòng mới là dòng "tính sẵn" do máy chủ tính (như `khungMua`); lời nhắc chỉ thêm khi không tính được. Bài học: lời dặn hình thức làm tư vấn tụt (−0,38), lời dặn tư vấn đã chạm trần.
- **Chỉ thêm khi câu hỏi cần.** Dòng thời tiết × số quán chỉ gắn cho câu có chữ thời tiết hoặc hỏi kế hoạch ngày / tuần tới.
- **Không lưu dữ liệu Apple lâu dài** (điều khoản 1.5, 1.6). Chỉ được lưu **con số kết luận** của quán (vd "ngày mưa giảm ~15%") vào bộ nhớ quán.
- Kiểm hình thức bằng mã sau khi mô hình trả lời (`kiemTraLoi` + viết lại 1 lần), như các lần 131, 164.

## Bộ đo (làm 1 lần, trước lô A)

- **Bộ mở T (30 câu)**, viết tay theo 6 loại, mỗi câu có "ý chính" và "cần tránh":
  - chuẩn bị ngày mưa / nắng nóng (6), nhập hàng theo dự báo (5), mở / nghỉ / giờ mở ca khi mưa (4), có nên khuyến mãi / quảng cáo / thuê thêm người vì trời (5), giờ mưa đè giờ bán (5), câu bẫy (5: doanh thu giảm vì sao — không đổ cho trời; "mua 1 tặng 1"; câu không liên quan thời tiết; dự báo 30% mà hỏi "chắc mưa không").
- **Bộ kín TK (20 câu)**: một trợ lý độc lập viết, Claude không xem câu trước khi đo.
- **Dữ liệu giả cho đo**: 3 quán mẫu (cà phê mang đi, quán ăn trưa, quán trà sữa tối) × 3 kiểu trời (mưa chiều, mưa cả ngày, nắng nóng 36°). Khối thời tiết giả viết tay theo đúng dạng `thoiTietChoBoom`, KHÔNG dùng dữ liệu Apple đã lưu.
- **Chấm**: thang 8 tiêu chí cũ + 3 tiêu chí thời tiết: (a) số dự báo đúng khối, (b) có nối với số quán, (c) không khuyên tốn tiền / không đổ lỗi cho trời khi thiếu bằng chứng. Mô hình sinh câu: gpt-6-luna như Boom thật.
- **Mốc**: lần 168, 3 lượt mỗi câu.

## Lô A — dòng tính sẵn ghép thời tiết với số quán (lần 169–172)

| Lần | Việc | Kiểm đơn vị |
|---|---|---|
| 169 | **MƯA × GIỜ BÁN**: khung mưa của ngày được hỏi đè lên bao nhiêu % doanh thu ngày (từ `by_hour` trung bình), giờ bán chạy nào nằm trong khung. Vd "Mai dễ mưa 15–20h, khung này thường chiếm 42% doanh thu ngày, gồm giờ đông nhất 18h". | quán bán sáng + mưa chiều → % thấp, không báo động |
| 170 | **MỨC NHẬP THEO THỨ**: ngày được hỏi là thứ mấy, trung bình doanh thu / đơn thứ đó (`by_weekday`, n−1 như lần 165) → mốc nhập hàng; dự báo chỉ để chỉnh nhẹ, không đổi mốc. | thứ chưa có số → không bịa mốc |
| 171 | **MÓN THEO TRỜI**: nắng nóng ≥ 34° → nhóm đồ uống / món có chữ "đá, lạnh, sinh tố, trà" chiếm bao nhiêu % và món nào bán chạy buổi chiều (`groups`, `by_band`); mưa → món nóng / mang đi theo tên món. Không đoán khi tên món không rõ. | quán không có nhóm đồ uống → không nhắc |
| 172 | **NGÀY CẦN CHÚ Ý TRONG TUẦN**: trong 7 ngày, ngày nào vừa dễ mưa vừa là thứ bán mạnh nhất của quán → 1 dòng "đáng chuẩn bị nhất". | tuần nắng hết → không có dòng |

**Đo lô A**: bộ T + TK, A/B mù với lần 168; đạt khi tiêu chí (b) tăng rõ và tổng không tụt. Thêm hồi quy 30 câu bộ cũ không liên quan thời tiết (không được tụt).

## Lô B — kiểm bằng mã sau khi trả lời (lần 173–175)

| Lần | Việc |
|---|---|
| 173 | Số % mưa / nhiệt độ trong câu trả lời phải có trong khối dự báo; sai → viết lại 1 lần (như kiểm số bán hàng). |
| 174 | Câu khuyên thuê thêm người, chạy quảng cáo, giảm giá, nhập nhiều hơn mà lý do chỉ là dự báo → viết lại thành "theo dõi, chuẩn bị nhẹ". |
| 175 | Câu "doanh thu giảm vì sao" mà trả lời đổ cho trời, trong khi không có số ngày mưa / không có khối thời tiết → bỏ câu đó (chốt bằng mã). |

**Đo lô B**: như lô A + đếm bằng mã số câu vi phạm (a), (c) trước / sau.

## Lô C — "ngày mưa quán mình thường giảm bao nhiêu" (lần 176–178, cần Chủ Quán quyết trước)

- **Kiểm trước (không tốn lần dạy)**: Apple có trả **thời tiết những ngày đã qua** cho Việt Nam không (tham số `dailyStart` lùi về quá khứ); đếm lượt gọi thế nào.
- 176: khi câu hỏi cần (vd "mưa thì quán giảm nhiều không"), hỏi Apple 30–60 ngày đã qua đúng lúc đó, ghép với `by_day`, tính "ngày mưa so ngày khô cùng thứ" — **chỉ giữ trong bộ nhớ máy chủ trong lượt hỏi**, không lưu dữ liệu Apple. Ít hơn 4 ngày mưa thì nói chưa đủ số.
- 177: lưu **con số kết luận** vào bộ nhớ quán (`boom_bo_nho`, loại sự thật, có ngày tính, hết hạn 60 ngày) để lần sau khỏi gọi lại.
- 178: dòng MƯA × GIỜ BÁN (169) dùng con số này: "ngày mưa quán thường giảm ~X% (n ngày)".
- ⚠️ Điều khoản: tính con số rồi bỏ dữ liệu gốc là cách đã ghi ở Giai đoạn 2 (`ke-hoach-boom-bo-nho-thoi-tiet.md`); Claude không phải luật sư, chỗ chưa chắc hỏi Apple.

## Sau cùng (không phải lần dạy)

- Nút "Hỏi Bé Boom" trong màn xem ngày: câu hỏi theo đúng ngày đang xem ("Thứ Ba mưa 15–20h, quán chuẩn bị gì?") — cần bản app.
- Đọc sổ thật sau 1–2 tuần: bao nhiêu câu có nhãn `+thoi_tiet`, 👍/👎 (đọc sổ thật phải hỏi Chủ Quán mỗi lần).
- Chưa làm thông báo tự động "mai mưa" (dễ phiền) — xét sau khi có số dùng thật.

## Chi phí, thời gian ước

- Bộ đo: ~1 buổi. Mỗi lô 3–4 lần dạy + 1 lần đo (sinh câu bằng gpt-6-luna ~0,1 USD / 60 câu; chấm bằng 2 trợ lý Claude, chỉ câu bị ảnh hưởng).
- Mỗi lần áp: kịch bản `db-fix/boom_lNNN_ap_dung.sh` (chỉ kiểm → hỏi Chủ Quán → áp → ghi `boom_changelog`).

## Cần Chủ Quán quyết

1. Bắt đầu theo thứ tự: bộ đo → lô A → lô B; lô C sau.
2. Lô C: đồng ý hỏi Apple thời tiết ngày đã qua đúng lúc cần, chỉ lưu con số kết luận?
3. Có cho đọc sổ hỏi đáp thật (chỉ câu có nhãn `+thoi_tiet`) để lấy câu thật làm bộ đo không?

## Kết quả lô A (09/11, chưa áp)

- Mã: `thoiTietVoiSoQuan` (logic.ts), `khungMuaSo` (thoi_tiet.ts), nối ở index.ts (nhãn sổ `+tt_so`). Kiểm thử hàm 157/157.
- Bộ đo: `tool/boom_do/do_09_11/cau_thoi_tiet.json` (30 câu mở), `cham_tu_van/thoi_tiet/de_kin.json` (20 câu kín, trợ lý độc lập viết), trời giả `cham_tu_van/thoi_tiet/troi_gia.ts`, công cụ `do_thoi_tiet.ts`.
- Chấm mù 100 cặp (2 lượt mỗi câu), lần 168 → lô A: **+1,34 ± 0,37** (13,70 → 15,04 / 16); bộ mở +1,58 ± 0,50, bộ kín +0,97 ± 0,55. Theo loại: giờ bán +2,86, chuẩn bị +1,71, nhập hàng +1,44, mở / nghỉ +1,36, chi tiền +0,44, bẫy +0,07. Tiêu chí: tìm vấn đề 1,44 → 1,89, lý lẽ 1,54 → 1,91, đúng số 1,96 → 1,94.
- Câu không có dự báo không đổi (dòng mới chỉ gắn khi đã có khối thời tiết), nên không chạy lại bộ hồi quy cũ.
- Lưu ý: bản mới bị kiểm số bắt viết lại nhiều hơn (80 so 66 / 150), chưa xem lý do. Trợ lý viết bộ kín có thể đã đọc trời giả trước khi sửa Thứ Bảy / Chủ nhật của kiểu "mưa chiều" (ảnh hưởng như nhau cả A và B).
- Kịch bản áp: `db-fix/boom_l172_ap_dung.sh` (chỉ kiểm đạt).

## Kết quả lô B (09/11, chưa áp)

- Thử trước: kiểm số có sẵn (`soLa`) đã bắt % mưa bịa, nhưng bỏ sót nhiệt độ bịa (37°) và "ngày mưa doanh thu giảm 30%".
- Mã: `soTroiSai` (173), `chiTienViTroi` (174), `doLoiTroi` (175) trong `kiemTraLoi`; dòng nắng nóng của lô A nâng ngưỡng 34° → 35° (khớp cảnh báo app). Kiểm thử hàm 158/158.
- Đếm trên 300 câu của lần đo lô A: bản lô A 0/150 câu bị báo, bản 168 có 2/150 (174, khuyên nhập thêm vì dự báo). Bản đầu của 174 báo nhầm 13/150 câu có rào ("không tăng nhập chỉ vì dự báo", "thử quảng cáo ngân sách nhỏ") → nới phần nhận biết rào.
- Không chấm mù lại: không câu nào của bộ đo đổi, lô B là lưới an toàn cho lỗi hiếm.
- Chưa làm: Boom chen "Cần xem lại: Thứ Bảy 8.750đ" (từ số bán hàng, không phải thời tiết).
- Kịch bản áp: `db-fix/boom_l175_ap_dung.sh` (chỉ kiểm đạt).
