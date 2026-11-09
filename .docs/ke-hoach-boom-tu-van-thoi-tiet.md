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

## Lô C (09/11, Chủ Quán "Làm lô C"; chưa áp)

- Kiểm trước: Apple trả thời tiết ngày đã qua cho TP.HCM (≤ ~10 ngày mỗi lần gọi), có lượng mưa mm. Mùa mưa gần như ngày nào cũng mưa → so **mưa lớn (≥ 10 mm)** với ngày cùng thứ ít mưa hơn. Apple thật 60 ngày (10/9–8/11): 28 ngày ≥ 10 mm, 32 ngày ít hơn.
- Mã: `layMuaDaQua` (thoi_tiet.ts: 7 lần gọi song song, chỉ đệm trong bộ nhớ tới nửa đêm theo khu vực, không ghi cơ sở dữ liệu), `HOI_MUA_BAN` (câu mưa × chuyện bán, không nhầm "mua bán"), `docDoanhThuNgay` (ban_hang.ts, cùng RPC màn Báo cáo, vé người hỏi), `muaLonVaDoanhThu` (logic.ts), nối ở index.ts (nhãn sổ `+mua_ls`, chỉ khi người hỏi đọc được số bán hàng). Kiểm thử hàm 160/160.
- < 4 ngày mưa lớn có số bán, hoặc > 70% ngày đều mưa lớn → dòng nói "chưa đủ số, không đoán %". Dòng ghi rõ "chỉ là tương quan".
- Khác kế hoạch: KHÔNG lưu con số kết luận vào bộ nhớ quán (177) — tính lại mỗi lần rẻ (Apple đệm theo khu vực trong ngày, doanh thu 1 lần đọc), khỏi lo điều khoản dữ liệu phái sinh. 178 (gắn con số vào mọi câu thời tiết) chưa làm: chỉ câu hỏi mưa × bán.
- Không chấm mù: cần lịch sử giả cho cả 4 quán mẫu; thử thật trên quán Demo sau khi áp.
- Kịch bản áp: `db-fix/boom_l176_ap_dung.sh` (chỉ kiểm đạt).

## Lô D (09/11, Chủ Quán "Tiếp tục dạy sâu"; chưa áp)

- 178: ngày dễ mưa → món nước / món nóng của quán (bún bò, phở, cháo, canh…, ≥ 3% doanh thu món; "phô mai" không phải phở). 179: câu hỏi người làm / ca → số đơn mỗi giờ trong khung mưa (hoặc giờ đông), đông nhất mấy đơn.
- Sửa thêm sau lần chấm đầu: giờ đông ghi theo THỨ HẠNG doanh thu (liệt kê theo giờ làm Boom gọi 7h là đông nhất → kiểm số bắt viết lại 6 lần còn 1); câu hỏi nguyên nhân chuyện đã qua không gắn dòng dự báo × số quán (câu kín "sao thứ 4 bán kém, có phải tại mưa" tụt 5 điểm vì Boom đổ cho mưa hôm nay); "tại / do / vì mưa", "kém" vào câu mưa × bán (lô C).
- Bộ đo thêm 8 câu (TD01–08: món, người làm). Công cụ đo ghi lỗi kiểm số (`loi_kiem`).
- Chấm mù 88 cặp đổi khối, lần 177 → D2: **+0,89 ± 0,39** (mở +1,05 ± 0,50, kín +0,57 ± 0,63); người làm +2,88, món +2,12, bẫy +2,17, chuẩn bị +0,88, nhập hàng −0,70 ± 0,72 (dòng món nước đôi khi kéo lệch đề).
- Kịch bản áp: `db-fix/boom_l179_ap_dung.sh` (chỉ kiểm đạt).
- D3 (sửa nhập hàng −0,70): "bánh mì" bị bộ nhận món nước bắt nhầm (chữ "mì"); dòng món nước chen vào câu hỏi đích danh ("nhập thịt nướng") → Boom lệch sang bún bò. Nay "bánh mì" không phải mì nước, dòng món nước chỉ khi hỏi chung "món gì / chuẩn bị gì / nấu gì". Chấm mù 28 cặp D3 vs D2 (khối của D2 đầy đủ hơn): +0,29 ± 0,64, nhập hàng +1,00, đúng số 1,86 → 1,96. Gộp vào lần 178–179.

