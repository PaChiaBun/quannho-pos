# Kế hoạch Boom: sửa lỗi QC, thời tiết, bộ nhớ quán

Lập ngày 07/11/2026. Mốc mã lúc lập: commit `f53ccb9` (máy chủ Boom lần 151).

**Cách dùng:** làm xong việc nào thì đánh dấu `[x]` và ghi ngày. Việc có ký hiệu 🔒 phải hỏi Chủ Quán trước khi áp lên máy chủ thật.

## Thứ tự

| Giai đoạn | Việc | Ước tính làm | Trạng thái |
|---|---|---|---|
| 1 | Sửa lỗi gốc QC | khoảng 1 ngày | Đã áp (lần 152, 08/11); 2 lỗi web 08/11 đã sửa, chưa áp |
| 2 | Thời tiết trên Trang chủ và Boom | 3–4 ngày | Mã xong, đã lên máy chủ nhưng tự tắt; chờ khoá Apple |
| 3 | Bật đường mới cho app | 2–4 ngày, cộng thời gian Apple duyệt | Mã xong (4e25a91); chờ thử máy có đăng nhập rồi phát hành |
| 4 | Bộ nhớ riêng từng quán | 3–5 ngày | **Đã áp và bật 09/11** (bỏ qua quán Demo); chờ quán thật dùng để đo |
| 5 | Ghi lời khuyên và tự đo kết quả | 3–5 ngày | **Bật cùng bộ nhớ 09/11**; kết quả đầu tiên sau khoảng 2 tuần |
| 6 | Thử công cụ và sổ tay trên mảng tiếp thị | khoảng 1 tuần | Công cụ bỏ; sổ tay +0,48 ± 0,42, **đã bật 09/11 (lần 160)** |
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

**Script áp lần 152 (08/11):** `db-fix/boom_l152_ap_dung.sh` chép `index.ts`, `logic.ts` và 4 tệp mới; có sao lưu, hoàn tác, chế độ chỉ kiểm `KHO=1`. Chạy chỉ kiểm 08/11: test qua, 6 tệp trên máy chủ khớp f53ccb9, 4 tệp mới chưa có. Script đòi mọi tệp chép đã commit, nên phải commit phần sửa đường ask trước khi áp.

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
- Còn: phép tính "mua 1 tặng 1" đã có nhưng người chấm thấy Boom chưa dùng (09/11: thêm cách đọc và mã kiểm, chưa áp); ưu đãi theo khung giờ chưa nói phải áp tay (đã sửa bằng mã 08/11, chưa áp). (Thứ 4 hai số khác nhau: đã áp lần 154.)

