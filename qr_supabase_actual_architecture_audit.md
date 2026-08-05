# Audit Kiến Trúc Thực Tế Hệ Thống Auth & Phân Quyền Quán Nhỏ POS (QR Module Alignment)
File: `qr_supabase_actual_architecture_audit.md`
Date: 2026-07-31

---

## 1. MỤC TIÊU AUDIT & HỆ THỐNG PHÂN LOẠI 5 CẤP (TAXONOMY)

Báo cáo này phân tích cơ chế dữ liệu và Auth thực tế của Quán Nhỏ POS (`/Users/banhbao/Quan Nho/quan_nho`). Mọi kết luận được phân loại nghiêm ngặt theo 5 cấp độ:

- **`CONFIRMED_FROM_SCHEMA`**: Đã xác minh từ khai báo DDL SQL trong `schema.sql` hoặc `add_auth_tables.sql`.
- **`CONFIRMED_FROM_CODE_BEHAVIOR`**: Đã xác minh từ logic xử lý mã nguồn Flutter Dart.
- **`CODE_EXPECTATION_NOT_SCHEMA_CONFIRMED`**: Mã nguồn Dart có truy vấn/kỳ vọng cột này, nhưng DDL SQL hiện tại chưa khai báo.
- **`NEEDS_STAGING_VERIFICATION`**: Cần truy vấn metadata thực tế trên cơ sở dữ liệu Staging mới xác nhận được.
- **`PROPOSED_ARCHITECTURE`**: Kiến trúc đề xuất mới cho Architecture v3.

---

## 2. BẢNG ĐỐI CHIẾU DỮ LIỆU CẮT LỚP THỰC TẾ

| Bảng | Các Cột Đã Khai Báo Trong Schema SQL | Phân Loại Cột Schema | Phân Loại Cột Kỳ Vọng Trong Code Dart |
|---|---|---|---|
| `user_accounts` | `id` (uuid), `phone` (text), `password_hash` (text), `display_name` (text), `created_at` (timestamptz) | `CONFIRMED_FROM_SCHEMA` (`add_auth_tables.sql`) | `CONFIRMED_FROM_CODE_BEHAVIOR` (`UserAuthService.dart`) |
| `store_members` | `id` (uuid), `user_id` (uuid), `store_id` (uuid), `role` (text), `is_owner` (boolean), `created_at` (timestamptz) | `CONFIRMED_FROM_SCHEMA` (`add_auth_tables.sql`) | `store_members.actions` / `modules` $\rightarrow$ `CODE_EXPECTATION_NOT_SCHEMA_CONFIRMED` (`StaffService.dart` L107) |
| `staff_members` | `id` (uuid), `store_id` (uuid), `name` (text), `role` (text), `pin_hash` (text), `avatar_color` (text), `phone` (text), `hourly_rate` (numeric), `is_active` (boolean), `created_at` (timestamptz) | `CONFIRMED_FROM_SCHEMA` (`schema.sql`) | `staff_members.user_id`, `modules`, `actions` $\rightarrow$ `CODE_EXPECTATION_NOT_SCHEMA_CONFIRMED` (`StaffService.dart` L118-L124) |

---

## 3. BẢNG PHÂN TÍCH SCHEMAS DRIFT & CHÍNH XÁC HÀNH VI LỖI POSTGREST

