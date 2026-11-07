# Kế hoạch Boom: sửa lỗi QC, thời tiết, bộ nhớ quán

Lập ngày 07/11/2026. Mốc mã lúc lập: commit `f53ccb9` (máy chủ Boom lần 151).

**Cách dùng:** làm xong việc nào thì đánh dấu `[x]` và ghi ngày. Việc có ký hiệu 🔒 phải hỏi Chủ Quán trước khi áp lên máy chủ thật.

## Thứ tự

| Giai đoạn | Việc | Ước tính làm | Trạng thái |
|---|---|---|---|
| 1 | Sửa lỗi gốc QC | khoảng 1 ngày | Chưa làm |
| 2 | Thời tiết trên Trang chủ và Boom | 3–4 ngày | Chờ khoá Apple |
| 3 | Bật đường mới cho app | 2–4 ngày, cộng thời gian Apple duyệt | Chưa làm |
| 4 | Bộ nhớ riêng từng quán | 3–5 ngày | Chưa làm |
| 5 | Ghi lời khuyên và tự đo kết quả | 3–5 ngày | Chưa làm |
| 6 | Thử công cụ và sổ tay trên mảng tiếp thị | khoảng 1 tuần | Chưa làm |
| 7 | Người dùng thật và dữ liệu | làm dần | Chưa làm |

Các con số là ước đoán, chưa phải cam kết. Giai đoạn 1 và 2 làm song song được. Thứ tự chưa được Chủ Quán chốt.

## Điều đã quyết

- Boom tự học trong lúc trò chuyện, không bắt chủ quán điền form.
- Mỗi quán có bộ nhớ riêng, lưu trong Supabase đang chạy, gắn theo `store_id`.
- Không dùng thêm cơ sở dữ liệu vector lúc này.
- Thời tiết chỉ dùng Apple WeatherKit (Cách A), không có nguồn dự phòng.
- API Google chưa dùng được: Việt Nam chỉ có cảnh báo, không có dự báo.
- Thẻ thời tiết đặt cạnh doanh thu trên Trang chủ, bấm vào mở màn chi tiết.
- Đo tiến bộ bằng bộ 32 câu người ngoài viết, không tự sửa câu.

## Điểm xuất phát để so

QC độc lập ngày 07/11. Dữ liệu ở `tool/boom_do/qc_doc_lap_07_11/`: `cau.json` (32 câu), `diem_fb.json` (chuyên gia F&B), `loi_qc.json` (QC soi số), `s25.ts` (bộ sinh câu trả lời, đọc `de/cau.json` theo đường dẫn tương đối nên phải đặt đúng thư mục khi chạy).

| Loại câu | Dùng được và không lỗi nặng |
|---|---|
| Số liệu | 6/10 |
| Phân tích | 2/10 |
| Tiếp thị | 1/16 |
| Giá món | 2/8 |
| Quyết định | 7/8 |
| Vận hành | 6/8 |
| Khác | 2/4 |
| **Tổng** | **26/64** |

Điểm 10,45/16. Câu lỗi nặng 12/64. Ngang cố vấn giỏi 16/64. 12/32 câu đổi kết luận giữa 2 lượt.

**Mục tiêu đề xuất, Chủ Quán có thể đổi:** sau 3 đợt sửa, tiếp thị đạt ít nhất 6/16, các mảng khác không tụt. Không đạt thì báo thẳng và đổi hướng.

## Giai đoạn 1: Sửa lỗi gốc QC

