# Kiểm toàn diện Boom 10/11/2026 và kế hoạch dạy tiếp

Bản đo: máy chủ lần 214 (mã phân tích lần 207, `logic.ts` b0798ce), gpt-6-luna mức suy nghĩ none, có kiểm số và viết lại như máy chủ.

## 1. Sổ thật (Chủ Quán cho đọc 10/11, một lần)

- 30 ngày có khoảng 33 lượt sau khi đổi sang gpt-6-luna, 3–4 người, phần lớn là một người hỏi thử. **Từ 06/11 tới nay không có lượt thật nào.** Nghẽn lớn nhất vẫn là người dùng thật (xem bộ nhớ "Boom ít người dùng thật").
- Dấu hiệu lỗi thật (không chép nguyên câu):
  - Câu so **món** giữa hai tháng đi nhầm sang đường tóm tắt doanh thu (đường đọc số trong app), nên không trả lời món nào giảm.
  - Câu hỏi tắt về **tổng thu nhập** đi đường hướng dẫn và trả lời "chưa có số", dù quán có Thu Chi.
  - Câu chuẩn bị cho **ngày lễ sắp tới** (20/11) không nhận ra đó là ngày lễ; chỉ dùng trung bình của thứ trong tuần.
  - "Món bán chạy nhất?" hỏi lúc quán chưa mở cửa thì báo "hôm nay chưa có món", không lùi sang hôm qua hoặc tháng này.
  - Nhân viên bấm câu gợi ý doanh thu bị từ chối: đã sửa ngày 06/11, chờ bản app mới.

## 2. Bộ kín mới `de_kin9` (52 câu, 13 lĩnh vực × 4, 4 quán, mỗi câu 2 lượt; người ngoài viết, 4 người chấm độc lập)

**85/104 câu dùng được (82%), điểm trung bình 13,83/16.** Đợt QC 07/11 (bộ khác, cách chấm gần giống) được 26/64 câu, trung bình 10,45/16. Hai đợt không so thẳng được, nhưng chênh lệch lớn.

| Lĩnh vực | Dùng được | Điểm TB | Lỗi chính |
|---|---|---|---|
| tiếp thị | 4/8 | 11,9 | chung chung; giờ không hợp nhóm khách; bài đăng đưa giá đề xuất như ưu đãi thật |
| thu chi | 5/8 | 12,9 | câu vay vốn không ước số tháng trả; phép trừ tiền mặt − lương vô nghĩa |
| thời tiết | 5/8 | 13,1 | **lấy tổng số phần cả kỳ làm số nấu một buổi**; bịa số |
| khuyến mãi | 6/8 | 13,3 | tính sai giá combo so với giá lẻ; quà tri ân quá rẻ |
| khách | 6/8 | 13,9 | việc làm yếu, không hợp quán |
| sàn giao | 7/8 | 13,9 | giá sàn tối thiểu chỉ hoà giá vốn |
| giờ / ngày | 7/8 | 14,0 | dài; khuyên mở ngày quán nghỉ |
| ngoài dữ liệu | 8/8 | 14,0 | chen việc lạc đề |
| kho | 7/8 | 14,3 | đổi số phần ra kg không có căn cứ |
| doanh thu | 8/8 | 14,4 | việc làm chung chung |
| giá / lời | 7/8 | 14,6 | ngưỡng giữ giá chưa theo hoà vốn |
| món | 7/8 | 14,8 | ghi nhầm % trên tổng thành % trong nhóm |
| nhân sự | 8/8 | 14,9 | — |

- Tiêu chí thấp nhất: việc làm (1,50/2), lý lẽ (1,60), gọn (1,63), tìm vấn đề (1,64). Đúng số (1,88) và thận trọng (1,88) đã tốt.
- Kiểu lỗi: chung chung 9, lạc đề 9, không hợp quán 6, tính sai 6, không trả lời thẳng 6.
- Lỗi trong mã tìm ra lúc chấm: `logic.ts:560` gắn nhãn **"trong mốc"** cho lương **dưới** mốc 20–30% (vd 16,6%), nên Boom nói sai.

## 3. Kế hoạch dạy (ưu tiên làm bằng mã, mỗi lô đo A/B chấm mù trên câu chạm tới, rồi mới áp)

**Lô 1: sửa số tính sẵn sai hoặc dễ đọc nhầm (nhỏ, chắc thắng)**
1. Nhãn lương dưới mốc: ghi "dưới mốc, không phải vấn đề" thay cho "trong mốc".
2. Dòng "Món bán chạy theo khung giờ" ghi rõ "cả kỳ N ngày" và kèm số phần / ngày. Mốc số phần (`mocSoPhan`) chạy cả với câu có thời tiết.
3. Tính giá lẻ so với giá combo cho **mọi** combo, không chỉ combo bán chạy nhất.

**Lô 2: thu chi và quyết định tiền**
4. Câu vay hoặc chi khoản lớn: tính sẵn số tháng trả = khoản vay / mức thu hơn chi mỗi tháng, kèm điều kiện "chưa trừ chi chưa ghi". Có kiểm mã bắt câu không nêu số tháng.
5. Kiểm mã chặn phép trừ hai khoản khác kỳ hoặc khác loại (tiền mặt kỳ này − lương tháng trước).

**Lô 3: tiếp thị và khuyến mãi**
6. Bài đăng chỉ được nêu giá có trong số liệu (giá đang bán). Giá đề xuất phải ghi rõ là đề xuất. Có kiểm mã.
7. Đưa giờ khách vào hồ sơ nhóm khách (học sinh ngoài giờ học, dân văn phòng sáng, thợ công trình sáng / trưa) để việc tiếp thị chọn đúng giờ. Đo trên câu tiếp thị và khách.
8. Ngưỡng giữ giá hoặc giảm giá lấy theo hoà vốn đã tính sẵn (lần 147), không tự đặt "dưới 10%".

**Lô 4: lỗi đường đi trong app (cần bản app mới)**
9. Câu so món giữa hai kỳ: không đi đường tóm tắt doanh thu.
10. Câu tắt về thu nhập / thu chi: đi đường số liệu Thu Chi.
11. Ngày lễ sắp tới (20/11, 24/12, Tết…): nhận ra là ngày lễ, ghi trong khối số rằng không có số năm trước.
12. "Món bán chạy" khi hôm nay chưa có đơn: lùi sang hôm qua hoặc tháng này.

**Không làm bằng lời dặn thêm:** chung chung, lạc đề, dài. Các lần trước thêm lời dặn đều không đo ra lợi ích; chờ các lô trên xong rồi đo lại.

