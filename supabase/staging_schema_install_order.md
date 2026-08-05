# Quy Trình Thứ Tự Install Schema & Audit Candidate Baseline Cho Staging
File: `supabase/staging_schema_install_order.md`
Date: 2026-08-01

---

## 1. BẢNG MANIFEST KHỔI TẠO ROLES & SCHEMAS NỘI BỘ SUPABASE (DATABASE INIT ROLES)

Trước khi import schema nghiệp vụ Quán Nhỏ, database Staging Postgres cần được khởi tạo các roles và schema hệ thống Supabase thông qua init scripts (`/docker-entrypoint-initdb.d/`):

| Service Name | Database Role | LOGIN Permission | Password Source | Schema Ownership | Grants & Privileges | Init Script Nguồn |
|---|---|---|---|---|---|---|
| `auth` (GoTrue) | `supabase_auth_admin` | YES | `GOTRUE_DB_DATABASE_URL` | `auth` | Full access schema `auth`, GRANT access `public` | `01-auth-schema.sql` |
| `storage` | `supabase_storage_admin` | YES | `DATABASE_URL` | `storage` | Full access schema `storage` | `02-storage-schema.sql` |
| `rest` (PostgREST) | `authenticator` | YES | `PGRST_DB_URI` | N/A (Proxy role) | `GRANT anon, authenticated TO authenticator` | `00-initial-schema.sql` |
| `realtime` | `supabase_admin` | YES | `DB_USER` / `DB_PASSWORD` | `realtime` | Full access schema `realtime`, publication `supabase_realtime` | `03-realtime-schema.sql` |
| `anon` (Public API) | `anon` | NO | N/A | N/A | SELECT `public` tables qua RLS policies | `00-initial-schema.sql` |
| `authenticated` | `authenticated` | NO | N/A | N/A | SELECT/INSERT/UPDATE `public` tables qua RLS policies | `00-initial-schema.sql` |

---

## 2. BẢNG AUDIT DEPENDENCY & SCHEMA DRIFT NỀN QUÁN NHỎ (ĐƠN BẢNG)

Mỗi bảng trong Quán Nhỏ có quy chuẩn kiểu dữ liệu riêng (bảng sync offline ưu tiên `bigint` epoch milliseconds, bảng giao dịch dùng `timestamptz`). Cần kiểm tra đơn bảng chi tiết:

| Tên Bảng & Cột (Table.Column) | Kiểu Dữ Liệu Khai Báo Trong `schema.sql` | Kiểu Dữ Liệu Code Flutter Thực Tế (`lib/core/`) | Kiểu Dữ Liệu Baseline Truth | Ghi Chú Audit & Tránh Lỗi Schema Drift |
|---|---|---|---|---|
| `products.updated_at` | `bigint` | `int` (`millisecondsSinceEpoch`) | `bigint` | **`bigint` LÀ ĐÚNG.** Code Flutter (`core_product_repository.dart` & `core_tables.dart`) dùng millisecond timestamp. KHÔNG đổi sang `timestamptz`. |
| `staff_members.updated_at` | `bigint` | `int` (`millisecondsSinceEpoch`) | `bigint` | Tương thích đồng bộ offline Flutter. |
| `qr_requests.created_at` | `timestamptz` | `DateTime` (ISO8601 String) | `timestamptz` | Bảng giao dịch QR dùng `timestamptz DEFAULT now()`. |
| `products.sell_price` | `numeric` | `double` | `numeric` | Tên cột chuẩn là `sell_price` (không dùng `price`). |
| `products.category` | `text` | `String` | `text` | Tên cột chuẩn là `category` (không dùng `category_id`). |
| `qr_channels.type` | `text` | `String` (`table`/`counter`) | `text` | Tên cột chuẩn là `type` (không dùng `channel_type`). |
| `devices.device_role` | `text` | `String` | `text` | Schema `devices(id, store_id, device_name, device_role, last_seen, created_at)`. KHÔNG có `name`, `device_code`, `is_active`. |
| `kitchen_ticket_items` | Nhiều fix scripts | `String` / `int` | Dynamic compat | Hợp nhất lưu cả legacy (`qty`, `name`) & v3 (`quantity`, `product_name`), mặc định `station_code = 'nong'`. |

---

## 3. NGUYÊN TẮC CANDIDATE BASELINE & AUDIT MANDATORY FOR STAGING