**Sửa thêm 08/11 sau khi thử web (chưa áp):**
- Kỳ ít đơn (dưới 30) mà câu xin lời khuyên không phải câu tiếp thị ("tháng này thế nào, nên làm gì") thì thiếu dòng ít đơn, Boom vẫn khuyên ưu đãi 14–17h. Nay `baiToanTiepThi` vẫn đưa dòng ít đơn cho câu xin lời khuyên, nên mã kiểm `khuyenTheoKyIt` bắt được; câu chỉ hỏi số thì không.
- "Đồ uống tăng 25.000đ → 580.000đ" khi doanh thu giảm 97%: doanh thu nhóm kỳ trước chỉ cộng món còn trên menu hiện tại, món đã xoá / tạo lại rơi mất. Nay (`ban_hang.ts`) nếu cộng món kỳ trước dưới 80% tiền đơn kỳ trước thì bỏ so theo nhóm và theo món. Chưa đọc dữ liệu thật của Demo để chắc đây đúng là nguyên nhân; "ca 2–5h" trên Demo chưa xem.
- Kiểm thử hàm 132/132.
- Đã áp lần 153 (9d334bd). Web Demo 7 đơn: không khuyên giờ, gợi ý xem 30 ngày.
- "Ca 2–5h" trên Demo: hỏi thử thấy chỉ 250.000đ = 0,7% doanh thu 30 ngày, là vài đơn lẻ lúc khuya bị gom thành ca. Nay khối giờ dưới 3% doanh thu ghi là "đơn lẻ ngoài giờ chính", không tính là ca, không vào dòng "có bán" (mã kiểm giờ ngoài bán vẫn bắt ưu đãi đặt vào giờ đó). Chưa áp.
- Thứ của hôm nay có 2 trung bình (dòng theo thứ chia đủ n gồm ngày dở; dòng so kỳ trước chia n−1 mà tiền vẫn gồm hôm nay). Nay cả hai bỏ tiền hôm nay khi có số từng ngày. Chưa áp.
- Đã áp lần 154 (d4ad958). Web Demo hỏi ca: không còn "ca 2–5h".
- Buổi sáng vẫn cộng tiền đơn lẻ 2–5h dù nhãn 6–11h: nay buổi không cộng khối đơn lẻ. Chưa áp.
- Ưu đãi theo khung giờ không nói cách áp (mã giảm của app không giới hạn theo giờ): `ghiApTay` gắn 1 câu "App không tự giới hạn ưu đãi theo giờ: dặn nhân viên áp tay đúng khung giờ này." vào dòng việc đầu tiên dính, bằng mã, không bắt viết lại. Trên 494 câu đã lưu (lượt đo giai đoạn 6): gắn 51 câu; đã soát hết các dòng bị gắn, sau khi bỏ "giảm người / ca / cơm dư", "mức giảm", "thay vì giảm giá" thì đều là ưu đãi theo giờ thật. Chưa áp.
- Đã áp lần 155 (2bcd8ca). Thời tiết bật lần 156 (9e2c5c1), thử trọn luồng trên Demo 09/11 đạt.
- 09/11, chưa áp:
  - Thứ của hôm nay chưa xong mà kỳ có 2 ngày thứ đó 0đ thì từng ghi "quán NGHỈ" (Demo: "quán đang nghỉ Thứ Hai" đúng hôm Thứ 2). Nay chỉ tính ngày trọn.
  - Hỏi "buổi chiều vắng" mà dòng xếp hướng theo tiền đứng đầu là "8h và 9h hồi nửa phần mất", Boom mở đầu bằng buổi sáng. Nay câu hỏi nói đúng một buổi thì bỏ hướng giờ ngoài buổi đó, dặn trả lời buổi đó trước.
  - Mua tặng: chỉ nhận "mua 1 tặng 1" bằng số; nay nhận "mua một tặng một", "1 tặng 1", "1+1" (khi câu nói mua / tặng / khuyến mãi). Thêm mã kiểm `muaTangChuaDung`: có phép tính mà câu trả lời không dùng số nào của nó thì viết lại. Chưa đo trên câu trả lời thật.
- Đã áp lần 157 (c1844bc). Web Demo "mua một tặng một có lỗ không": Boom dùng đúng phép tính (giảm 50%, gấp 2,2 / 5,5 lần). Lộ lỗi lần 156: "mua" bỏ dấu khớp "mưa" → lấy thời tiết và gắn nguồn Apple cho câu mua bán. Đã sửa (chỉ "mưa" có dấu hoặc "trời mua", "mua to"…), chưa áp.

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

**Đã làm 08/11 (chưa commit, chưa áp, chưa phát hành):**
- `kBoomServerRoute = true`: app (Android, iOS, Windows) đi đường ask như web; lỗi hoặc máy chủ từ chối thì tự quay về đường cũ như trước.
- App gửi `nen_tang`; máy chủ có chốt `BOOM_ASK_TAT_APP=1` trả 503 cho câu ask không phải từ web → app đi đường cũ, tắt được mà không cần phát hành lại.
- Kiểm thử Boom của app 127/127. CHƯA thử trên máy thật hay máy ảo: không có máy ảo đang chạy, và app cần đăng nhập tài khoản thật (Claude không nhập mật khẩu).
- Thứ tự an toàn: áp máy chủ lần 152 trước (có chốt tắt), rồi mới phát hành app. Máy chủ cũ bỏ qua `nen_tang` nên thứ tự ngược cũng không lỗi, chỉ thiếu chốt tắt.

- [x] Kiểm đường cũ của app có dính lỗi số/so không. 08/11 chạy 12 câu có chữ "số" qua `IntentClassifier`: đọc kỳ đúng hết ("số đơn tháng trước" → tháng trước, "doanh số tháng 10" → tháng 10); mẫu so sánh ở app cần "so với / so tháng…" nên không dính.
- [ ] Thử đường mới trên bản dựng thử, tài khoản chủ và tài khoản nhân viên (cần Chủ Quán đăng nhập sẵn trên máy ảo hoặc máy thử).
- [ ] 🔒 Phát hành theo quy trình `/qn`. Android từ build 23 trở xuống phải cập nhật tay; hỏi trước khi ghi `app_versions`.

## Giai đoạn 4: Bộ nhớ riêng từng quán

