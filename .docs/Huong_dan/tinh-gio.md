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
  - lib/modules/tinh_gio/bao_cao_tinh_gio.dart
  - lib/modules/tinh_gio/gia_gio_ui.dart
  - lib/modules/tinh_gio/ngay_le_ui.dart
  - lib/modules/tinh_gio/goi_gio_ui.dart
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
- Ô **Các hoạt động tính giờ** ở Trang chủ (ô có bốn hình nhỏ xếp vuông), hoặc mục **"Tính giờ"** ở thanh dưới (máy tính bảng: thanh bên trái), mở màn riêng cùng tên; thanh dưới vẫn hiện để qua Trang chủ, Bán hàng, Bàn nhanh. Màn này: chỉ hiện các bàn có giá giờ và mọi bàn của khu mang biểu tượng ngành (bi da, sân, phòng hát). Bàn ăn uống thường không hiện ở đây; xem mọi bàn thì vào **Bàn**. Quán chỉ có một loại hình thì chọn loại hình đó, ô và màn đổi tên theo ngành: Bi da, Karaoke, Cầu lông, Tennis, Pickleball, Bóng bàn, Sân bóng.
- Đầu màn có ô xanh đậm ghi **"Đang chơi"** (ví dụ "3 / 6 bàn") và **"Tiền giờ đang chạy"** (tổng tiền giờ tạm tính của các bàn đang chơi). Cạnh đó là nút **"Lịch đặt"** và ba ô lọc **"Tất cả"**, **"Đang chơi"**, **"Trống"**, mỗi ô kèm số bàn.
- Bàn xếp theo khu. Đầu mỗi khu có tên khu, số bàn đang chơi, nút **"…"** để sửa khu và nút **"+ Thêm bàn"** để thêm bàn vào đúng khu đó. Điện thoại hiện mỗi bàn một hàng; máy tính bảng, Sunmi màn lớn hiện 3 bàn một hàng; máy tính hiện 4.
- Thẻ bàn trống nền trắng, ghi giá giờ và số chỗ, ví dụ "60.000 đ/giờ • 4 chỗ", có nút **"Mở bàn"**. Bàn chưa có giá ghi **"Chưa đặt giá giờ"** và nút **"Đặt giá"**: chạm vào thì app mở hộp đặt giá trước, đặt giá xong chạm lại mới mở bàn.
- Thẻ bàn đang có khách nền xanh đậm: bên trái tên bàn, dòng "Vào 14:05 • 2 khách", dòng dưới ghi người mở bàn và số món khách đã gọi (ví dụ "Lan  3 món", chưa gọi thì "Chưa gọi món"); bên phải đồng hồ **"Đã chơi"** (giờ:phút, ví dụ "1:05") và số tiền vàng là tổng tạm tính của bàn, đã gồm tiền giờ. Bàn chạy quá 6 giờ có nhãn đỏ **"Quá 6 giờ"**, để nhân viên xem khách còn chơi không (hay quên đóng bàn). Có đơn QR chờ thì có nhãn vàng "QR"; có món quá 3 phút chưa gửi bếp thì có nhãn đỏ "… món chưa gửi".
- Ở màn **Bàn**, thẻ bàn tính giờ vẫn là ô vuông như bàn thường, ghi đồng hồ và dòng "Vào 14:05 • giờ 65.000 đ"; quá 6 giờ thì đồng hồ nền trắng chữ đỏ.
- Trong màn chi tiết bàn, trên cùng là khối nền xanh đậm **"ĐANG TÍNH GIỜ"**: góc phải ghi **Vào lúc** (ví dụ "Vào lúc 14:05"), giữa là hai số lớn **Đã chơi** (ví dụ "1 giờ 05 phút") và **Tiền giờ**; dòng dưới ghi đơn giá, ví dụ "60.000 đ/giờ • tính theo phút, chốt khi Thanh toán". Bàn chạy quá 6 giờ thì có thêm dải đỏ "Quá 6 giờ, xem khách còn chơi không". Đồ ăn uống nằm bên dưới. Ô tổng ghi **"TỔNG TẠM TÍNH (gồm tiền giờ)"**, đã cộng cả tiền giờ.
- Nút **"Lịch đặt"** ở đầu màn Các hoạt động tính giờ, hoặc nút hình tờ lịch ở góc trên màn Quản lý Bàn, mở lịch đặt trước.

## Các việc thường làm

### Bật module Các hoạt động tính giờ và chọn loại hình
Bật tính giờ cho quán bi da, karaoke, sân cầu lông, sân bóng, tennis, pickleball, bóng bàn ở đâu:
1. Trang chủ, bấm **"Sửa"**, bấm ô **"Thêm"**, chọn **"Các hoạt động tính giờ"**.
2. App hỏi **"Quán thuộc loại hình nào?"**: chọn Bi da, Karaoke, Cầu lông, Tennis, Pickleball, Bóng bàn, Sân bóng; quán có từ hai loại trở lên thì chọn **"Nhiều loại"**.
3. Ô ở Trang chủ đổi tên và biểu tượng theo loại hình vừa chọn. Chọn "Nhiều loại" thì ô giữ tên Các hoạt động tính giờ.

Đổi loại hình sau này: giữ lâu vào một bàn trống, chọn **"Đặt giá giờ"**, bấm nút ghi tên loại hình ở góc trên bên phải hộp (ví dụ "Bi da", "Nhiều loại").

