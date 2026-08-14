# Snapshot Runtime Schema & Scope Integrity Audit (Phase 0C)
File: `supabase/qr_v3_runtime_schema_snapshot.md`  
Date: 13/08/2026  
Status: **PHASE 0 PRODUCTION METADATA VERIFIED — STAGING STILL BLOCKED — READY TO DESIGN PHASE 1 CONTRACT**

---

## 1. Môi Trường & Trạng Thái Worktree Git

### 1.1 Git Worktree Status (`git status --short`) [`CONFIRMED_FROM_CODE`]
Worktree có 5 file bẩn có sẵn trước nhiệm vụ và 1 file snapshot của Phase 0C được cập nhật:
```text
 M .docs/Ai_Bum/Ai_Bum.md
 M .docs/Ai_Bum/xu-ly-data.md
 M nhat_ky.md
?? .docs/Ai_Bum/cac-module/ai-bum.md
?? ke-hoach-fix-qr-antigravity.md
?? supabase/qr_v3_runtime_schema_snapshot.md
```
- **Cam kết bảo vệ worktree:** 0 database write, 0 migration execution, 0 deploy, 0 commit/push, 0 format project.

### 1.2 Trạng Thái Môi Trường (Staging & Production)
- **Staging Database (`quannho-staging.lpm.vn`):** **`BLOCKED_STAGING`** [`UNVERIFIED_STAGING`]
  - Kết quả tra cứu DNS: `[Errno 8] nodename nor servname provided, or not known`. Tên miền Staging chưa phân giải DNS, chưa thể kết nối.
- **Production REST Endpoint (`https://quannho.lpm.vn/supabase/rest/v1/`):** [`CONFIRMED_REST_BEHAVIOR`]
  - Web POS `/pos/`: HTTP 200 OK.
  - Legacy Route `/goi-mon`: HTTP 404 Not Found.
  - REST RPC Query: HTTP 404 `PGRST202` (`REQUESTED_RPC_SIGNATURE_NOT_FOUND_IN_POSTGREST_CACHE`).
  - REST Table Query: HTTP 404 `PGRST205` cho các bảng QR (`NOT_EXPOSED_OR_NOT_IN_SCHEMA_CACHE`).
- **Production PostgreSQL Catalog (`pg_catalog` / `information_schema`):** **`CONFIRMED_PG_CATALOG`**
  - Đã truy cập Supabase Studio SQL Editor của project `default` ngày 13/08/2026.
  - Truy vấn xác nhận `current_database() = postgres`, `current_user = postgres`, `transaction_read_only = on`.
  - Tất cả truy vấn catalog đều chạy trong `BEGIN TRANSACTION READ ONLY`, đặt `statement_timeout = 10s` và kết thúc bằng `ROLLBACK`.
  - Không chạy DDL, DML, migration, GRANT/REVOKE hoặc deploy.

---

## 2. Phân Tích Kỹ Thuật Chuẩn Xác (Phase 0C Clarifications)