- [x] Dòng "Việc nên nhắm cho buổi X" bật theo chữ trong câu: "sáng thì làm k kịp" ra khuyên ưu đãi buổi sáng.
- [x] Việc thử ngắn so với mốc cả kỳ: thử 2 tuần so 608 phần của 28 ngày. Mốc phải quy về đúng số ngày thử.
- [x] Bài đăng in giá combo đề xuất như giá thật, trong khi quán đang thu giá khác.
- [x] Khung giờ cố định rơi vào lúc quán đóng cửa (5–11h ở quán mở 9h, 14–17h ở quán đóng 14–16h).
- [x] Gán sai tồn kho: nói một món dưới mức tối thiểu khi khối số liệu không ghi vậy.
- [x] Đề xuất giảm nhiều hơn giá món (giảm 5.000đ cho món 3.000đ).
- [x] Hỏi một món, trả lời món khác mà không nói đã đổi.
- [x] Xếp hạng bỏ sót món mà không nói tiêu chí (top món theo tiền hay theo phần).
- [x] Bảo xem số theo kênh bán trong Báo cáo, màn đó không có mục này.
- [x] Né tính khi thiếu một con số, thay vì tính theo giả định có ghi rõ.
- [x] Nhãn "Cao nhất" sai theo thứ khi hôm nay đang dở ngày: kiểm lại cách tính trung bình.
- [x] Đo lại bằng bộ 32 câu, so với bảng điểm xuất phát.
- [ ] 🔒 Áp lên máy chủ, hỏi lại trên web Demo.

Xong khi: các lỗi trên không còn trong lượt đo, không mảng nào tụt.

**Kết quả 07/11 (đã sửa trong mã, CHƯA commit, CHƯA áp):**
- Chấm mù 64 cặp, cùng một người chấm cho cả hai bản: +0,88 ± 0,70 (11,62 → 12,50/16). Dùng được và không lỗi nặng 36 → 40/64; hỏng 9 → 1; lỗi nặng theo QC 12 → 8.
- Câu có đổi lời nhắc +1,53; câu không đổi lời nhắc +0,13 (dao động giữa 2 lượt, độ lệch chuẩn 2,37). Mảng quyết định tụt 7 → 4 nằm ở câu không đổi lời nhắc, nên là dao động, không do mã mới.
- Bộ cũ và bộ kín 26 cặp: −0,31 ± 0,71 (kín 10 cặp −0,50). Khoảng chứa 0, chưa rõ có tụt thật không.
- Người chấm lần này cho bản cũ dùng được 38/64, còn người chấm QC lần đầu cho 27/64: người chấm khác nhau lệch nhiều, nên chỉ so trong cùng một lần chấm, không so với bảng điểm xuất phát ở trên.
- Lượt đo cuối với mã cuối: lỗi so mốc còn 3/64 sau khi viết lại; không còn khuyên ưu đãi buổi đang quá tải, giảm quá giá món, trả lời sai món, top món bỏ sót. Lượt này chỉ đếm bằng máy, chưa chấm mù lại.
- Còn: phép tính "mua 1 tặng 1" đã có nhưng người chấm thấy Boom chưa dùng; ưu đãi theo khung giờ chưa nói phải áp tay; khối số liệu có Thứ 4 hai số khác nhau (trung bình tháng và trung bình so kỳ trước).

## Giai đoạn 2: Thời tiết

