# Kế Hoạch Triển Khai QR Order Theo Kiến Trúc Mới

> Lập ngày 2026-08-26. Chưa bắt đầu triển khai và chưa apply migration.

Tài liệu giao việc chi tiết cho Antigravity: `ke-hoach-qr-antigravity-v4.md`.

## Mục tiêu nghiệm thu

- Một QR TABLE_SHARED và một QR COUNTER cho mỗi cửa hàng.
- Mỗi lần khách gửi đơn tạo đúng một request và một order.
- QR bàn giao động claim một lần; hai nhân viên quét đồng thời chỉ một người thành công.
- TABLE chỉ biết bàn sau khi nhân viên quét và chọn bàn; sau đó xuất hiện đúng trên module Bàn.
- COUNTER không bao giờ gửi Bếp khi chưa thanh toán.
- Nhân viên dùng account/membership hiện tại, không có pairing/POS device session riêng.
- Retry/crash/mất phản hồi không tạo trùng order, payment, kitchen ticket, stock movement hoặc finance record.

## Giai đoạn 0 — Baseline và quyết định migration

1. Xác minh trên Supabase production rằng toàn bộ migration QR V3 chưa apply.
2. Chụp schema contract hiện tại của các bảng core liên quan: `orders`, `order_items`, `ban_sessions`, `ban_session_items`, `kitchen_tickets`, payment, finance và stock.
3. Chốt cách migration:
   - Ưu tiên thay/squash bộ migration QR V3 chưa apply thành một chuỗi migration mới sạch.
   - Chỉ viết compatibility migration nếu phát hiện staging/production đã có một phần V3.
4. Chốt thời hạn QR bàn giao động trong khoảng 15–30 phút.

Điều kiện qua cổng: có bằng chứng schema thật và không còn giả định migration đã apply.

## Giai đoạn 1 — Schema, RLS và RPC contract

1. Chuyển `qr_channels` sang unique channel theo `(store_id, type)` với `table_shared` và `counter`.
2. Bổ sung liên kết duy nhất `qr_requests.order_id`; unique source guard trong `orders`.
3. Thêm token bàn giao hash/expiry/single-use và index phục vụ claim.
4. Thiết kế audit chỉnh sửa, claim, gán bàn, từ chối và payment transition.
5. RPC public: tải menu; submit idempotent/tính giá authoritative; đọc trạng thái bằng tracking token.
6. RPC nhân viên dùng auth/membership hiện hành: claim handoff token; sửa item; gán bàn/session; confirm; reject; kitchen dispatch idempotent.
7. RPC COUNTER payment gate chỉ chấp nhận actor có `pos.checkout`.

Kiểm thử bắt buộc: schema contract, RLS cross-store, token replay/expiry, double claim, submit retry, unique order và permission denial.

## Giai đoạn 2 — Web khách

1. Một route/channel cho TABLE_SHARED và một cho COUNTER.
2. Giữ menu, topping, ghi chú và giá authoritative hiện có; bỏ giả định TABLE có `table_id` từ channel.
3. Sau submit thành công, render QR bàn giao động và mã dự phòng ngắn nếu cần hỗ trợ camera.
4. Hiển thị trạng thái: chờ nhân viên, đang xác nhận, đã gán bàn/đã thanh toán, đã gửi Bếp, bị từ chối hoặc hết hạn.
5. COUNTER hiển thị lựa chọn thanh toán theo cấu hình nhưng không báo paid nếu chưa có xác nhận authoritative.

Kiểm thử bắt buộc: refresh trang, submit double-tap, mất mạng sau response, QR hết hạn và không lộ ID nội bộ.

## Giai đoạn 3 — App nhân viên và module Bàn

1. Thêm scanner QR bàn giao trong app Flutter, xin quyền camera đúng lúc và có fallback nhập mã/mở hàng chờ.
2. Sau claim TABLE, mở sheet chọn bàn từ `ban_dining_tables` đúng store.
3. Mở review editor: chỉnh số lượng, topping, ghi chú, xóa/thêm món; hiển thị chênh lệch giá và xác nhận lại.
4. Gắn order vào `ban_session` bằng RPC server; invalidate/realtime để thẻ bàn hiển thị ngay.
5. Gửi Bếp bằng kitchen commit idempotent.
6. COUNTER mở hàng chờ Thu ngân nếu actor không có `pos.checkout`.
7. Gỡ `PosDeviceSessionCard` và thay mọi call `PosDeviceTokenService` trong QR bằng auth/membership chính thức; không ảnh hưởng cấu hình máy in theo `device_id`.

Kiểm thử bắt buộc: Android/iOS camera, hai điện thoại cùng quét, chọn nhầm rồi đổi bàn trước commit, bàn vừa đóng/mở bởi thiết bị khác, app bị kill sau claim và phục hồi active request.

## Giai đoạn 4 — Checkout, kho, tài chính và in Bếp

1. TABLE checkout lấy toàn bộ order hợp lệ chưa thanh toán của `ban_session`; không tạo lại order QR.
2. COUNTER transaction đi qua `awaiting_payment → paid → sent_kitchen` và kiểm tra `pos.checkout` server-side.
3. Payment, finance, stock/COGS và trạng thái order phải idempotent; lỗi side effect không được báo hoàn tất giả.
4. Kitchen ticket unique theo order/dispatch key; retry sau timeout reconcile ticket hiện có.
5. Nhãn Bếp giữ bàn cho TABLE và pickup code cho COUNTER.

Kiểm thử bắt buộc: thanh toán toàn bàn nhiều order, retry payment/dispatch, crash tại từng boundary, chuyển khoản chưa xác nhận, bán âm kho và `is_available=false`.

## Giai đoạn 5 — Dọn legacy, tài liệu và pilot

1. Xóa UI in QR riêng từng bàn và thay bằng poster TABLE_SHARED.
2. Xóa migration/RPC/table pairing QR không còn dùng sau khi xác nhận không có consumer khác.
3. Cập nhật `maqr.md`, kiến trúc data, tính năng và nhật ký theo source/migration đã nghiệm thu.
4. Đồng bộ CodeGraph/Graphify và chạy full test/analyze.
5. Apply staging trước, chạy test SQL concurrency/security, sau đó pilot tại KAY với ít nhất hai điện thoại nhân viên.
6. Chỉ deploy production sau checklist rollback, backup và xác nhận thủ công của người dùng.

## Thứ tự ưu tiên triển khai

1. P0: schema/RPC/auth/claim/idempotency.
2. P0: scanner, gán bàn, module Bàn, COUNTER payment gate.
3. P0: checkout một order, kho/tài chính/kitchen boundary.
4. P1: trải nghiệm QR động, fallback và phục hồi sau crash.
5. P1: dọn UI/PDF QR per-table và hoàn thiện cấu hình poster.
6. P2: webhook/reconciliation thanh toán QR tự động nếu được yêu cầu sau.