### Đặt giá giờ cho bàn, phòng, sân
Cài giá mỗi giờ cho bàn bi da, phòng hát, sân ở đâu:
1. Ở màn Các hoạt động tính giờ, bấm **"Đặt giá"** ở bàn ghi **"Chưa đặt giá giờ"**. Bàn ở màn Quản lý Bàn, hoặc bàn đã có giá: **giữ lâu** vào bàn đang trống, chọn **"Đặt giá giờ"** (dòng nhỏ bên dưới ghi "Chưa tính giờ" hoặc giá đang dùng).
2. Gõ số tiền vào ô **"Giá một giờ"**, ví dụ 60000, hoặc bấm một mức ở hàng **"Chọn nhanh"** (mức có dấu tích là giá quán đang dùng). Bên dưới ô giá app tính sẵn ví dụ khách vào lúc này chơi 25 phút, 47 phút, 1 giờ 40 phải trả bao nhiêu (đã theo khung giá và cách làm tròn đang cài).
3. Muốn đặt cùng giá cho mọi bàn của khu thì bấm **"Cả khu · … bàn"**; không thì để **"Chỉ …"** (tên bàn).
4. Bấm nút **"Lưu"** ở dưới cùng.

App tự tạo trong Kho hàng một món tên "Giờ chơi 60.000 đ/giờ", danh mục "Tiền giờ"; mỗi mức giá là một món (món tạo từ trước có thể mang tên "Tiền giờ 60.000 đ", vẫn dùng bình thường). Không cần vào Kho hàng tạo trước.

> Chỉ Chủ quán và Quản lý đặt được giá giờ. Bàn đang có khách tính giờ thì chưa đổi được giá giờ; tính tiền xong mới đổi.

### Giá theo khung giờ (giờ tối, cuối tuần đắt hơn)
Muốn buổi tối hoặc thứ Bảy, Chủ nhật tính giá khác:
1. Mở hộp **"Đặt giá giờ"** của bàn (như mục trên), bấm dòng **"Giá theo giờ & làm tròn"** để mở ra.
2. Bấm **"Thêm khung giá"**. Chọn ngày áp dụng (bấm từng ngày T2…CN, hoặc nút nhanh **"Mọi ngày"**, **"T2–T6"**, **"T7, CN"**), chọn giờ **"Từ"** – **"Đến"** (bật **"Cả ngày"** nếu tính cả ngày), gõ **"Giá một giờ trong khung"**, bấm **"Xong"**.
3. Thêm khung khác nếu cần (tối đa 12). Ngoài các khung, app tính theo **"Giá một giờ"** ở trên. Hai khung trùng giờ thì khung nằm trên được ưu tiên; bấm mũi tên lên để đổi thứ tự, bấm thùng rác để xoá khung.
4. Bấm **"Lưu"**. Muốn áp cho mọi bàn của khu thì chọn **"Cả khu"** trước khi lưu.

Khách chơi vắt qua hai khung thì mỗi phút tính theo giá của khung lúc đó, ví dụ 16:30 – 17:30 mà từ 17:00 giá 80.000 đ thì tính 30 phút giá thường + 30 phút giá 80.000. Khung qua nửa đêm (ví dụ 22:00 – 02:00) tính theo ngày bắt đầu khung. Khung giá theo giờ Việt Nam.

### Giá ngày lễ (Tết, 30/4, 2/9…)
1. Mở hộp **"Đặt giá giờ"** → **"Giá theo giờ & làm tròn"** → **"Thêm khung giá"** (hoặc bấm vào khung có sẵn để sửa).
2. Ở hàng **"ÁP DỤNG"** bấm ô **"Lễ"** (ô màu cam cuối hàng T2…CN). Muốn khung chỉ dùng cho ngày lễ thì bấm nút nhanh **"Chỉ ngày lễ"**. Bật Lễ thì hiện các ngày lễ sắp tới của quán; chưa có ngày nào thì bấm **"Thêm ›"**. Chọn giờ (hoặc **"Cả ngày"**), gõ giá (dưới ô giá có dòng so với giá thường, ví dụ "+50%"), bấm **"Xong"**, rồi **"Lưu"**.
3. Thêm các ngày lễ của quán: trong hộp khung giá bấm **"Thêm ›"** (hoặc **"Sửa ›"**). Hộp **"Ngày lễ của quán"** xếp ngày lễ theo tháng; kỳ nghỉ nhiều ngày liền cùng tên gộp thành một dòng:
   - **"Thêm nhanh"**: bấm 01/01, 30/04, 01/05, 02/09 (app lấy lần tới của mỗi ngày).
   - Tết âm lịch và ngày khác: gõ tên (ví dụ "Tết", không bắt buộc), bấm **"Chọn ngày"**, chọn một ngày hoặc ngày đầu và ngày cuối (tối đa 15 ngày liền), bấm **"Thêm"**.
   - Bỏ một ngày (hoặc cả kỳ nghỉ): bấm dấu ✕ ở dòng đó.