**Nháp đã viết 07/11 (chưa commit, CHƯA áp lên cơ sở dữ liệu thật, chưa nối vào Boom):**
- `supabase/migrations/20261107_boom_bo_nho_quan_v1.sql` và `_ROLLBACK.sql`: 3 bảng; RLS bật, không policy, chỉ service_role đọc ghi; chủ quán xem, sửa, xoá, tắt qua 4 hàm `boom_bo_nho_*_v1`; giới hạn 200 ghi nhớ còn hiệu lực mỗi quán; sang nhượng xoá điều riêng của chủ cũ; xoá quán xoá hết.
- `supabase/tests/boom_bo_nho_quan_v1_test.sql`: 24/24 qua trên Postgres 17 tạm dựng tại máy (bảng `stores`, `store_members`, `auth.uid()` là bản giả lập). Áp hai lần không lỗi; hoàn tác xoá sạch; áp lại sau hoàn tác vẫn 24/24.
- `supabase/functions/boom-chat/bo_nho_quan.ts` + kiểm thử 5/5: lọc ứng viên (bỏ nhất thời, số bán hàng, số điện thoại, tài khoản), nguồn và mức xem, gộp trùng ý, dời quán thì điều cũ hết hiệu lực, Boom đoán trái điều đã xác nhận thì sinh một câu hỏi lại, khối đưa Boom tối đa 12 dòng.
- **Đã nối vào `index.ts` 07/11 (chưa áp):** đọc ghi nhớ trước khi trả lời câu tư vấn (nhân viên chỉ thấy điều "cả quán"), rút ghi nhớ SAU khi đã trả lời (chạy nền, không làm khách chờ; chỉ khi câu có nói về quán, khoảng một nửa câu), lọc rồi ghi bảng. Công tắc toàn hệ thống `BOOM_BO_NHO=1` (mặc định tắt); `BOOM_BO_NHO_BO_QUA` = mã quán bỏ qua, đặt mã quán Demo khi bật.
- Đo lượt rút ghi nhớ bằng gpt-6-luna, 20 câu mẫu viết sẵn đáp án, 2 lượt (`tool/boom_do/bo_nho_07_11/`): nhớ đúng 16/20 → sau khi sửa 19/20 (2 lần chạy); nhớ bậy 0/20; điều riêng lộ cho cả quán 0. Dời quán: chủ quán nói thì điều cũ hết hiệu lực; nhân viên nói thì không đè, sinh câu hỏi lại. Câu còn hay sót: mục tiêu có số ("tăng 20% doanh thu"). Bộ câu do Claude viết, nhỏ, chưa phải câu người thật; đã nới đáp án câu giờ mở từ "6h" thành "6" vì mô hình viết "6 giờ".
- **Đo Boom dùng bộ nhớ khi trả lời (07/11, `tool/boom_do/bo_nho_07_11/dung.ts`):** quán mẫu A, 6 câu, có và không có bộ nhớ, 2 lượt. Lỗi thật tìm ra: chủ quán nói combo sáng đã thử không hiệu quả, Boom vẫn khuyên sửa combo đó mà không nhắc. Đã thêm mã kiểm `khuyenLaiDaThu`; sau đó cả 2 lượt đều nhắc chuyện đã thử (một lượt nêu lý do mới là combo đang đắt hơn mua lẻ, một lượt khuyên chưa nên thử lại). Không lộ chuyện riêng cho nhân viên 0/2; không khuyên ưu đãi Chủ nhật quán nghỉ; nhắc bộ nhớ kiểu khoe 1/12 cả hai bên (ngang nhau). Bộ đếm bằng mẫu chữ khá thô, đã đọc lại tay các câu chính.
- **Màn chủ quán (07/11):** `lib/features/ai_assistant/bo_nho/bo_nho_quan_screen.dart`, ô "Bé Boom nhớ gì về quán" trong Cài đặt (chỉ chủ quán, tự ẩn khi máy chủ chưa có hàm). Xem theo nhóm, nút "Đúng rồi" cho điều đoán, sửa, xoá (hỏi lại trước khi xoá), công tắc tắt. Kiểm thử `test/features/bo_nho_quan_test.dart` 3/3, chưa thử với máy chủ thật vì migration chưa áp.
- Chưa làm: bảng lời khuyên và tự đo (giai đoạn 5); thử cả luồng trên máy chủ thật sau khi áp.
- Bản giả lập khác máy chủ thật ở `store_members` (chỉ các cột cần) và `auth.uid()`; khi áp phải chạy kiểm thử ngay trên máy chủ trong giao dịch rồi hoàn tác, như các migration khác.
- **09/11 chuẩn bị áp:** `db-fix/boom_bo_nho_ap_dung.sh` (KHO=1 chỉ kiểm; thường: sao lưu database → migration → 24 test tự ROLLBACK, công tắc vẫn tắt; BAT=1: bật `BOOM_BO_NHO=1` bỏ qua quán Demo; ROLLBACK=1: tắt công tắc, gỡ bảng). Bài test thêm người dùng giả vào `user_accounts` khi máy chủ có bảng đó (máy chủ thật có khoá ngoài stores / store_members → user_accounts); chạy lại tại máy 24/24 cả khi có và không có khoá ngoài đó. Chưa chạy trên máy chủ.
- **09/11 đã áp và bật:** sao lưu `quannho_before_bo_nho_20261109_102811.dump`; migration xong; 24/24 test trên máy chủ (tự ROLLBACK); app không đọc thẳng bảng, chủ quán gọi được hàm xem; `BOOM_BO_NHO=1`, `BOOM_BO_NHO_BO_QUA` = quán Demo. Thử Demo: không nhãn `+bo_nho`, 0 ghi nhớ. CHƯA thấy luồng ghi nhớ chạy trên quán thật; màn "Bé Boom nhớ gì về quán" chỉ có ở bản app chưa phát hành. Hoàn tác: `ROLLBACK=1 bash db-fix/boom_bo_nho_ap_dung.sh` (mất ghi nhớ đã lưu).

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
- [x] Hỏi "em đang nhớ gì về quán anh" thì Boom kể ra được. (09/11, sau công tắc BOOM_BO_NHO: khối bộ nhớ nới tới 20 dòng, dặn kể đúng, chỉ chỗ sửa / xoá; chưa nhớ gì thì nói thẳng; nhân viên vẫn chỉ thấy điều "cả quán". Chưa áp.)

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

