# QR Order — Kiến Trúc Mục Tiêu Đã Chốt

> Ngày chốt: 2026-08-26  
> Trạng thái: source/migration V4 đã triển khai local và đang chờ nghiệm thu trên PostgreSQL staging; chưa apply production.  
> Nguồn sự thật hiện hành cho hướng phát triển QR; `maqr.md` mô tả V3 legacy để đối chiếu khi chuyển đổi.

## 1. Quyết định sản phẩm

- Mỗi cửa hàng chỉ cần hai QR tĩnh:
  - `TABLE_SHARED`: một QR gọi món tại bàn dùng chung cho toàn bộ cửa hàng.
  - `COUNTER`: một QR gọi món mang đi tại quầy.
- Không in QR riêng cho từng bàn.
- Mỗi lần khách xác nhận giỏ hàng, server tạo một yêu cầu QR cô lập và một `order_id` chuẩn duy nhất.
- Web khách hiển thị QR bàn giao động cho chính yêu cầu đó. QR động chỉ chứa token ngẫu nhiên một lần, không lộ `request_id`, `order_id`, `table_id` hoặc `store_id`.
- Nhân viên dùng điện thoại cá nhân đã đăng nhập Quán Nhỏ và đã tham gia quán bằng mã quán để quét QR bàn giao.
- Không có bước bootstrap, pairing, PIN hoặc POS device session riêng cho module QR. `device_id` nếu cần chỉ là metadata nội bộ cho audit/idempotency, không phải credential và không tạo thêm thao tác kết nối quán.
- Nhân viên được chỉnh món sau khi claim và trước khi gửi Bếp; server luôn tính lại giá authoritative và lưu audit phần thay đổi.
- Một QR request luôn hội tụ vào đúng một `order_id`; retry không được tạo order, payment hoặc kitchen ticket thứ hai.

## 2. Xác thực và quyền

Luồng nhân viên chính thức:

```text
SĐT + mật khẩu
  → membership trong store_members
  → store_id hiện tại
  → role/modules/actions
  → RPC kiểm tra lại quyền phía server
```

- Mã quán `QN-XXXX` chỉ dùng khi người dùng tham gia quán.
- PIN chỉ dùng cho phê duyệt quản lý theo quy tắc chung, không dùng để ghép thiết bị QR.
- Claim, sửa đơn, gán bàn, gửi Bếp và thanh toán là các action độc lập; UI không phải biên bảo mật.
- Chỉ Thu ngân hoặc vai trò được cấp `pos.checkout` mới được xác nhận thanh toán.
- Mọi RPC nhân viên phải fail-closed nếu account không còn active membership trong đúng `store_id`.

## 3. Luồng TABLE_SHARED

```text
Khách quét QR TABLE_SHARED
  → web tải menu đúng store
  → khách chọn món/topping/ghi chú
  → khách bấm Xác nhận
  → submit RPC tính giá authoritative
  → tạo qr_request + order_id duy nhất, status pending_staff
  → web hiển thị QR bàn giao động
  → nhân viên quét bằng app Quán Nhỏ
  → atomic claim, status processing
  → nhân viên nhập/chọn số bàn từ ban_dining_tables của store
  → đọc lại món với khách và chỉnh sửa nếu cần
  → server tính lại giá, lưu edit audit
  → nhân viên xác nhận gán bàn
  → request xuất hiện ngay trên thẻ bàn trong module Bàn
  → nhân viên bấm Gửi Bếp
  → gắn canonical order/món vào ban_session của bàn
  → kitchen commit idempotent, status sent_kitchen
```

Quy tắc gán bàn:

- Khách không nhập bàn và QR tĩnh không tự nhận diện bàn.
- Chỉ sau khi nhân viên claim QR động mới chọn bàn.
- Danh sách bàn lấy từ server theo `store_id`; không nhận tên bàn dạng text tự do.
- Bàn trống: mở `ban_session` khi xác nhận gán bàn.
- Bàn đang mở: gắn order vào session hiện tại.
- Trước khi gán bàn, request nằm trong hàng chờ QR chung, chưa hiển thị trên một thẻ bàn cụ thể.
- Sau khi gán, thẻ bàn hiển thị request/order và realtime cập nhật trên module Bàn.

Thanh toán TABLE:

- Gửi Bếp không yêu cầu thanh toán trước.
- Khi checkout, thanh toán toàn bộ các order hợp lệ chưa thanh toán thuộc `ban_session`.
- Request chưa claim hoặc chưa gán bàn không được tính vào hóa đơn bàn.
- Mỗi order vẫn giữ actor tạo, claim, sửa, gán bàn và gửi Bếp để audit.

## 4. Luồng COUNTER

```text
Khách quét QR COUNTER
  → đặt món mang đi
  → server tạo qr_request + order_id duy nhất + pickup_code
  → web hiển thị QR bàn giao động
  → khách tới Thu ngân; Thu ngân quét và atomic claim
  → kiểm tra, chỉnh sửa, xác nhận giá
  → khách chọn tiền mặt hoặc chuyển khoản VietQR
  → Thu ngân thu tiền/kiểm tra tiền đã vào và xác nhận thanh toán
  → kitchen commit idempotent
  → gửi Bếp với nhãn Mang đi + pickup_code
```