Danh sách ngày lễ dùng chung cho mọi bàn, mỗi lần thêm / bỏ là lưu ngay. Vào ngày lễ, khung có "ngày lễ" **luôn được ưu tiên** hơn khung thường, dù nằm trên hay dưới; giờ nào không có khung ngày lễ thì tính như ngày thường. Ví dụ khung lễ 22:00 – 02:00 bắt đầu tối 30/4 thì tính tới 02:00 sáng hôm sau. Năm sau nhớ thêm lại ngày Tết âm lịch (app không tự tính âm lịch). Bàn đang có khách mà vừa thêm ngày lễ hôm nay thì lúc thanh toán cũng tính theo giá lễ.

### Bán gói giờ (ví dụ 2 giờ 100.000 đ)
Cài gói cho bàn:
1. Giữ lâu vào bàn → **"Đặt giá giờ"** → bấm dòng **"Giá theo giờ & làm tròn"** để mở ra.
2. Ở phần **"Gói giờ"** bấm **"Thêm gói giờ"**, chọn ô thời gian (30 phút tới 6 giờ), gõ **"Giá trọn gói"** (app báo gói rẻ hơn tính giờ bao nhiêu), bấm nút **"Thêm gói …"**. Mỗi bàn tối đa 6 gói, không trùng thời gian.
3. Bấm **"Lưu"**. Muốn mọi bàn của khu có cùng gói thì chọn **"Cả khu"** trước khi lưu.

Chọn gói cho khách đang chơi:
1. Mở bàn đang tính giờ. Trong khối **"ĐANG TÍNH GIỜ"** bấm **"Chọn gói"**, chạm thẻ gói khách mua (mỗi thẻ ghi giá, rẻ hơn tính giờ bao nhiêu, giờ hết gói) rồi bấm nút **"Dùng gói …"** để xác nhận.
2. Gói tính từ lúc khách vào. Khối ghi **"Gói 2 giờ 100.000 đ · còn 25 phút"**, thẻ bàn ghi **"gói còn 25'"**; hết gói thì ghi **"hết gói, lố 8'"**.
3. Khối ghi thêm thanh còn lại: xanh khi còn nhiều, vàng khi còn 10 phút, cam đỏ khi đã lố.
4. Còn 10 phút và khi hết gói, máy đang mở app hiện hộp nhắc có vòng đếm ngược; báo khách xong bấm **"Đã báo khách"**, khách gia hạn thì bấm **"Đổi / thêm gói"**.

Hoá đơn và phiếu tạm tính của bàn có cọc in thêm "Đã cọc (ví khách)" và "CÒN PHẢI TRẢ"; mã QR chuyển khoản trên đó lấy số còn phải trả.

Tiền: khách về sớm vẫn trả đủ giá gói; chơi lố thì phần lố tính theo giá giờ (có khung giá, ngày lễ, làm tròn). Dòng hoá đơn ghi ví dụ "chơi 2 giờ 17 phút · gói 2 giờ 100.000 đ + 17 phút × 60.000 đ/giờ". Ai có quyền thu tiền chọn gói được; **đổi hoặc bỏ** gói đã chọn cần Chủ quán / Quản lý. Sửa giá gói trong "Đặt giá giờ" không đổi gói của khách đang chơi. Chuyển bàn khi đang có gói: bàn cũ tính đủ giá gói, bàn mới dùng nốt phần gói còn lại (không tính tiền thêm, không áp "chơi tối thiểu" của bàn mới), hết phần còn mới tính theo giờ.

### Làm tròn theo block, chơi tối thiểu
Quán muốn tính tròn mỗi 15 / 30 phút hoặc tối thiểu 1 giờ:
1. Trong hộp **"Đặt giá giờ"**, mở **"Giá theo giờ & làm tròn"**.
2. **"Tính tiền theo"**: **"Từng phút"** (mặc định) hoặc **"Mỗi 5 phút"** … **"Mỗi 1 giờ"**. Chơi lố sang block mới thì tính trọn block đó, ví dụ mỗi 30 phút: chơi 47 phút tính 1 giờ.
3. **"Ân hạn"** (khi đã chọn block): lố không quá số phút này thì chưa tính sang block mới, ví dụ ân hạn 5 phút: chơi 33 phút vẫn tính 30.
4. **"Chơi tối thiểu"**: chơi ít hơn thì vẫn tính đủ, ví dụ tối thiểu 1 giờ: chơi 20 phút tính 1 giờ.
5. Bấm **"Lưu"**.

Trên hoá đơn, dòng tiền giờ ghi rõ: làm tròn thì "chơi 47 phút, tính 1 giờ × 60.000 đ/giờ"; nhiều giá thì "47 phút (27 phút × 60.000 + 20 phút × 90.000 đ/giờ)". Khối "ĐANG TÍNH GIỜ" trong bàn ghi giá đang áp lúc này và báo trước giờ sắp đổi giá, ví dụ "Từ 17:00: 80.000 đ/giờ".

### Bỏ tính giờ cho một bàn
Giữ lâu vào bàn trống, chọn **"Đặt giá giờ"**, bấm **"Không tính giờ (bàn thường)"**.

### Đổi giá mỗi giờ
Giữ lâu vào bàn trống, chọn **"Đặt giá giờ"**, gõ giá mới vào ô **"Giá một giờ"**, bấm **"Lưu"**. Bàn đang có khách thì đợi tính tiền xong mới đổi được.

Cách khác: sửa giá bán của món "Tiền giờ …" trong **Kho hàng**, mọi bàn đang dùng món đó đổi giá theo; bàn đang chạy giờ sẽ tính cả lượt theo giá mới, vì tiền giờ tính lúc bấm Thanh toán.

