---
module: qr_order
ten: QR Gọi Món
phien_ban: 1.0.5+20
cap_nhat: 2026-10-22
nguon:
  - lib/modules/qr_order/screens/qr_order_screen.dart, tabs/qr_channel_card.dart, tabs/qr_settings_tab.dart, qr_poster_print_screen.dart
  - lib/modules/qr_order/widgets/qr_order_review_sheet.dart, qr_counter_queue_sheet.dart, qr_locked_banner.dart
  - lib/modules/qr_order/screens/customer_qr_order_screen.dart (trang khách)
  - lib/modules/qr_order/providers/qr_order_providers.dart (chuông đơn mới)
  - supabase/migrations/20261013_qr_order_simple_v4.sql, 20261014_qr_chong_pha_v4.sql
  - .docs/qr-rpc-contract-don-gian.md
---

# QR Gọi Món

> Khách quét mã QR, tự chọn món trên điện thoại và gửi đơn. Nhân viên nhận đơn trên app, kiểm tra rồi gửi bếp (tại bàn) hoặc thu tiền rồi gửi bếp (mang đi).

## Ai dùng được
- **Bật/tắt kênh, tạo mã QR mới, cài chuyển khoản, tên miền**: Chủ quán, Quản lý (máy chủ kiểm quyền).
- **Nhận và duyệt đơn**: mọi nhân viên đang hoạt động trong quán, từ màn **Bán hàng** hoặc **Quản lý Bàn**.
- **Thu tiền đơn mang đi**: người có **quyền Thanh toán hoá đơn**. Chủ quán, Quản lý luôn thu được; Thu ngân và các vai trò có module Bán hàng / Quản lý Bàn (kể cả Phục vụ) thu được, trừ khi Chủ quán tắt "Thanh toán hoá đơn" cho vai trò đó. Người khác chỉ xem được và được nhắc chuyển cho thu ngân.
- **Khách**: không cần cài app, không cần tài khoản; mở link từ mã QR trên trình duyệt điện thoại.