## Lô D đủ 5 lần — ĐÃ ÁP 09/11 16:47 (Chủ Quán "Dạy đủ 5 lần rồi áp luôn"; TS 20261109_164706)

- 180: hỏi nhập hàng nhiều ngày → tổng mức bán thường các ngày mở bán (trừ ngày nghỉ). 181: ngày ≥ 35° → khung nóng nhất đè bao nhiêu % doanh thu, gồm giờ đông nào. 182: ghi rõ dự báo chỉ tới ngày nào, không đoán ngoài tầm. Bộ đo thêm TD09–TD11.
- Chấm mù gộp 116 cặp, lần 177 → 178–182: **+0,45 ± 0,35** (mở +0,62 ± 0,45, kín +0,11 ± 0,56); người làm +2,62, món +1,50, nhập hàng +0,65; giờ bán −0,38 ± 1,10, chi tiền −0,06 (trong dao động). Câu dùng được bộ mở 57 → 72 / 78.
- Thử máy ảo Demo sau áp: "mai mưa chiều, ca chiều cần mấy nhân viên?" → dòng 179 lấy giờ đông chung (8h, 12h, 9h) vì mai ít mưa, không lấy ca chiều → Boom nói "chưa có lượng đơn riêng ca chiều". Cần: câu hỏi nêu ca (sáng / trưa / chiều / tối) thì tính đơn/giờ của đúng ca đó.
- Hoàn tác: `ROLLBACK=1 bash db-fix/boom_l182_ap_dung.sh 20261109_164706`. Mã CHƯA commit (logic.ts 5d304380, thoi_tiet.ts 64f522e1).

## Lần 183 (09/11, Chủ Quán "Sửa đi"; chưa áp)

- Hỏi ca nào tính đơn mỗi giờ của đúng ca đó. Bản đầu dùng giờ ca cố định (chiều 14–18h, tối 18–22h) → chấm mù 30 cặp −0,90 ± 0,69: lệch giờ bán thật (quán bán chiều 16–20h, tối 17–21h). Bỏ.
- Bản sửa: khối giờ quán thật sự bán (liền nhau, > 1% doanh thu) giao nhiều nhất với ca; khối ≤ 6 tiếng lấy cả khối, dài hơn cắt theo ca; ghi "ca chiều (quán bán 16–20h)"; khung mưa có trùng ca không. Chấm mù 30 cặp vs 182 (khối gộp dòng hai bản): +0,37 ± 0,71; đúng quán 1,70 → 1,97, gọn 1,50 → 1,70, lý lẽ 1,77 → 1,63.
- Kịch bản áp: `db-fix/boom_l183_ap_dung.sh` (chỉ kiểm đạt; đối chiếu mã băm lần 182 vì lô D chưa commit).

## Lần 184 (09/11, Chủ Quán "dạy tiếp đi"; chưa áp)

- Chấm mù 183 cho thấy Boom có đơn/giờ của ca nhưng chưa nối ra "cần mấy người" (lý lẽ 1,63). Nay dòng người làm thêm số người làm cùng lúc theo chấm công (giờ công ÷ giờ mở × ngày mở), đơn mỗi giờ công, mức đơn của ca tương đương mấy người. Không quy đổi giờ đông nhất (chia thẳng ra quá nhiều: quán trà sữa ra 6 người = cả quán). Nhân viên hỏi (chấm công của riêng mình) thì không quy đổi. Sửa nhận nhầm "thêm canh" là "thêm ca".
- Chấm mù 39 cặp vs 183 (khối gộp dòng hai bản): **+0,67 ± 0,60**; lý lẽ 1,23 → 1,56, tìm vấn đề 1,74 → 1,95, đúng quán 1,87 → 1,97, đúng số 1,90 → 1,82 (Boom chen số không liên quan, lỗi có từ trước).
- Kịch bản áp: `db-fix/boom_l184_ap_dung.sh` (chép logic.ts, index.ts; chỉ kiểm đạt).

## Lần 185 (09/11, Chủ Quán "dạy tiếp đi"; ĐÃ ÁP TS `20261109_175324`)