**Điều khoản Apple đã đọc 07/11** (Apple Developer Program License Agreement, mục 3.3.8 B và Attachment 8; tôi không phải luật sư, chỗ nào chưa chắc thì hỏi Apple trước khi phát hành):
- 1.6: chỉ được lưu đệm **tạm thời, có giới hạn, để tăng tốc**. 1.5: cấm tải hàng loạt và cấm đưa vào **cơ sở dữ liệu thứ cấp hoặc phái sinh**. → **Bỏ việc tự lưu lịch sử thời tiết hằng ngày từ Apple.** Muốn học "ngày mưa quán giảm bao nhiêu" thì: (a) hỏi lịch sử từ Apple đúng lúc cần, tính xong không lưu dữ liệu gốc, cần kiểm Apple có trả lịch sử cho Việt Nam không; hoặc (b) dùng nguồn khác cho phép lưu (Open-Meteo gói trả phí có lịch sử, cần đọc điều khoản).
- 1.2: không thu phí riêng cho dữ liệu thời tiết ở dạng gốc, không cấp phép lại. → Thẻ thời tiết không được làm thành tính năng trả phí riêng.
- 1.3: không thiết kế hay quảng bá cho mục đích khẩn cấp, cứu sinh. 1.4: không được sửa cảnh báo thời tiết. → Chưa làm cảnh báo bão lúc đầu.
- 2.2: ứng dụng có hướng dẫn thời tiết thời gian thực phải có câu thông báo trong điều khoản người dùng: dùng tự chịu rủi ro, dữ liệu thời tiết có thể không chính xác. → **Chủ Quán quyết** thêm câu này vào điều khoản sử dụng của app.
- Ghi nguồn: nhãn Apple Weather và liên kết tới trang nguồn dữ liệu của Apple; dữ liệu đã biến đổi thành sản phẩm giá trị gia tăng thì ghi "Weather" kèm câu dữ liệu Apple đã được chỉnh sửa.
- Không thấy điều cấm riêng về đưa dữ liệu cho AI viết lại thành lời, chuyển cho bên thứ ba hay dùng ngoài nền tảng Apple. Câu Boom trả lời là dữ liệu đã biến đổi, có lẽ thuộc sản phẩm giá trị gia tăng; chưa chắc, ghi nguồn theo cách đó cho an toàn.
- 2.1, 3.2: Apple không cam kết có dữ liệu ở mọi nước, có thể ngừng quyền truy cập bất cứ lúc nào. → Thẻ và Boom phải chạy được khi không có thời tiết.

**Chủ Quán chốt 07/11: Cách A, chỉ dùng Apple.**
- Chỉ một nguồn là Apple. Bỏ WeatherAPI và Open-Meteo, kể cả vai trò dự phòng.
- Lấy thời tiết khi có người mở app lần đầu trong ngày; sau đó tối đa **3 tiếng** một lần, khi có người mở app hoặc app đang mở.
- Máy chủ đệm theo khu vực, quán cùng khu dùng chung. App không lưu gì.
- Đệm trong bộ nhớ máy chủ trước (như đệm số liệu bán hàng trong `hoi.ts`), chưa tạo bảng.
- **Không lưu dữ liệu thời tiết Apple lâu dài, kể cả 30 ngày** (điều khoản 1.5, 1.6). Chủ Quán từng đề nghị lưu 30 ngày cho Boom học; Claude không làm vì nghĩ vẫn vi phạm.
- Boom học "ngày mưa giảm bao nhiêu" bằng cách hỏi Apple dữ liệu cũ đúng lúc cần, tính xong chỉ lưu **con số kết luận** vào bộ nhớ quán, không lưu dữ liệu gốc. Cần kiểm Apple có trả dữ liệu cũ cho Việt Nam không.
- Mất Apple thì thẻ ẩn, Boom nói chưa có thời tiết; không có nguồn dự phòng.

**Chuẩn bị**
- [x] Đọc điều khoản Apple (07/11, xem trên).
- [ ] **Chủ Quán:** tạo khoá WeatherKit trong tài khoản Apple Developer, cất vào Keychain, không dán vào chat.
- [ ] Gọi thử API bằng toạ độ Hà Nội, Đà Nẵng, TP.HCM: có đủ dự báo theo giờ và theo ngày không.
- [ ] Kiểm Apple đếm lượt thế nào khi lấy nhiều loại dữ liệu trong một lần gọi.
- [ ] Kiểm Apple có trả dữ liệu cũ (lịch sử) cho Việt Nam không.
- [ ] Nếu Apple không có dữ liệu Việt Nam: báo Chủ Quán, quyết lại nguồn.