## Hai loại mã QR
| | **Tại bàn** | **Mang đi** |
|---|---|---|
| Mã | Một mã dùng chung cho mọi bàn | Một mã đặt ở quầy |
| Khách | Tự chọn số bàn rồi gọi món | Gọi món, nhận **mã lấy món** (#Q01, #Q02…) |
| Nhân viên | **"DUYỆT & GỬI BẾP"** — đơn vào phiên của bàn | Thu tiền rồi **"ĐÃ THU TIỀN & GỬI BẾP"** |
| Thu tiền | Sau, khi thanh toán cả bàn ở **Quản lý Bàn** | Trước khi gửi bếp |

Không in mã riêng cho từng bàn. Không có thanh toán tự động: hiện mã VietQR **không** có nghĩa là đã thu tiền.

## Màn hình "Mã QR gọi món" (Chủ quán / Quản lý)
Mở module **QR Gọi Món** từ Trang chủ. Có hai thẻ kênh: **"Tại bàn"** và **"Mang đi"**, mỗi thẻ có:
- **Công tắc** bật/tắt kênh. Bật lần đầu sẽ tạo mã QR.
- Ảnh mã QR và các nút **"Sao chép link"**, **"Mở thử"**, **"In / Tải PDF"** (chọn khổ **A5** hoặc **A4** rồi in hoặc lưu file).
- Khi kênh bị khoá: khung đỏ **"Mã QR này đang bị khoá"** và nút **"Tạo mã QR mới"**.

Phần cài đặt:
- **"Chuyển khoản tại quầy"** — tài khoản nhận tiền khi khách mang đi chuyển khoản: **"Ngân hàng nhận tiền"**, **"Số tài khoản"** (6–19 chữ số), **"Tên chủ tài khoản"** → **"Lưu"**.
- **"Nâng cao"** — **"Tên miền tùy chỉnh (để trống = mặc định)"**. Chỉ đổi khi có tên miền riêng; **"Dùng mặc định"** để quay lại.

## Các việc thường làm

### 1. Bật QR và dán mã ở quán
1. Mở **QR Gọi Món**, gạt công tắc kênh **Tại bàn** và/hoặc **Mang đi**.
2. Bấm **"Mở thử"** để tự gọi thử một đơn.
3. Bấm **"In / Tải PDF"**, chọn khổ giấy, in và dán: mã Tại bàn ở mỗi bàn (cùng một mã), mã Mang đi ở quầy.
4. Đơn mang đi muốn khách chuyển khoản: điền **"Chuyển khoản tại quầy"** rồi **"Lưu"**.

### 2. Khách gọi món (để hướng dẫn khách)
1. Quét mã QR → trang gọi món của quán.
2. **Tại bàn**: chọn **"BẠN ĐANG NGỒI BÀN NÀO?"** (có ô **"Tìm bàn..."**). Đổi bàn sau: **"Đổi bàn"**.
3. Chọn món. Món có topping: bảng **"CHỌN TOPPING THÊM"** và ô ghi chú (vd: ít đá, không đường) → **"Thêm vào giỏ"**.
4. Mở giỏ → kiểm tra → **"XÁC NHẬN & GỬI ĐƠN HÀNG"**.
5. Trang **"Theo dõi đơn gọi món"** tự cập nhật trạng thái:
   - "Đã gửi, chờ quán xác nhận" → "Quán đã nhận và đang kiểm tra đơn" → "Đơn đã vào bếp" / "Quán đang chuẩn bị món cho bạn".
   - **Mang đi**: hiện **"MÃ LẤY MÓN CỦA BẠN"** và **"Vui lòng ra quầy thanh toán"**.
   - Bị từ chối: "Quán từ chối đơn" kèm lý do.
   - Quá **60 phút** chưa được nhận: "Đơn đã hết hạn".
6. Mất mạng lúc gửi: khách bấm **"GỬI LẠI ĐƠN HÀNG"** — hệ thống **không tạo đơn trùng**.

### 3. Nhận đơn mới (nhân viên)
Khách quét QR gọi món xong, nhân viên nhận đơn ở đây rồi duyệt để món xuống bếp (đơn tại bàn: mục 4; đơn mang đi: mục 5).
1. Có đơn mới: app **kêu chuông** (một lần cho mỗi đơn) và hiện nhãn **"Đơn QR (n)"** trên thanh trên cùng của **Bán hàng**, hoặc nút đơn QR ở **Quản lý Bàn**.
   - Cam: có đơn mới đang chờ. Xanh: đơn đang được xử lý. Xám + biểu tượng mất sóng: mất kết nối, danh sách có thể cũ.
2. Bấm nhãn → danh sách **"Đơn gọi món QR (n)"**: bàn/mã lấy món, số món, tiền, đã chờ bao lâu.
3. Chạm một đơn để mở. Mở đơn = **nhận đơn**: người khác không duyệt trùng được (họ sẽ thấy "Đơn này đã được xử lý ở thiết bị khác.").

### 4. Duyệt đơn tại bàn
1. Kiểm tra **"Bàn khách chọn"**. Khách chọn sai: chọn ở **"Đổi sang bàn khác (nếu khách chọn sai)"**.
2. Kiểm tra món, ghi chú của khách (**"Khách ghi chú: …"**). Sửa số lượng hoặc **"Thêm món"** nếu cần; sửa xong bấm dòng **"Chưa lưu thay đổi món - bấm để lưu"** để tính lại tiền.
3. Bấm **"DUYỆT & GỬI BẾP"** → "Đã gửi bếp đơn <bàn>." Món vào phiên của bàn đó (nhiều đơn QR cùng bàn gộp chung một phiên).
4. Thu tiền sau ở **Quản lý Bàn** như đơn gọi tại bàn bình thường.

### 5. Thu tiền và gửi bếp đơn mang đi
1. Mở đơn, xem **"Mã lấy món: #Qxx"** và nhãn **"CHƯA THANH TOÁN"**.
2. Chọn **"Tiền mặt"** hoặc **"Chuyển khoản"**. Chuyển khoản: app hiện mã VietQR đúng số tiền của tài khoản đã cài — **kiểm tra tiền đã vào** trước khi xác nhận.
3. Bấm **"ĐÃ THU TIỀN & GỬI BẾP"** → "Đã thu tiền và gửi bếp đơn mang đi #Qxx." Hệ thống tạo đơn, ghi thu, trừ kho và gửi bếp trong một lần.
4. Gọi khách theo **mã lấy món** khi món xong.

> Không có quyền thu tiền: app báo "Chuyển thu ngân: tài khoản của bạn không có quyền thu tiền. Hãy nhờ thu ngân mở đơn này để thu tiền và gửi bếp."

### 6. Từ chối đơn
1. Trong đơn bấm **"Từ chối"**.
2. Nhập **"Lý do (khách sẽ thấy)"** (mặc định "Hết món") → **"Từ chối đơn"**.
3. Chỉ từ chối được khi đơn **chưa gửi bếp**.

### 7. Khi mã QR bị khoá (bị quét phá)
- Nếu một kênh nhận **từ 100 lượt gửi trong 1 phút**, hệ thống tự **khoá** kênh đó.
- Nhân viên thấy dải đỏ trên **Bán hàng** và **Quản lý Bàn**: "Có người đang cố tình quét mã QR gọi món để phá quán… Đề nghị chủ quán tạo và in mã QR mới." → bấm **"Xử lý"**.
- Khách quét mã cũ thấy: "Quán tạm ngừng nhận đơn qua mã QR này do có lượt quét bất thường…".
- Chủ quán / Quản lý: **"Tạo mã QR mới"** → đọc cảnh báo → **"Tạo mã mới"** → **in lại và dán thay mã cũ**. Mã cũ không dùng lại được; đơn đang chờ từ mã cũ sẽ hết hạn.

> Ngoài ra có giới hạn theo **địa chỉ mạng (IP)**, không phải theo từng điện thoại: khoảng 12 lần gửi/phút, 60 lần/giờ, tối đa 10 đơn đang chờ cho mỗi IP. Nhiều khách dùng **chung Wi-Fi của quán** thường chung một IP nên có thể chạm giới hạn cùng lúc vào giờ đông. Khách gửi quá nhanh thấy "Bạn thao tác quá nhanh. Vui lòng đợi một lát rồi thử lại." — gợi ý khách chờ một phút hoặc dùng 4G.
> Mỗi kênh cũng giới hạn: tối đa khoảng **15 đơn mới mỗi phút**, giới hạn số đơn chưa ai nhận và số đơn chờ của **một bàn**. Vượt mức, khách thấy "Quán đang nhận quá nhiều đơn, vui lòng thử lại sau ít phút" — nhân viên nên mở/nhận các đơn đang chờ để giải phóng hàng đợi.

## Lỗi thường gặp
| Thấy gì | Vì sao | Làm gì |
|---|---|---|
| Khách: "Liên kết gọi món không hợp lệ" | Mã in sai, hoặc mã cũ đã bị thay | In lại mã từ màn Mã QR gọi món |
| Khách: "Quán tạm ngưng nhận đơn qua QR. Vui lòng gọi nhân viên." | Kênh đang tắt | Bật lại công tắc kênh |
| Khách: "Quán tạm ngừng nhận đơn qua mã QR này do có lượt quét bất thường…" | Kênh bị khoá | Tạo mã QR mới, in và dán lại |
| Khách: "Bạn thao tác quá nhanh. Vui lòng đợi một lát rồi thử lại." | Vượt giới hạn gửi theo IP (nhiều khách chung Wi-Fi quán) | Chờ một phút hoặc dùng 4G |
| Khách: "Quán đang nhận quá nhiều đơn, vui lòng thử lại sau ít phút" | Kênh vượt ~15 đơn/phút hoặc quá nhiều đơn chưa ai nhận / bàn có quá nhiều đơn chờ | Nhân viên mở và xử lý các đơn đang chờ; khách thử lại sau |
| Khách: "Có món đã hết hoặc ngừng bán…" | Món vừa hết / ngừng bán | Khách bỏ món đó khỏi giỏ |
| Khách: "Bàn đã chọn không còn hợp lệ…" | Bàn bị xoá/đổi | Khách chọn lại bàn |
| Khách: "Đơn đã hết hạn" | Quá 60 phút chưa ai nhận | Khách đặt đơn mới; nhân viên chú ý chuông |
| Nhân viên: "Đơn này đã được xử lý ở thiết bị khác." | Người khác đã nhận/duyệt | Đóng đơn, không cần làm gì |
| Nhân viên: "Đơn vừa được cập nhật ở thiết bị khác. Lưu hoặc tải lại để đồng bộ." | Hai người cùng sửa | Lưu hoặc tải lại rồi duyệt |
| Nhân viên: "Vui lòng chọn bàn trước khi gửi bếp." | Đơn tại bàn chưa có bàn | Chọn bàn ở ô đổi bàn |
| Nhân viên: "Mạng không ổn định. Đã tải lại đơn, vui lòng kiểm tra rồi bấm lại." | Mất mạng lúc duyệt | Kiểm tra đơn rồi bấm lại — không bị gửi bếp hai lần |
| "Chưa cấu hình tài khoản VietQR trong mục Thiết lập của module QR." | Chưa cài chuyển khoản | Điền "Chuyển khoản tại quầy" |
| Nhãn "Đơn QR" màu xám | Mất kết nối hàng đợi QR | Kiểm tra mạng; trên máy Android/Sunmi phải đăng nhập lại nếu báo lỗi quyền |

## Liên quan module khác
- **Bán hàng / Quản lý Bàn**: nơi nhận đơn QR và thấy cảnh báo khoá mã.
- **Quản lý Bàn**: thanh toán đơn tại bàn sau khi đã gửi bếp.
- **Bếp**: nhận phiếu khi duyệt.
- **Thu Chi / Kho**: đơn mang đi ghi thu và trừ kho ngay khi bấm "ĐÃ THU TIỀN & GỬI BẾP".
- **In Hoá Đơn**: in poster QR; phiếu bếp theo luật in (hình thức "Đặt qua QR").

## Ghi chú cho Chủ Quán (không đưa cho khách)
1. **Lớp xác minh người thật (Cloudflare Turnstile)** đã có code nhưng đang **tắt**; bật cần tạo site Turnstile rồi đặt khoá trong `qr_security_config` (nhật ký 14/10).
2. Màn Mã QR gọi món dùng màu tím (`0xFF8B5CF6`), khác màu navy/cam của phần còn lại của app.
3. Mã QR "Mang đi" của Bò Đen đã đổi trong lúc test 14/10 — poster cũ không còn dùng (nhật ký 14/10).
4. Topping khách chọn qua QR có, nhưng **POS quầy chưa có topping** (xem bài Bán hàng) — nhân viên tự gọi món cho khách mang đi sẽ không chọn được topping như khách.
5. Giới hạn chống phá (`20261014_qr_chong_pha_v4.sql`): theo IP băm `ip_per_min`=12, `ip_per_hour`=60, `ip_pending`=10 (đổi được trong `qr_security_config`); theo kênh `c_max_per_minute`=15, `c_max_unclaimed`, `c_max_per_table`. Quán đông khách chung Wi-Fi có thể cần nâng `ip_per_min`.
6. "Thu tiền đơn mang đi" kiểm `pos.checkout` trong app (`qr_order_review_sheet.dart` 680/983, **không** có ngoại lệ Thu ngân như `isPrivileged` ở Bàn); module `pos` hoặc `ban` tự cấp quyền này nên Phục vụ mặc định cũng thu được. Chủ quán/Quản lý luôn có đủ quyền (danh sách tắt không áp cho họ).