### Mở bàn và xem đồng hồ
Mở bàn như bàn thường. Đồng hồ chạy từ lúc mở bàn, theo giờ của máy chủ nên máy sai giờ cũng không làm sai tiền. Thẻ bàn và màn chi tiết bàn hiện thời lượng và tiền giờ tạm tính. Khách vẫn gọi đồ ăn uống, gửi bếp như thường.

### Tính tiền bàn tính giờ
1. Trong màn chi tiết bàn bấm **"Thanh toán"**. Bàn chưa gọi món nào thì bấm **"Tính tiền giờ"**.
2. App chốt giờ: thêm một dòng tiền giờ vào bàn, ghi tên bàn, giờ vào, giờ ra, thời lượng và đơn giá, ví dụ "Giờ chơi · Bàn 3 · 14:05 – 15:35 · 1 giờ 30 phút × 60.000 đ/giờ"; số tiền của dòng là 90.000 đ. Bàn chơi qua ngày thì giờ vào, giờ ra ghi kèm ngày, ví dụ "25/11 11:39 – 26/11 12:01".
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

### Báo cáo tính giờ (giờ đông khách, theo bàn)
Mở module **Báo cáo** → tab **"Doanh thu"**, chọn **"Hôm nay"**, **"Tuần này"** hoặc **"Tháng này"** (bấm ‹ › để lùi / tới kỳ khác), kéo xuống cuối tới khối **"Các hoạt động tính giờ"** (chỉ có khi quán bật module này; ai xem được Báo cáo thì xem được). Tuần / tháng đang chạy chỉ tính tới hôm nay:
- **"Lượt chơi"**, **"Giờ chơi"**, **"Tiền giờ"**, **"Món kèm"** (đồ ăn uống gọi thêm trong các lượt đó), kèm trung bình mỗi lượt và tiền giờ chiếm bao nhiêu phần trăm.
- **"Giờ đông khách"**: mỗi cột là một giờ trong ngày, cột cao là nhiều bàn có khách; dòng trên ghi giờ đông nhất và trung bình bao nhiêu phần trăm số bàn có khách giờ đó. Dùng để chọn giờ đặt giá cao / khuyến mãi giờ vắng.
- **"Theo ngày"**: tiền giờ (vàng) và món kèm (xanh) từng ngày.
- **"Theo bàn"**: số lượt, giờ chơi, giờ chơi trung bình mỗi ngày, tiền giờ, tiền món của từng bàn / sân / phòng.

Chỉ tính lượt đã thanh toán, theo ngày thanh toán; bàn huỷ không tính. Số tiền là trước giảm giá và phụ thu của hoá đơn, nên có thể lệch nhẹ với doanh thu ở màn Báo cáo.

### Đặt trước sân, bàn, phòng
Khách gọi điện đặt sân, đặt bàn bi da, đặt phòng hát trước thì ghi ở đâu:
1. Ở màn Các hoạt động tính giờ bấm nút **"Lịch đặt"** (hoặc nút tờ lịch ở góc trên màn Quản lý Bàn).
2. Chọn ngày bằng mũi tên hai bên, hoặc bấm vào ngày để chọn trên lịch.
3. Lịch mở dạng **lưới**: cột bên trái là giờ, mỗi bàn / sân / phòng một cột, lượt đặt là khối màu (xanh đậm = đã đặt, xanh lá = khách đã đến; lượt đã huỷ hoặc không đến không chiếm ô, trừ khi còn cọc chưa xử lý); hôm nay có vạch đỏ ở giờ hiện tại. Trên lưới có dòng gợi ý. Chạm vào **ô trống** ở đúng bàn và giờ muốn đặt (làm tròn theo nửa giờ): app mở hộp đặt đã điền sẵn bàn và giờ. Hoặc bấm nút **"+ Đặt lịch"** ở góc dưới, chọn bàn / sân: app mở hộp đặt ở nửa giờ kế tiếp (ngày khác hôm nay thì 18:00), sửa giờ trong hộp. Nhiều bàn hơn bề ngang màn thì vuốt ngang để xem.
4. Hộp đặt ghi tên bàn, ngày và giá giờ, ví dụ "Đặt A 2 · Thứ 7, 28/11 · 60.000 đ/giờ". Mục **Khách**: gõ tên hoặc số điện thoại vào ô **"Tìm tên, SĐT hoặc gõ khách mới"**. Khách có sẵn hiện ngay bên dưới, chạm để chọn. Khách chưa có thì cứ gõ tên, app hiện thêm ô **"Số điện thoại (để gọi nhắc)"** (gõ số trước thì app hỏi **"Tên khách mới"**). Ô tìm còn trống thì có vài khách đặt gần đây, chạm là điền luôn. Đã chọn khách thì bấm **"Đổi"** để chọn lại. Sửa lượt đặt mà khách đã cọc thì không đổi khách được.
5. Mục **Giờ**: hai ô **"Bắt đầu"** và **"Kết thúc"**, bấm **−** / **+** để lùi hoặc thêm 30 phút, bấm vào số giờ để chọn giờ khác. Chọn giờ kết thúc sớm hơn giờ bắt đầu thì app hiểu là qua nửa đêm, ô ghi **"Kết thúc · hôm sau"**. Hàng **30'**, **1 giờ**, **1g30**, **2 giờ**, **3 giờ** chọn nhanh thời lượng.
6. Dải lịch dưới phần giờ hiện các lượt đã đặt của bàn trong ngày (xanh đậm = đã đặt, xanh lá = khách đã đến) và khung **"Lượt này"**. Trống thì ghi "Trống, không trùng lượt nào · tạm tính 60.000 đ" (tiền giờ tạm tính theo giá của bàn, gồm khung giá, ngày lễ). Trùng thì khung chuyển đỏ và ghi ví dụ "Trùng Chị Lan 19:00–20:00 · đổi giờ hoặc chọn bàn khác".
7. Mục **Thêm (không bắt buộc)**: **Tiền cọc**, **Lặp lại hàng tuần**, **Ghi chú**, chạm dòng nào thì dòng đó mở ra. Bấm nút dưới cùng, ví dụ **"Đặt A 2 · 21:00 – 22:00"**; bấm **✕** ở góc trên để đóng không đặt.