- Máy ảo Demo (có chấm công ảo) sau lần 184: Boom quy đổi ca chiều ~0,8 người, xếp 1 người, nhưng vẫn hỏi "ca chiều hiện có mấy người đã được xếp". Nay `soNhanSu` (lay_so.ts) tổng hợp thêm `lich`: mỗi người một dòng {tên, thứ thường làm (≥ 2 lần), giờ vào / ra trung vị, giờ VN} (một dòng / người vì cleanModule chỉ giữ 3 tầng, 12 phần tử); dòng người làm ghi "Thứ X khung này quán thường có N người: tên (giờ)". Nhân viên xem của mình thì không có lịch.
- 4 quán mẫu thêm `lich` khớp giờ mở và giờ công. Chấm mù 33 cặp vs 184: **+1,48 ± 0,75** (mở +1,78, kín +0,17 trên 6 cặp); đúng quán 1,36 → 1,85, tìm vấn đề 1,48 → 1,88; câu dùng được bộ mở 8 → 21 / 27.
- Kịch bản áp: `db-fix/boom_l185_ap_dung.sh` (chép logic.ts, lay_so.ts; chỉ kiểm đạt).

## Lần 186 (09/11, sửa sau khi thử Demo; ĐÃ ÁP TS `20261109_180421`)

- Kỳ "tháng này" mới 9 ngày → mỗi thứ có ca 1 lần, ngưỡng "≥ 2 lần" loại hết người, Boom chỉ nói "khoảng 1 người". Nay `lay_so.ts` đếm số ngày mỗi thứ có ca trong kỳ; một người "thường làm" thứ đó khi có mặt ≥ nửa số ngày ấy. Không ai thì dòng ghi "chấm công trong kỳ chưa thấy ai thường làm khung này vào Thứ X", không ghi "0 người".
- Không chấm mù (sửa lỗi theo số thật, không đổi lời dặn). Demo hỏi lại "mai mưa chiều, ca chiều cần mấy nhân viên?": Boom nêu Hà (17h–) và Tâm (–15h). Còn: chưa tính sẵn khoảng trống giờ không ai làm.

## Lần 187 (09/11, Chủ Quán "dạy tiếp đi"; ĐÃ ÁP TS `20261109_182731`)

- `gioTrong` (logic.ts): giờ bán của khung không thuộc giờ vào–ra thường lệ của ai → "KHOẢNG TRỐNG: a–bh chưa thấy ai thường làm (~X đơn/giờ)", đoạn liền gộp lại. Chỉ ghi khi có người thường làm thứ đó.
- Bộ cũ (41 mở + 20 kín) không câu nào có giờ trống → thêm 4 câu mở TD12–TD15 (quán B, ca chiều Thứ Năm: Ngọc 9–15h, Thảo 16–22h, trống 15–16h). Chấm mù 12 cặp vs 186: **+2,00 ± 0,80**; tìm vấn đề 0,83 → 2,00; dùng được 3 → 8 / 12. Chỉ một quán, một tình huống.
- Demo: Boom nêu khoảng trống 15–17h. Còn: "14–15h có 2 người" (chỉ Tâm), chưa nối giờ đông nhất 15h nằm trong khoảng trống, gán 6,5 đơn/giờ của ca cho khung mưa 15–20h (cả hai bản).

## Lần 188 (09/11, Chủ Quán "dạy tiếp đi"; KHÔNG ÁP — chấm mù không hơn)

- Thử 3 dòng tính sẵn: người phủ một phần ca ghi "phủ a–bh của khung"; khoảng trống chứa giờ đông nhất thì ghi thẳng; khung mưa trùng ca ghi đoạn trùng + đơn/giờ riêng.
- Chấm mù 26 cặp (13 câu đổi khối × 2) vs 187: **−0,19 ± 0,63**. Đúng số 1,73 → 1,88 nhưng việc làm 1,58 → 1,38, lý lẽ 1,65 → 1,54 (dòng dài hơn, Boom trả lời dàn trải). Bỏ, trả mã về 187.
- Người chấm thấy điểm chung cả hai bản bỏ sót: lịch chỉ 1 người lúc giờ đông (ki-ốt 6–10h chỉ Lan, 7h ~26 đơn; trà sữa ca tối 1 người, tải ~4,6 người) — Boom có cả hai số nhưng không so. Hướng tiếp: một phép so tính sẵn "tải ~M người, lịch thường có N → thiếu ~M−N".
- ⚠️ Câu kín K17: ý chính người ra đề viết lệch khối số liệu (theo hai người chấm); Claude không xem bộ kín nên chưa sửa.