**Nháp đã viết 07/11 (chưa commit, chưa áp; dùng chung công tắc `BOOM_BO_NHO`, mặc định tắt):**
- `supabase/functions/boom-chat/loi_khuyen.ts` + kiểm thử 3/3: rút tối đa 2 việc đo được từ phần "Việc tuần này" (khung giờ, một thứ, số phần một món, giá trị mỗi đơn, số đơn, doanh thu), mốc là trung bình mỗi ngày mở bán lúc khuyên, ngày đo theo "N tuần / N ngày" (mặc định 14, trong 7–60).
- `index.ts`: sau khi trả lời, ghi việc vào `boom_quan_loi_khuyen` (bỏ việc trùng chỉ số đang chờ đo); trước khi trả lời câu của **chủ quán**, đọc việc tới ngày đo, đọc số đúng khoảng thử bằng vé của chủ quán, ghi kết quả, đưa khối "KẾT QUẢ VIỆC BÉ BOOM ĐÃ KHUYÊN" để Boom báo 1–2 câu cuối và hỏi chủ quán có làm không; quá 3 giây thì bỏ.
- Đo phần rút trên 64 câu trả lời thật của bộ QC (`tool/boom_do/bo_nho_07_11/do_loi_khuyen.ts`): lần đầu khoảng 6/14 gán đúng; sửa 6 kiểu lỗi (lấy dòng "Cần xem lại", việc bị dặn không làm, nhầm món, khung giờ đè món, việc đo thứ app không có số, "thử 2 tuần" đọc thành Thứ 2); lần cuối rút 33 việc ở 27/64 câu, Claude đọc lại thấy còn khoảng 2–3 việc gán sai. Đây là Claude tự chấm, không chấm mù.
- 09/11: chủ quán trả lời "có / chưa làm" ngay sau lượt Boom báo kết quả (sổ hỏi đáp ghi `+do_ket_qua`, trong 30 phút, câu ngắn rõ ý) → ghi `chu_quan_lam` cho việc vừa đo (`traLoiCoLam` + `ghiCoLam`, chưa áp; phần đọc câu có kiểm thử, phần ghi bảng chưa chạy thử vì migration chưa áp).
- Chưa làm: dùng kết quả để học "việc nào hiệu quả với loại quán nào" (cần nhiều quán dùng thật); chưa chạy thử luồng đo trên máy chủ thật.

- [x] Ghi: khuyên gì, ngày nào, đo bằng số nào, số lúc đầu. (nháp, chưa áp)
- [x] Sau khoảng 2 tuần tự đọc số, báo lại và hỏi chủ quán có làm không. (nháp, chưa áp)
- [ ] Không kết luận từ một quán, một lần; loại trừ thời tiết, mùa, ngày lễ khi so.
- [ ] Số gộp giữa các quán phải ẩn danh, có chính sách rõ với chủ quán.
- [ ] Bài học mới phải có người duyệt, không cho AI tự sửa luật của mình.

