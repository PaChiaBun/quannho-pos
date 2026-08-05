# Manifest Architecture v3 Schema & RPC Objects
File: `supabase/qr_v3_schema_manifest.md`
Date: 2026-07-31

---

## 1. TÓM TẮT DANH SÁCH MIGRATION FILES (DRAFT CREATED, NOT EXECUTED)

| File Migration | Mục Đích | Bảng / RPC Tác Động | Dependencies | State Rollback | Status |
|---|---|---|---|---|---|
| `20260731_create_pos_device_sessions.sql` | Tạo bảng `qr_v3_migration_metadata` trước tiên, ghi PRE-state immutable (`ON CONFLICT DO NOTHING`), sau đó `ALTER TABLE qr_requests ADD COLUMN`, tạo `pos_store_bootstrap_state`, session token, pairing code, brute-force attempt & composite type `pos_session_info` | `qr_v3_migration_metadata`, `pos_store_bootstrap_state`, `pos_device_sessions`, `store_pairing_codes`, `pos_auth_attempts`, `qr_audit_logs`, `pos_session_info` | `stores`, `devices`, `staff_members`, `user_accounts` | `DROP TABLE` (No CASCADE) | `DRAFT_CREATED_NOT_EXECUTED` |
| `20260731_qr_permissions_v3.sql` | Tạo helper resolver phân quyền action an toàn (JSONB & TEXT JSON parsing, fail-closed, separate user_account_id & staff_id) | `check_pos_staff_action_permission` | `store_members`, `staff_members` | `DROP FUNCTION` | `DRAFT_CREATED_NOT_EXECUTED` |
| `20260731_create_qr_public_rpc_v3.sql` | Tạo RPCs public cho Khách hàng (`get_qr_menu_v3` với topping_links, `submit_qr_order_v3` có server topping validation & channel-scoped idempotency, `get_qr_request_status_v3`) | `get_qr_menu_v3`, `submit_qr_order_v3`, `get_qr_request_status_v3` | `qr_channels`, `products`, `product_topping_links`, `qr_requests`, `qr_request_items` | `DROP FUNCTION` | `DRAFT_CREATED_NOT_EXECUTED` |
| `20260731_create_qr_staff_rpc_v3.sql` | Tạo RPCs xác thực Token POS cho Nhân viên (`bootstrap_first_pos_device_v3` owner-credential-first, `generate_pos_pairing_code_v3`, `pair_pos_device_v3`, `issue_pos_device_session_v3` hỗ trợ quick_pin salted hash, `revoke_pos_device_session_v3`, `get_pending_qr_requests_v3`, `claim_qr_request_v3`, `reject_qr_request_v3`, `confirm_qr_request_v3`, `send_to_kitchen_qr_v3` strict branching) | `verify_pos_token_internal`, `bootstrap_first_pos_device_v3`, `generate_pos_pairing_code_v3`, `pair_pos_device_v3`, `issue_pos_device_session_v3`, `revoke_pos_device_session_v3`, `get_pending_qr_requests_v3`, `claim_qr_request_v3`, `reject_qr_request_v3`, `confirm_qr_request_v3`, `send_to_kitchen_qr_v3` | `pos_device_sessions`, `pos_store_bootstrap_state`, `qr_requests`, `qr_request_items`, `orders`, `order_items`, `ban_sessions`, `ban_session_items`, `kitchen_tickets`, `kitchen_ticket_items` | `DROP FUNCTION` | `DRAFT_CREATED_NOT_EXECUTED` |
| `20260731_qr_audit_and_constraints_v3.sql` | Ghi metadata PRE-state cho indexes/constraints (`ON CONFLICT DO NOTHING`), kiểm tra `indexdef` chính xác trước khi xoá V2 index, tạo V3 index theo `(channel_id, idempotency_key)`, tạo CHECK status constraint (NOT VALID), và hoãn RLS hardening | `chk_qr_requests_status_v3`, `idx_qr_requests_channel_idempotency`, `qr_v3_migration_metadata` | `qr_requests`, `qr_channels`, `qr_request_items` | `DROP CONSTRAINT / INDEX` | `DRAFT_CREATED_NOT_EXECUTED` |
| `rollback_qr_architecture_v3.sql` | Script teardown tổng thể đọc metadata PRE-state để phục hồi chính xác đối tượng legacy (bọc trong `BEGIN; ... COMMIT;`, thực thi preflight metadata validation đứng đầu, xoá V3 index trước cột `idempotency_key`, xoá metadata table ở bước cuối) | Toàn bộ objects v3 | `qr_v3_migration_metadata` | Single master script (No CASCADE) | `STATIC_UNVERIFIED` |

---

## 2. BẢNG PHÂN TÍCH SCHEMAS THỰC TẾ & KHỚP CỘT

