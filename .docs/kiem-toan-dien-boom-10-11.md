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