**Mã đã viết 07/11 (chưa commit, chưa áp, chưa gọi Apple thật):**
- Máy chủ: `supabase/functions/boom-chat/thoi_tiet.ts` (ký vé ES256, gọi Apple, rút gọn, đệm 3 tiếng hoặc tới nửa đêm, ghi nguồn), lệnh `thoi_tiet` trong `index.ts`, Boom đọc thời tiết khi câu hỏi liên quan (`thoiTiet` trong `buildMessages`). Kiểm thử `thoi_tiet_test.ts` 4/4, toàn bộ hàm 119/119.
- App: `lib/features/thoi_tiet/` (dữ liệu, thẻ, màn chi tiết, chọn khu vực bằng GPS hoặc thành phố), thẻ cạnh nhãn "Sẵn sàng" ở cả nhánh chủ quán và nhân viên, `BoomAiService.thoiTiet`. Kiểm thử `test/features/thoi_tiet_test.dart` 4/4.
- Khu vực lưu ở `app_settings` khoá `thoi_tiet_vi_tri`, làm tròn 0,05 độ; không cần bảng mới.
- Biến môi trường máy chủ cần thêm: `WEATHERKIT_TEAM_ID`, `WEATHERKIT_KEY_ID`, `WEATHERKIT_SERVICE_ID`, `WEATHERKIT_PRIVATE_KEY`. Thiếu một biến thì thẻ ẩn, Boom không nhắc.
- Script áp phải chép thêm `thoi_tiet.ts` và `index.ts`, không chỉ `logic.ts`.
- Khi bật thật: rà lại bài hướng dẫn `bat-dau.md` (Trang chủ có thẻ mới), kiểm thử đồng bộ hướng dẫn đang báo vì `dashboard_screen.dart` đổi; bài đó còn đang báo vì tệp của phiên khác.
- Chưa làm: hỏi lịch sử Apple cho "ngày mưa giảm bao nhiêu"; nút "Hỏi Boom nên chuẩn bị gì" trên màn chi tiết.

**Máy chủ**
- [x] 🔒 Lấy và lưu đệm theo khu vực, tối đa 3 tiếng, chỉ để tăng tốc; khoá chỉ nằm trên máy chủ. (mã đã viết, chưa áp)
- [ ] ~~Lưu lịch sử thời tiết hằng ngày~~: bỏ, vì điều khoản Apple 1.5, 1.6.
- [x] Chỉ gửi toạ độ làm tròn theo khu vực, không gửi địa chỉ hay tên quán. (mã đã viết, chưa áp)

**App và web**
- [x] Chọn khu vực cho quán, chỉ hỏi một lần. (mã đã viết, chưa áp)
- [ ] Thẻ cạnh doanh thu trên màn rộng; màn nhỏ chuyển xuống hàng dưới để không cắt số.
- [x] Thêm thẻ vào cả nhánh hiển thị của nhân viên. (mã đã viết, chưa áp)
- [ ] Màn Thời tiết: hiện tại, theo giờ, các ngày tới, nút hỏi Boom.
- [x] Ghi nguồn Apple Weather trên thẻ và màn chi tiết. (mã đã viết, chưa áp)
- [x] Lỗi hoặc mất mạng thì ẩn thẻ, không làm chậm Trang chủ, không ảnh hưởng bán hàng. (mã đã viết, chưa áp)
- [ ] Có thể tắt thẻ theo quán.
- [ ] 🔒 Đăng lên web trước; app theo đợt phát hành sau.

**Boom**
- [x] Boom đọc thời tiết khi câu hỏi liên quan, chỉ làm khi điều khoản cho phép. (mã đã viết, chưa áp)
- [x] Dùng chữ "dự báo", "khả năng"; không khuyên việc tốn tiền chỉ dựa vào dự báo. (mã đã viết, chưa áp)
- [ ] Không lấy thời tiết làm cớ che vấn đề thật của quán.

**Về sau, khi đủ dữ liệu**
- [ ] So 2 tuần báo đúng theo vùng để biết độ tin cậy thật (chỉ ghi kết quả đúng/sai, không lưu dữ liệu Apple).
- [ ] "Ngày mưa quán mình thường giảm X%": hỏi lịch sử khi cần, chỉ lưu con số kết luận, có ngưỡng số ngày tối thiểu.
- [ ] Chưa làm thông báo tự động "mai mưa", xét sau vì dễ phiền.

