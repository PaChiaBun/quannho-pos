---
module: ho_tro
ten: Hỗ trợ kỹ thuật
phien_ban: 1.0.6+24
cap_nhat: 2026-11-04
nguon:
  - lib/modules/bill_printer/screens/bill_preview_screen.dart (đường in thật: bill IP mở hộp thoại, cổng cố định 9100)
  - lib/modules/bill_printer/providers/printer_settings_provider.dart (máy chủ in, web không tự in)
  - lib/screens/ban_screen.dart (gửi bếp thành công không tự in tại máy)
  - lib/core/services/bug_reporter_service.dart (gửi phản hồi không kèm dòng nhật ký)
  - lib/core/services/app_update_manager.dart (cập nhật)
  - lib/screens/chamcong_screen.dart (camera, vị trí, tải ảnh)
  - lib/modules/qr_order/providers/qr_order_providers.dart (đơn QR chỉ báo khi app đang mở)
  - lib/screens/kitchen_screen.dart (chuông phiếu bếp)
---

# Hỗ trợ kỹ thuật

> Khoanh vùng và xử lý lỗi của app theo triệu chứng: máy in, mạng, đăng nhập, cập nhật, chấm công, QR, chuông; chuẩn bị gì khi gọi hỗ trợ.

## Ai dùng được
- Chủ quán, Quản lý và nhân viên đều làm được phần kiểm tra trên máy mình. Việc đổi cài đặt máy in, vai trò, module cần Chủ quán hoặc Quản lý.

## Màn hình gồm những gì
Các chỗ hay dùng khi xử lý lỗi: Cài đặt → "Gửi phản hồi"; ô Nhật Ký Log; ô In Hoá Đơn gồm "Cấu Hình Trạm In", "Máy In & Luật In", "Thiết Kế Mẫu In".

## Các việc thường làm

### App bị lỗi, app lỗi rồi, bấm không được mà chưa rõ lỗi gì
Cần biết 3 điều để khoanh vùng: đang dùng máy gì (điện thoại, Sunmi, máy tính Windows, trình duyệt web), đang làm việc gì, màn hình báo chữ gì.
1. Kiểm tra mạng wifi hoặc 4G.
2. Thoát hẳn app rồi mở lại, làm lại thao tác đó.
3. Thông báo đỏ tắt nhanh chưa kịp đọc: làm lại rồi chụp màn hình; hoặc xem ô Nhật Ký Log đúng giờ đó.

### Chuẩn bị gì khi gọi Hotline, gửi lỗi cho bên hỗ trợ, gửi log
App không có mã lỗi. Bên hỗ trợ cần: ảnh thông báo, số phiên bản, giờ xảy ra, máy đang dùng, việc đang làm.
1. Gọi Hotline 0927 55 8888, hoặc Cài đặt → "Gửi phản hồi".
2. "Gửi phản hồi" chỉ gửi kèm thông tin máy và phiên bản, không kèm dòng nhật ký.
3. Muốn gửi log: mở ô Nhật Ký Log, lọc đúng giờ, bấm "Sao chép Logs", dán vào phần mô tả hoặc tin nhắn.

### Xem lỗi tối qua, log ở đâu
1. Mở ô Nhật Ký Log; chưa thấy ô thì Chủ quán bật ở Trang chủ → "Sửa" → "Thêm".
2. Chọn ngày giờ, "Phân loại Log" là Lỗi nghiêm trọng hoặc Cảnh báo hệ thống, bấm "Truy xuất Log".
3. Lỗi máy in: chọn "Loại thao tác" là Máy in. Dòng log mới có thể trễ tới 3 phút.

### Xem số phiên bản, app đang là bản mấy
Xem ở cuối Trang chủ, cuối màn Cài đặt, hoặc màn đăng nhập ("Phiên bản … build …").

### Máy in không in được, không ra bill: khoanh vùng trước
Cần biết: máy in nối kiểu gì (Sunmi liền thân, máy tính Windows, máy in wifi/LAN, bán trên web) và màn hình báo gì.
1. Xem máy in đã bật, còn giấy, đúng mặt giấy.
2. Mở In Hoá Đơn, đọc dòng "Đang in theo: …" và cảnh báo đỏ nếu có.
3. Bấm in thử ở tab "Máy in" hoặc "Cấu Hình Trạm In".
4. Xem log: ô Nhật Ký Log, "Loại thao tác" là Máy in.
Dòng "Bill đã gửi máy in" chỉ nói lệnh đã gửi, chưa chắc giấy đã ra. Bill chưa in thì bấm "IN LẠI BILL".