| Cột Kỳ Vọng | Bảng | DDL Repo Khai Báo? | Tác Động Thực Tế Khi Cột Thiếu Trên Database (PostgREST Behavior) | Phương Pháp Xác Minh Staging |
|---|---|---|---|---|
| `store_members.actions` | `store_members` | ❌ KHÔNG | Query `.select('actions')` phát sinh PostgREST exception. Outer catch trong `getEffectiveActionPermissions()` ném catch và trả về `[]` (empty list); **KHÔNG** tiếp tục chạy fallback sang `staff_members`/`app_settings`/mặc định. | `SELECT column_name FROM information_schema.columns WHERE table_name='store_members' AND column_name='actions'` |
| `store_members.modules` | `store_members` | ❌ KHÔNG | Method `StaffService.saveDirectPermissions()` ghi `modules`/`actions` vào `staff_members`, sau đó thử ghi mirror vào `store_members`. Nếu cột `store_members.modules`/`actions` không tồn tại, nhánh ghi `store_members` phát sinh exception và được catch/log. Việc ghi `staff_members` có thể đã thành công trước đó vì hai thao tác không nằm trong một transaction. Đây là nguy cơ đồng bộ quyền một phần. | `SELECT column_name FROM information_schema.columns WHERE table_name='store_members' AND column_name='modules'` |
| `staff_members.user_id` | `staff_members` | ❌ KHÔNG | Query `.or('user_id.eq...,id.eq...')` phát sinh PostgREST exception khi `user_id` không tồn tại; outer catch trả về `[]`; **KHÔNG** tự động fallback bằng `id`. | `SELECT column_name FROM information_schema.columns WHERE table_name='staff_members' AND column_name='user_id'` |
| `staff_members.actions` | `staff_members` | ❌ KHÔNG (`schema.sql` L26) | Query `.select('actions')` phát sinh PostgREST exception và outer catch trả về `[]`; **KHÔNG** tiếp tục sang `app_settings` hay mặc định vì nằm trong cùng outer try block. | `SELECT column_name FROM information_schema.columns WHERE table_name='staff_members' AND column_name='actions'` |
| `staff_members.modules` | `staff_members` | ❌ KHÔNG (`schema.sql` L26) | Trong `getModulePermissions()`, query nằm trong `try...catch` riêng lẻ nên khi lỗi sẽ catch và **CÓ THỂ** tiếp tục thử `app_settings` rồi về hardcoded `kDefaultPerms`. | `SELECT column_name FROM information_schema.columns WHERE table_name='staff_members' AND column_name='modules'` |

---

## 4. QUAN HỆ ID THỰC TẾ & LUỒNG XÁC THỰC POS

### 4.1 Quan Hệ ID Đã Xác Minh Từ Luồng Tạo Nhân Viên
- **Quan hệ chuẩn hiện tại:**
  `user_accounts.id` = `store_members.user_id` = `staff_members.id`
  - Đã xác minh từ luồng đăng ký/tạo nhân viên trong `UserAuthService.dart` và `StaffService.dart`.
- **Cột `staff_members.user_id`:**
  - `schema.sql` hiện **KHÔNG KHAI BÁO** cột `staff_members.user_id`.
  - Phân loại: `CODE_EXPECTATION_NOT_SCHEMA_CONFIRMED` & `NEEDS_STAGING_VERIFICATION`.

### 4.2 Luồng Xác Thực POS Custom Auth
- **Cơ chế xác thực:** Đăng nhập bằng `phone` + `password` qua Custom Auth (`UserAuthService.dart`).
- **Tình trạng Supabase Auth Session:**
  *"Đối với các request hiện tại từ POS Custom Auth sử dụng anon key và không có Supabase Auth session, `auth.uid()` là NULL."*
- **Hệ quả:** Các RPC/RLS Policies kiểm tra `auth.uid()` hoặc `TO authenticated` đều không thể sử dụng cho client POS Custom Auth.
- **Phân loại:** `CONFIRMED_FROM_CODE_BEHAVIOR`.

---

## 5. LỖ HỔNG DIRECT TABLE UPDATE CẦN LOẠI BỎ

- `lib/modules/qr_order/repository/qr_order_repository.dart` L193-L205 có đoạn fallback trực tiếp:
  `_sb.from('qr_requests').update({'status': 'processing'}).eq('id', requestId)`
- `updateRequestStatus()` gọi cập nhật trực tiếp `qr_requests`.
- **Đã phân loại:** `CONFIRMED_FROM_CODE_BEHAVIOR`.
- **Yêu cầu loại bỏ:** 100% mutation phải thông qua Protected RPCs có kiểm tra token và phân quyền.

---

## 6. DANH SÁCH CẦN XÁC MINH TRÊN STAGING DB

| Hạng Mục | Trạng Thái | Phương Pháp Xác Minh |
|---|---|---|
| Kiểm tra sự tồn tại của cột `store_members.actions` | `NEEDS_STAGING_VERIFICATION` | Runs `information_schema.columns` query on Staging |
| Kiểm tra sự tồn tại của cột `staff_members.user_id` | `NEEDS_STAGING_VERIFICATION` | Runs `information_schema.columns` query on Staging |
| Kiểm tra sự tồn tại của cột `staff_members.modules` & `actions` | `NEEDS_STAGING_VERIFICATION` | Runs `information_schema.columns` query on Staging |
| Kiểm tra bảng `environment_guard` | `NEEDS_STAGING_VERIFICATION` | Runs `information_schema.tables` query on Staging |
| Xác minh khả năng deploy Supabase Edge Functions trên Self-Hosted | `NEEDS_STAGING_VERIFICATION` | Inspects self-hosted Deno runtime availability |