- **Khái Niệm Candidate Baseline:** Snapshot schema-only (export từ Production bằng `pg_dump --schema-only --no-owner`) được coi là **Candidate Baseline, chờ Audit**, chưa thể kết luận "chuẩn 100%" trước khi vượt qua 6 mục kiểm định:
  1. Kiểm tra danh sách PostgreSQL Extensions bắt buộc (`pgcrypto`, `uuid-ossp`, `pg_graphql`).
  2. Rà soát lại câu lệnh `ALTER OWNER TO` và `GRANT` phù hợp với roles Staging.
  3. Lọc bỏ 100% hardcoded Production Store IDs, Production domains và secrets.
  4. Lọc bỏ các bảng/trigger xung đột với QR V2 cũ.
  5. Rà soát các triggers/functions xem có chứa dữ liệu tĩnh cố định không.
  6. Loại trừ các schema nội bộ do Supabase tự quản lý (`auth`, `storage`, `realtime`).
- **Lưu Ý An Toàn:** Hiện tại **CHƯA THỰC THI** câu lệnh `pg_dump`.
- **TUYỆT ĐỐI KHÔNG COPY DỮ LIỆU THẬT TỪ PRODUCTION.**
- Chỉ seed 100% dữ liệu giả với Store Test `KAY STAGING TEST` (Store ID: `00000000-0000-0000-0000-000000000099`).

---

## 4. THỨ TỰ THỰC THI SCRIPT CHUẨN TRÊN STAGING DATABASE (STAGING ONLY)

| Bước | Tên File Script | Loại Thao Tác | Mục Đích Thực Thi | Lệnh Kiểm Tra Sau Cài Đặt (Verification Query) |
|---|---|---|---|---|
| **1** | `candidate_baseline_schema.sql` | Candidate Baseline Schema | Import cấu trúc bảng nghiệp vụ sau khi đã pass 6 mục audit | `SELECT data_type FROM information_schema.columns WHERE table_name='products' AND column_name='updated_at';` (Mong đợi: `bigint`) |
| **2** | `supabase/product_topping_links_migration.sql` | Schema Extension | Tạo bảng `product_topping_links` liên kết món & topping | `SELECT count(*) FROM information_schema.tables WHERE table_name='product_topping_links';` |
| **3** | `supabase/staging_seed_test_data.sql` | Seed Fake Data | Seed duy nhất 1 Store Test (`KAY STAGING TEST`, store_id `...0099`) và món/bàn giả | `SELECT store_code FROM public.stores;` (Mong đợi: Duy nhất `KAY-STAGING-TEST`) |
| **4** | `supabase/staging_schema_preflight.sql` | Preflight Verification | Preflight read-only kiểm tra bảng nền đã sẵn sàng | `SELECT verify_staging_preflight('PRE');` (Mong đợi: `PASS`) |
| **5** | `supabase/staging_schema_preflight_pos_qr.sql` | Preflight Verification | Preflight read-only 'PRE' mode cho POS QR V3 | `SELECT verify_staging_preflight('PRE');` (Mong đợi: `PASS`) |
| **6** | `supabase/migrations/20260731_create_pos_device_sessions.sql` | Migration V3 (1/5) | Tạo bảng session token POS, pairing code, brute-force attempt, metadata | `SELECT count(*) FROM information_schema.tables WHERE table_name='pos_device_sessions';` |
| **7** | `supabase/migrations/20260731_qr_permissions_v3.sql` | Migration V3 (2/5) | Tạo helper resolver phân quyền action an toàn | `SELECT proname FROM pg_proc WHERE proname='check_pos_staff_action_permission';` |
| **8** | `supabase/migrations/20260731_create_qr_public_rpc_v3.sql` | Migration V3 (3/5) | Tạo RPCs public cho Khách hàng (`get_qr_menu_v3`, `submit_qr_order_v3`) | `SELECT proname FROM pg_proc WHERE proname='submit_qr_order_v3';` |
| **9** | `supabase/migrations/20260731_create_qr_staff_rpc_v3.sql` | Migration V3 (4/5) | Tạo RPCs xác thực Token POS cho Nhân viên (`bootstrap_first_pos_device_v3`, ...) | `SELECT proname FROM pg_proc WHERE proname='send_to_kitchen_qr_v3';` |
| **10** | `supabase/migrations/20260731_qr_audit_and_constraints_v3.sql` | Migration V3 (5/5) | Tạo index idempotency V3 & CHECK status constraint | `SELECT indexname FROM pg_indexes WHERE indexname='idx_qr_requests_channel_idempotency';` |