## Lần 189 (09/11, Chủ Quán "Làm lần 189"; KHÔNG ÁP — chấm mù không hơn)

- Thử vế "SO VỚI LỊCH: ~N người thường làm cùng lúc → mỗi người ~X đơn/giờ, gấp ~K lần mức cả kỳ → NẶNG HƠN THƯỜNG / ngang / nhẹ". Bản đầu "mức đơn ~M người → THIẾU ~M−N người" bỏ trước khi đo: ra "thiếu 5,2 người", lặp lỗi chia thẳng của lần 184.
- Chấm mù 30 cặp (15 câu đổi khối × 2) vs 187: **+0,07 ± 0,77**. Tìm vấn đề 1,30 → 1,67, lý lẽ 1,40 → 1,67, nhưng gọn 1,77 → 1,37, đúng số 1,97 → 1,80. Bỏ, trả mã về 187.
- Hai lần liền (188, 189): thêm vế tính sẵn vào dòng người làm thì cái được ở tìm vấn đề bị trả lại ở độ gọn. Dòng người làm đã dài; muốn thêm phép so phải THAY vế khác (vd. vế "tương đương ~X người" của 184), không cộng thêm.

## Lần 190 (09/11, Chủ Quán "Thử lần 190"; ĐÃ ÁP TS `20261109_185152`)

- Phép so của 189 nhưng THAY vế "tương đương ~X người" của 184 khi quán có lịch thường lệ (không lịch thì giữ vế cũ). Dòng người làm ngắn hơn bản 189.
- Chấm mù 30 cặp vs 187, khối gộp hai bản (bản mới bỏ một vế): **+0,63 ± 0,69**; câu người làm **+1,25 ± 0,92**; tìm vấn đề 1,47 → 1,77, gọn 1,63 → 1,77; dùng được bộ mở 19 → 22 / 26.
- Demo: Boom nêu khoảng trống 15–17h ngay câu đầu, không còn đếm sai "14–15h có 2 người". Còn: khuyên "2 người cùng lúc" khi ca ~1,9 đơn/giờ — NẶNG HƠN THƯỜNG ở đây do lịch chỉ phủ ~nửa khung; lần sau tách "phủ thiếu giờ" khỏi "thiếu người".

## Lần 191 (09/11, sửa sau Demo; ĐÃ ÁP TS `20261109_190127`)

- Lần 190 chia đơn cả khung cho số người trung bình cả khung (gồm giờ trống) → Demo ~0,5 người ra NẶNG HƠN THƯỜNG, Boom khuyên "2 người cùng lúc" khi ca ~1,9 đơn/giờ. Nay phép so chỉ lấy giờ có người; giờ trống để dòng KHOẢNG TRỐNG lo.
- Chấm mù 12 cặp (quán B, TD12–15, khối gộp) vs 190: +0,17 ± 1,13 (ngang, đúng số 1,83 → 2,00) — quán B ca chiều nặng thật ở cả hai cách. Demo hỏi lại: "chưa cần thêm người… xếp 1 người phủ khoảng trống 15–17h".

## Lần 192 (09/11, Chủ Quán "dạy tiếp đi"; ĐÃ ÁP TS `20261109_191004`)

- Người chấm 188–191 cùng thấy: quán nướng than còn 0 bao, ly 700ml hết khi bàn giao hàng ngày mưa, gạo / gas dưới tối thiểu — Boom có khối KHO nhưng không nối. Nay câu chuẩn bị / nhập / giao / món trong `thoiTietVoiSoQuan` kèm "Kho trước <ngày>: … ĐÃ HẾT / còn … (tối thiểu …) → nhập trước" (hàng dưới nửa tối thiểu, tối đa 3); câu người làm thuần, câu chỉ hỏi trời không gắn.
- Chấm mù 56 cặp (28 câu × 2) vs 191: **+0,89 ± 0,46** (mở +0,78 ± 0,54, kín +1,19 ± 0,88); tìm vấn đề 1,46 → 1,88, việc làm 1,54 → 1,80, đúng quán 1,73 → 1,95; gọn 1,77 → 1,52; dùng được kín 5 → 12 / 16, mở 30 → 35 / 40.
- Còn (người chấm): "nấu bao nhiêu" chưa ra số phần mỗi ngày (chia số tháng / số ngày mở); gán số khung này cho khung khác; kín K13 / K17 / K20 ý chính lệch dự báo trong khối.