### 2.1 Action Permissions Source
- **Phân loại:** `CONFIRMED_PG_CATALOG` và `CONFIRMED_FROM_CODE`.
- **Xác minh:** Bảng `app_settings` (`key = 'action_perms_{role}'`) là **`CANONICAL_PERMISSION_CANDIDATE`** được xác nhận từ mã nguồn Flutter ([`StaffService.dart:L1487-L1503`](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/core/services/staff_service.dart#L1487-L1503)).
- **Xác nhận catalog:** `staff_members` và `store_members` thực sự không có cột `actions` hoặc `modules`; đây không phải hiện tượng bị che bởi PostgREST column privilege.
- **Nguyên tắc khóa contract:** `app_settings` với key `action_perms_{role}` là nguồn permission canonical hiện tại. SQL resolver phải dùng role đã được token xác minh, ưu tiên exact role key rồi mới canonical role fallback; owner/manager override phải đồng nhất với Flutter.

### 2.2 Phân Tích Ba Thế Hệ Mã Pickup Code
- **Thế hệ V3 ([`20260731_create_qr_public_rpc_v3.sql`](file:///Users/banhbao/Quan%20Nho/quan_nho/supabase/migrations/20260731_create_qr_public_rpc_v3.sql#L427-L434)):** RPC `submit_qr_order_v3` hiện tại **bỏ hẳn** việc sinh, chèn (insert) và trả về `pickup_code`.
- **Thế hệ Legacy MVP ([`migration_qr_ordering.sql:L204-L208`](file:///Users/banhbao/Quan%20Nho/quan_nho/supabase/migration_qr_ordering.sql#L204-L208)):** Dùng `SELECT COALESCE(COUNT(*), 0) + 1` không có lock.
- **Thế hệ Legacy V2 ([`migration_kay_public_ordering_v2.sql:L364-L370`](file:///Users/banhbao/Quan%20Nho/quan_nho/supabase/migration_kay_public_ordering_v2.sql#L364-L370)):** Dùng `SELECT COALESCE(COUNT(*), 0) + 1` kết hợp với transaction-level advisory lock `pg_advisory_xact_lock(...)`.
- **Đánh giá rủi ro:** Bản V2 tuy có advisory lock nhưng vẫn **chưa có unique database constraint guarantee** cho `pickup_code`. Contract mới trong Phase 1 bắt buộc thiết kế cơ chế cấp mã atomic nguyên tử và constraint chống trùng phù hợp tại database level.

### 2.3 SQL & Flutter Test Inventory
- **SQL Integration Test Suite:**
  - **`NO_EXECUTABLE_QR_SQL_INTEGRATION_TEST_SUITE_FOUND`**
  - Các file `staging_seed_test_data.sql`, `staging_cleanup_test_data.sql`, `staging_verification_checklist.md` chỉ là script dữ liệu mẫu và checklist tài liệu, không phải là test suite tự động thực thi có assertion.
- **Flutter Test Suite:**
  - **`NO_QR_SPECIFIC_FLUTTER_TESTS_FOUND`**
  - Chưa có unit test suite riêng nào cho `qr_order` hoặc `PosDeviceTokenService` trong thư mục `test/`.

### 2.4 Production Object Existence (`CONFIRMED_PG_CATALOG`)

Catalog `public` xác nhận các object QR V3 sau **không tồn tại** trên Production:

- Tables: `qr_channels`, `qr_requests`, `qr_request_items`, `qr_audit_logs`, `product_topping_links`, `pos_device_sessions`, `store_pairing_codes`, `pos_auth_attempts`.
- Functions: toàn bộ public/customer RPC, staff RPC, token helpers và permission helper đã liệt kê trong draft V3, gồm cả `get_qr_menu_v3`, `submit_qr_order_v3`, `get_qr_request_status_v3`, `issue_pos_device_session_v3`, `get_pending_qr_requests_v3`, `claim_qr_request_v3`, `reject_qr_request_v3`, `confirm_qr_request_v3`, `send_to_kitchen_qr_v3`, `verify_pos_token_internal` và `check_pos_staff_action_permission`.

Các bảng lõi cần cho QR đều tồn tại: `products`, `ban_dining_tables`, `ban_sessions`, `ban_session_items`, `orders`, `order_items`, `kitchen_tickets`, `kitchen_ticket_items`, `staff_members`, `store_members`, `app_settings`, `stores`, `devices`, `user_accounts`.

Kết luận: Phase 1 phải thiết kế một **clean forward installation** cho QR V3 trên Production schema hiện hữu, không được giả định migration QR Legacy/V2/V3 đã từng chạy.

### 2.5 Production Canonical Types (`CONFIRMED_PG_CATALOG`)

| Object | Kiểu/cột quan trọng đã xác nhận | Tác động lên contract QR |
|---|---|---|
| `ban_dining_tables` | `id text`, `zone_id text`, `name text`, `capacity int4`; đồng thời còn compatibility columns `label text`, `seats int8` | `qr_channels.table_id` và `qr_requests.table_id` phải dùng `text` để tham chiếu đầy đủ bàn hiện hữu. Không được khai báo FK UUID vào bảng này. |
| `ban_sessions` | `id uuid`, `table_id uuid`, không có FK từ `table_id` sang `ban_dining_tables` | Dispatch phải preflight/cast table ID có kiểm soát; không dùng `TRIM(uuid)`. Hai bàn đang có ID không phải UUID cần chiến lược data repair riêng trước khi bật QR cho chúng. |
| `ban_session_items` | `product_id uuid`, `quantity numeric`, `modifiers_json text` | RPC phải cast/serialize đúng schema thật, không tự đổi core column sang JSONB trong QR migration. |
| `products` | `id uuid`, `sell_price numeric`, `station_code text`, các cờ `is_available`, `is_active`, `is_deleted`, `is_topping` | Public RPC phải tính giá và station từ server. Giá trị station runtime gồm `bep_bar`, `bep_nong`, `nong`; cần normalize về contract in/bếp hiện hành. |
| `orders` | `id/store_id/device_id/staff_id uuid`, `source_id text`, `total numeric`, `status text` | QR request ID có thể lưu vào `source_id` dạng text; actor staff/device phải dùng UUID đã xác minh. |
| `order_items` | `product_id uuid`, `qty int4`, `quantity numeric`, `modifiers_json text` | RPC phải theo compatibility columns hiện có và test tổng tiền. |
| `kitchen_tickets` | `session_id uuid`, `round int4`, `station_code text` | Chưa có unique constraint `(session_id, round)`; Phase 2 phải bổ sung preflight + unique constraint và locking đúng. |
| `kitchen_ticket_items` | `product_id text`, `qty int4`, `quantity numeric`, `modifiers_json text`, `station_code text` | Draft V3 đang giả định kiểu không hoàn toàn đúng; contract phải map rõ từng field. |
| `staff_members` | `id/store_id uuid`, `role text`, `is_active bool`; không có `actions/modules` | Không được query `staff_members.actions/modules`. |
| `store_members` | `user_id/store_id uuid`, `role text`, `is_owner bool`; không có `actions/modules` | Xác minh owner/membership tại đúng store trước override. |
| `app_settings` | `store_id uuid`, `key text`, `value text`, unique `(store_id,key)` | Settings và role action permissions là JSON encode trong text, không phải JSONB. |

### 2.6 Constraints, Indexes và Runtime Data Quality (`CONFIRMED_PG_CATALOG`)

- Không có FK giữa `ban_sessions.table_id` và `ban_dining_tables.id` do lệch kiểu UUID/text.
- Không có unique constraint đảm bảo chỉ một `ban_sessions(status='open')` cho mỗi `(store_id, table_id)`.
- Không có unique constraint `(session_id, round)` trên `kitchen_tickets`.
- Runtime hiện có `0` nhóm duplicate open session và `0` nhóm duplicate ticket round, nên có thể thêm constraint/repair theo preflight mà chưa phải dọn duplicate hiện hữu.
- Có 105 bàn: 103 ID có dạng UUID và 2 ID không phải UUID; cả 2 bàn non-UUID đang active và chưa có `qr_token`.
- Station runtime: `bep_bar` 109 sản phẩm, `bep_nong` 89 sản phẩm, `nong` 12 sản phẩm.
- Permission settings hiện có exact-role keys như `action_perms_Quản Lý`, `action_perms_Thu ngân`, `action_perms_Phục Vụ`, `action_perms_Barista` và một số vai trò tùy chỉnh. SQL resolver không được chỉ lowercase/canonicalize rồi bỏ qua exact key.

### 2.7 RLS và Grants Liên Quan (`CONFIRMED_PG_CATALOG`)

- Các core tables được kiểm tra hiện grant `SELECT/INSERT/UPDATE/DELETE` cho cả `anon`, `authenticated` và `service_role`.
- Nhiều core tables có permissive policy `ALL USING (true)`, gồm `app_settings`, `ban_sessions`, `orders`, `order_items`, `kitchen_tickets`, `kitchen_ticket_items`, `products`; `store_members` hiện chưa bật RLS.
- Đây là security debt cấp hệ thống đã tồn tại trước QR và **không được âm thầm sửa trong QR migration**, vì POS Custom Auth hiện có thể phụ thuộc các grants/policies này.
- Riêng các bảng QR V3 mới phải fail-closed ngay từ lúc tạo: không direct CRUD cho `anon`; public chỉ được execute đúng customer RPC, staff chỉ thao tác qua token-verified RPC.

---

## 3. Danh Sách Mã Nguồn, Điểm Tích Hợp & Inventory Chi Tiết

### 3.1 Code Flutter Module QR (`lib/modules/qr_order/`) [`CONFIRMED_FROM_CODE`]
1. **Models:**
   - [`lib/modules/qr_order/models/qr_order_model.dart`](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/modules/qr_order/models/qr_order_model.dart)
2. **Providers & Repositories:**
   - [`lib/modules/qr_order/providers/qr_order_providers.dart`](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/modules/qr_order/providers/qr_order_providers.dart)
   - [`lib/modules/qr_order/repository/qr_order_repository.dart`](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/modules/qr_order/repository/qr_order_repository.dart)
3. **Screens & Tabs:**
   - [`lib/modules/qr_order/screens/qr_order_screen.dart`](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/modules/qr_order/screens/qr_order_screen.dart)
   - [`lib/modules/qr_order/screens/customer_qr_order_screen.dart`](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/modules/qr_order/screens/customer_qr_order_screen.dart)
   - [`lib/modules/qr_order/screens/table_qr_print_screen.dart`](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/modules/qr_order/screens/table_qr_print_screen.dart)
   - [`lib/modules/qr_order/screens/counter_qr_print_screen.dart`](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/modules/qr_order/screens/counter_qr_print_screen.dart)
   - [`lib/modules/qr_order/screens/tabs/batch_table_print_tab.dart`](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/modules/qr_order/screens/tabs/batch_table_print_tab.dart)
   - [`lib/modules/qr_order/screens/tabs/counter_qr_design_tab.dart`](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/modules/qr_order/screens/tabs/counter_qr_design_tab.dart)
   - [`lib/modules/qr_order/screens/tabs/pos_device_session_card.dart`](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/modules/qr_order/screens/tabs/pos_device_session_card.dart)
   - [`lib/modules/qr_order/screens/tabs/qr_settings_tab.dart`](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/modules/qr_order/screens/tabs/qr_settings_tab.dart)
   - [`lib/modules/qr_order/screens/tabs/table_qr_list_tab.dart`](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/modules/qr_order/screens/tabs/table_qr_list_tab.dart)
4. **Services & Widgets:**
   - [`lib/modules/qr_order/services/qr_pdf_service.dart`](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/modules/qr_order/services/qr_pdf_service.dart)
   - [`lib/modules/qr_order/services/qr_sound_service.dart`](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/modules/qr_order/services/qr_sound_service.dart)
   - [`lib/modules/qr_order/widgets/qr_counter_queue_sheet.dart`](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/modules/qr_order/widgets/qr_counter_queue_sheet.dart)
   - [`lib/modules/qr_order/widgets/qr_order_review_sheet.dart`](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/modules/qr_order/widgets/qr_order_review_sheet.dart)
5. **Token Core Service:**
   - [`lib/core/services/pos_device_token_service.dart`](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/core/services/pos_device_token_service.dart)

### 3.2 Điểm Tích Hợp Hệ Thống [`CONFIRMED_FROM_CODE`]
- **Main ([`lib/main.dart`](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/main.dart)):** L97-L103 (Global `badCertificateCallback`), L155 (`/qr_order` route), L159-L166 (Deep-link query parameter `code` mở `CustomerQrOrderScreen`).
- **Dashboard ([`lib/screens/dashboard_screen.dart`](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/screens/dashboard_screen.dart)):** L2220-L2221 (Push route `/qr_order` sang `QrOrderScreen`).
- **POS ([`lib/screens/pos_screen.dart`](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/screens/pos_screen.dart)):** L23-L26 (Imports), Header badge `⚡ QR Quầy (N) #Q01`, mở `QrOrderReviewSheet` / `QrCounterQueueSheet`.
- **Bàn ([`lib/screens/ban_screen.dart`](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/screens/ban_screen.dart)):** L49-L50 (Imports), `_PulsingTableBorder`, Badge `⚡ QR (N món)`, mở `QrOrderReviewSheet`.
- **Settings ([`lib/screens/settings_screen.dart`](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/screens/settings_screen.dart)):** L21 (Import), Mở tab cài đặt QR Order.
- **Module Tile ([`lib/core/repositories/module_repository.dart`](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/core/repositories/module_repository.dart#L29), [`lib/shared/widgets/module_tile.dart`](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/shared/widgets/module_tile.dart#L146-L152)):** Khai báo module `'qr_order'`.
- **Auth & Staff ([`lib/core/services/user_auth_service.dart`](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/core/services/user_auth_service.dart#L1243-L1270), [`lib/core/services/staff_service.dart`](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/core/services/staff_service.dart)):** Xóa session context khi logout (chưa gọi `clearTokenSession()`), tra cứu action permissions (chưa bổ sung `qr_order.*`).

### 3.3 Inventory File SQL & Test Trong Repo [`REPO_DRAFT_ONLY`]
- **Migration V3 Canonical Drafts:**
  - `supabase/migrations/20260731_create_pos_device_sessions.sql`
  - `supabase/migrations/20260731_create_qr_public_rpc_v3.sql`
  - `supabase/migrations/20260731_create_qr_staff_rpc_v3.sql`
  - `supabase/migrations/20260731_qr_permissions_v3.sql`
  - `supabase/migrations/20260731_qr_audit_and_constraints_v3.sql`
  - `supabase/migrations/20260801_fix_qr_menu_response_v3.sql`
- **Hotfix / Legacy Scripts:**
  - `supabase/migration_qr_ordering.sql` (Legacy MVP)
  - `supabase/migration_kay_public_ordering_v2.sql` (Legacy V2)
  - `supabase/migrations/phase1_versions_bugs.sql`
- **Rollback Scripts:**
  - `supabase/migrations/rollback_qr_architecture_v3.sql`
  - `supabase/rollback_kay_public_ordering_v2.sql`
- **Preflight Scripts:**
  - `supabase/staging_schema_preflight_pos_qr.sql`
  - `supabase/staging_v3_dependency_preflight.sql`
  - `supabase/staging_v3_prerequisites.sql`
- **SQL Integration Tests:**
  - **`NO_EXECUTABLE_QR_SQL_INTEGRATION_TEST_SUITE_FOUND`**
- **Flutter QR Unit Tests:**
  - **`NO_QR_SPECIFIC_FLUTTER_TESTS_FOUND`**

---

## 4. Quan Sát Qua REST API & Phân Loại Độ Tin Cậy

### 4.1 Quan Sát Đối Tượng Bảng Qua REST API

| Bảng | Trạng Thái PostgREST Endpoint | Phân Loại Độ Tin Cậy | Ghi Chú Kỹ Thuật |
|---|---|---|---|
| `qr_channels` | `NOT_EXPOSED_OR_NOT_IN_SCHEMA_CACHE` | `CONFIRMED_REST_BEHAVIOR` | REST trả HTTP 404 (`PGRST205`); `pg_catalog` xác nhận table `MISSING`. |
| `qr_requests` | `NOT_EXPOSED_OR_NOT_IN_SCHEMA_CACHE` | `CONFIRMED_REST_BEHAVIOR` | REST trả HTTP 404 (`PGRST205`); `pg_catalog` xác nhận table `MISSING`. |
| `qr_request_items` | `NOT_EXPOSED_OR_NOT_IN_SCHEMA_CACHE` | `CONFIRMED_REST_BEHAVIOR` | REST trả HTTP 404 (`PGRST205`); `pg_catalog` xác nhận table `MISSING`. |
| `pos_device_sessions` | `NOT_EXPOSED_OR_NOT_IN_SCHEMA_CACHE` | `CONFIRMED_REST_BEHAVIOR` | REST trả HTTP 404 (`PGRST205`); `pg_catalog` xác nhận table `MISSING`. |
| `product_topping_links` | `NOT_EXPOSED_OR_NOT_IN_SCHEMA_CACHE` | `CONFIRMED_REST_BEHAVIOR` | REST trả HTTP 404 (`PGRST205`); `pg_catalog` xác nhận table `MISSING`. |
| `products` | `EXISTS_IN_REST_SCHEMA_CACHE` | `CONFIRMED_REST_BEHAVIOR` | Cột quan sát qua REST JSON: `id`, `store_id`, `name`, `sku`, `category`, `unit`, `product_type`, `sell_price`, `cost_price`, `stock_qty`, `min_stock`, `is_available`, `is_active`, `is_deleted`, `updated_at`, `created_at`, `station_code`, `is_raw_material`, `ingredient_category`, `cost_price_latest`, `unit_cooking`, `image_path`, `image_url`, `is_topping`, `topping_unit`, `version`. |
| `ban_dining_tables` | `EXISTS_IN_REST_SCHEMA_CACHE` | `CONFIRMED_REST_BEHAVIOR` | Bảng phản hồi HTTP 200; `pg_catalog` xác nhận table tồn tại với `id text`. |
| `ban_sessions` | `EXISTS_IN_REST_SCHEMA_CACHE` | `CONFIRMED_REST_BEHAVIOR` | Cột quan sát qua REST JSON: `id`, `store_id`, `table_id`, `status`, `opened_at`, `closed_at`, `total`, `total_amount`, `guest_count`, `waiter_id`. |
| `kitchen_tickets` | `EXISTS_IN_REST_SCHEMA_CACHE` | `CONFIRMED_REST_BEHAVIOR` | Cột quan sát qua REST JSON: `id`, `store_id`, `order_id`, `station_code`, `status`, `note`, `created_at`, `updated_at`, `session_id`, `table_label`, `zone_label`, `round`, `station_id`, `sent_at`, `started_at`, `done_at`. |
| `kitchen_ticket_items` | `EXISTS_IN_REST_SCHEMA_CACHE` | `CONFIRMED_REST_BEHAVIOR` | Cột quan sát qua REST JSON: `id`, `store_id`, `ticket_id`, `name`, `qty`, `status`, `kitchen_note`, `station_code`, `session_item_id`, `modifiers_json`, `free_note`, `edit_history_json`, `started_at`, `done_at`, `product_name`, `quantity`, `done`, `product_id`. |
| `staff_members` | `EXISTS_IN_REST_SCHEMA_CACHE` | `CONFIRMED_REST_BEHAVIOR` | Cột quan sát qua REST JSON: `id`, `store_id`, `name`, `role`, `pin_hash`, `avatar_color`, `phone`, `hourly_rate`, `is_active`, `updated_at`, `created_at`. |
| `store_members` | `EXISTS_IN_REST_SCHEMA_CACHE` | `CONFIRMED_REST_BEHAVIOR` | Cột quan sát qua REST JSON: `id`, `user_id`, `store_id`, `role`, `is_owner`, `created_at`. |
| `app_settings` | `EXISTS_IN_REST_SCHEMA_CACHE` | `CONFIRMED_REST_BEHAVIOR` | Cột quan sát qua REST JSON: `id`, `store_id`, `key`, `value`. |

### 4.2 Quan Sát Hàm RPC Qua PostgREST
Truy vấn RPC 13 hàm (`get_qr_menu`, `submit_qr_order`, `get_qr_request_status`, `claim_qr_request`, `get_qr_menu_v3`, `submit_qr_order_v3`, `get_qr_request_status_v3`, `issue_pos_device_session_v3`, `get_pending_qr_requests_v3`, `claim_qr_request_v3`, `reject_qr_request_v3`, `confirm_qr_request_v3`, `send_to_kitchen_qr_v3`) đều trả về lỗi HTTP 404 `PGRST202`:
- **Phân loại:** `REQUESTED_RPC_SIGNATURE_NOT_FOUND_IN_POSTGREST_CACHE` [`CONFIRMED_REST_BEHAVIOR`].

---

## 5. Xác Minh Route Trình Duyệt & Deep-Link

- **URL Public Customer Route (`https://quannho.lpm.vn/pos/#/qr_order?code=QC_INVALID_TEST`):** **`FAIL_CONFIRMED_BROWSER_ROUTE`**
  - Đã mở bằng trình duyệt render thật ngày 13/08/2026.
  - URL bị chuyển thành `https://quannho.lpm.vn/pos/#/auth` và hiển thị màn Đăng nhập Quán Nhỏ POS.
  - `CustomerQrOrderScreen` không được mở; query `code` không đến được customer flow.
  - Nguyên nhân cần xử lý trong Phase 3: `initialRoute: '/'`/Splash auth redirect đang thắng deep-link. Public QR route phải được resolve trước auth gate.
- **Legacy Web Route (`https://quannho.lpm.vn/goi-mon`):** [`CONFIRMED_REST_BEHAVIOR`]
  - Web Server trả về HTTP 404 Not Found.

---

## 6. Danh Sách Drift Chi Tiết & Bằng Chứng Mã Nguồn

| Drift / Vấn Đề Kỹ Thuật | Phân Loại Độ Tin Cậy | File & Dòng Mã Nguồn Thể Hiện Lỗi |
|---|---|---|
| **Global `badCertificateCallback => true`** | `CONFIRMED_FROM_CODE` | [`lib/main.dart:L93-L103`](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/main.dart#L93-L103) ghi đè `HttpOverrides.global` cho phép chấp nhận mọi SSL cert không an toàn ở bản release. |
| **Token QR không purge khi logout/đổi store** | `CONFIRMED_FROM_CODE` | `PosDeviceTokenService.clearTokenSession()` định nghĩa tại [`lib/core/services/pos_device_token_service.dart:L112`](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/core/services/pos_device_token_service.dart#L112), nhưng [`UserAuthService.logout()`](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/core/services/user_auth_service.dart#L1243-L1270) **KHÔNG** gọi hàm này. |
| **Fallback `#Q01` cứng trong mã nguồn** | `CONFIRMED_FROM_CODE` | [`lib/modules/qr_order/models/qr_order_model.dart:L31, L33, L56, L59, L288`](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/modules/qr_order/models/qr_order_model.dart#L288) (`return '#Q01'`), [`lib/modules/qr_order/screens/customer_qr_order_screen.dart:L748`](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/modules/qr_order/screens/customer_qr_order_screen.dart#L748) (`_pickupCode ?? "#Q01"`), [`lib/modules/qr_order/services/qr_pdf_service.dart:L229`](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/modules/qr_order/services/qr_pdf_service.dart#L229). |
| **`saveSettings` nuốt lỗi / báo thành công giả** | `CONFIRMED_FROM_CODE` | [`lib/modules/qr_order/repository/qr_order_repository.dart:L93-L96`](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/modules/qr_order/repository/qr_order_repository.dart#L93-L96) bọc `catch` và chỉ `debugPrint`, không throw hoặc return error status. |
| **Settings Table/Counter chưa được Public RPC enforce** | `REPO_DRAFT_ONLY` | RPC `get_qr_menu_v3` và `submit_qr_order_v3` chưa kiểm tra hai key canonical `is_table_enabled` và `is_counter_enabled`. |
| **Reject SQL chặn trạng thái `confirmed`** | `REPO_DRAFT_ONLY` | [`supabase/migrations/20260731_create_qr_staff_rpc_v3.sql:L728`](file:///Users/banhbao/Quan%20Nho/quan_nho/supabase/migrations/20260731_create_qr_staff_rpc_v3.sql#L728) `IF v_req.status NOT IN ('pending_staff', 'processing')` chặn reject khi đơn đã ở `confirmed`. |
| **Price change làm đơn kẹt ở `confirmed`** | `REPO_DRAFT_ONLY` | Nếu giá sản phẩm thay đổi sau khi đơn ở `confirmed`, `send_to_kitchen_qr_v3` thăng hoa exception, trong khi `reject_qr_request_v3` từ chối từ `confirmed`, khiến đơn bị kẹt vĩnh viễn. |
| **`TRIM()` gọi trực tiếp trên UUID `table_id`** | `REPO_DRAFT_ONLY` | [`supabase/migrations/20260731_create_qr_staff_rpc_v3.sql:L984`](file:///Users/banhbao/Quan%20Nho/quan_nho/supabase/migrations/20260731_create_qr_staff_rpc_v3.sql#L984) gọi `TRIM(v_req.table_id)` gây lỗi type casting với kiểu UUID. |
| **Không đồng nhất kiểu `modifiers_json`, `subtotal`, UUID/TEXT** | `REPO_DRAFT_ONLY` | Giữa `migration_qr_ordering.sql`, `migration_kay_public_ordering_v2.sql` và `20260731_*_v3.sql`, `table_id` bị lệch giữa `UUID` và `TEXT`, `modifiers_json` lệch giữa `TEXT` và `JSONB`. |
| **Counter không sinh pickup code thật trên server** | `REPO_DRAFT_ONLY` | RPC `submit_qr_order_v3` bỏ hẳn `pickup_code`, MVP dùng `COUNT(*)+1` không lock, V2 dùng `COUNT(*)+1` với `pg_advisory_xact_lock` nhưng chưa có DB unique guarantee. |
| **Kitchen Station hardcode `nong`** | `REPO_DRAFT_ONLY` | RPC `send_to_kitchen_qr_v3` hardcode station `nong` thay vì đọc `products.station_code`. |
| **Thiếu lock chống concurrency cho session & round** | `REPO_DRAFT_ONLY` | `send_to_kitchen_qr_v3` chưa serialize theo parent session/advisory lock và production chưa có unique constraint `(session_id, round)` hoặc unique open-session guard. Chỉ thêm `FOR UPDATE` vào `MAX(round)` là không đủ. |
| **Polling chưa pause/background/backoff** | `CONFIRMED_FROM_CODE` | [`lib/modules/qr_order/providers/qr_order_providers.dart:L40-L100`](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/modules/qr_order/providers/qr_order_providers.dart#L40-L100) chạy Timer polling cố định, chưa pause khi app vào background hoặc áp dụng exponential backoff. |
| **Flutter Idempotency Key không giữ ổn định qua retry** | `CONFIRMED_FROM_CODE` | [`CustomerQrOrderScreen`](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/modules/qr_order/screens/customer_qr_order_screen.dart) sinh `idempotency_key` mới cho mỗi lần bấm nút thay vì giữ nguyên key cho cùng một giỏ hàng khi bấm thử lại. |
| **Thiếu Unit Test riêng cho QR & Token Service** | `CONFIRMED_FROM_CODE` | Báo cáo chính xác: **`NO_QR_SPECIFIC_FLUTTER_TESTS_FOUND`** trong toàn bộ cây thư mục `test/`. |

---

## 7. Kết Luận Phase 0 và Gate Sang Phase 1

- Production metadata: **PASS — `CONFIRMED_PG_CATALOG`**.
- Production browser route: **FAIL — redirect sang `/#/auth`**.
- Staging: **vẫn `BLOCKED_STAGING`**; chưa được phép chạy migration hay integration test.
- Database writes trong đợt audit: **0**.
- Migration executions: **0**.
- Deploy/commit/push: **0**.

Phase 1 được phép bắt đầu ở phạm vi **chỉ viết `supabase/qr_v3_canonical_contract.md`**, dựa trên catalog production đã xác minh. Chưa được viết migration/Flutter hoặc deploy. Contract phải chốt clean-install strategy, type mapping, state machine, permissions, pickup allocation, table-ID compatibility, session/round locking và test matrix trước khi Phase 2 bắt đầu.
