---
module: tinh_gio
ten: Các hoạt động tính giờ
phien_ban: 1.0.8+38
cap_nhat: 2026-11-24
nguon:
  - lib/modules/tinh_gio/tinh_gio.dart
  - lib/modules/tinh_gio/tinh_gio_widgets.dart
  - lib/modules/tinh_gio/loai_hinh.dart
  - lib/modules/tinh_gio/dat_truoc.dart
  - lib/modules/tinh_gio/dat_truoc_ui.dart
  - lib/screens/ban_screen.dart
  - supabase/migrations/20261123_ban_tinh_gio_v1.sql
  - supabase/migrations/20261124_ban_dat_truoc_v1.sql
---

# Các hoạt động tính giờ

> Dành cho quán bi da, karaoke, sân cầu lông, sân bóng, tennis, pickleball, bóng bàn: mở bàn (phòng, sân) là đồng hồ chạy, lúc thanh toán hoá đơn có thêm một dòng tiền giờ. Có đặt trước và nhắc gọi khách trước giờ đặt 30 phút.

## Ai dùng được
- Module **Các hoạt động tính giờ** (hay gọi tắt là tính giờ) mặc định **tắt**. Chủ quán bật ở Trang chủ: **"Sửa"** → **"Thêm"** → **"Các hoạt động tính giờ"**. Bật module này thì app bật kèm **Quản lý Bàn** nếu quán chưa bật.
- Ai có module **Quản lý Bàn** thì thấy ô Các hoạt động tính giờ và dùng được Lịch đặt.
- **Đặt giá giờ cho bàn**: chỉ Chủ quán và Quản lý.
- **Tính tiền, đặt trước, nhận sân, đánh dấu đã nhắc**: người có quyền **"Thanh toán hoá đơn"**.
- **Bỏ tiền giờ của một bàn, huỷ bàn đã chạy giờ quá 5 phút**: Chủ quán / Quản lý tự làm; nhân viên khác cần Quản lý nhập mã PIN.
- Mọi máy của quán phải cập nhật app. Máy nào chưa cập nhật sẽ không thanh toán được bàn tính giờ.

## Màn hình gồm những gì
- Ô **Các hoạt động tính giờ** ở Trang chủ (ô có bốn hình nhỏ xếp vuông) mở màn **Quản lý Bàn**. Quán chỉ có một loại hình thì chọn loại hình đó, ô đổi tên và biểu tượng theo ngành: Bi da, Karaoke, Cầu lông, Tennis, Pickleball, Bóng bàn, Sân bóng.
- Thẻ bàn trống có giá giờ ghi thêm giá, ví dụ "4 chỗ • 60.000 đ/giờ".
- Thẻ bàn đang có khách ghi thời lượng và tiền giờ tạm tính, ví dụ "1g05 • giờ 65.000 đ"; số tiền lớn bên dưới là tổng bàn đã gồm tiền giờ.
- Trong màn chi tiết bàn có dải **"Đang tính giờ … • tiền giờ tạm tính … • chốt khi bấm Thanh toán"**.
- Nút **"Lịch đặt"** (hình tờ lịch) ở góc trên màn Quản lý Bàn mở lịch đặt trước.

## Các việc thường làm

### Bật module Các hoạt động tính giờ và chọn loại hình
Bật tính giờ cho quán bi da, karaoke, sân cầu lông, sân bóng, tennis, pickleball, bóng bàn ở đâu:
1. Trang chủ, bấm **"Sửa"**, bấm ô **"Thêm"**, chọn **"Các hoạt động tính giờ"**.
2. App hỏi **"Quán thuộc loại hình nào?"**: chọn Bi da, Karaoke, Cầu lông, Tennis, Pickleball, Bóng bàn, Sân bóng; quán có từ hai loại trở lên thì chọn **"Nhiều loại"**.
3. Ô ở Trang chủ đổi tên và biểu tượng theo loại hình vừa chọn. Chọn "Nhiều loại" thì ô giữ tên Các hoạt động tính giờ.

