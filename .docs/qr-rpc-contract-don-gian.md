# Hợp đồng RPC QR đơn giản hóa (đích triển khai 13/10/2026)

Nguồn: `ke-hoach-don-gian-hoa-qr.md`. Mọi bên (SQL, web khách, app nhân viên, màn Mã QR) bám đúng file này.

## Quy ước chung
- Mọi RPC trả JSON `{success: bool, data: {...}, error_code: text, message: text}`; giữ nguyên các `error_code` hiện có trong `QrErrorCode`, thêm: `TABLE_REQUIRED`, `TABLE_NOT_FOUND`, `NOT_CLAIMER`, `VERSION_CONFLICT`, `PAYMENT_PERMISSION_DENIED`, `RATE_LIMITED`.
- Trạng thái `qr_requests.status` (chỉ 6 giá trị, chữ thường): `submitted` → `claimed` → `sent_kitchen`; nhánh `rejected`, `expired`, `cancelled`.
- COUNTER có thêm `payment_status`: `unpaid` | `paid`. Thu tiền xảy ra trong cùng RPC gửi bếp.
- Loại kênh `qr_channels.type` chuẩn hóa: `TABLE_SHARED`, `COUNTER_TAKEAWAY` (hoa). Mỗi quán tối đa một kênh active cho mỗi loại.
- id bàn là `text` (`ban_dining_tables.id` text). Không có handoff token, không có `table_hint`.
- Khóa chống trùng phía nhân viên do server suy ra từ `request_id`; Dart KHÔNG gửi idempotency key cho claim/approve/pay.

## RPC công khai (anon)
1. `get_qr_channel_info_v4(p_channel_code text)` — giữ nguyên.
2. `get_qr_menu_v4(p_channel_code text)` — như cũ, THÊM `data.tables`: danh sách `[{id text, name text, zone_name text|null}]` các bàn đang dùng của quán (chỉ khi kênh `TABLE_SHARED`; `COUNTER_TAKEAWAY` trả mảng rỗng), và `data.channel_type`.
3. `submit_qr_order_v4(p_channel_code text, p_items jsonb, p_table_id text, p_idempotency_key text, p_payload_hash text)` — TABLE_SHARED bắt buộc `p_table_id` (kiểm bàn thuộc đúng store, lỗi `TABLE_REQUIRED`/`TABLE_NOT_FOUND`); COUNTER bỏ qua `p_table_id`. Giá tính ở server. Giới hạn tần suất và kích thước (≤ 50 dòng, ghi chú ≤ 300 ký tự) → `RATE_LIMITED`. Cùng `p_idempotency_key` trả lại đúng đơn cũ. Trả `data`: `request_id, tracking_token, status, pickup_code (COUNTER), table_id, table_name, total_amount, expires_at`.
4. `get_qr_request_status_v4(p_tracking_token text)` — trả `id, status, payment_status, table_id, table_name, pickup_code, total_amount, reject_reason, expires_at, updated_at`. Đơn `submitted` quá `expires_at` (60 phút) được đánh `expired` khi đọc.

## RPC nhân viên (authenticated, kiểm active membership đúng `p_store_id`)
5. `claim_qr_request_v4(p_request_id uuid, p_store_id uuid)` → `data` = chi tiết đơn (như `get_qr_request_detail_v4`). Atomic `submitted → claimed`, ghi `claimed_by`. Gọi lại bởi chính người đã nhận → trả lại chi tiết (idempotent); người khác → `ALREADY_CLAIMED`.
6. `get_qr_request_detail_v4(p_request_id uuid, p_store_id uuid)` — giữ nguyên, thêm `payment_status, table_id, table_name, version, claimed_by`.
7. `update_qr_order_items_v4(...)` — giữ chữ ký hiện tại; chỉ người đang `claimed_by` (hoặc owner/manager), chỉ khi `status='claimed'`; giữ snapshot món khách gửi ban đầu.
8. `set_qr_order_table_v4(p_request_id uuid, p_store_id uuid, p_table_id text)` — đổi bàn khi `status='claimed'` (thay `assign_qr_order_table_v4`).
9. `approve_and_send_table_v4(p_request_id uuid, p_store_id uuid, p_version int)` — chỉ TABLE; yêu cầu `claimed` + đúng người nhận + `version` khớp; gắn order vào `ban_session` của bàn (khóa theo bàn, không tạo hai phiên mở), tạo vé bếp, → `sent_kitchen`. Gọi lại → trả kết quả cũ. Không thu tiền, không trừ kho.
10. `pay_and_send_counter_v4(p_request_id uuid, p_store_id uuid, p_version int, p_payment_method text)` — chỉ COUNTER; kiểm quyền thu tiền ở server (owner/manager/cashier hoặc modules có `pos` / actions `pos.checkout`, như `verify_staff_qr_membership_v4`) nếu không → `PAYMENT_PERMISSION_DENIED`; tạo order + finance + trừ kho + vé bếp trong một giao dịch → `sent_kitchen`, `payment_status='paid'`. Gọi lại → trả kết quả cũ.
11. `cancel_qr_order_v4(...)` — giữ chữ ký; chỉ khi chưa `sent_kitchen`.
12. `manage_qr_channel_v4(p_store_id, p_type, p_is_active, p_payment_mode)` — giữ; khóa advisory để gọi đồng thời không vỡ unique.
13. Thanh toán bàn TABLE vẫn qua `settle_ban_session_v5` có sẵn (không viết lại).

## RPC bị bỏ
`claim_qr_handoff_v4`, `regenerate_handoff_token_v4`, `assign_qr_order_table_v4`, `mark_qr_order_paid_v4`, `send_qr_order_to_kitchen_v4`, `settle_ban_session_v4`, bảng `qr_handoff_tokens`.

## Pickup code (COUNTER)
Số thứ tự theo ngày của quán (`#Q01…`, không giới hạn 99), `UNIQUE(store_id, pickup_date, pickup_seq)`.
