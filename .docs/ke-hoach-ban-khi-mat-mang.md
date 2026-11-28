# Kế hoạch: Bán khi mất mạng

> Lập 23/11/2026 theo câu hỏi của Chủ Quán: "làm sao để máy vẫn dùng được khi không có mạng". Mới khảo sát và lập kế hoạch. **Chưa sửa mã, chưa đổi gì trên máy chủ. Chờ Chủ Quán chọn phạm vi.**

Trả lời ngắn: làm được ở mức **bán nhanh tại quầy trên một máy cài app**, đơn nằm chờ trong máy rồi tự gửi lên khi có mạng lại. Bàn, bếp trên màn hình, nhiều máy thấy nhau, ví khách, báo cáo thì chưa làm được khi mất mạng nếu không xây lại phần lớn app. Cách rẻ và nhanh nhất để quán không đứng hình vẫn là **cục phát 4G dự phòng**, nên làm trước dù chọn phạm vi nào.

## 1. Hiện trạng (đã kiểm trên mã và máy chủ ngày 23/11)

### Kho dữ liệu trong máy có khung nhưng không ai dùng
- `lib/core/database/app_database.dart` khai báo 27 bảng trong máy (đơn, món của đơn, phiên bàn, phiếu bếp, hàng chờ sự kiện...). Đây là Drift, tức kho dữ liệu SQLite nằm ngay trong máy.
- Không chỗ nào trong app mở kho này: `AppDatabase()` không được gọi ở đâu, `AppEventBus` (nơi duy nhất ghi vào `PendingEvents`) cũng không được tạo. `app_providers.dart` ghi rõ "100% Supabase, không còn AppDatabase".
- Bản web không kèm tệp chạy SQLite, nên kho này trên web chưa chạy được.
- Kết luận: các bảng đó là khung cũ để lại, **không phải chế độ mất mạng làm dở**.

### Mọi màn đọc ghi thẳng lên máy chủ
| Màn | Khi mất mạng | Vì sao |
|---|---|---|
| Bán hàng (quầy) | Thấy thực đơn nếu app đang mở sẵn. Tắt mở lại app thì thực đơn trống. Bấm thanh toán là lỗi. | Thực đơn chỉ giữ trong bộ nhớ tạm. Thanh toán gọi hàm máy chủ `complete_pos_sale_v1`. |
| Sau một lần thanh toán lỗi mạng | **Không bán tiếp được đơn khác** | Máy chỉ giữ được đúng 1 đơn "chưa rõ kết quả" (`PosSaleOperationManager`), phải đối soát xong mới cho tạo đơn mới. |
| Quản lý bàn | Chết | `ban_repository.dart` đọc ghi thẳng máy chủ, gửi bếp gọi `send_kitchen_ticket_v2`. |
| Phiếu bếp trên màn hình | Chết | Đọc máy chủ, nhận phiếu mới qua kênh trực tiếp của máy chủ. |
| Máy chủ in tự in phiếu bếp | Chết | Nghe phiếu mới từ máy chủ rồi mới in. |
| Kho, Thu Chi, Báo cáo, Khách và ví, QR gọi món, Chấm công, Lương, Boom | Chết | Toàn bộ nằm trên máy chủ. |
| Web /pos | Đang mở thì còn nhìn được, tải lại trang là trắng | `web/index.html` chủ động gỡ phần lưu trang để dùng ngoại tuyến (tránh kẹt bản cũ). |

### Cái đã chạy được khi mất mạng
- **Mở app:** sau JWT Pha 2, app cài máy mở được, cứ 20 giây thử xin lại vé đăng nhập (`PosJwtAuthService.waitingForRefresh`), có mạng lại thì báo các màn nạp lại (`jwtRecovered`).
- **In bill và phiếu bếp từ chính máy bán:** app cài máy gửi thẳng tới máy in trong mạng nội bộ (cổng 9100) hoặc máy in liền thân Sunmi. Mẫu bill, cấu hình máy in, tên quán đều có bản lưu trong máy. Mạng nội bộ còn chạy khi mất internet, miễn là cục phát wifi còn điện.
- **Web không in thẳng ra máy in mạng được**, chỉ mở hộp in của trình duyệt.