## Lần 193 (09/11, Chủ Quán "dạy tiếp đi"; ĐÃ ÁP TS `20261109_192158`)

- Câu nấu / pha / ướp / chuẩn bị bao nhiêu (`HOI_PHAN`, không tính câu người làm) → "Mốc số phần (tính sẵn, ƯỚC = số cả kỳ ÷ ngày mở bán × hệ số thứ đó)": top 3 món của buổi được hỏi (`by_band`), không có buổi thì cả ngày (`groups`). Buổi lấy ở vế hỏi số phần, không có thì cả câu; buổi < 5 phần / ngày gộp buổi kế ("chiều – tối"); món hỏi đích danh lên đầu; ngày quán nghỉ bỏ.
- Bộ cũ chỉ T11, T26 (T26 là ngày nghỉ) → thêm TD16–TD19. Chấm mù 15 cặp vs 192: **+4,60 ± 0,93**; thẳng 0,73 → 2,00, việc làm 0,93 → 1,73, đúng quán 1,20 → 2,00, gọn 1,07 → 1,73; dùng được 2 → 13 / 15. Bộ thiên về tính năng (ý chính đòi số phần), bộ kín không có câu loại này.
- Demo: "~8 tô bún bò buổi sáng" đúng, nhưng Boom dẫn 245 phần (cả ngày) làm căn cứ → lần sau ghi số cả kỳ của buổi trong dòng. Dòng kho (192) chưa bắt "ướp".

## Lần 194 (09/11, Chủ Quán "dạy tiếp đi"; ĐÃ ÁP TS `20261109_193016`)

- Dòng mốc phần ghi số cả kỳ của đúng buổi, gom một vế cuối dòng: "… phần / ngày (cả kỳ buổi tối: 130, 70, 40 phần / 24 ngày mở)" (bản đầu lặp "phần buổi tối / 24 ngày" từng món → bỏ vì dài). Dòng kho thêm ướp / pha / nướng.
- Chấm mù 15 cặp vs 193: +0,53 ± 0,76 (chưa rõ); tìm vấn đề 1,27 → 1,67; câu ướp sườn quán hết than: mới 3 / 3 nhắc, cũ 0 / 3. Demo: Boom dẫn đúng 73 phần buổi sáng / 9 ngày.
- Còn (cả hai bản): gán số của khung này cho khung khác (doanh thu cả ngày 4.525.000đ gọi là "buổi tối", 15% gọi là của khung tối).

## Lần 195 (09/11, Chủ Quán "dạy tiếp đi"; ĐÃ ÁP TS `20261109_193937`)

- Lỗi lặp lại qua các lần chấm 188–194: số trung bình CẢ NGÀY gọi là của buổi / ca ("Tối quán thường bán khoảng 4.525.000đ/ngày", "tối thứ Năm thường đạt 4.525.000đ"). Kiểm bằng mã `tienNgayGoiBuoi` (không thêm lời dặn): số "…đ/ngày" của khối, trong cùng vế (tách , ; : .) có chữ buổi / ca / khung đứng trước trong 50 ký tự; "tối mai / nay" không tính; có tên thứ chen giữa ("ca trưa sớm: Thứ Hai …") thì là số của thứ đó, trừ khi thứ đứng liền sau buổi ("ca tối Thứ Năm").
- Độ chính xác trên 458 câu trả lời đo hôm nay: 3 / 3 là lỗi thật, 0 bắt nhầm. Lời viết lại: "chỉ sửa số, KHÔNG viết thêm câu giải thích về lỗi này" (bản đầu làm Boom chèn "không phải doanh thu cả ngày quy đổi…").
- Không chấm mù: lỗi ~3 / 458 câu, A/B không thấy.