## Giai đoạn 6: Thử công cụ và sổ tay

**Kết quả thử 07/11 (thử nghiệm, KHÔNG đổi Boom đang chạy; chưa commit):**
- Sổ tay `supabase/functions/boom-chat/so_tay.ts`: 14 bài (học sinh, văn phòng, khu dân cư, chợ / công trình, quán ít đơn, đơn tụt, giờ vắng, giữ khách, giá trị đơn, mã giảm, mang về / sàn, ngày lễ, bài đăng, cuối tuần), chọn tối đa 2 bài theo câu hỏi rồi hồ sơ; kiểm thử 2/2.
- So 3 cách trên 8 câu tiếp thị của bộ QC × 2 lượt, cả 3 đều có hồ sơ quán (`tool/boom_do/giai_doan_6/thu_3_cach.ts`), một người chấm mù xếp hạng cả 3:

| Cách | Điểm TB /16 | Dùng được / tạm / hỏng | Thời gian trung vị | Chữ tốn TB |
|---|---|---|---|---|
| A: đang chạy | 11,81 | 6 / 7 / 3 | 5,1 giây | 20.051 |
| B: A + sổ tay | 12,38 (B − A = +0,56 ± 1,39) | 9 / 6 / 1 | 8,2 giây | 21.741 |
| C: tự gọi công cụ | 10,62 (C − A = −1,19 ± 2,15) | 8 / 5 / 3 | 6,2 giây | 28.108 (+40%) |

- **C thua: bỏ, không chuyển sang công cụ** (đúng điều đã ghi "thua thì bỏ"). C còn 1/16 câu rỗng vì gọi công cụ hết 5 lượt; tìm vấn đề tụt 1,00 → 0,69 vì chỉ thấy phần số tự xin.
- **B nhỉnh hơn nhưng chưa chắc**: khoảng tin cậy chứa 0, chỉ 16 cặp. Đúng quán 1,12 → 1,38, hỏng 3 → 1. Thời gian trung bình của B bị kéo lên bởi một lượt chờ OpenAI 1.546 giây (lỗi mạng / hàng chờ), trung vị 8,2 giây.
- Người chấm: cả 3 cách vẫn chép khung việc tính sẵn mà không xét khách là ai (ưu đãi học sinh lúc các em đang học), bỏ sót điểm đáng tiền nhất trong khối (Thứ 4 yếu, chiết khấu sàn tăng), gợi ý 2 mã chồng nhau.
- **Đo thêm 08/11** (`tool/boom_do/giai_doan_6/do_so_tay.ts`, kết quả ở `do_them/`): A đang chạy vs B thêm sổ tay, cả hai có hồ sơ quán, 2 lượt, chấm mù.
  - Bộ QC 32 câu, mọi loại: +0,23 ± 0,36 (64 cặp). Riêng **tiếp thị +1,25 ± 0,58 (16 cặp, rõ)**; giá món −0,62 ± 1,04, phân tích −0,30 ± 1,10, còn lại quanh 0.
  - Bộ cũ + bộ kín 60 câu: +0,03 ± 0,32 (120 cặp); bộ cũ −0,15 ± 0,37, bộ kín +0,38 ± 0,61; so sánh +1,00, kế hoạch −0,31, dự báo −0,27, chẩn đoán −0,17 (đều chứa 0).
  - Lần đo này sổ tay mở bài cho MỌI câu vì chọn cả theo hồ sơ quán. Kết luận: sổ tay giúp rõ ở câu tiếp thị, không giúp (có thể hơi hại) ở câu khác.
  - **Đề xuất:** chỉ mở sổ tay khi CÂU HỎI là câu tiếp thị (khớp bài theo câu hỏi), không mở theo hồ sơ cho câu khác; câu không khớp thì lời nhắc giống hệt bản đang chạy nên không thể tụt. Cần đo lại riêng câu tiếp thị với cách chọn này trước khi áp.