Muốn xem kiểu cũ (mỗi bàn một thẻ, có nút **"Đặt"**) thì bấm nút ở góc trên bên phải (**"Xem dạng danh sách"**); bấm lại để về lưới. Chạm ô giờ đã qua thì app báo "Giờ này đã qua".

Hai lượt đặt không được trùng giờ trên cùng một bàn; đặt sát giờ nhau thì được. Lịch đặt hiện các bàn có giá giờ; quán chưa đặt giá giờ cho bàn nào thì hiện mọi bàn.

### Nhận tiền cọc khi khách đặt
Tiền cọc nằm trong **ví của khách** (module Khách hàng), vào Thu Chi ngay lúc nhận, và tự trừ khi thanh toán bàn.
1. Trong hộp đặt chọn khách ở mục **Khách** (gõ tìm hoặc chạm khách đặt gần đây). Khách mới thì gõ tên và số điện thoại: lúc đặt app tự tìm khách theo số đó, chưa có thì tạo khách mới.
2. Chạm dòng **"Tiền cọc"**, gõ số ở ô **"Số tiền cọc"** hoặc chạm nhanh **100.000**, **200.000**, **500.000**; chọn **"Tiền mặt"** hoặc **"Chuyển khoản"**. Trên nút hiện dòng tạm tính, ví dụ "Tạm tính 60.000 đ · cọc 200.000 đ".
3. Bấm **"Đặt A 2 · nhận cọc …"**. Ví khách cộng số cọc (không tặng thưởng như gói nạp ví), lịch sử ví ghi "Cọc đặt Sân 1 · 03/12 18:00", Thu Chi có phiếu thu "Cọc đặt sân: tên khách" đúng quỹ tiền mặt hoặc ngân hàng.

Không lấy cọc thì để dòng Tiền cọc ghi "Không cọc", không cần chọn khách. Lịch cố định chỉ cọc một lần cho cả lịch, trừ vào buổi đầu tiên khách đến. Lượt đã có cọc thì không đổi số cọc và không đổi khách được nữa.

### Thanh toán bàn của khách đã cọc
Khách đặt đã đến và bàn đã nhận lượt đặt: bấm Thanh toán như thường. Màn Thu tiền tự điền khách đã đặt (không đổi được), ghi **"Tổng hoá đơn"**, **"Đã cọc (ví tên khách) −…"** và số to **"KHÁCH TRẢ THÊM"**. Mã QR chuyển khoản và ô tiền khách đưa tính theo số khách trả thêm.

Ví dụ cọc 200.000 đ, bàn 480.000 đ: khách trả thêm 280.000 đ. Đơn hàng và báo cáo doanh thu ghi đủ 480.000 đ. Thu Chi có 200.000 đ lúc nhận cọc và 280.000 đ lúc thanh toán, cọc không bị tính hai lần. Màn thanh toán xong ghi "Đã trừ ví khách 200.000 đ · khách trả thêm 280.000 đ".

Khách còn tiền trong ví (nạp ví trước) thì bật **"Trả bằng ví khách (số dư …)"** ở ô khách hàng để trả nốt phần còn lại bằng ví.

### Gộp bàn khi bàn có cọc
Gộp bàn của khách đã cọc vào bàn khác: cọc tự theo sang bàn mới, app báo "Đã mang cọc … sang bàn mới", thanh toán bàn mới sẽ tự trừ cọc. Nếu bàn mới đã có cọc của một khách khác thì cọc không mang sang (tránh trừ nhầm ví); xử lý cọc đó trong **Lịch đặt** → lượt đặt → **"Xử lý tiền cọc"**.

### Khách huỷ hoặc không đến khi đã cọc
Bấm **"Huỷ lượt đặt"** hoặc **"Khách không đến"** ở lượt có cọc, app hỏi **"Tiền cọc … xử lý thế nào?"**:
- **"Để trong ví khách"**: tiền nằm lại trong ví, lần sau khách trả bằng ví. Chọn sẵn khi khách báo huỷ.
- **"Quán giữ cọc"**: trừ ví, lịch sử ví ghi mất cọc; Thu Chi không đổi vì tiền đã thu lúc đặt. Chọn sẵn khi khách không đến.
- **"Hoàn cọc"**: trừ ví và ghi phiếu chi "Hoàn cọc đặt sân" đúng quỹ đã nhận. Chỉ Chủ quán hoặc Quản lý chọn được.