## Giai đoạn 3: Bật đường mới cho app

Đính chính 07/11 sau khi đọc `index.ts`: app điện thoại và Windows đi đường `advice`, gửi số app tự đọc lên, nhưng **vẫn dùng chung** `buildMessages` và `kiemTraLoi` trên máy chủ. Vậy phần lớn sửa trong `logic.ts` (tính sẵn, mã kiểm, bài toán tiền) **đã đến app** khi áp máy chủ. Phần app **chưa có**: máy chủ tự đọc kỳ (`ky.ts`: gõ tắt, "tới h"…), máy chủ đọc số theo quyền (`lay_so.ts`: chủ quán đọc mục Khách hàng dù module tắt, mã voucher trong ghi chú đơn), tên quán, câu "tài khoản chưa xem được", và các trường app không gửi (không thấy `by_day` trong mã Dart nên số từng ngày, bỏ tiền hôm nay khi xếp thứ không chạy trên app). App tự đọc kỳ bằng `intent_classifier.dart`, mẫu "so với" ở đó cần chữ "voi" đi kèm, nên có lẽ không dính lỗi số/so của máy chủ; mới đọc mã, chưa chạy thử.

- [ ] Kiểm đường cũ của app có dính lỗi số/so không.
- [ ] Thử đường mới trên bản dựng thử, tài khoản chủ và tài khoản nhân viên.
- [ ] 🔒 Phát hành theo quy trình `/qn`. Android từ build 23 trở xuống phải cập nhật tay; hỏi trước khi ghi `app_versions`.

## Giai đoạn 4: Bộ nhớ riêng từng quán

**Nháp đã viết 07/11 (chưa commit, CHƯA áp lên cơ sở dữ liệu thật, chưa nối vào Boom):**
- `supabase/migrations/20261107_boom_bo_nho_quan_v1.sql` và `_ROLLBACK.sql`: 3 bảng; RLS bật, không policy, chỉ service_role đọc ghi; chủ quán xem, sửa, xoá, tắt qua 4 hàm `boom_bo_nho_*_v1`; giới hạn 200 ghi nhớ còn hiệu lực mỗi quán; sang nhượng xoá điều riêng của chủ cũ; xoá quán xoá hết.
- `supabase/tests/boom_bo_nho_quan_v1_test.sql`: 24/24 qua trên Postgres 17 tạm dựng tại máy (bảng `stores`, `store_members`, `auth.uid()` là bản giả lập). Áp hai lần không lỗi; hoàn tác xoá sạch; áp lại sau hoàn tác vẫn 24/24.
- `supabase/functions/boom-chat/bo_nho_quan.ts` + kiểm thử 5/5: lọc ứng viên (bỏ nhất thời, số bán hàng, số điện thoại, tài khoản), nguồn và mức xem, gộp trùng ý, dời quán thì điều cũ hết hiệu lực, Boom đoán trái điều đã xác nhận thì sinh một câu hỏi lại, khối đưa Boom tối đa 12 dòng.
- **Đã nối vào `index.ts` 07/11 (chưa áp):** đọc ghi nhớ trước khi trả lời câu tư vấn (nhân viên chỉ thấy điều "cả quán"), rút ghi nhớ SAU khi đã trả lời (chạy nền, không làm khách chờ; chỉ khi câu có nói về quán, khoảng một nửa câu), lọc rồi ghi bảng. Công tắc toàn hệ thống `BOOM_BO_NHO=1` (mặc định tắt); `BOOM_BO_NHO_BO_QUA` = mã quán bỏ qua, đặt mã quán Demo khi bật.
- Đo lượt rút ghi nhớ bằng gpt-6-luna, 20 câu mẫu viết sẵn đáp án, 2 lượt (`tool/boom_do/bo_nho_07_11/`): nhớ đúng 16/20 → sau khi sửa 19/20 (2 lần chạy); nhớ bậy 0/20; điều riêng lộ cho cả quán 0. Dời quán: chủ quán nói thì điều cũ hết hiệu lực; nhân viên nói thì không đè, sinh câu hỏi lại. Câu còn hay sót: mục tiêu có số ("tăng 20% doanh thu"). Bộ câu do Claude viết, nhỏ, chưa phải câu người thật; đã nới đáp án câu giờ mở từ "6h" thành "6" vì mô hình viết "6 giờ".
- Chưa làm: màn chủ quán xem, sửa, xoá bộ nhớ trong app (hàm SQL đã có); đo Boom có dùng bộ nhớ đúng khi trả lời (không hỏi lại điều đã biết, không khoe); bảng lời khuyên và tự đo (giai đoạn 5).
- Bản giả lập khác máy chủ thật ở `store_members` (chỉ các cột cần) và `auth.uid()`; khi áp phải chạy kiểm thử ngay trên máy chủ trong giao dịch rồi hoàn tác, như các migration khác.