Đổi loại hình sau này: giữ lâu vào một bàn trống, chọn **"Tính tiền giờ"**, bấm dòng **"Loại hình: … • Đổi"**.

### Đặt giá giờ cho bàn, phòng, sân
Cài giá mỗi giờ cho bàn bi da, phòng hát, sân ở đâu:
1. Vào **Kho hàng**, bấm **"Thêm sản phẩm"** → **"Thêm sản phẩm mới"**, tạo một món làm giá giờ, ví dụ "Giờ bàn lỗ", giá bán **60.000đ**, danh mục "Tiền giờ". Giá bán của món là giá **một giờ**.
2. Ở Quản lý Bàn, **giữ lâu** vào bàn đang trống, chọn **"Tính tiền giờ"**.
3. Chọn món giá giờ trong danh sách (có ô **"Tìm món"**). Bật **"Áp cho cả khu …"** nếu muốn đặt cùng giá cho mọi bàn của khu.

Mỗi loại giá tạo một món riêng, ví dụ "Giờ bàn lỗ" và "Giờ phòng VIP".

> Chỉ Chủ quán và Quản lý đặt được giá giờ. Bàn đang có khách tính giờ thì chưa đổi được giá giờ; tính tiền xong mới đổi.

### Bỏ tính giờ cho một bàn
Giữ lâu vào bàn trống, chọn **"Tính tiền giờ (đang bật)"**, bấm **"Không tính giờ (bàn thường)"**.

### Đổi giá mỗi giờ
Sửa giá bán của món giá giờ trong **Kho hàng**. Bàn đang chạy giờ sẽ tính cả lượt theo giá mới, vì tiền giờ tính lúc bấm Thanh toán.

### Mở bàn và xem đồng hồ
Mở bàn như bàn thường. Đồng hồ chạy từ lúc mở bàn, theo giờ của máy chủ nên máy sai giờ cũng không làm sai tiền. Thẻ bàn và màn chi tiết bàn hiện thời lượng và tiền giờ tạm tính. Khách vẫn gọi đồ ăn uống, gửi bếp như thường.

### Tính tiền bàn tính giờ
1. Trong màn chi tiết bàn bấm **"Thanh toán"**. Bàn chưa gọi món nào thì bấm **"Tính tiền giờ"**.
2. App chốt giờ: thêm một dòng tiền giờ vào bàn, ghi món giá giờ, tên bàn, giờ vào, giờ ra và thời lượng, ví dụ "Giờ bàn lỗ · Bàn 3 · 14:05–15:35 (1g30)".
3. Màn **"Thu tiền"** hiện tổng đã gồm tiền giờ. Thu tiền như bàn thường; mã giảm giá và điểm áp trên cả tiền giờ.

Khách chơi tiếp sau khi đã mở màn Thu tiền: bấm **"Hủy bỏ"**, lúc sau bấm Thanh toán lại. Dòng tiền giờ được tính lại, không sinh dòng thứ hai.

### Tiền giờ tính thế nào
Tính theo phút, làm tròn lên từng phút, rồi làm tròn tiền lên 1.000đ. Ví dụ giá 60.000đ một giờ: 90 phút là 90.000đ; 61 phút giá 70.000đ là 72.000đ. Chưa có giá theo khung giờ (ngày, tối, cuối tuần): mỗi bàn một giá.

### Chuyển bàn, gộp bàn khi đang tính giờ
Bấm **"Chuyển"** hoặc **"Gộp bàn"** như thường. Giờ ở bàn cũ được chốt thành một dòng theo giá bàn cũ và đi theo sang bàn mới. Bàn mới có giá giờ thì đồng hồ chạy tiếp theo giá bàn mới; bàn mới là bàn thường thì hết tính giờ.

### Bỏ tiền giờ cho khách
Trong màn chi tiết bàn, huỷ dòng tiền giờ như huỷ món bếp đã làm xong: chọn lý do, Quản lý duyệt (nhân viên cần mã PIN Quản lý). Sau khi huỷ, bàn đó không bị tính tiền giờ nữa.