**Đo:** mỗi lô sinh A/B trên các câu bị chạm trong `de_kin9`, chấm mù bằng người chấm độc lập. `de_kin9` nay đã lộ, nên kiểm tổng cuối cần một bộ kín mới (`de_kin10`).

## 4. Kết quả lô 1 (lần 215, chưa áp)

- Đã làm trong `logic.ts`: nhãn lương dưới mốc; dòng khung giờ ghi "số phần CẢ KỲ N ngày" kèm ~số/ngày; combo có % rẻ hơn lẻ và khoảng giá 5–10%; `HOI_PHAN` nhận "bn" (câu "nấu bn phần" trước không có mốc số phần). Test 182/182.
- Chấm mù 104 cặp (cả 52 câu de_kin9 đều bị chạm vì dòng khung giờ / combo có ở mọi khối): **tổng +0,04 ± 0,36** (không đo ra khác biệt); **thời tiết +1,75 ± 1,42** (đúng chỗ nhắm: mốc ~17 phần thay vì 420); sàn giao +0,62, tiếp thị +0,88 (đều cắt 0); giờ / ngày −0,75 ± 0,89, khuyến mãi −0,62 ± 1,43 (cắt 0). Dùng được 89 → 88 / 104.
- Kịch bản áp: `db-fix/boom_l215_ap_dung.sh` (chỉ chép logic.ts; đã chạy chế độ kiểm `KHO=1`).

## 5. Lô 2 (lần 216, chưa áp)

- Đếm lỗi thu chi trên bản 215 (8 câu): chỉ câu vay còn lỗi (2/2 lượt không chốt số tháng); phép trừ vô nghĩa 0/8 → lô 2 thu hẹp còn câu vay.
- Mã: `vayTinhSan()` trong `logic.ts` — dòng "Trả nợ (tính sẵn)": tiền góp / tháng so thu − chi / tháng (quy 30 ngày), tổng + kỳ hạn, "vay phần còn lại", lãi %/năm (đọc trên câu gốc), "gốc lãi".
- Đo: bộ câu vay 12 câu do người ngoài viết (`de_vay.json`) + T43. Bản đầu (lấy số tiền đầu tiên) +0,77 ± 0,69 và người chấm bắt lỗi lấy sai khoản vay → viết lại; bản sửa **+1,85 ± 0,85** (26 cặp). Sau đó sửa lãi %/năm và "gốc lãi" (2 câu, có test, chưa đo lại).
- Kịch bản: `db-fix/boom_l216_ap_dung.sh` (đã chạy chế độ kiểm).

## 6. Lô 3 (lần 217, chưa áp)

- Đếm lỗi trên bản 215 (16 câu tiếp thị / khuyến mãi, TB ~14,5): "sửa sao cho đắt" hiểu thành tăng giá 2/2; bài đăng chung chung, để trống [Địa chỉ] 1/2; quảng bá cho thợ công trình lạc sang quảng bá chung 1/2. Lỗi "giờ không hợp học sinh" của lần kiểm đầu không còn.
- Mã: `tiepThiTinhSan()` — dòng "Thông tin THẬT cho bài đăng" (món + giá + mã đang chạy), "Nhóm khách được hỏi", "cho đắt = bán chạy hơn".
- Đo: bộ `de_tiep_thi.json` 16 câu người ngoài viết (mã nhận 8) + 6 câu bộ kín cũ, 2 lượt: **+1,43 ± 0,92** (28 cặp); bài đăng +3,88, nhóm khách +0,69, đắt hàng −0,50 (4 cặp, bản mới hiểu đúng ý 2/2).
- Chưa bắt: kịch bản clip TikTok, tin nhắn Zalo, câu "giữ chân" nhóm khách → lô sau, đo bằng bộ mới.

## 7. Bài đăng (lần 217b–220, đã áp) và lô 4 (lần 221, chưa áp)

- Bài đăng: thử trên Demo sau mỗi lần áp lộ dần lỗi — chỗ trống "[giờ mở]" (217b `boChoTrong`), "hôm nay 0 đơn" chặn viết (217c `xinViet`), không có món / giá vì đọc số hôm nay (218 `hoi.ts vietNoiDung` → 30 ngày), câu cụt giờ mở (219 `khungBan`), gọi "mời Anh" (220). Demo cuối: bài có 3 món + giá, giờ 6h–23h, gọi khách "bạn".
- Lô 4, thử 4 câu sổ thật trên Demo (mã hiện tại): so món hai kỳ đã đi đường tư vấn (còn thiếu số món kỳ so); "món bán chạy" lúc 0 đơn đã lùi kỳ đúng; còn lỗi: (1) câu 0 đơn bị cắt giữa số "0 đơn.305.000đ từ 27 đơn)" (`gonKhiKhongDon`), (2) "tổng thu nhập nhiêu rồi" đọc thành hôm nay (`ky.ts`), (3) 20/11 không nhận ra ngày lễ.
- Lần 221 sửa cả 3 (ngày lễ: `ngayLe()`, lễ dương lịch; Tết âm / Trung thu chưa có). Chấm mù câu ngày lễ: **+3,38 ± 0,73** (8 cặp, 2 câu × 4 lượt); nhắc ngày lễ cũ 4/8, mới 7/8. Test 191/191.

## 8. Kiểm toàn diện lần 2 (10/11 tối, bản 221) và kế hoạch đợt sau

**Sổ thật:** từ 05/11 tới nay 0 lượt hỏi của quán thật (Chủ Quán cho đọc 10/11, lần 2).

**Bộ kín mới `de_kin10`** (60 câu, 15 lĩnh vực × 4, thêm "viết nội dung" và "so sánh hai kỳ"; người ngoài viết, 4 người chấm): **92/120 dùng được (77%), TB 12,94/16.** Bộ khó hơn và cách chấm nghiêm hơn lần 1 (85/104, 13,83) nên KHÔNG so thẳng được.

| Lĩnh vực | Dùng được | TB | Lỗi chính |
|---|---|---|---|
| khách | 3/8 | 9,9 | việc chung chung; dòng "Giữ khách" gọi 64% quay lại là "ít" |
| khuyến mãi | 3/8 | 10,3 | giảm X đồng cho học sinh không tính số phần phải bán thêm; bàn "mua 2 tặng 1" như có thật; lạc đề |
| kho | 6/8 | 12,1 | quá thận trọng, chung chung |
| thời tiết | 5/8 | 12,4 | lấy số buổi sáng làm số cả ngày; bỏ sót mưa cuối tuần |
| so sánh kỳ | 6/8 | 12,6 | nói "buổi tối giảm" khi không có số giờ kỳ trước |
| nhân sự | 7/8 | 12,8 | có số theo giờ mà vẫn nói "chưa đủ" |
| tiếp thị | 5/8 | 13,0 | tờ rơi học sinh dùng mã giao hàng; không có cách cho người mới biết quán |
| giá / lời | 6/8 | 13,4 | khuyên đẩy món không lời nhất (do dòng tính sẵn) |
| doanh thu, giờ / ngày, viết nội dung, ngoài dữ liệu, sàn, thu chi, món | 7–8/8 | 13,6–14,8 | — |

