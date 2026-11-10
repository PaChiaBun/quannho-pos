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