- **Đo lại 08/11 với cách chọn mới** (chỉ câu tiếp thị; sửa từ khoá bỏ dấu lọt nhau như "hẻm" trong "thêm", "sàn" trong "sáng"): sổ tay mở cho 21/92 câu (QC 12/32, bộ cũ 5/40, bộ kín 4/20); 71 câu còn lại lời nhắc giống hệt bản đang chạy. 3 lượt, một người chấm mù, 63 cặp: **+0,48 ± 0,42** (khoảng không chứa 0); QC +0,47, bộ cũ +0,67, bộ kín +0,25; không nhóm nào âm. Việc làm 1,46 → 1,63, đúng quán 1,84 → 1,95.
- Đã nối vào `index.ts` sau công tắc `BOOM_SO_TAY=1` (mặc định tắt); hồ sơ để chọn bài lấy từ bộ nhớ quán (bộ nhớ tắt thì chỉ chọn theo câu hỏi). Phép đo trên giả định có hồ sơ quán; khi bộ nhớ tắt, bài vị trí / khách chính sẽ ít được mở hơn, chưa đo riêng trường hợp đó.
- **Bật 09/11 (lần 160):** `BOOM_SO_TAY=1` trong tệp bí mật (sao lưu `boom-ai.env.truoc_so_tay_20261109_032134`). Web Demo: câu "quán gần trường, kéo thêm học sinh" có nhãn `+so_tay`; câu "doanh thu bao nhiêu" không. Tắt: xoá dòng rồi tạo lại container functions.

## Đo 09/11: Boom đã thông minh hơn chưa

**Thử 12 câu trên web Demo qua máy chủ thật (lần 161, sổ tay + thời tiết bật, Demo bỏ qua bộ nhớ):**
- Đúng như mong đợi: hỏi buổi chiều thì trả lời buổi chiều trước; ưu đãi theo giờ có câu "dặn nhân viên áp tay"; mưa dùng dự báo, không khuyên nhập nhiều chỉ vì dự báo, có ghi nguồn; sáng quá tải thì không kéo thêm khách; sổ tay mở đúng câu tiếp thị.
- Lỗi thấy (chưa sửa):
  1. Đầu kỳ ít số: ngày 9 trong tháng chỉ 12 đơn, máy vẫn dùng "tháng này" → khuyên tăng giá dựa trên 5 ly, mã giảm không có số, mua tặng "chưa đủ dữ liệu". Nên lấy kỳ dài hơn (30 ngày qua) khi kỳ mặc định quá ít đơn và câu hỏi không nói kỳ.
  2. "Tuần này so với tuần trước" đầu tuần: so với đúng số ngày tuần trước (chỉ Thứ 2) → "chưa có số tuần trước"; nên nêu cả tuần trước.
  3. "Trong 30 ngày tới" đọc thành "tháng này"; kế hoạch tương lai nên dựa trên 30 ngày qua.
  4. Mua 1 tặng 1 một món có giá vốn riêng: phép tính dùng tỉ lệ nguyên liệu cả quán, không dùng giá vốn món (trà đào 35.000đ / 12.000đ → phải bán gấp ~4,2 lần).
  5. Mã giảm khi kỳ ít đơn: phép tính ngưỡng bị tắt nên không có số; chỉ cần giá trị đơn trung bình.
  6. Bài đăng Facebook bị gắn "Số trên là của tháng này…" ở cuối.
  7. "Tuần này" (câu so số) mở thời tiết vì HOI_THOI_TIET có "tuần này".
  8. "Em nhớ gì về quán" khi quán không dùng bộ nhớ: Boom nói "đang nhớ" rồi kể số bán hàng như trí nhớ.
  9. Mời thêm món 55.000đ cho khách gọi ly trà; vẫn khuyên tăng giá khi đơn giảm 96% (kỳ ít đơn).
  10. Lần gọi đầu sau khi tạo lại hàm, 4 câu cùng lúc: 1 câu 500 "worker did not respond in time" (khởi động chậm, gọi lại được).

**Chấm mù A/B 09/11** (`tool/boom_do/do_09_11/`: `do.ts`, `tron.py`, `tong.py`; bộ mới `cau_moi.json` do trợ lý khác viết). A = lần 151 (f53ccb9), B = lần 161 (sổ tay bật), cả hai chạy như máy chủ (viết lại 1 lần, B có ghiApTay), không hồ sơ quán, 2 lượt/câu, 8 người chấm, 168 cặp:

| Bộ | n | Cũ /16 | Mới /16 | Mới − cũ | Dùng được / tạm / hỏng (cũ → mới) |
|---|---|---|---|---|---|
| QC 07/11 (đã sửa theo bộ này) | 64 | 13,27 | 13,53 | +0,27 ± 0,45 | 42/21/1 → 47/17/0 |
| Mới (chưa từng thấy) | 64 | 12,22 | 12,50 | +0,28 ± 0,55 | 29/31/4 → 34/27/3 |
| Kín | 40 | 13,00 | 12,53 | −0,47 ± 0,68 | 23/17/0 → 16/22/2 |
| Tất cả | 168 | 12,80 | 12,90 | +0,10 ± 0,32 | |