Tiêu chí thấp: việc làm 1,38, lý lẽ 1,47, gọn 1,47, tìm vấn đề 1,52. Kiểu lỗi: chung chung 20, lạc đề 13, không trả lời thẳng 12, quá thận trọng 10.

**Lỗi trong số tính sẵn (người chấm bắt, đã kiểm mã):**
1. Dòng "Giữ khách" (`logic.ts` ~734) gắn cứng "ít người quay lại" mỗi khi có khách có điểm, kể cả 64% → sai.
2. Dòng "Món lời nhiều mỗi phần" (~2563) lọc giá vốn ≤ 40% nên món lời nhiều tiền nhất (vốn 48%) bị loại, trái với nhãn.
3. Trung bình Thứ 4 bị đội lên: chỉ ở bộ đo (quán mẫu thiếu `by_day`); máy chủ thật có `by_day` (`ban_hang.ts:170`) nên đúng → bổ sung `by_day` cho quán mẫu để đo khớp thật.

**Kế hoạch đợt sau (mã, mỗi lô A/B chấm mù rồi mới áp):**
- Lô A — sửa 2 dòng tính sẵn sai (giữ khách theo tỉ lệ thật; món lời xếp theo tiền lời, ghi rõ giá vốn) + `by_day` cho quán mẫu.
- Lô B — khuyến mãi: câu "giảm X đồng / X% cho món Y" → tính sẵn lời còn lại / phần và số phần phải bán thêm để giữ lời (như mua X tặng Y đã có); chương trình người hỏi nêu mà không có trong số → nói rõ "quán chưa có chương trình này".
- Lô C — khách: câu kéo / giữ khách → tính sẵn nhóm khách quen (số khách, % quay lại, khách lâu chưa ghé nếu có số) để việc làm cụ thể.
- Để sau: "chung chung / lạc đề / quá thận trọng" là lỗi chung nhiều lĩnh vực — chưa có cách bằng mã; lời dặn thêm các lần trước không đo ra lợi ích.

## 9. Lô A đợt 2 (lần 222, chưa áp)

- Dòng "Giữ khách": < 30% mới ghi THẤP / "ít người quay lại"; cao thì ghi KHÁ CAO, việc nhắm khách mới quay lại lần 2.
- "Món lời nhiều mỗi phần": xếp theo tiền lời / phần (câu "mời thêm" vẫn lọc món nhỏ giá vốn thấp).
- Khoảng giá combo 5–10%: làm tròn vào trong mốc (35.000–36.000đ từ lẻ 38.000đ).
- Quán mẫu: thêm `by_day` hôm nay (ước theo phần bán trước 9h) để mốc thứ của hôm nay chia ngày đã trọn như máy chủ thật; 2 test thời tiết cũ giữ ý bằng cách bỏ `by_day` trong test.
- Chấm mù 22 cặp: **+1,18 ± 0,75** (món lời +1,70, giữ khách +0,50). Test 192/192.
- Còn thấy khi chấm: "BÀI TOÁN TIỀN" vẫn chia tổng Thứ 4 cho 4 ngày (gồm hôm nay); caption sàn bảo khách nhập mã của app (GIAOHANG10) trên ShopeeFood / Grab — khách sàn không dùng được.

## 10. Lô B đợt 2 (lần 223, chưa áp — đo chưa rõ)

- Đếm lỗi khuyến mãi bản 221: "giảm 10k cho hs phải bán thêm bn phần" 2/2 không ra số; "chương trình mua 2 tặng 1 tháng này" 2/2 bàn như có thật; tích điểm chung chung 1/2 (thuộc lô C).
- Mã: dòng "Giảm giá theo phần" (giảm X đồng / X% → lời còn lại, phải bán gấp mấy lần); dòng "quán CHƯA có chương trình mua X tặng Y" khi câu nói như đang chạy; sửa công thức chung mua X tặng Y (trước so 1 suất với 1 lượt → mua 2 tặng 1 ra 0,7 lần, nay 1,4 lần số lượt).
- Đo 20 cặp (10 câu bị chạm × 2): **+0,85 ± 1,57 — chưa rõ** (cắt 0). Người chấm: câu đầu vẫn hay không nêu số lần phải bán gấp; mã chưa nhận "mua món này tặng món khác", "hạ giá còn 37k", câu không dấu "tuần rồi chạy mua 1 tặng 1".
- Công thức mua X tặng Y sửa sau đo (lỗi tính cũ, có test). Test 194/194.

## 11. Lô C đợt 2 (lần 224, chưa áp)

- Đếm lỗi khách bản 221: "khách quen còn đều hay rớt" 2/2 kết luận "vẫn đều" từ 64% cộng dồn khi số đơn −14,8%; "khách lâu chưa ghé, nhắn được ko" 2/2 nói app lọc được (app không có ngày ghé cuối); giữ chân khách 2/2 đề xuất thẻ giấy khi quán đã có tích điểm.
- Mã (khối KHÁCH HÀNG): dòng "Xu hướng khách quen" (cộng dồn ≠ xu hướng, so số đơn kỳ trước, giờ mất nhiều nhất); dòng "Khách lâu chưa ghé" (app không lọc được, nhắn nhóm chi nhiều nhất kèm ưu đãi cụ thể); "Giữ khách": quán có tích điểm → KHÔNG thẻ giấy.
- Đo 28 cặp (14 câu bị chạm × 2; 5 câu bộ `de_khach` người ngoài viết): **+3,21 ± 1,32**. Người chấm được nhắc 3 sự thật về số (có thể nghiêng); đếm máy: thẻ giấy 5 → 1, "vẫn quay lại đều" 2 → 1. Test 194/194.
- Chưa làm: "khách ăn sáng hay trưa" quá thận trọng; "có nên làm tích điểm" chung chung.

## 12. Lô B làm lại (lần 225, chưa áp)