**3 bảng** (🔒 đổi cơ sở dữ liệu, viết kèm cách hoàn tác)
- [ ] `boom_quan_ho_so`: mỗi quán một dòng: loại quán, khách chính, gần gì, khu vực, giờ mở, ngày nghỉ, mục tiêu.
- [ ] `boom_quan_ghi_nho`: nội dung, nguồn, trạng thái, mức xem, ngày bắt đầu, ngày hết hiệu lực.
- [ ] `boom_quan_loi_khuyen`: dùng ở giai đoạn 5.

**Cách học**
- [ ] Chạy sau khi đã trả lời xong, để chủ quán không phải chờ.
- [ ] Chủ quán nói thẳng: ghi luôn, không hỏi lại.
- [ ] Boom suy ra: ghi là "đoán", chỉ hỏi khi điều đó làm đổi lời khuyên.
- [ ] Chuyện nhất thời ("hôm nay mưa nên vắng"): không ghi.
- [ ] Nhân viên nói: để dạng "đoán", chờ chủ quán xác nhận.
- [ ] Câu mơ hồ: không ghi.

**Khi thông tin đổi**
- [ ] Hỏi lại khi chủ quán nói điều khác đi (dời quán, đổi giờ, đổi món chính).
- [ ] Số bán hàng đổi lạ thì hỏi "dạo này quán có thay đổi gì không", không tự kết luận.
- [ ] Thông tin quá cũ thì hỏi lại lúc cần dùng.
- [ ] Mỗi câu trả lời hỏi tối đa một câu, trả lời xong việc chính rồi mới hỏi.
- [ ] Giữ lịch sử khi sửa, có ngày hiệu lực; chủ quán muốn xoá hẳn thì xoá được.
- [ ] Hiểu chuyện tương lai: "tháng sau dời quán" thì hiện vẫn ở chỗ cũ, tới ngày thì hỏi lại.

**10 điểm phải giữ**
- [ ] Không lộ cho nhân viên: 2 mức xem, chưa rõ thì mặc định chỉ chủ quán.
- [ ] Không lẫn giữa các quán, kể cả khi Đổi quán và trong chuỗi.
- [ ] Số thật thắng trí nhớ; không lưu số bán hàng vào bộ nhớ.
- [ ] Công tắc tắt toàn hệ thống và tắt theo quán.
- [ ] Nhớ việc đã thử không hiệu quả, câu chủ quán không muốn trả lời.
- [ ] Nhớ nhưng không khoe.
- [ ] Gộp câu trùng, giới hạn số ghi nhớ, chỉ gửi phần liên quan cho AI.
- [ ] Sang nhượng quán: chủ mới không thấy ghi nhớ riêng của chủ cũ. Xoá quán thì xoá bộ nhớ. Quán Demo tắt hoặc tự xoá.
- [ ] Cùng một bộ nhớ trên mọi thiết bị (cần giai đoạn 3).
- [ ] Coi bộ nhớ là dữ liệu, không phải lệnh. Không nhớ số điện thoại khách, chuyện riêng nhân viên, tài khoản ngân hàng.