Bấm **"Để sau"** thì cọc vẫn trong ví; lúc khác chạm lượt đặt đó chọn **"Xử lý tiền cọc …"**. Lịch cố định: huỷ riêng một buổi thì cọc giữ cho các buổi sau; huỷ hết các buổi còn lại thì app mới hỏi xử lý cọc.

Hồ sơ khách (module Khách hàng) có thêm **"Ví"**, mục **"Đặt sân · … lượt"** (cọc đang giữ, từng lượt đặt và cọc đã trừ / giữ / hoàn) và **"Lịch sử ví"**.

### Đặt lịch cố định hàng tuần cho khách quen
Khách thuê sân cố định, ví dụ thứ 3 và thứ 5 từ 18 giờ đến 20 giờ cả tháng:
1. Mở hộp đặt như mục trên (chạm ô trống trên lưới Lịch đặt), chọn khách, giờ bắt đầu và thời lượng của một buổi.
2. Bật công tắc ở dòng **"Lặp lại hàng tuần"**.
3. Chọn các thứ (bấm T2 … CN), chọn **"Đến ngày"**: **"4 tuần"**, **"8 tuần"**, **"Hết tháng này"**, **"Hết tháng sau"**, **"3 tháng"** hoặc bấm ngày để chọn trên lịch.
4. Xem dòng đếm, ví dụ "8 buổi · T3, T5 · 18:00–20:00 · 03/12 → 26/12", và các buổi đầu bên dưới ("T3 03/12", "T5 05/12"…), rồi bấm **"Đặt 8 buổi"**. Có giá giờ thì trên nút ghi tạm tính cả lịch, ví dụ "Tạm tính 8 buổi · 960.000 đ".

Có buổi trùng giờ với lượt đặt khác thì app hiện danh sách buổi trùng (ngày, giờ, trùng với khách nào): bấm **"Bỏ qua, đặt … buổi còn lại"** để đặt các buổi không trùng, hoặc **"Chọn lại"** để sửa. Tối đa 120 buổi một lần, trong vòng một năm. Trên lưới, buổi thuộc lịch cố định có biểu tượng hai mũi tên vòng.

Chạm một buổi thuộc lịch cố định, hộp ghi ví dụ "Lịch cố định · buổi 2/8 · T3, T5 · tới 26/12". Huỷ: **"Huỷ riêng buổi này"**, hoặc **"Huỷ buổi này và các buổi sau"** — app hỏi lại kèm số buổi sẽ huỷ và từ ngày nào tới ngày nào; buổi khách đã đến và các buổi trước giữ nguyên. Sửa giờ một buổi: chạm buổi đó → **"Sửa lượt đặt"**.

### Khách đặt trước đã đến
Cách 1: trong Lịch đặt bấm vào lượt đặt, chọn **"Khách đã đến: nhận …"**. App mở bàn và đồng hồ chạy.
Cách 2: ở sơ đồ bàn bấm vào bàn có dòng "Đặt 18:00 • tên khách". App hỏi ai đang nhận bàn: chọn tên khách đặt nếu khách đặt đã đến, hoặc **"Khách khác"**.

### Tiền giờ của khách đặt trước
Tính theo khung đã đặt. Đến trễ vẫn tính từ giờ đặt. Về sớm vẫn tính tới hết khung. Chơi quá khung thì tính thêm theo phút tới lúc thanh toán. Đến sớm thì tính từ lúc đến. Khi đang tính theo khung, thẻ bàn ở màn Các hoạt động tính giờ ghi "tính đủ khung đặt" (màn Bàn ghi "khung đặt …").

### Sửa, huỷ lượt đặt, khách không đến
Trong Lịch đặt bấm vào lượt đặt, chọn **"Sửa lượt đặt"**, **"Huỷ lượt đặt"** hoặc **"Khách không đến"**. Huỷ hoặc ghi không đến thì khung giờ đó trống lại. Lượt đã nhận (khách đã đến) thì không sửa, không huỷ được nữa.

### Nhắc gọi khách trước giờ đặt
Còn 30 phút tới giờ đặt, app bật hộp **"Sắp tới giờ đặt"** kèm chuông, ghi bàn, giờ, tên và số điện thoại khách. Bấm **"Gọi khách"** để gọi, rồi bấm **"Đã nhắc"**. Một người bấm "Đã nhắc" thì máy khác không nhắc nữa, và lịch ghi giờ đã nhắc. Hộp nhắc chỉ hiện khi app đang mở; app đang tắt thì không có thông báo. Lượt đặt khi còn dưới 30 phút tới giờ thì không nhắc.