- Bản vá lô B cũ + bắt thêm: "hạ giá còn 37k" (giá mới), "mua A tặng B" món khác, câu không dấu "tuần rồi chạy …"; khớp tên món nằm trọn trong câu; món hỏi chưa có giá vốn thì không tính sang món khác.
- Bộ mới `de_khuyen_mai2` (16 câu người ngoài viết, mã nhận 10): chấm mù 30 cặp (3 lượt) **+2,40 ± 1,73**, cả hai người chấm nghiêng bản mới (201–172, 197–154).
- Sau chấm sửa 3 dòng tính sẵn sai người chấm bắt (Cơm tấm sườn bị khớp thành sườn bì chả; món chưa có giá vốn bị tính sang Trà đào / Bạc xỉu). Test 197/197.

## 13. Sửa nhỏ (lần 226, chưa áp)

- Bài toán tiền: trung bình theo thứ (dòng "Chọn ngày", "Các hướng xếp theo tiền") bỏ ngày dở hôm nay — hàm `tbThuKy` dùng chung.
- Caption cho ShopeeFood / Grab: không đưa mã giảm của app quán (khách sàn không nhập được).
- Số lần phải bán gấp ghi 2 chữ số (1,17 thay 1,2 cạnh "thêm 17%").
- Chấm mù 21 cặp +0,48 ± 1,14 (tổng chưa rõ); đếm máy: bài đăng sàn có mã app cũ 3/3 → mới 0/3. Test 198/198.

## 14. Luật kiểm "khuyên giảm giá món giá vốn cao" (lần 227, KHÔNG áp)

- Soát 29 câu bị luật bắt: ~25 vế là bắt nhầm (đang tính "giảm 20% thì … còn", khuyên ngược "chưa / tránh giảm", nhắc chương trình người hỏi hỏi). Sửa luật bỏ các vế đó → còn 2 / 29.
- Chấm mù 24 cặp (8 câu luật cũ từng bắt × 3): **−0,08 ± 0,54 — không đổi**; viết lại 19 → 14 / 24. Không áp (đường low trên máy chủ vốn không viết lại khi bắt lỗi). Bản vá: `db-fix/boom_l227_luat_kiem_khong_ap.patch`.
- Thấy thêm: "giảm giá trên Grab" — tính lời không trừ phí sàn (cả hai bản sai).

## 15. Giảm giá qua sàn (lần 228, chưa áp)

- `phiSanTrongCau()`: chỉ % đi với phí / chiết khấu / hoa hồng / sàn lấy-ăn-thu là phí sàn (trước "giảm 10% trên Grab" thành phí 10%).
- Dòng "Giảm giá khi bán QUA SÀN": (giá − giảm) × (1 − phí) − giá vốn, so chưa giảm, số lần phải bán gấp.
- Chấm mù 20 cặp (5 câu × 4): **+4,65 ± 1,65**; đếm máy lẫn "giảm 10%" thành phí: 6/20 → 1/20. Bộ `de_san_giam` (8 câu người ngoài): 7 câu bản cũ đã đúng (phí nêu rõ, hoặc món chưa có giá vốn), chỉ 1 câu bị chạm. Test 199/199.

## 16. Hai việc còn lại — không làm bằng mã

- "Khách ăn sáng hay trưa": dòng DOANH THU THEO BUỔI (`caBan`) đã bật đúng cả câu không dấu; lỗi 1/2 lượt là mô hình quá thận trọng — chỉ sửa được bằng lời dặn / luật kiểm, các lần trước không đo ra lợi ích; mới 1 lượt nên không làm.
- "Có nên làm tích điểm": việc cụ thể cần đường dẫn thật trong app (bài học "có mã chưa chắc mở được") — cần lần màn hình Khách hàng / điểm thưởng trước.
- Gợi ý tiếp: kiểm toàn diện lần 3 bằng bộ kín mới khi có thêm lượt hỏi thật (sổ thật vẫn 0 lượt từ 05/11).

## 17. Kiểm toàn diện lần 3 (10/11 khuya, bản 228)

**Bộ kín `de_kin11`** (60 câu, 15 lĩnh vực × 4, người ngoài viết, 4 người chấm): **79/120 dùng được (66%), TB 12,79/16.** Lần 2 (bộ khác, bản 221) 92/120, 12,94. Người chấm lần này nghiêm hơn và lĩnh vực yếu đổi hẳn giữa hai bộ (doanh thu 8/8 → 3/8, khách 3/8 → 7/8) → điểm theo lĩnh vực với 8 câu dao động mạnh, KHÔNG dùng một mình để chọn lô.

| Lĩnh vực | Dùng được | TB |
|---|---|---|
| doanh thu | 3/8 | 10,0 |
| giờ / ngày | 5/8 | 11,9 |
| khuyến mãi, thu chi, ngoài dữ liệu | 4/8 | 12,0–12,1 |
| viết nội dung | 5/8 | 12,1 |
| thời tiết | 5/8 | 12,4 |
| tiếp thị | 4/8 | 12,5 |
| các lĩnh vực khác | 6–7/8 | 12,8–14,4 |

Kiểu lỗi: chung chung 34, lý lẽ sai hướng 21, không trả lời thẳng 14, sai số 13, lạc đề 11, quá thận trọng 10. Tiêu chí thấp: việc làm 1,26, lý lẽ 1,40, tìm vấn đề 1,43.

**Dòng tính sẵn sai người chấm bắt (kiểm được bằng phép tính — nên làm trước):**
1. Kịch bản tăng giá: món CÓ giá vốn vẫn tính điểm hoà theo doanh thu (giảm 9,4% số ly là hoà) thay vì lãi gộp (~15,8%).
2. "XẾP MÓN THEO TIỀN LỜI" chỉ lấy món trong top / slow của nhóm, bỏ món nhỏ có giá vốn (Trứng ốp thêm lời 2.800đ) → Boom nói sai "lời ít nhất".
3. Dự báo cả tháng: cộng các ngày còn lại nhưng bỏ phần còn lại của hôm nay (thiếu ~2 triệu).
4. "Combo tính sẵn" (dòng riêng) 45.000–48.000đ — chưa làm tròn vào mốc như dòng nhóm (lần 222).
5. "So cuối tuần – ngày thường": ngày thường chia cả hôm nay dở.
6. Tỉ lệ "Điện nước / gas" bỏ sót khoản "Than, gas".
7. "Tính sẵn lời theo nhóm" kết luận "thiếu giá vốn phần lớn món" khi 10/12 món đã có.
8. "Ngày đáng chuẩn bị nhất": ~2.284.000đ trong khung mưa ≠ 55% × 5.228.000đ.
9. "GIÁ TRONG CÂU KHÁC MENU" khớp giá quán đối diện với món của quán mình.
10. Quán mẫu d: số so cùng kỳ theo nhóm / món tự mâu thuẫn (có thể do dữ liệu quán mẫu).