### Gửi lại đơn có bị nhân đôi không
Không. Đã kiểm hàm đang chạy trên máy chủ, khớp với `supabase/migrations/20261008_fix09_quy_doi_don_vi_cong_thuc.sql`:
- Mỗi đơn mang một mã chống trùng do máy tạo. Máy chủ khoá theo mã đó, có chỉ mục duy nhất `(quán, mã)` trên bảng `pos_idempotency_operations`.
- Gửi lại cùng mã, cùng giỏ: trả đúng đơn cũ (`is_replay`), không tạo đơn mới, không trừ kho lần hai.
- Cùng mã mà giỏ khác: từ chối (`IDEMPOTENCY_CONFLICT`).
- 30 ngày qua hàm này đã ghi khoảng 3.500 đơn theo cách đó.

Hai điểm của hàm hiện tại không hợp với đơn gửi trễ:
1. **Giờ của đơn là giờ máy chủ nhận**, không phải giờ bán. Mất mạng 1 tiếng thì cả loạt đơn dồn vào một phút. Mất mạng qua nửa đêm thì doanh thu rơi sang ngày hôm sau.
2. **Giá khác giá máy chủ là bị từ chối** (`FINANCIAL_QUOTE_CHANGED`). Nếu chủ quán đổi giá lúc máy quầy đang mất mạng, đơn đã thu tiền sẽ không gửi lên được.

Số đơn trong ngày (QN-001...) do máy chủ cấp lúc nhận đơn, nên **không thể trùng**, nhưng máy không biết trước số đó để in lên bill.

### Số liệu thật 30 ngày (chỉ đọc)
- Đơn bán tại quầy: khoảng 3.500 đơn ở **25 quán**. Đơn theo bàn: khoảng 3.100 đơn ở **5 quán**.
- Tiền mặt khoảng 76%, chuyển khoản 22%, thẻ 1%, ví 17 đơn.
- Đơn có gắn khách (tích điểm, ví): **0**. Đơn có giảm giá: khoảng 7%.
- Máy dùng app 14 ngày qua: **web 52**, iPhone/iPad 35, Android 15, Windows 3.

Ý nghĩa: bán tại quầy là phần nhiều quán dùng nhất. Ví và điểm gần như chưa ai dùng, chặn lúc mất mạng không thiệt gì. Một nửa số máy đang dùng web, là nền khó làm mất mạng nhất.

## 2. Các phương án

### A. Cục phát 4G dự phòng (không sửa app)
Cục phát wifi có khe SIM, hoặc loại tự chuyển sang 4G khi dây mạng rớt.
- **Được:** mọi thứ chạy như thường, cả bàn, bếp, nhiều máy, web, QR gọi món.
- **Không cứu:** mất điện (cần thêm bộ lưu điện cho cục phát), hoặc máy chủ Quán Nhỏ gặp sự cố.
- **Công:** không sửa mã. Mỗi quán tự mua và cắm. Ước chừng 1 đến 2,5 triệu tiền máy và 50 đến 100 nghìn một tháng tiền SIM (giá ước lượng, cần hỏi lại lúc mua).
- **Việc của mình:** viết một bài hướng dẫn cho chủ quán, cho Boom biết để chỉ.
- Vụ Bò Đen tối 12/11 (mạng cố định quán rớt 19:56 đến 20:59) thuộc đúng loại này.

### B1. Bán nhanh ở quầy khi mất mạng, không đổi máy chủ (đề xuất làm đầu tiên trong app)
Chỉ app cài máy (Android/Sunmi, Windows, iPhone/iPad), một máy, bán tại quầy.

Cách chạy:
1. Thực đơn và giá được lưu thêm xuống máy mỗi lần tải thành công. Mở app lúc mất mạng vẫn có thực đơn, kèm dòng "Thực đơn cập nhật lúc ...".
2. Bấm thanh toán mà không tới được máy chủ sau vài giây: app hỏi "Lưu đơn, bán tiếp". Đơn vào **hàng chờ trong máy** cùng mã chống trùng của nó.
3. Bill in ngay, mang **mã tạm của máy** (ví dụ `T2-014`, T2 là máy, 014 là số thứ tự trong máy) và dòng "Đơn lưu trong máy, chưa gửi lên hệ thống". Phiếu bếp và tem ly in thẳng từ máy bán như hiện nay.
4. Có mạng lại (`jwtRecovered`): app gửi lần lượt từng đơn qua đúng hàm `complete_pos_sale_v1` với mã chống trùng đã lưu. Xong đơn nào xoá đơn đó khỏi hàng chờ. Mã tạm ghi vào ghi chú của đơn để tra lại.
5. Màn bán hàng có dải "Đang mất mạng, còn N đơn chờ gửi, tổng X đồng" và danh sách "Đơn chờ gửi". Đơn bị máy chủ từ chối nằm ở mục "Cần xử lý", không bao giờ tự xoá.