- Kết luận: CHƯA thấy khá lên rõ. Bộ QC và bộ mới nhích lên (khoảng tin cậy chứa 0); bộ kín tụt (chứa 0, nhưng dùng được 23 → 16). Theo loại: số liệu +0,85, tiếp thị +0,53, khác +1,00; quyết định −0,21, so sánh −1,00, kế hoạch −1,67 (n nhỏ).
- Theo tiêu chí: việc làm 1,36 → 1,50 (khá lên); tìm vấn đề 1,25 → 1,26 và lý lẽ 1,24 → 1,25 vẫn thấp nhất, cả hai bản.
- Người chấm (cả hai bản): bỏ sót điểm đắt nhất đã có trong khối số (món lời nhất theo tiền lời chứ không theo bán chạy, mua 1 tặng 1 lỗ ngay mỗi đơn khi 2 phần giá vốn > giá bán, lời trên sàn với giá vốn đã có, Thứ 4 tụt riêng, mã đang chạy, hao hụt); không đối chiếu giá chủ quán nói với giá menu (20k vs 25k); hay dừng ở "chưa có số" thay vì tự tính phép nhỏ; chèn số lạc đề làm dài.
- Giới hạn: bộ đo cho mọi câu số "tháng này" nên câu "trưa nay / hôm qua" bị chấm sai số do cách đo, không phải lỗi máy chủ (máy chủ đọc kỳ riêng). Khối số đưa người chấm là của bản cũ (có lỗi Thứ 4 hai số đã sửa ở lần 154).

### Lô dạy 5 lần (09/11, chưa áp)
1. Kỳ: câu không nêu kỳ mà "tháng này" < 30 đơn → `hoi.ts` đọc lại 30 ngày qua (`ky30Ngay`); "30 ngày tới / tháng tới / sắp tới" → 30 ngày qua; "tuần này so tuần trước" khi kỳ chạy chưa trọn 1 ngày → so trọn tuần trước (không áp cho kỳ ngày).
2. Tiền lời: dòng "XẾP MÓN THEO TIỀN LỜI" (lời mỗi phần, % giá vốn, tiền lời cả kỳ) khi hỏi lời nhất / lời hơn / đáng đẩy; dòng "BÁN QUA SÀN" (phí sàn theo câu hỏi, không có thì giả sử 25–30%).
3. Mua tặng theo giá vốn của đúng món (lỗ mỗi lượt hoặc phải bán gấp bao nhiêu); mã kiểm `muaTangChuaDung` nhận cả số của phép tính theo món.
4. `giaKhacMenu`: giá chủ quán nói khác giá menu → nói ra, tính theo menu, hỏi lại. `monKhop` khớp tên món gọi tắt ("ca phe sua", "bún bò", "cơm tấm").
5. Bài đăng không gắn câu ghi kỳ; "tuần này" không lấy thời tiết; hỏi "nhớ gì" khi quán không dùng bộ nhớ → nói thẳng chưa có bộ nhớ riêng.
- Đo lô (bản 161 vs lô, bộ mới + kín, 104 cặp, 5 người chấm; khối số liệu đưa người chấm lấy của bản MỚI — lần đo 151/161 trước lấy khối bản cũ, có thể đã trừ oan bản 161 khi dẫn số dòng mới): tổng +0,03 ± 0,40; giá món +2,12 ± 1,90 (câu bật dòng mới: M22 +7/+4, M21 +4); so sánh (kín) −2,17 ± 1,18 — K18 −4/−3 do dòng xếp món ghi "lời nhiều nhất cả kỳ" như đáp án → Boom kết luận "lời hơn" theo tổng tiền. Đã sửa: "món lời hơn" = lời mỗi phần, câu so đúng 2 món không bật dòng xếp. Phần 1 (kỳ) và 5 (nhớ gì) bộ đo không chạm tới (bộ đo luôn đưa số tháng này đủ đơn).
- Người chấm vẫn thấy: khối số có Thứ 4 hai trung bình khác nhau khi không có số từng ngày (lần 154 chỉ sửa khi có by_day); "trưa nay / hôm qua" bộ đo đưa số cả kỳ (giới hạn bộ đo).
- Đo lại riêng 14 câu có dòng tính sẵn mới (QC + mới + kín), sau khi sửa dòng xếp món, 3 lượt/câu, 42 cặp, 2 người chấm: +0,62 ± 0,63; kín +2,33 (K18 hết tụt); tìm vấn đề 1,12 → 1,48, lý lẽ 1,24 → 1,33, trả lời thẳng 1,62 → 1,76. Câu không có dòng mới: lời nhắc giống hệt bản 161.
- Sửa thêm sau đo: `boQuaGiaMenu` (có dòng giá khác menu mà câu trả lời không nhắc giá menu → viết lại); thứ của hôm nay khi KHÔNG có số từng ngày: dòng so kỳ trước chia đủ n như bảng theo thứ (hết Thứ 4 hai số). Test 150/150.
- **Đã áp lần 162 (a2844b2, 09/11 12:02).** Thử web Demo: tăng giá cà phê dùng 30 ngày qua (395 đơn) thay 12 đơn; "30 ngày tới" dùng 30 ngày qua, việc theo tuần; mua 1 tặng 1 trà đào: còn 11.000đ/lượt so 23.000đ, gấp 2,1 lần; "nhớ gì" nói thẳng chưa ghi nhớ; bài đăng không còn câu kỳ. Lỗi mới: "tuần này so tuần trước" lúc Thứ 2 trưa 0 đơn → "giảm 100%" và khuyên ẩn hết món chưa bán. Đã sửa (kỳ tuần / tháng đang chạy chưa có đơn → trả lời ngắn như ngày không đơn), test 151/151, chưa commit, chưa áp.
- Áp lần 163 (a5081fe): chỉ lời nhắc → Boom vẫn "giảm 100%" + đủ mục (hết khuyên ẩn món). Áp lần 164 (29102a0, 09/11 12:12): mã kiểm `kyKhongDonDai` + chốt `gonKhiKhongDon`. Web Demo: "Tuần này so với tuần trước" → 1 câu: chưa có đơn tới giờ này, tuần trước 80.000đ/ngày, hỏi đã mở bán chưa. Câu "30 ngày qua bán thế nào" vẫn đủ mục.