**Kế hoạch:** lô D sửa 1–9 (từng dòng có test; đo A/B câu bị chạm). Lỗi chung chung / lạc đề / quá thận trọng vẫn không có cách bằng mã.

## 18. Lô D (lần 229, chưa áp)

- Sửa 9 dòng tính sẵn (mục 17: 1–9). Chấm mù 48 cặp (24 câu ngẫu nhiên de_kin11 bị chạm × 2): **+0,88 ± 0,47**.
- Sau chấm sửa thêm: xếp món chọn theo lời / phần (trước chọn theo tiền cả kỳ rồi mới xếp → Cơm tấm sườn bì chả 24.000đ bị loại); "lời ít nhất" xếp từ thấp cả khi hiển thị; hôm nay chưa có dòng doanh thu = 0đ (quán mở 9h). Test 200/200.
- Còn thấy: dòng "Chi bằng tiền mặt X, chuyển khoản Y" bị cả hai bản đọc thành tiền THU; một dòng khác vẫn gợi ý "thẻ tích ly" khi quán đã có tích điểm; số so cùng kỳ theo nhóm của quán mẫu d tự mâu thuẫn (dữ liệu mẫu).

## 19. Lần 230 (không áp)

- Sửa chữ dòng "Chi bằng tiền mặt / chuyển khoản" (ghi rõ là tiền CHI) và gợi ý ưu đãi giờ (bỏ "thẻ tích ly"; "x2 điểm" bị loại vì app không có — luật `viecAppKhongLam`).
- Chấm mù 40 cặp (20 câu ngẫu nhiên de_kin11 × 2): **+0,00 ± 0,69**; hai lỗi đích không xuất hiện ở cả hai bản trong mẫu này → chưa đo được tác dụng, không áp. Bản vá: `db-fix/boom_l230_chi_tich_ly_chua_ap.patch`. Muốn đo lại: chọn đúng câu thu chi hỏi tiền mặt / két.

## 20. Kiểm toàn diện lần 4 (10/11 khuya, bản 229)

- Sổ thật (Chủ Quán cho đọc): vẫn 0 lượt thật từ 05/11.
- Bộ kín mới `cham_tu_van/thoi_tiet/de_kin12.json`: 90 câu, 15 lĩnh vực × 6, mỗi câu 1 lượt, **2 người chấm độc lập mỗi câu** (6 người chấm, 3 phần × 2 vòng).
- Kết quả: **132/180 lượt chấm "dùng được" (73%)**, cả hai cùng đồng ý dùng được 62/90 câu; TB 12,72/16. Hai vòng đồng ý kết luận 82/90 câu (91%) → số đo đáng tin hơn các lần trước (8 câu/lĩnh vực, 1 người chấm).

| Lĩnh vực | Dùng được (2 vòng) | TB |
|---|---|---|
| kho | 6/12 | 12,6 |
| khuyến mãi | 7/12 | 11,3 |
| tiếp thị | 7/12 | 11,9 |
| khách | 7/12 | 12,6 |
| doanh thu | 8/12 | 10,5 |
| nhân sự, món | 8/12 | 11,6–12,3 |
| sàn giao, giá lời | 9/12 | 12,8–14,3 |
| so kỳ, thời tiết, nội dung, ngoài dữ liệu | 10/12 | 12,8–13,9 |
| giờ ngày, thu chi | 11–12/12 | 13,3–14,5 |

Tiêu chí thấp: việc làm 1,31, tìm vấn đề 1,45, gọn 1,46, lý lẽ 1,57. Kiểu lỗi (số câu): chung chung 28, sai số 13, quá thận trọng 12, không trả lời thẳng 12, lạc đề 12.

**Ba kiểu lỗi lặp lại (đọc lời người chấm):**
1. **Không trả lời đúng cái được hỏi** — hỏi "nhập chỗ nào nhiều tiền nhất" trả khoản chi Nguyên liệu thay vì tên nhà cung cấp; hỏi giữ khách MỚI / học sinh nhưng việc làm nhắm khách chi nhiều nhất; hỏi "làm sao cho bớt hư" chỉ bảo ghi sổ.
2. **Quá thận trọng khi số đã đủ để ước** — "chưa có trung bình ngày" dù chia được; "chưa có giá vốn món" dù có; hoà vốn tiếp thị không dùng tỉ lệ nguyên liệu / doanh thu để ước.
3. **Gán số một phần thành số cả kỳ** — số khung giờ sáng thành số cả ngày; % tổng doanh thu ghi là % trong nhóm; số 1–28 thành "cả tháng".

**Dòng tính sẵn sai người chấm bắt (làm trước, kiểm được bằng phép tính):**
1. Mua X tặng Y "phải bán gấp ~1,2 lần" chỉ là 6÷5, chưa tính nguyên liệu phần tặng (đúng ~1,42 lần với nguyên liệu 44%).
2. "SO CÙNG KỲ … TĂNG Ở ĐÂU" (quán d): doanh thu nhóm kỳ trước lẻ, tổng nhóm < doanh thu; chênh từng món ≠ số phần × giá — kỳ trước bị nhân theo tỉ lệ. Cần xem là do quán mẫu hay do mã.
3. "So cuối tuần – ngày thường" quán b vẫn chia 20 ngày khi by_day rỗng (hôm nay 0 đơn) — xử như dự báo (lần 229).
4. XẾP MÓN có `itNhat`: câu "lời / phần cao nhất" tính trên 5 món thấp nhất → sai.
5. Dòng "Từng ngày có đơn trong kỳ… ngày không ghi là không có đơn" hiện khi by_day chỉ có vài ngày → Boom từ chối tính trung bình ngày. Chỉ hiện khi by_day phủ phần lớn kỳ.
6. % theo nhóm / món tính trên tổng trước giảm giá nhưng ghi "doanh thu"; nhãn "% tổng doanh thu" cần rõ để không bị đọc thành % trong nhóm.
7. KHO "nhà cung cấp lớn nhất" xếp sai thứ tự (quán b) — và câu hỏi "nhập chỗ nào nhiều nhất" chưa đưa dòng này lên đầu.