Cách làm gọn: **không dựng lại kho Drift**. Mở rộng chỗ đang giữ 1 đơn chờ đối soát (`PosSaleOperationManager`, lưu bằng bộ nhớ cài đặt của máy) thành một danh sách. Đủ cho vài trăm đơn. Khi nào cần bàn hoặc cả nghìn đơn mới tính tới Drift.

Giới hạn chấp nhận ở B1:
- Giờ của đơn là giờ gửi lên. Giờ bán thật nằm trong ghi chú. Báo cáo theo giờ sẽ dồn cục, mất mạng qua nửa đêm thì lệch ngày.
- Chủ quán đổi giá đúng lúc máy quầy mất mạng thì các đơn món đó vào mục "Cần xử lý".

Ước lượng: 3 đến 4 buổi làm, cộng 1 buổi thử thật ở quán (rút dây mạng). Phải phát hành app mới trên cả 3 nền, iPhone/iPad chờ Apple duyệt.

### B2. Thêm giờ bán thật và nhận giá đã bán (cần đổi máy chủ)
Thêm một hàm máy chủ mới cho đơn bán lúc mất mạng, hàm cũ giữ nguyên cho app cũ:
- Nhận giờ bán thật từ máy, có chặn (không ở tương lai, không cũ quá 72 giờ). Đơn, thu chi, kho ghi theo giờ đó.
- Giá đã bán khác giá hiện tại: vẫn ghi theo giá đã thu, đánh dấu để chủ quán xem lại.
- Có cột riêng cho mã tạm, tra bill giấy ra đơn ngay.

Ước lượng: thêm 1 đến 2 buổi, một lần đổi máy chủ có bản hoàn tác và bộ test, phải chạy thử trên bản sao trước. Nên làm sau khi B1 chạy thật vài tuần và thấy có cần.

### C. Thêm bản web
- Phải bật lại phần lưu trang để mở được khi mất mạng. Phần này từng bị gỡ có chủ ý, bật lại dễ gặp cảnh máy quán kẹt bản cũ sau mỗi lần phát hành.
- Web không in thẳng ra máy in mạng, lúc mất mạng chỉ in qua hộp in của trình duyệt.
- Xoá dữ liệu trình duyệt là mất hàng chờ, tức mất đơn đã thu tiền.

Ước lượng: thêm 3 đến 5 buổi, rủi ro cao. **Không đề xuất.** Quán dùng web nên chọn A, hoặc cài app cho máy quầy.

### D. Mất mạng đầy đủ (bàn, bếp, nhiều máy thấy nhau)
Cần một máy trong quán làm "máy chủ nhỏ" để các máy nói chuyện qua mạng nội bộ, và cơ chế gộp dữ liệu hai chiều khi có mạng lại. Tính bằng nhiều tuần đến vài tháng, đụng toàn bộ luồng Bàn, Bếp, Thanh toán. Quy trình dự án cũng ghi phần này làm sau. **Không đề xuất lúc này.**

## 3. Không cho làm khi mất mạng (áp cho B1, B2)
| Việc | Lý do |
|---|---|
| Ví khách, nạp ví, đổi điểm | Số dư nằm trên máy chủ. Máy không biết số thật, dễ tiêu hai lần. |
| Mã giảm giá | Hạn dùng, lượt dùng, mức tối thiểu do máy chủ kiểm. |
| Giảm giá tay | Quyền giảm giá do máy chủ kiểm. Nếu bị từ chối thì tiền đã thu rồi. (Có thể mở sau cho chủ quán, quản lý nếu Chủ Quán muốn.) |
| Gắn khách vào đơn | Điểm cộng theo số dư trên máy chủ. |
| Bàn, gộp bàn, chuyển bàn, thanh toán bàn | Bàn là dữ liệu chung nhiều máy. Hai máy không thấy nhau sẽ mở trùng bàn, thu trùng tiền. |
| Gửi bếp lên màn hình bếp | Màn hình bếp nhận phiếu qua máy chủ. Lúc mất mạng chỉ có phiếu giấy in từ máy bán. |
| QR gọi món | Điện thoại khách phải tới được máy chủ. |
| Huỷ đơn, hoàn tiền, sửa đơn đã thu | Cần duyệt và ghi sổ trên máy chủ. |
| Kho (nhập, kiểm kê, huỷ hàng), Thu Chi | Số tồn và quỹ là của chung. Sửa trên số cũ sẽ lệch. |
| Báo cáo, Lương, Chấm công, Boom | Số liệu trên máy chủ. Không gấp trong lúc mất mạng. |
| Sửa thực đơn, giá, nhân viên, quyền | Tránh hai nơi sửa khác nhau. |
| Hoá đơn điện tử | Xuất sau khi đơn đã lên máy chủ. |
| Chuyển khoản | Cho ghi "khách đã chuyển khoản" theo xác nhận bằng mắt của thu ngân. Mã QR có số tiền đang lấy ảnh từ mạng nên lúc mất mạng không hiện được, quán dùng mã QR in sẵn. |