### Đo lại 09/11 chiều: lần 151 vs lần 164 (đang chạy)
Khối số đưa người chấm lấy của bản mới (sửa lỗi lần đo trước). Bộ: mới (09/11), mới thứ hai (`cau_moi2.json`, trợ lý khác viết, chưa dùng để dạy, không hỏi số hôm nay / hôm qua), kín. 168 cặp, 8 người chấm, cùng một lượt.

| Bộ | n | Cũ | Mới | Mới − cũ | Dùng được / tạm / hỏng (cũ → mới) |
|---|---|---|---|---|---|
| Mới 09/11 | 64 | 11,78 | 12,52 | +0,73 ± 0,48 | 25/33/6 → 35/27/2 |
| Mới thứ hai | 64 | 12,64 | 13,09 | +0,45 ± 0,54 | 35/25/4 → 37/24/3 |
| Kín | 40 | 12,70 | 12,85 | +0,15 ± 0,56 | 23/14/3 → 18/22/0 |
| Tất cả | 168 | 12,33 | 12,82 | **+0,49 ± 0,30** | |

- Kết luận: Boom ĐÃ khá lên, khoảng tin cậy không chứa 0. Rõ nhất: giá món +1,88 ± 0,86, quyết định +1,04 ± 0,91, so sánh +1,83 ± 1,38. Tụt (n nhỏ, chưa chắc): kế hoạch −1,50 ± 1,41, chẩn đoán −0,83 ± 0,94. Tiếp thị chỉ +0,09.
- Tiêu chí: trả lời thẳng 1,65 → 1,75, tìm vấn đề 1,12 → 1,27, đúng số 1,78 → 1,84; lý lẽ vẫn thấp nhất (1,23).
- Người chấm vẫn thấy (cả hai bản): né phép tính then chốt dù đủ số (hoà vốn thuê quầy / quảng cáo / thuê người, giá cần đặt trên sàn = giá ÷ (1 − phí), tiền mất khi giảm % giờ cuối), gán số một giờ cho cả khung giờ, chèn số lạc đề (thu − chi, mã giảm), bỏ sót ý thực tế (thu tiền gói ăn trước, 3 người không chia nổi 2 điểm, bún nước giao xa).
- Sửa sau đo (chưa commit, chưa áp): giá khác menu nhận chữ chen "mình đang bán 25k"; thứ của hôm nay khi không có số từng ngày: mọi dòng chia n−1 (lần 162 làm bảng chia n còn dòng "MỚI tụt" chia n−1 → Thứ 4 −19,9% và −39,9%). Test 153/153.