**Kế hoạch lô E (mã, đo A/B câu bị chạm de_kin12):** sửa 1, 3, 4, 5, 6, 7; xem 2 (nếu do mã thì sửa). Lỗi 1–3 phần trên (trả lời lệch câu, quá thận trọng, gán số) không có cách bằng mã trực tiếp — chỉ giảm được bằng dòng tính sẵn đúng câu hỏi (vd. trung bình ngày tính sẵn, hoà vốn tiếp thị theo tỉ lệ nguyên liệu khi món thiếu giá vốn).

## 21. Lô E (lần 231, chưa áp)

- Sửa (mục 20): mua X tặng Y ghi cả số lần SỐ PHẦN (người chấm đọc 1,2 lần lượt thành số phần); "So cuối tuần" và dòng theo thứ khi hôm nay 0 đơn (by_day rỗng → tiền hôm nay = 0); XẾP MÓN "cao nhất" tìm trên mọi món + ghi rõ "N món lời / phần thấp nhất trong M món" + món lời thấp / cao nhất TỪNG nhóm (câu "mỗi dĩa"); dòng "Trung bình mỗi ngày (tính sẵn)" bỏ ngày dở; "Từng ngày có đơn" chỉ hiện khi by_day phủ ≥ nửa kỳ; "% doanh thu cả quán"; nhà cung cấp xếp theo tiền. Mục 2 (so cùng kỳ quán d) là do dữ liệu quán mẫu, không sửa.
- Chấm mù trên de_kin12 (bộ đã lộ ở lần kiểm 4): 24 câu ngẫu nhiên × 2 = 48 cặp **+0,27 ± 0,66**; trong đó 28 cặp chỉ đổi nhãn +0,04 ± 0,72. Đo thêm 18 câu bị chạm thật còn lại × 2 = 36 cặp −0,08 ± 0,65 (có thêm phần xếp theo nhóm). Gộp 56 cặp bị chạm thật **+0,16 ± 0,61**; cả 84 cặp **+0,12 ± 0,47** → chưa rõ.
- Câu nhắm đúng lỗi thắng rõ: trung bình mỗi ngày +6 / +3; lời ít nhất +8.
- Còn thấy: mốc nấu trân châu chỉ lấy món topping, bỏ trân châu trong ly trà sữa (cả hai bản); so dự báo cả tháng với số 1–28 tháng trước; trung bình ngày chia cả ngày quán nghỉ.

## 22. Lần 232 (không áp)

- Sửa 3 lỗi còn lại của lô E: mốc nấu nguyên liệu nằm trong tên món khác (trân châu trong "Trà sữa trân châu đường đen"); kỳ trước chỉ là N ngày đầu tháng trước → ước thô cả tháng trước để so với dự báo; trung bình ngày CÓ MỞ BÁN (bỏ thứ quán nghỉ).
- Chấm mù 46 cặp (23 câu bị chạm ở de_kin10/11/12 × 2): **+0,04 ± 0,84** → không áp. Câu đích "so dự báo với tháng trước" thắng rõ (+6 / +4), nhưng dòng ước tháng trước còn bám vào câu "giờ nào tụt so với tháng trước" (−4 / −10) vì luật bắt chữ quá rộng ("so", "tháng trước"). Trân châu −1 / +1.
- Bản vá: `db-fix/boom_l232_tran_chau_thang_truoc_khong_ap.patch`. Muốn làm lại: chỉ gắn dòng ước tháng trước khi câu hỏi CẢ dự báo / cuối tháng LẪN tháng trước / mức tháng N, đo bằng bộ kín mới.

## 23. Lần 232b (làm lại, chưa áp)

- Như lần 232, nhưng dòng ước cả tháng trước chỉ gắn khi câu hỏi CẢ tháng / cuối tháng / dự báo LẪN tháng trước / tháng N (`hoiCaThangVoiTruoc`, đọc trên chữ bỏ dấu).
- Bộ kín MỚI `cham_tu_van/thoi_tiet/de_kin13.json` (32 câu, 4 loại × 8: cả tháng so tháng trước, so tháng trước theo giờ / món, trung bình ngày, nấu nguyên liệu; người khác viết, Claude không đọc trước khi đo). Chấm mù 64 cặp (4 người chấm): câu bị chạm 22 cặp **+2,14 ± 1,48**; câu không chạm 42 cặp +0,50 ± 1,08; cả bộ +1,06 ± 0,89. Cả tháng so tháng trước (chạm) +3,33; so tháng trước theo giờ / món ±0 (hết bám sai).
- Người chấm còn bắt: câu "tháng này có đạt tháng 9 không" bị coi là hỏi THÁNG KHÁC → mất dòng dự báo (lỗi có từ trước); ước tháng trước theo ngày lịch, quán nghỉ Chủ nhật lệch ~1 điểm %; câu "mục tiêu 130 triệu" bị đọc thành khoản vay; trân châu ở câu không có chữ hỏi số phần vẫn chỉ 13 phần; tháng sau có bao nhiêu ngày mở bán chưa tính sẵn.

## 24. Lần 233 (chưa áp)

- Ước thô cả tháng khi kỳ tháng < 14 ngày (Demo ngày 11 nói "có khả năng vượt" khi đang giảm 3,3%) — chỉ thử được trên Demo vì quán mẫu là ngày 28; câu "tháng này có đạt tháng 9 không" không còn bị coi là hỏi tháng khác; "muốn đạt 130 triệu" không còn bị đọc thành vay (câu có dấu đọc trên chữ gốc); ước cả tháng trước theo ngày mở bán (quán nghỉ Chủ nhật).
- Bộ kín MỚI `de_kin14.json` (24 câu: mục tiêu tiền, so tháng N, vay thật; người khác viết). Chấm mù 48 cặp: câu bị chạm 14 cặp **+1,79 ± 1,89** (so tháng N +3,75; mục tiêu tiền −0,83 trên 6 cặp); không chạm +0,21; cả bộ +0,67 ± 0,73. Vay thật không bị chạm (không hại).
- Người chấm bắt lỗi vay có sẵn: tiền góp "2,5 triệu/tháng" trong câu bị đọc sai (~278.000đ); vay có lãi chỉ chia gốc; vay nóng trả MỘT LẦN bị chia như trả góp; nợ trả cuối tháng bị coi là trả góp.

## 25. Lần 234 — dòng trả nợ (chưa áp)