## 4. Rủi ro và cách chặn
| Rủi ro | Cách chặn |
|---|---|
| **Trùng số thứ tự đơn trong ngày** | Số chính thức vẫn do máy chủ cấp lúc nhận, không trùng được. Bill lúc mất mạng dùng dãy mã tạm riêng theo từng máy. Hệ quả: số chính thức không theo đúng thứ tự giờ bán. |
| **Nhiều máy cùng quán không thấy nhau** | Lúc mất mạng chỉ bán tại quầy, khoá màn Bàn. Mỗi máy có hàng chờ riêng, mã tạm riêng. Máy này không thấy đơn chờ của máy kia cho tới khi gửi lên. |
| **Tồn kho lệch** | Kho chỉ trừ khi đơn lên máy chủ. Trong lúc chờ, số tồn trên các máy khác cao hơn thật, có thể bán quá số còn. Quy tắc hiện có là thiếu tồn chỉ cảnh báo nên không chặn bán. Nhắc "còn đơn chờ gửi" trước khi kiểm kê. |
| **Giá, thực đơn cũ trong máy** | Hiện giờ cập nhật thực đơn. Bản lưu cũ quá 7 ngày thì không cho bán khi mất mạng. Món đã tắt bán hay đổi giá trong lúc đó: B1 đưa vào "Cần xử lý", B2 ghi theo giá đã thu và đánh dấu. |
| **Đóng ca, đăng xuất, đổi quán khi còn đơn chưa gửi** | Chặn đăng xuất và đổi quán khi hàng chờ còn đơn (chủ quán, quản lý mới bỏ qua được, có ghi lại). Thẻ bàn giao ca hiện "còn N đơn chưa gửi, tổng X đồng". Đơn gửi lên dưới đúng tài khoản đã bán. |
| **Máy hỏng, mất, gỡ app khi còn đơn chờ** | Đơn chưa gửi sẽ mất. Bill giấy là bằng chứng để nhập lại tay. Giới hạn hàng chờ (đề xuất 200 đơn hoặc 24 giờ), tới ngưỡng thì dừng bán và báo chủ quán. |
| **Gửi lại bị nhân đôi** | Mã chống trùng lưu xuống máy trước khi in bill, không bao giờ tạo lại. Máy chủ đã chống trùng theo mã (đã kiểm). |
| **Mất mạng ngay lúc đang gửi** | Không biết máy chủ đã nhận chưa. Đơn vẫn vào hàng chờ với đúng mã cũ, gửi lại thì máy chủ trả đơn đã ghi. |
| **Giờ máy sai** | B1 không phụ thuộc giờ máy. B2 có chặn giờ ở máy chủ. |
| **Quyền bị thu, quán bị khoá trong lúc mất mạng** | Máy chủ từ chối lúc gửi. Đơn vào "Cần xử lý" cho chủ quán quyết. |
| **Thu ngân tưởng đã lên hệ thống** | Dải báo luôn hiện khi còn đơn chờ. Bill in rõ "chưa gửi lên hệ thống". |

## 5. Thứ tự đề xuất
1. **A:** viết hướng dẫn cục phát 4G dự phòng cho chủ quán (không sửa mã).
2. **B1:** bán nhanh ở quầy khi mất mạng trên app cài máy, không đổi máy chủ.
3. **B2:** chỉ làm nếu sau vài tuần thấy giờ đơn dồn cục hoặc đơn kẹt vì đổi giá là vấn đề thật.
4. C, D: để lại.

## 6. Việc cần Chủ Quán quyết
1. Chọn phạm vi: chỉ A, hay A + B1, hay A + B1 + B2.
2. Lúc mất mạng có cho ghi "khách đã chuyển khoản" không, hay chỉ tiền mặt.
3. Giảm giá tay lúc mất mạng: chặn hẳn, hay cho chủ quán và quản lý.
4. Ngưỡng dừng bán: 200 đơn hoặc 24 giờ có hợp không.