### Máy in wifi, LAN báo không kết nối được, lúc nãy còn in
1. Máy in bật và cùng mạng wifi với máy bán.
2. Đổi wifi hoặc khởi động lại bộ phát thì máy in có thể đổi địa chỉ IP: bấm "Quét" hoặc xem IP trên máy in, sửa lại IP rồi lưu.
3. In thử lại. App luôn dùng cổng 9100, đổi ô "Cổng" không có tác dụng; máy in phải nghe ở cổng 9100.
4. In thử được mà bill thật lại hiện hộp thoại in: bill và tem qua máy in IP đi bằng hộp thoại, chọn máy in rồi in; huỷ hộp thoại tính là chưa in.

### Máy tính Windows in không ra, máy in không nhận lệnh
1. Tên máy in trong app phải đúng tên trong Windows; để trống thì không in.
2. Tải lại Công cụ Cài máy in ở quannho.lpm.vn/cai-may-in.html, chạy rồi bấm "CÀI MÁY IN".
3. In thử trong tab "Máy in".

### Máy Sunmi cầm tay bấm in không ra
1. Xem còn giấy, nắp đóng chặt.
2. In thử máy in tích hợp ở "Máy In & Luật In".
3. Báo "Không kết nối được dịch vụ in tích hợp": thoát app, khởi động lại máy rồi thử lại.
4. Quán đang dùng luật in: phải có luật hoá đơn trỏ tới máy này.

### Máy chính in được, máy nhân viên bấm không ra; máy tính tắt thì điện thoại có in được không
Khi quán dùng Máy chủ in, máy khác chỉ gửi lệnh và đợi máy chủ in thay.
1. Máy chủ in (Windows hoặc Sunmi) phải bật, mở app, có mạng. Máy chủ tắt thì máy khác vẫn bán được nhưng không ra giấy và app không báo.
2. Dòng "Máy chủ in hiện tại" vẫn hiện tên dù máy đó đã tắt, nên phải nhìn chính máy đó.
3. Máy chủ không dùng được nữa: trên máy mới bấm "Chuyển máy chủ sang thiết bị này".
4. Bật lại máy chủ: phiếu chưa in trong 24 giờ có thể ra dồn một lúc.

### Bán trên web không ra giấy
Trình duyệt web không tự in và không báo gì sau thanh toán. In tay bằng nút in, hoặc đặt một máy Windows hay Sunmi làm Máy chủ in.

### Phiếu bếp không ra giấy mà hoá đơn vẫn ra
Gửi bếp thành công thì máy gửi không tự in phiếu. Phiếu ra giấy nhờ Máy chủ in, hoặc in tay ở màn Phiếu bếp.
1. Mở ô Phiếu bếp xem phiếu đã tới chưa. Đã tới là gửi bếp đúng, lỗi ở phần in.
2. Quán chưa có Máy chủ in: đặt một máy Windows hoặc Sunmi làm Máy chủ in. Quán chỉ có điện thoại với máy in wifi, không có máy đó: in tay ở màn Phiếu bếp.
3. Máy chủ in phải có trạm hoặc luật cho "Phiếu bếp nóng", "Phiếu bếp bar".
4. Phiếu đã chuyển "đang làm" mà chưa in thì không tự in nữa, in tay ở màn Phiếu bếp.

### Bếp không nhận được món, không thấy phiếu trên màn hình
1. Máy gửi có báo gửi thất bại không: có thì món vẫn chưa gửi, kiểm tra mạng rồi bấm gửi lại.
2. Mở màn Phiếu bếp trên máy bếp, xem bộ lọc trạm và mạng của máy đó.
3. Màn trống sau khi mở: đợi 10 giây hoặc mở lại màn.
4. Màn chỉ giữ phiếu trong 4 giờ gần nhất, phiếu xong ẩn sau 15 phút.