- Đọc số trên chữ bỏ dấu GIỮ dấu phẩy ("2,5 triệu" trước thành 5 triệu; "2tr5" = 2,5 triệu); lãi %/tháng (trước chỉ %/năm); góp đều cả gốc lẫn lãi khi biết lãi và số tháng; trả MỘT LẦN (vay nóng, nợ nhà cung cấp, hạn cuối tháng) = gốc + lãi so với thu − chi tới hạn, cảnh báo lãi ≥ 2%/tháng quy ra %/năm.
- Bộ kín MỚI `de_kin15.json` (24 câu: vay góp, trả một lần, không phải vay). Chấm mù 48 cặp: câu bị chạm 18 cặp **+2,72 ± 2,41** (vay góp +3,5; trả một lần +1,75); không chạm −0,20 ± 0,91.
- Sau chấm sửa thêm (chưa đo bằng GPT, chỉ có test): "ngày 30 tháng sau" bị đọc thành 30 tháng (câu đó −2 / −7); "trả một cục" chưa nhận là trả một lần; "công ty nợ quán" bị tính như quán đi vay.
- Còn thấy: tiền hụi / để dành theo tuần, hạn theo ngày (chia mỗi ngày tới 15/12) chưa có dòng tính sẵn; Boom né không tính dù khối có sẵn số.

## 26. Kiểm toàn diện lần 5 (11/11, bản 234)

- Sổ thật (Chủ Quán cho đọc): vẫn 0 lượt thật từ 05/11.
- Bộ kín MỚI `cham_tu_van/thoi_tiet/de_kin16.json` (90 câu, 15 lĩnh vực × 6, người khác viết; trời gán ngẫu nhiên nên vài câu thời tiết lệch trời). Mỗi câu 1 lượt, 2 người chấm độc lập.
- Kết quả: **140/180 dùng được (78%)** (lần 4: 73%), cả hai đồng ý dùng được 66/90; TB **12,97** (lần 4: 12,72). Hai vòng đồng ý 82/90.

| Lĩnh vực | Dùng được | TB |
|---|---|---|
| khuyến mãi | 5/12 | 11,6 |
| nội dung (bài đăng, tin nhắn) | 6/12 | 10,7 |
| giờ / ngày | 7/12 | 11,8 |
| kho | 8/12 | 13,3 |
| khách, ngoài dữ liệu | 9/12 | 12,5–12,7 |
| tiếp thị, doanh thu, so kỳ, thời tiết | 10/12 | 12,4–13,9 |
| thu chi, nhân sự, sàn giao, giá lời | 11/12 | 13,0–14,8 |
| món | 12/12 | 14,0 |

Tiêu chí thấp: việc làm 1,32, tìm vấn đề 1,41, lý lẽ 1,45. Kiểu lỗi: chung chung 25, quá thận trọng 15, lạc đề 11, tính sai 8.

**Lỗi theo lĩnh vực yếu:**
- Khuyến mãi: giảm 33% (mua 2 tặng 1) bị nói NGƯỢC là "lớn hơn phần còn lại sau nguyên liệu" (còn 62,7%) dù dòng tính sẵn đúng; mã giảm trên đơn qua sàn không có phép tính (lời qua sàn 6–8 nghìn/phần, mã bớt 15.000đ/đơn); đề xuất thẻ giấy khi app đã có tích điểm.
- Nội dung: bài đăng thiếu giá / giờ / mã đang chạy; tin báo "món mới" không có tên món mà không hỏi lại; "bù" khách đơn sàn bằng mã của app (khách sàn không nhập được).
- Giờ / ngày: "khung 6–7h" bị cộng cả giờ 7h; không tính doanh thu / ngày của một giờ để quyết đóng / mở sớm, không so lương / giờ công; bỏ qua người làm quá giờ.
- Kho: lúc 9h vẫn dặn nhập "trước khung 6h–13h"; hết ly / than không nói nhập ngay bao nhiêu, gợi ngưng món chủ lực.

**Dòng tính sẵn sai người chấm bắt:**
1. "Việc nên nhắm" gợi "thẻ tích ly mua 8 tặng 1" trong khi dòng Giữ khách dặn KHÔNG thẻ giấy (quán có tích điểm).
2. "ĐIỂM CẦN CHÚ Ý": "4 món chưa bán" nhưng chỉ kể 3 tên, không ghi "và 1 món khác".
3. "MÓN ĐANG HỎI" khớp "Cơm tấm sườn cây" sang "Cơm tấm sườn".
4. Khung "Sáng (5–11h)" ghi cả cho quán mở 9h.
5. Thứ của ngày cuối kỳ trước chia n−1 (cắt cùng giờ) mà không ghi rõ → người chấm tưởng chia sai.
6. Quán mẫu d: số so cùng kỳ theo nhóm / món lẻ, tự mâu thuẫn (dữ liệu mẫu, đã biết).

**Kế hoạch lô F:** (a) mã: sửa dòng 1–5; "khung A–Bh" = giờ A tới trước B; dòng doanh thu / ngày của giờ hỏi đóng / mở + lương / giờ công; mã giảm trên đơn sàn (lời còn lại sau phí sàn − tiền mã); giờ hiện tại trong dòng nhập kho (đã qua giờ mở → "nhập ngay"). (b) kiểm bằng mã: câu trả lời nói "lớn hơn phần còn lại" khi số giảm < phần còn lại; bài đăng thiếu giá khi dòng bài đăng có giá. Đo bằng bộ kín mới theo loại câu đích.

## 27. Lô F — lần 235 (ĐÃ ÁP 11/11 01:41, TS 20261111_014105)

- Bỏ gợi ý thẻ tích ly giấy (Việc nên nhắm, mucBot); "N món chưa bán" ghi "và K món khác" khi tên bị cắt; nhãn khung buổi luôn theo giờ bán thật; dòng kho thêm giờ hiện tại khi hỏi hết / nhập (đã qua giờ mở → nhập ngay, không ngưng món chủ lực); `khungHoi()` tính sẵn khung giờ được hỏi ("6–7h" = giờ 6h, không gồm 7h; giờ đơn khi hỏi mở / đóng / về sớm) + doanh thu / ngày mở bán; `giamNoiNguoc()` bắt câu nói mức giảm "lớn hơn phần còn lại" khi thật ra nhỏ hơn. Không sửa "MÓN ĐANG HỎI" khớp gần (Boom vẫn trả lời đúng món).
- Bộ kín MỚI `de_kin17.json` (32 câu: khuyến mãi, giờ mở / đóng, kho hết, giữ khách). Chấm mù 64 cặp: câu bị chạm 46 cặp **+0,78 ± 0,62**; kho +1,29, khuyến mãi +1,2, giữ khách +0,75, giờ mở / đóng ±0; không chạm −0,22.
- Sau chấm sửa: dòng kho ghi "Bây giờ là 0h" (lấy giờ của mốc đầu ngày) → giờ VN thật (có test).
- Còn thấy: số khung giờ Boom tự cộng sai khi khung khác dòng tính sẵn (14–16h vs 14–17h); mã giảm trên đơn qua sàn vẫn không được dùng dù có dòng; quán có mã HSSV10 mà vẫn đề xuất mã học sinh mới; người làm quá 48 giờ / tuần không được nhắc ở câu giờ mở.