### Huỷ bàn tính giờ
Mở nhầm bàn: huỷ trong 5 phút đầu thì chỉ cần chọn lý do. Bàn đã chạy giờ quá 5 phút: app chốt giờ trước rồi mới huỷ, và phải có Quản lý duyệt.

### Xem tiền giờ trong báo cáo
Tiền giờ nằm trong doanh thu như mọi món. Muốn tách tiền giờ với đồ ăn uống: Báo cáo, tab **Sản phẩm**, lọc danh mục của món giá giờ (ví dụ "Tiền giờ").

### Đặt trước sân, bàn, phòng
Khách gọi điện đặt sân, đặt bàn bi da, đặt phòng hát trước thì ghi ở đâu:
1. Ở Quản lý Bàn bấm nút **"Lịch đặt"** ở góc trên.
2. Chọn ngày bằng mũi tên hai bên, hoặc bấm vào ngày để chọn trên lịch.
3. Bấm **"Đặt"** ở bàn cần đặt. Nhập tên khách, số điện thoại, bấm vào dòng giờ để chọn giờ bắt đầu, chọn thời lượng (30 phút, 1 giờ, 1 giờ 30, 2 giờ, 3 giờ), rồi bấm **"Đặt"**.

Hai lượt đặt không được trùng giờ trên cùng một bàn; đặt sát giờ nhau thì được. Lịch đặt hiện các bàn có giá giờ; quán chưa đặt giá giờ cho bàn nào thì hiện mọi bàn. Tiền cọc chỉ là ô ghi nhớ, không vào Thu Chi và không tự trừ vào hoá đơn.

### Khách đặt trước đã đến
Cách 1: trong Lịch đặt bấm vào lượt đặt, chọn **"Khách đã đến: nhận …"**. App mở bàn và đồng hồ chạy.
Cách 2: ở sơ đồ bàn bấm vào bàn có dòng "Đặt 18:00 • tên khách". App hỏi ai đang nhận bàn: chọn tên khách đặt nếu khách đặt đã đến, hoặc **"Khách khác"**.

### Tiền giờ của khách đặt trước
Tính theo khung đã đặt. Đến trễ vẫn tính từ giờ đặt. Về sớm vẫn tính tới hết khung. Chơi quá khung thì tính thêm theo phút tới lúc thanh toán. Đến sớm thì tính từ lúc đến. Thẻ bàn ghi "khung đặt … • giờ …" khi đang tính theo khung.

### Sửa, huỷ lượt đặt, khách không đến
Trong Lịch đặt bấm vào lượt đặt, chọn **"Sửa lượt đặt"**, **"Huỷ lượt đặt"** hoặc **"Khách không đến"**. Huỷ hoặc ghi không đến thì khung giờ đó trống lại. Lượt đã nhận (khách đã đến) thì không sửa, không huỷ được nữa.

### Nhắc gọi khách trước giờ đặt
Còn 30 phút tới giờ đặt, app bật hộp **"Sắp tới giờ đặt"** kèm chuông, ghi bàn, giờ, tên và số điện thoại khách. Bấm **"Gọi khách"** để gọi, rồi bấm **"Đã nhắc"**. Một người bấm "Đã nhắc" thì máy khác không nhắc nữa, và lịch ghi giờ đã nhắc. Hộp nhắc chỉ hiện khi app đang mở; app đang tắt thì không có thông báo. Lượt đặt khi còn dưới 30 phút tới giờ thì không nhắc.