### In tem không ra
1. "Máy In & Luật In" → mục "Tem dán ly" không được để "Không in tem"; dùng luật in thì phải có luật tem.
2. Chỉ món có "Bộ phận chế biến" là Bếp Bar mới có tem.
3. Tem đi cùng phiếu bếp nên cần Máy chủ in như phiếu bếp.

### Bluetooth
App chưa hỗ trợ máy in Bluetooth. Dùng máy in USB qua máy tính Windows, máy in wifi/LAN, hoặc Sunmi liền thân.

### App quay vòng không vào, màn hình trắng, mở app không lên
1. Kiểm tra mạng, thử đổi wifi sang 4G: app cần mạng để vào.
2. Thoát hẳn rồi mở lại; mạng chậm app có thể đưa về màn đăng nhập, đăng nhập lại là được.
3. Xem ngày giờ trên máy có đúng không, bật tự động theo mạng.
4. Vẫn vậy: cập nhật bản mới; trên web tải lại trang. Rồi gọi Hotline 0927 55 8888.

### Đang dùng tự văng ra màn đăng nhập, về màn chọn quán
1. Văng ra màn đăng nhập: phiên đăng nhập hết hạn, app không báo lý do. Đăng nhập lại; món và đơn không mất.
2. Văng nhiều lần: kiểm tra mạng và ngày giờ trên máy, rồi báo Hotline kèm giờ xảy ra.
3. Về màn chọn quán: tài khoản có thể đã bị xoá khỏi quán, hỏi người quản lý quán.

### Đăng nhập báo sai mật khẩu mà chắc chắn đúng, bị khoá
1. Kiểm tra lại đúng số điện thoại đã đăng ký.
2. Sai 5 lần trong 5 phút: báo "Quá nhiều lần thử thất bại", chờ 5 phút, không có nút mở khoá.
3. Vẫn sai: bấm "Quên mật khẩu?". Nhân viên nhờ Chủ quán đặt lại; Chủ quán gọi Hotline.
4. "Dịch vụ đăng nhập an toàn chưa sẵn sàng": thường là mất mạng, kiểm tra mạng trước.

### Máy này thêm món, thanh toán rồi mà máy kia chưa thấy, không đồng bộ
1. Các máy tự cập nhật sau vài giây, chậm nhất khoảng 15 giây. Đợi rồi xem lại.
2. Máy kia kiểm tra mạng: mất mạng thì danh sách giữ dữ liệu cũ, đa số màn không báo.
3. Vẫn cũ: thoát app máy đó rồi mở lại.
4. Vừa bật, tắt module: máy khác phải thu nhỏ rồi mở lại app mới đổi.

### Thanh toán quay vòng, báo mạng chậm, không biết tiền đã ghi chưa
Đừng thanh toán lại ngay và đừng sửa món; app giữ đúng giao dịch cũ nên không thu hai lần.
1. Bán hàng: bấm nút đồng hồ trên thanh trên cùng, chọn "Đối soát / tiếp tục đơn cũ". Báo "Không có thanh toán đang chờ đối soát" là không còn gì treo.
2. Bàn: báo "Chưa xác định được trạng thái thanh toán" thì bấm thanh toán lại, không đổi món.
3. Đơn đối soát xong không tự in bill: mở lại bill để in tay.

### Wifi vẫn có mà app báo mất mạng, app chậm, đơ, phải tắt mở lại hoài
1. Thử mở một trang web trên máy đó, rồi đổi sang 4G xem có nhanh hơn không. Nhanh hơn là do wifi.
2. Thoát hẳn app rồi mở lại, khởi động lại máy, cập nhật bản mới.
3. Vẫn chậm: ghi lại chậm ở màn nào, giờ nào, máy nào rồi gửi hỗ trợ.

### Cập nhật app, không cập nhật được, cài bản mới có mất dữ liệu không
Cài bản mới không mất món và đơn vì dữ liệu nằm trên máy chủ.
1. App tự báo khi mở nếu có bản mới; không có nút kiểm tra tay. Báo "Bắt buộc cập nhật" thì phải cập nhật mới dùng tiếp.
2. Android cài ngoài: bấm "Cập nhật ngay", cho phép cài từ nguồn này. Cài từ CH Play thì cập nhật trong CH Play.
3. Windows: bấm "Cập nhật ngay", app tự cài rồi thoát, mở lại.
4. iPhone: cập nhật trong App Store; App Store có thể ra bản muộn hơn Android.
5. Web: không có thông báo, tải lại trang.
6. Bấm không chạy hoặc tải lỗi: tải tay ở quannho.lpm.vn/download.