**Minh bạch**
- [ ] Chủ quán xem, sửa, xoá được những gì Boom nhớ.
- [ ] Hỏi "em đang nhớ gì về quán anh" thì Boom kể ra được.

**Bộ thử trước khi bật**

| Kiểm | Ví dụ | Yêu cầu |
|---|---|---|
| Nhớ đúng | Nói một lần, lần sau không hỏi lại | Đo tỉ lệ |
| Không nhớ bậy | "Hôm nay mưa nên vắng" không vào hồ sơ | Đo tỉ lệ |
| Biết sửa | Dời quán thì hỏi lại và cập nhật | Đo tỉ lệ |
| Không lộ | Nhân viên không moi được chuyện của chủ | **100%** |
| Không lẫn | Đổi quán không thấy ghi nhớ quán kia | **100%** |

Xong khi: bộ thử đạt và câu tiếp thị trong bộ 32 câu khá lên so với điểm xuất phát.

## Giai đoạn 5: Ghi lời khuyên và tự đo kết quả

- [ ] Ghi: khuyên gì, ngày nào, đo bằng số nào, số lúc đầu.
- [ ] Sau khoảng 2 tuần tự đọc số, báo lại và hỏi chủ quán có làm không.
- [ ] Không kết luận từ một quán, một lần; loại trừ thời tiết, mùa, ngày lễ khi so.
- [ ] Số gộp giữa các quán phải ẩn danh, có chính sách rõ với chủ quán.
- [ ] Bài học mới phải có người duyệt, không cho AI tự sửa luật của mình.

## Giai đoạn 6: Thử công cụ và sổ tay

Chỉ làm khi đã có đo so sánh. Có thể không vượt được cách hiện tại.

- [ ] Thử gpt-6-luna gọi công cụ trên mảng tiếp thị, đo chất lượng, độ trễ, chi phí.
- [ ] Viết 10–15 bài sổ tay theo tình huống thật: học sinh, văn phòng, quán mới ít đơn, đơn đang tụt...
- [ ] Mã tính số hiện có giữ nguyên, chuyển thành công cụ.
- [ ] Thua thì bỏ, không chuyển.

## Giai đoạn 7: Người dùng thật

- [ ] Xem lại sổ hỏi đáp theo định kỳ, mỗi lần đọc phải hỏi Chủ Quán.
- [ ] Thúc nhập giá vốn (06/11 chỉ 8,9% món có giá vốn).
- [ ] Theo dõi: chủ quán có quay lại hỏi không, có làm theo không.
- [ ] Câu sai từ người dùng thật đưa vào bộ đo, không đưa nguyên văn hay tên quán.

## Lỗi đã biết, chưa xếp vào đợt nào

- Việc tạo mã ở câu chọn ngày ưu đãi chưa có mức giảm, vì phép tính ngưỡng mã chưa bật khi câu chỉ nói "ưu đãi".
- Boom tự chen "thay vì tăng giá" dù không ai hỏi (tác dụng phụ của kiểm tăng giá).
- Tiếp thị ra một khuôn, không theo nhóm khách: chờ giai đoạn 4 và 6.
- Khuyên ghép combo món giá vốn cao, khuyên tặng món khi chưa có giá vốn.
- "Tăng đơn" bị đổi thành mời thêm món.
- Mẫu trả lời cứng với người đang nản.

## Quy tắc xuyên suốt

- Hỏi trước khi áp lên máy chủ thật, kể cả khi đã "sửa đi".
- Chỉ chat tiếng Việt. Không lưu khoá trong mã, tài liệu hay chat.
- Mỗi lần áp thêm một dòng `boom_changelog`, có lệnh hoàn tác.
- Bộ kín chỉ người chấm đọc. Không đưa câu hỏi thật hay tên quán vào mã, bộ đo, commit.
- Muốn nói app có tính năng gì thì lần tới màn gọi nó trước.