## Lỗi thường gặp
| Thấy gì trên màn hình | Vì sao | Làm gì |
|---|---|---|
| Giữ lâu vào bàn không thấy "Tính tiền giờ" | Quán chưa bật module Các hoạt động tính giờ, hoặc bàn đang có khách | Bật module Các hoạt động tính giờ; đợi bàn trống rồi giữ lâu lại |
| "Chỉ Chủ quán / Quản lý đặt được giá giờ" | Tài khoản không phải Chủ quán hay Quản lý | Nhờ Chủ quán hoặc Quản lý đặt giá giờ |
| "Bàn đang có khách tính giờ, tính tiền xong mới đổi giá giờ được" | Bàn đang chạy giờ | Tính tiền bàn đó rồi đổi |
| Danh sách chọn giá giờ ghi "Chưa có món nào. Vào Kho hàng bấm "Thêm sản phẩm" để tạo món giá giờ trước." | Chưa có món nào để làm giá giờ | Vào Kho hàng tạo món giá giờ rồi quay lại |
| "Giờ chơi cần tính lại (chưa chốt hoặc đã chốt quá 15 phút). Đóng màn thanh toán rồi bấm Thanh toán lại." | Màn Thu tiền để mở quá 15 phút, hoặc máy đó chưa cập nhật app | Đóng màn Thu tiền, bấm Thanh toán lại; máy chưa cập nhật thì cập nhật app |
| "Chưa chốt được giờ: …" khi bấm Thanh toán | Mất mạng lúc chốt giờ | Kiểm tra mạng rồi bấm Thanh toán lại |
| Bấm sửa số lượng dòng tiền giờ, app báo "Dòng tiền giờ" | Tiền giờ do hệ thống tính theo đồng hồ | Muốn bỏ tiền giờ thì Quản lý huỷ dòng đó |
| Thẻ bàn không hiện đồng hồ dù bàn có giá giờ | Bàn được mở trước khi đặt giá giờ | Lượt khách đó không tính giờ; lượt mở bàn sau sẽ tính |
| Đặt trước báo "Trùng giờ với lượt đặt của …" | Khung giờ đã có người đặt trên bàn đó | Chọn giờ khác hoặc bàn khác |
| Đặt trước báo "Khung giờ này đã qua" | Giờ kết thúc đã qua | Chọn lại giờ |
| Không thấy hộp nhắc trước giờ đặt | App đang tắt, lượt vừa đặt khi còn dưới 30 phút, hoặc đã có người bấm "Đã nhắc" | Mở app ở máy quầy trong giờ bán; xem dòng "đã nhắc" trong Lịch đặt |
| Lượt đặt ghi "Đã nhận" vẫn giữ khung giờ dù khách đã về | Khung đã đặt được giữ tới hết giờ | Đặt khách khác vào sau giờ kết thúc của khung đó |

## Liên quan module khác
- **Quản lý Bàn**: tính giờ chạy ngay trên sơ đồ bàn, gọi món, gửi bếp, chuyển, gộp, thanh toán như bàn thường.
- **Kho hàng**: món giá giờ là một món bình thường tạo ở Kho hàng; giá bán là giá một giờ.
- **Báo cáo**: tiền giờ là một dòng trong hoá đơn, vào doanh thu và tab Sản phẩm.
- **Bếp**: dòng tiền giờ không lên phiếu bếp.

## Ghi chú cho Chủ Quán (không đưa cho khách)
1. Bài viết theo mã ở nhánh `feature/ai-bum-ui` ngày 24/11/2026, **chưa phát hành**. Chỉ đăng bài này cho Boom khi bản app có module này đã tới tay quán, nếu không Boom sẽ chỉ khách dùng thứ họ chưa có.
2. Kế hoạch và nhật ký: `.docs/ke-hoach-ban-tinh-gio.md`.
3. Chưa có: giá theo khung giờ, lịch cố định lặp hàng tuần, khách tự đặt qua mạng, thông báo đẩy khi app tắt, tiền cọc vào Thu Chi, lưới giờ × sân trong Lịch đặt.
4. Cách gọi "bàn / phòng / sân" theo loại hình mới lưu trong `loai_hinh.dart`, chữ trên màn Bàn vẫn ghi "bàn".
5. Chưa kiểm trên app: gộp bàn có tính giờ, in bill 58mm với dòng tiền giờ, màn Bếp. Bài mô tả theo mã và test máy chủ; sửa lại nếu thử thật ra khác.
6. Máy chủ: `ban_chot_gio_v1`, `ban_chuyen_ban_tinh_gio_v1`, bảng `ban_dat_truoc` và 4 hàm `ban_dat_truoc_*`.