## Lỗi thường gặp
| Thấy gì trên màn hình | Vì sao | Làm gì |
|---|---|---|
| Khối tính giờ trong Báo cáo ghi "Chưa có lượt chơi nào được thanh toán trong kỳ này." | Chưa thanh toán bàn tính giờ nào trong kỳ đã chọn | Chọn "Tuần này" / "Tháng này" hoặc bấm ‹ để xem kỳ trước |
| "Đã lưu lượt đặt, nhưng chưa nhận được cọc: …" | Lượt đặt đã ghi nhưng bước nhận cọc lỗi (mất mạng, máy chủ chưa có tiền cọc vào ví khách) | Bấm lại nút đặt trong hộp đó (chỉ làm phần cọc); hoặc chạm lượt đặt → "Sửa lượt đặt" để nhập cọc |
| "Máy chủ chưa có tiền cọc vào ví khách. Báo chủ app cập nhật máy chủ." | Máy chủ của quán chưa được nâng cấp phần cọc | Báo chủ app; trong lúc chờ đặt không cọc |
| "Nhận cọc cần khách hàng: chọn khách hoặc nhập số điện thoại" | Có tiền cọc mà chưa có khách | Chọn khách hoặc nhập số điện thoại |
| "Chưa đọc được tiền cọc của bàn. Kiểm tra mạng rồi bấm Thanh toán lại." | Mất mạng lúc mở màn Thu tiền | Kiểm tra mạng rồi bấm Thanh toán lại |
| "Bàn này có tiền cọc trong ví khách. Cập nhật app để thanh toán …" | Máy đó chưa cập nhật app, chưa biết trừ cọc | Cập nhật app rồi thanh toán, hoặc thanh toán ở máy đã cập nhật |
| "Còn buổi chờ khách: huỷ lượt đặt trước rồi mới xử lý cọc" | Lịch cố định còn buổi chưa tới | Cọc giữ cho các buổi sau; huỷ hết các buổi còn lại rồi xử lý cọc |
| "Máy chủ chưa có lịch cố định. Báo chủ app cập nhật máy chủ." | Máy chủ của quán chưa được nâng cấp phần đặt lặp hàng tuần | Báo chủ app; trong lúc chờ đặt từng buổi (tắt "Lặp lại hàng tuần") |
| "Bàn mới đã có cọc của khách khác nên cọc … chưa mang sang…" khi gộp bàn | Gộp bàn có cọc thường tự mang cọc sang bàn mới; bàn mới đã có cọc của khách khác thì không mang để khỏi trừ nhầm ví | Vào **Lịch đặt** → chạm lượt đặt của bàn cũ → **"Xử lý tiền cọc"** (để trong ví / quán giữ / hoàn) |
| Huỷ bàn đã nhận khách có cọc, cọc chưa trừ | Cọc gắn với lượt đặt của bàn đã huỷ | Vào **Lịch đặt** → chạm lượt đó → **"Xử lý tiền cọc"** |
| "Bàn của lượt này đang mở: thanh toán bàn sẽ tự trừ cọc" | Bấm xử lý cọc khi bàn vẫn đang có khách | Không cần làm gì: thanh toán bàn đó sẽ trừ cọc |
| "Máy chủ chưa có gói giờ. Báo chủ app cập nhật máy chủ." | Máy chủ của quán chưa được nâng cấp phần gói giờ | Báo chủ app; trong lúc chờ tính theo giờ như thường |
| "Đổi hoặc bỏ gói đã chọn cần Chủ quán / Quản lý" | Bàn đã có gói, tài khoản không phải Chủ quán hay Quản lý | Nhờ Chủ quán hoặc Quản lý đổi gói |
| "Gói không còn ở bàn này" | Gói vừa bị xoá hoặc sửa trong "Đặt giá giờ" | Đóng hộp, bấm "Chọn gói" lại |
| Không thấy nút "Chọn gói" trong khối ĐANG TÍNH GIỜ | Bàn chưa có gói nào | Giữ lâu vào bàn → "Đặt giá giờ" → "Gói giờ" để thêm |
| "Máy chủ chưa có ngày lễ. Báo chủ app cập nhật máy chủ." | Máy chủ của quán chưa được nâng cấp phần ngày lễ | Báo chủ app; trong lúc chờ không dùng khung "Ngày lễ" |
| Khung ngày lễ không áp, dòng "Quán chưa có ngày lễ nào" màu đỏ | Chưa thêm ngày lễ cho quán | Bấm "Thêm" / "Thêm ngày lễ của quán" rồi thêm ngày |
| "Mỗi lần chọn tối đa 15 ngày liền." | Chọn khoảng ngày quá dài trên lịch | Chọn ngắn hơn, thêm nhiều lần |
| "Chỉ Chủ quán / Quản lý sửa được ngày lễ" | Tài khoản không phải Chủ quán hay Quản lý | Nhờ Chủ quán hoặc Quản lý thêm ngày lễ |
| "Máy chủ chưa có khung giá giờ. Báo chủ app cập nhật máy chủ." | Máy chủ của quán chưa được nâng cấp phần khung giá / làm tròn | Báo chủ app; trong lúc chờ vẫn đặt được giá một giờ như cũ (để phần "Giá theo giờ & làm tròn" ở mặc định) |
| Giữ lâu vào bàn không thấy "Đặt giá giờ" | Quán chưa bật module Các hoạt động tính giờ, hoặc bàn đang có khách | Bật module Các hoạt động tính giờ; đợi bàn trống rồi giữ lâu lại |
| "Chỉ Chủ quán / Quản lý đặt được giá giờ" | Tài khoản không phải Chủ quán hay Quản lý | Nhờ Chủ quán hoặc Quản lý đặt giá giờ |
| "Bàn đang có khách tính giờ, tính tiền xong mới đổi giá giờ được" | Bàn đang chạy giờ | Tính tiền bàn đó rồi đổi |
| Bấm Lưu giá giờ báo "Chưa lưu được giá giờ. Kiểm tra mạng rồi thử lại." | Máy mất mạng lúc tạo món giá giờ | Kiểm tra mạng rồi bấm Lưu lại |
| Nút "Lưu giá giờ" bị mờ | Chưa gõ giá, hoặc giá dưới 1.000 đ | Gõ giá một giờ từ 1.000 đ trở lên |
| "Giờ chơi cần tính lại (chưa chốt hoặc đã chốt quá 15 phút). Đóng màn thanh toán rồi bấm Thanh toán lại." | Màn Thu tiền để mở quá 15 phút, hoặc máy đó chưa cập nhật app | Đóng màn Thu tiền, bấm Thanh toán lại; máy chưa cập nhật thì cập nhật app |
| "Chưa chốt được giờ: …" khi bấm Thanh toán | Mất mạng lúc chốt giờ | Kiểm tra mạng rồi bấm Thanh toán lại |
| Bấm sửa số lượng dòng tiền giờ, app báo "Dòng tiền giờ" | Tiền giờ do hệ thống tính theo đồng hồ | Muốn bỏ tiền giờ thì Quản lý huỷ dòng đó |
| Thẻ bàn không hiện đồng hồ dù bàn có giá giờ | Bàn được mở trước khi đặt giá giờ | Lượt khách đó không tính giờ; lượt mở bàn sau sẽ tính |
| Đặt trước báo "Trùng giờ với lượt đặt của …" | Khung giờ đã có người đặt trên bàn đó | Chọn giờ khác hoặc bàn khác |
| Đặt trước báo "Khung giờ này đã qua" | Giờ kết thúc đã qua | Chọn lại giờ |
| Bàn có cả dòng "Tiền giờ … đ" gọi như món lẫn dòng tiền giờ lúc thanh toán (thu hai lần) | Dòng gọi như món được thêm từ thực đơn trước khi app giấu món giá giờ | Bấm thùng rác ở dòng "Tiền giờ … đ" đang "Chưa gửi" rồi mới Thanh toán |
| Bàn không hiện ở màn Các hoạt động tính giờ | Bàn chưa có giá giờ và khu của bàn không mang biểu tượng ngành | Vào màn Bàn, giữ lâu vào bàn, chọn "Đặt giá giờ" |
| Không thấy hộp nhắc trước giờ đặt | App đang tắt, lượt vừa đặt khi còn dưới 30 phút, hoặc đã có người bấm "Đã nhắc" | Mở app ở máy quầy trong giờ bán; xem dòng "đã nhắc" trong Lịch đặt |
| Lượt đặt ghi "Đã nhận" vẫn giữ khung giờ dù khách đã về | Khung đã đặt được giữ tới hết giờ | Đặt khách khác vào sau giờ kết thúc của khung đó |