### Chấm công không mở được camera, tải ảnh thất bại
1. Báo "Yêu cầu chụp ảnh trực tiếp": cấp quyền Camera cho app trong cài đặt của máy; app không có nút mở cài đặt.
2. Báo "Tải ảnh thất bại": kiểm tra mạng, nút "Thử lại" chỉ đóng hộp, phải bấm "VÀO CA" lại.
3. Bấm vào ca mà không báo gì: xem trạng thái ca đã đổi chưa, rồi thử lại.

### Chấm công không lấy được vị trí, GPS
Không có GPS vẫn vào ca được: app không báo cho nhân viên, Chủ quán thấy "Không GPS". Muốn có vị trí: bật định vị và cho app quyền vị trí trong cài đặt máy.

### Khách quét QR báo lỗi không vào được
1. "Liên kết gọi món không hợp lệ": khách quét lại mã, mã có thể mờ hoặc rách.
2. "Quán tạm ngừng nhận đơn qua mã QR này do có lượt quét bất thường": Chủ quán bấm "Tạo mã QR mới", in và dán thay.
3. "Quán tạm ngưng nhận đơn qua QR": bật lại kênh ở ô QR Gọi Món.
4. "Không thể tải thực đơn": khách kiểm tra mạng, bấm "Thử lại".
5. Báo xác minh người thật: khách tải lại trang.

### Đơn QR khách đặt mà máy không báo gì
App không có thông báo đẩy, chỉ báo khi đang mở.
1. Để máy ở màn Bán hàng hoặc Bàn, app ở màn hình chính: màn khác hoặc thu nhỏ app thì không báo.
2. Tăng âm lượng máy.
3. Nhãn đơn QR có dấu "!" là mất kết nối, kiểm tra mạng.

### Chuông bếp không kêu
1. Màn Phiếu bếp phải đang mở trên máy đó, và chỉ kêu với phiếu gửi sau khi mở màn.
2. Máy phải đăng nhập vai trò có chữ "Bếp"; Chủ quán, Quản lý, thu ngân, "Pha chế" không nghe chuông phiếu.
3. Bấm "Bật tiếng" và tăng âm lượng máy.
4. Trên web, bấm vào trang một lần vì trình duyệt có thể chặn âm thanh.

## Lỗi thường gặp
| Thấy gì trên màn hình | Vì sao | Làm gì |
|---|---|---|
| "Đăng nhập thất bại. Hãy chụp lại báo chủ app." | Lỗi phía máy chủ đăng nhập, mật khẩu có thể vẫn đúng | Thử lại sau ít phút; vẫn báo thì gọi Hotline 0927 55 8888 kèm ảnh |
| "Gửi bếp thất bại. Hãy chụp lại báo chủ app." | Thường do mạng; món vẫn chưa gửi | Kiểm tra mạng rồi bấm gửi lại; lặp lại nhiều lần mới báo hỗ trợ |
| "Không thể đăng ký. Đã có thiết bị khác làm máy chủ in." | Có thể do mạng, thiếu quyền, hoặc đã có máy chủ | Kiểm tra mạng và quyền; muốn thay máy dùng "Chuyển máy chủ sang thiết bị này" |

## Liên quan module khác
- In Hoá Đơn, Bán hàng, Bếp, Nhân viên & Phân quyền, Chấm công, QR Gọi Món, Nhật Ký Log.

## Ghi chú cho Chủ Quán (không đưa cho khách)
- Bài viết từ đọc mã 04/11/2026, chưa kiểm trên máy in thật; "gửi bếp thành công không tự in" đúng khi máy chủ đã có hàm gửi bếp bản 2.
- Nhiều chỗ app im lặng hoặc nói sai là lỗi của app, nên sửa app rồi sửa bài: "Gửi phản hồi" ghi "tự động đính kèm nhật ký" nhưng không kèm; "Máy chủ in hiện tại" không xét máy đã tắt; ô "Cổng" không có tác dụng; nút "Thử lại" khi tải ảnh chỉ đóng hộp; SePay trong thiết kế bill không có tác dụng.