- COUNTER không chọn bàn, không gắn `ban_session` và không xuất hiện trong module Bàn.
- COUNTER bắt buộc thanh toán thành công trước khi gửi Bếp.
- Cấu hình QR, trạng thái kênh và tài khoản VietQR nằm trực tiếp trong module QR.
- VietQR chỉ hỗ trợ khách thực hiện chuyển khoản tại quầy. Khi chưa có webhook/reconciliation đáng tin cậy, việc hiển thị VietQR hoặc ảnh giao dịch không được coi là đã thanh toán; Thu ngân vẫn phải kiểm tra tiền vào và xác nhận thủ công.
- Người không có `pos.checkout` có thể claim/sửa nếu được cấp quyền, nhưng đơn phải dừng ở `awaiting_payment` và hiển thị trong hàng chờ Thu ngân.

## 5. QR bàn giao động

Token bàn giao phải:

- Có entropy cao, lưu dạng hash ở server và bind với request/order/store.
- Chỉ dùng một lần để claim.
- Có thời hạn ngắn, dự kiến 15–30 phút; thời hạn chính thức chốt khi triển khai.
- Bị vô hiệu ngay sau atomic claim hoặc khi request bị từ chối/hết hạn.
- Không tự gán bàn, tự thanh toán hoặc tự gửi Bếp.
- Có rate limit và audit lần quét thành công/thất bại nhưng không log token thô.
- Có fallback mở request từ hàng chờ chung nếu camera lỗi hoặc khách mất màn hình QR; fallback vẫn gọi cùng atomic claim RPC.

## 6. State machine mục tiêu

Trạng thái chung:

```text
pending_staff
  → processing
  → confirmed
  → sent_kitchen

pending_staff | processing | confirmed
  → rejected | expired
```

COUNTER chèn payment gate:

```text
processing
  → confirmed
  → awaiting_payment
  → paid
  → sent_kitchen
```

Các bất biến:

- Claim phải atomic và chỉ một actor sở hữu request đang xử lý.
- Chỉnh sửa chỉ hợp lệ trước kitchen commit; sau commit dùng luồng hủy món có phê duyệt/audit hiện hành.
- Giá, availability, topping và station được revalidate phía server ngay trước confirm/kitchen commit.
- Sau kitchen commit không rollback ticket nếu có thể gây in trùng; retry chỉ reconcile trạng thái theo khóa idempotency.
- Trừ kho chỉ xảy ra sau thanh toán. Với TABLE trả sau, gửi Bếp không trừ kho; checkout toàn bàn mới ghi stock/COGS/finance.

## 7. Data contract mục tiêu

Các tên cuối cùng phải được xác nhận trong migration, nhưng quan hệ bắt buộc gồm:

- `qr_channels`: tối đa một channel active cho mỗi `(store_id, type)` với type `table_shared` hoặc `counter`; không còn channel per-table.
- `qr_requests`: `store_id`, `channel_id`, `type`, `order_id`, status, totals, pickup code, claimed actor, assigned table/session cho TABLE sau khi nhân viên chọn.
- `qr_request_items`: snapshot khách gửi và phiên bản hiện hành sau chỉnh sửa; audit thay đổi không được ghi đè mất lịch sử.
- `qr_handoff_tokens`: token hash, request/order/store binding, expiry, claimed/revoked timestamps.
- `orders`: một order duy nhất cho mỗi request, unique theo source `qr_order` + request id.
- `ban_sessions`: TABLE order được liên kết sau bước gán bàn.
- Payment/finance/stock/kitchen dùng khóa idempotency hoặc unique constraint theo order/source để chống side effect trùng.

## 8. Hiện trạng V3 cần thay thế

Source hiện tại còn các giả định không đúng mục tiêu:

- Tạo channel/QR riêng từng bàn.
- TABLE request biết `table_id` ngay từ QR tĩnh.
- Nhân viên nhận đơn chủ yếu từ badge/hàng chờ, chưa có camera quét QR bàn giao động.
- `PosDeviceTokenService`, pairing RPC và `PosDeviceSessionCard` tạo một lớp xác thực thiết bị riêng song song với account/membership.
- `send_to_kitchen_qr_v3` tạo order khi gửi Bếp và chưa có payment gate COUNTER khép kín.
- Checkout TABLE có nguy cơ tạo order khác thay vì hoàn tất đúng order QR.

Toàn bộ migration QR V3 chưa apply production, vì vậy phải thay hoặc squash migration trước khi triển khai; không viết migration chồng lên một schema chưa từng được apply rồi báo là đã nâng cấp production.

## 9. Phạm vi không tự động suy diễn

- Chưa có QR Payment tự động hoặc webhook xác nhận chuyển khoản trong phạm vi đã chốt.
- Chưa thay đổi auth tổng thể ngoài việc QR tái sử dụng session/membership hiện hành.
- Chưa deploy, apply migration, build release hoặc push Git.