## 7. Thử thật trên Sunmi Bò Đen, 23/11 12:45 (app 1.0.8 build 38, tắt wifi, điều khiển qua cáp)
Chỉ xem màn hình, không bấm Thanh toán, Mở bàn, Gửi bếp vì là quán thật.
| Màn | App đang mở sẵn | Tắt hẳn app rồi mở lại |
|---|---|---|
| Trang chủ | Vẫn ghi "Sẵn sàng", doanh thu 0 đ | Mở được, còn đăng nhập, vẫn ghi "Sẵn sàng" |
| Bán hàng | Còn thực đơn, thêm món vào giỏ được, ghi "Bếp sẵn sàng" | **"Chưa có sản phẩm nào. Bấm nút bên dưới để thêm sản phẩm đầu tiên"** |
| Quản lý bàn | Quay vòng mãi (hơn 20 giây), không báo gì | chưa xem |
| Bếp | "Bếp đang yên tĩnh. Chưa có phiếu bếp nào" | chưa xem |
| Kho | Còn danh sách hàng đã tải | chưa xem |
| Báo cáo | Hôm nay 0 đ, **tháng 11 0 đ**, không báo lỗi | chưa xem |

Điều đáng lo hơn cả việc không bán được: **app không nói là đang mất mạng**. Nó hiện số 0 và màn trống như thể quán chưa có gì. Nhân viên có thể tưởng mất thực đơn rồi bấm thêm món mới. Việc nhỏ nên làm trước mọi phương án: một dải "Đang mất mạng" và thay các màn trống, số 0 bằng câu "Chưa tải được, đang chờ mạng".

**Bật lại wifi lúc 12:51, không khởi động lại app:** mở Bán hàng có lại thực đơn, Quản lý bàn có lại khu vực và bàn, Báo cáo tháng 11 hiện lại số thật, không còn lỗi trong nhật ký máy. Không phải đăng nhập lại. Chưa tách được màn tự nạp lại hay nạp vì vừa được mở.

### Dải báo "Đang mất mạng" (Chủ Quán duyệt làm 23/11; commit `7675653`, ĐÃ CÀI SUNMI BÒ ĐEN 23/11 13:04, CHƯA PHÁT HÀNH)
- `lib/core/services/net_status.dart`: nhận biết mất mạng từ chính các yêu cầu app gửi lên máy chủ, không thêm thư viện. Một yêu cầu hỏng thì 2 giây sau hỏi thử máy chủ, hỏng tiếp mới bật dải, rồi hỏi lại mỗi 10 giây. Có yêu cầu nào thành công là tắt dải ngay.
- `JwtGateHttpClient` (nơi mọi yêu cầu Supabase đi qua) báo hỏng / thông vào đó.
- `lib/core/widgets/net_status_banner.dart`: dải đỏ "Đang mất mạng. Số liệu có thể thiếu." trên mọi màn, gắn ở `MaterialApp.builder`.
- Màn Bán hàng lúc mất mạng mà chưa có thực đơn: ghi "Chưa tải được thực đơn", bỏ nút "Thêm sản phẩm mới".
- Test `test/core/net_status_test.dart` (6 test). Ảnh xem thử `scratch/mat_mang_bat.png`.
- Chưa làm: chip "Sẵn sàng" ở Trang chủ, số 0 ở Báo cáo, câu "Bếp đang yên tĩnh", vòng quay ở Quản lý bàn vẫn như cũ (đã có dải đỏ phía trên nói rõ).
- Thử thật trên Sunmi 23/11 13:04–13:09: có mạng không hiện dải nhầm; tắt wifi hiện dải đỏ một dòng; mở lại app lúc mất mạng thì Bán hàng ghi "Chưa tải được thực đơn"; bật wifi lại, không bấm gì, dải tự tắt và thực đơn tự hiện trong dưới 1 phút.

## 8. Chưa kiểm
- Chưa bấm Thanh toán lúc mất mạng trên máy thật (quán thật, cần Chủ Quán cho phép).
- Chưa đo app chờ bao lâu mới báo lỗi khi bấm thanh toán lúc mất mạng.
- Chưa kiểm quán đang bật "máy chủ in" trên máy khác thì máy bán có tự in phiếu bếp được không. Mã hiện tại chỉ cho máy bán tự in khi quán không dùng máy chủ in, hoặc máy đó được chỉ định in thay.
- Chưa thử bộ nhớ cài đặt của máy giữ được bao nhiêu đơn trên Sunmi đời cũ.