| Bảng | Cột Đã Khai Báo Trong Schema Thực Tế | Ghi Chú Khớp Schema v3 |
|---|---|---|
| `devices` | `id`, `store_id`, `device_name`, `device_role`, `last_seen`, `created_at` | Yêu cầu `p_device_id` tồn tại hoặc dùng RPC `bootstrap_first_pos_device_v3` / `pair_pos_device_v3` khởi tạo thiết bị. KHÔNG có `name`, `device_code`, `is_active`. |
| `pos_store_bootstrap_state` | `store_id`, `bootstrapped_at`, `bootstrapped_by`, `initial_device_id` | Bảng lưu trạng thái bootstrap bền vững theo store. |
| `qr_channels` | `id`, `store_id`, `type`, `table_id`, `channel_code`, `name`, `is_active` | Sử dụng cột `type` (`table`/`counter`), KHÔNG dùng `channel_type`. |
| `products` | `id`, `store_id`, `name`, `sku`, `category`, `unit`, `sell_price`, `is_available`, `is_topping`, `is_active`, `is_deleted` | Sử dụng `sell_price` (không dùng `price`) và `category` (không dùng `category_id`). |
| `product_topping_links` | `product_id`, `topping_id`, `sort_order`, `created_at` | Bảng link giữa món chính (`is_topping=false`) và topping (`is_topping=true`). |
| `qr_requests` | `id`, `store_id`, `channel_id`, `table_id`, `type`, `status`, `note`, `total_amount`, `tracking_token`, `idempotency_key`, `claimed_by_user_account_id`, `claimed_by_staff_id` | KHÔNG lưu `items` trực tiếp; chi tiết món được ghi vào `qr_request_items`. |
| `qr_request_items` | `id`, `request_id`, `product_id`, `product_name`, `unit_price`, `quantity`, `modifiers_json`, `note` | Bảng lưu chi tiết các món của đơn QR. `unit_price` lưu giá đơn vị đã bao gồm topping. |
| `orders` | `id`, `store_id`, `device_id`, `staff_id`, `source_type`, `source_id`, `total`, `status`, `note` | Đơn hàng POS/Bàn (`source_type = 'qr_order'`). |
| `order_items` | `id`, `store_id`, `order_id`, `product_id`, `name`, `qty`, `unit_price`, `note`, `kitchen_status` | Chi tiết món hàng của đơn (`unit_price` lưu giá đơn vị gồm topping để `qty * unit_price = total`). |
| `ban_sessions` | `id`, `store_id`, `table_id`, `status`, `guest_count`, `total_amount`, `staff_id`, `pos_order_id`, `note`, `opened_at` | Phiên bàn (`status = 'open'`). Bàn mang đi sử dụng deterministically generated takeaway table UUID cho từng store. |
| `ban_session_items` | `id`, `store_id`, `session_id`, `product_id`, `product_name`, `unit_price`, `quantity`, `subtotal`, `note`, `added_by`, `kitchen_status`, `added_at` | Món phiên bàn (`unit_price` lưu giá gồm topping, `subtotal` = unit_price * quantity). |
| `kitchen_tickets` | `id`, `store_id`, `order_id`, `table_id`, `session_id`, `table_label`, `zone_label`, `round`, `status`, `sent_at` | Phiếu bếp (`status = 'cho'`, `round` tính động từ ticket hiện hữu). |
| `kitchen_ticket_items` | `id`, `store_id`, `ticket_id`, `session_item_id`, `product_id`, `name`, `product_name`, `qty`, `quantity`, `status`, `kitchen_note`, `free_note`, `modifiers_json`, `station_code`, `done` | Món phiếu bếp (`station_code = 'nong'`, trỏ đúng `session_item_id` của món). |

---

## 3. THIẾT KẾ ĐÍCH VÀ QUY TRÌNH KỸ THUẬT V3

### 3.1 Quy Trình Bootstrap Thiết Bị Đầu Tiên & Credential Security Notice
`bootstrap_first_pos_device_v3`:
1. Advisory lock theo store chống race condition.
2. **Xác thực Owner PIN FIRST** qua mảng các store owner (`sm.is_owner IS TRUE`). Người lạ/PIN sai luôn nhận `INVALID_CREDENTIAL`.
3. **Kiểm tra persistent state SECOND** qua bảng `pos_store_bootstrap_state`. Nếu đã tồn tại record bootstrap cho store thì trả `ALREADY_BOOTSTRAPPED`. Trạng thái này bền vững, session expired/revoked không làm mất trạng thái bootstrap.
4. Ghi `devices`, `pos_device_sessions`, và `pos_store_bootstrap_state` trong cùng 1 transaction.

### 3.2 Quy Trình Rollback An Toàn 100% Nguyên Tử
`rollback_qr_architecture_v3.sql` được bọc toàn bộ trong giao dịch `BEGIN; ... COMMIT;`:
- **Bước 1 (Preflight Validation):** Kiểm tra sự tồn tại của bảng `qr_v3_migration_metadata` và 100% metadata keys bắt buộc. Ném `RAISE EXCEPTION` hủy giao dịch ngay lập tức nếu thiếu/sai.
- **Bước 2 (Drop V3 RPC Functions):** Xoá các hàm RPC `_v3`.
- **Bước 3 (Drop V3 Constraints & V3 Indexes):** Xoá index V3 `idx_qr_requests_channel_idempotency` **trước khi** xoá cột `idempotency_key`.
- **Bước 4 (Restore Legacy V2 Index):** Tái tạo V2 index `idx_qr_requests_idempotency_unique` nếu `legacy_v2_idempotency_index_existed = true`.
- **Bước 5 (Drop V3 Columns):** Xoá các cột V3 nếu `existed_before = false`.
- **Bước 6 (Drop V3 Isolated Tables & Composite Type):** Xoá các bảng/type V3 nếu `existed_before = false`.
- **Bước 7 (Drop Metadata Table):** Xoá `qr_v3_migration_metadata` ở bước cuối cùng trước câu lệnh `COMMIT;`.