## 28. Kiểm toàn diện lần 6 (11/11, bản 235)

- Sổ thật (Chủ Quán cho đọc): vẫn 0 lượt thật từ 05/11.
- Bộ kín MỚI `de_kin18.json` (90 câu, 15 lĩnh vực × 6, người khác viết; 6 câu thời tiết có trời khớp câu). 1 lượt, 2 người chấm mỗi câu.
- Kết quả: **135/180 dùng được (75%)**, TB **13,06** (lần 5: 78%, 12,97 — bộ khác, coi như ngang). Hai vòng đồng ý 79/90; một người chấm phần 1 nghiêm hơn hẳn (16/30 so với 21/30).

| Lĩnh vực | Dùng được | TB |
|---|---|---|
| kho | 5/12 | 12,8 |
| giờ / ngày | 6/12 | 10,8 |
| tiếp thị | 7/12 | 12,2 |
| khách, thời tiết, sàn giao | 8/12 | 12,7–12,9 |
| ngoài dữ liệu, khuyến mãi | 9/12 | 12,1–13,3 |
| so kỳ, món, giá lời, nội dung | 10/12 | 12,4–14,7 |
| nhân sự | 11/12 | 14,4 |
| thu chi, doanh thu | 12/12 | 13,7–14,1 |

Nội dung lên 10/12 (lần 5: 6/12), khuyến mãi 9/12 (5/12). Tiêu chí thấp: việc làm 1,31, tìm vấn đề 1,44. Kiểu lỗi: chung chung 31, không trả lời thẳng 13, lạc đề 12, quá thận trọng 11.

**Lỗi lặp lại:**
- Kho: hàng ĐÃ HẾT lúc quán đang bán (than) vẫn không dặn nhập ngay hôm nay, có câu dặn "ngày mai"; hỏi hao hụt không quy ra lượng bỏ mỗi ngày (bún, rau, bánh mì) để đặt ít lại; không nêu thứ bán yếu để đặt ít hơn.
- Giờ / ngày, nhân sự: cuối tuần dùng đơn / giờ trung bình mọi ngày → kết luận "không cần thêm người"; câu ca tối / trưa không ước số, không nhắc người quá 48 giờ / tuần; "chưa có đơn / giờ" dù chia được doanh thu ÷ giá trị đơn.
- Tiếp thị / khách: hoà vốn tiếp thị tính theo doanh thu (72 ly) dù có lời / ly và % nguyên liệu; đề xuất mã học sinh mới khi đã có HSSV10; "chưa có giá vốn món tặng" dù có.
- Sàn giao: không ra giá cần tăng khi có phí sàn trong câu (giá mới = (giá vốn + lời cũ) ÷ (1 − phí)).

**Dòng tính sẵn sai:**
1. `khungHoi` (lần 235): "5 giờ tới 9 giờ" / "4h–8h" chiều tối bị hiểu thành giờ sáng (lỗi của chính lô F; Boom chưa dùng nhưng phải sửa trước).
2. Dòng người làm Thứ 7 / Chủ nhật: đơn / giờ trung bình mọi ngày ghi như số cuối tuần → "ngang mức thường, không thêm người", trái dòng "So cuối tuần" (~165%).
3. Bài toán tiền "Mua 2 tặng 1 = giảm 33%" khi món tặng KHÁC món mua (mua 2 cà phê tặng bánh mì trứng ~26%).
4. Bài toán tiền ghép combo trong combo ("Bánh mì thịt + Combo cà phê sữa + bánh mì thịt").
5. Dòng người làm ca chiều "gấp ~1,4 lần mức cả kỳ" mà kết luận "ngang mức thường".
6. Mốc số phần ghi "× 0,4" nhưng tính bằng 0,44 (hệ số ghi làm tròn).

**Kế hoạch lô G:** (a) sửa 1–5; (b) kho: hàng đã hết + quán đang mở → dòng tính sẵn "nhập ngay hôm nay X" cả ở câu thời tiết; hao hụt / ngày tính sẵn; (c) giá trên sàn khi câu có phí: giá mới giữ lời; (d) mã đang chạy cho nhóm khách được hỏi (HSSV…) nêu rõ "đã có mã X". Đo bằng bộ kín mới theo loại câu đích.

## 29. Lô G — lần 236 (ĐÃ ÁP 11/11 02:15, TS 20261111_021527)

- `khungHoi`: "5 giờ tới 9 giờ tối", "4h–8h" khi khung sáng không bán → cộng 12 (phân biệt "tới" / "tối" trên chữ có dấu). Dòng người làm trong khối thời tiết: đơn / giờ nhân hệ số thứ của ngày được hỏi (Thứ 7 ×1,3…); `soVoiLich` ≥ 1,2 lần = "nặng hơn thường". Mua X tặng MÓN KHÁC có số ("mua 2 ly cà phê tặng 1 bánh mì") → tính theo món khác, mức giảm theo giá món tặng (không phải 33%); câu có số chỉ nhận tên món nằm trọn trong câu; món tặng không có trong menu → không tính kiểu tặng cùng món. Combo không lấy món combo có sẵn làm một vế. Kho trong khối thời tiết: hàng ĐÃ HẾT → nhập ngay hôm nay. Bán qua sàn: giá trên sàn giữ lời = giá ÷ (1 − phí). Hỏi nhóm học sinh / sinh viên mà đã có mã HS/SV → nêu mã đang có, không đề xuất mã mới. So cuối tuần ghi đúng ngày có bán (quán nghỉ Chủ nhật).
- Bộ kín MỚI `de_kin19.json` (30 câu: kho hết, giờ ca, giá sàn, nhóm khách, tặng món). Chấm mù 60 cặp: câu bị chạm 26 cặp **+1,15 ± 0,94**; giờ ca +1,4, giá sàn +0,88; không chạm −0,44 ± 0,66.
- Sau chấm sửa (có test, chưa đo lại bằng GPT): "trân châu đường đen" khớp nhầm topping "Trân châu đen" (giảm 68%); "tặng 1 trà tắc" tính như tặng bạc xỉu; "Chủ nhật có bán" khi quán nghỉ Chủ nhật.
- Còn thấy: Boom vẫn né giá sàn ở vài câu dù có dòng; ước lượng hàng cần nhập từ số ly bán / ngày chưa có dòng.