## Liên quan module khác
- **Quản lý Bàn**: tính giờ chạy ngay trên sơ đồ bàn, gọi món, gửi bếp, chuyển, gộp, thanh toán như bàn thường.
- **Kho hàng**: món giá giờ ("Tiền giờ …", danh mục "Tiền giờ") nằm trong Kho hàng, app tự tạo khi đặt giá giờ; giá bán là giá một giờ. Món này không hiện trong thực đơn **Thêm món** và màn **Bán hàng**: không gọi tiền giờ như món, app tự thêm dòng tiền giờ lúc bấm Thanh toán.
- **Báo cáo**: tiền giờ là một dòng trong hoá đơn, vào doanh thu và tab Sản phẩm.
- **Bếp**: dòng tiền giờ không lên phiếu bếp.

## Ghi chú cho Chủ Quán (không đưa cho khách)
1. Bài viết theo mã ở nhánh `feature/ai-bum-ui` ngày 24/11/2026, **chưa phát hành**. Chỉ đăng bài này cho Boom khi bản app có module này đã tới tay quán, nếu không Boom sẽ chỉ khách dùng thứ họ chưa có.
2. Kế hoạch và nhật ký: `.docs/ke-hoach-ban-tinh-gio.md`.
3. Chưa có: khách tự đặt qua mạng, thông báo đẩy khi app tắt. Máy chủ đợt 1, 3, 4, 6, 7 (khung giá, lịch cố định, tiền cọc, ngày lễ, gói giờ) ĐÃ ÁP 28/11. Nhắc hết gói theo từng máy, máy nào mở app cũng nhắc. Bill và phiếu tạm tính bàn có cọc ghi "Đã cọc (ví khách)" và "CÒN PHẢI TRẢ".
4. Cách gọi "bàn / phòng / sân" theo loại hình mới lưu trong `loai_hinh.dart`, chữ trên màn Bàn vẫn ghi "bàn".
5. Đã thử thật trên máy ảo + quán Demo 28/11: đặt có cọc → nhận khách → thanh toán trừ cọc, sửa lượt đặt, lịch cố định huỷ cả lịch + hoàn cọc, gói giờ + chuyển bàn, gộp hai bàn đang tính giờ, báo cáo Doanh thu khớp máy chủ. Chưa kiểm: in bill 58mm trên máy in thật, màn Bếp.
6. Máy chủ: `ban_chot_gio_v1`, `ban_chuyen_ban_tinh_gio_v1`, bảng `ban_dat_truoc` và 4 hàm `ban_dat_truoc_*`.
