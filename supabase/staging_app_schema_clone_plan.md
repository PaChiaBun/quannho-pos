# Kế Hoạch Clone Schema Ứng Dụng Nền Quán Nhỏ Sang Staging (Schema-Only Clone Plan V10)
File: `supabase/staging_app_schema_clone_plan.md`
Date: 2026-08-01
Mode: `FULL_PUBLIC_SCHEMA_CLONE (ZERO DATA DUMP)`
Status Migration V3: **`BLOCKED_STATIC_QC`** (Chưa đủ điều kiện thi hành trên Production/Staging)

---

## 1. MỤC TIÊU KẾ HOẠCH & QUY TRÌNH QUÉT STATIC TÀI NGUYÊN CUSTOM DUMP

- **Chế độ Clone Phản Ánh Đúng Production (`FULL_PUBLIC_SCHEMA_CLONE`):**
  - Thực hiện trích xuất toàn bộ cấu trúc DDL của schema `public` từ Production bằng định dạng custom archive `pg_dump -Fc` (không chứa data, không chứa owner `--no-owner`, không chứa ACL/grants `--no-acl`).
  - File binary `.dump` được render thành SQL văn bản bằng `pg_restore --schema-only --file=candidate_rendered_schema.sql` để phục vụ Static Scan kép.
- **Cảnh Báo Hard-Stop Migration V3 (`BLOCKED_STATIC_QC`):**
  - **Lý do Block:** Mã nguồn Migration V3 hiện tại (`20260731_*.sql`) đang chứa lệnh: `SET search_path = public, extensions, pg_catalog, pg_temp;`. Việc bao gồm `pg_temp` trong `search_path` của `SECURITY DEFINER` function mở ra nguy cơ tấn công Schema Hijacking.
  - **Hành động bắt buộc:** Migration V3 bị dừng (Hard-Stop) ở trạng thái `BLOCKED_STATIC_QC`. Không được phép chạy migration này vào Staging hay Rehearsal cho đến khi lỗi `search_path` chứa `pg_temp` được sửa ở vòng QC Migration riêng.
- **Quy trình rà soát Kép & Manifest Review:**
  1. **Tạo Custom Archive:** `docker exec -i supabase-db pg_dump -U postgres -d postgres -Fc --schema-only --no-owner --no-acl --schema=public > candidate_baseline_schema.dump`.
  2. **Tạo Manifest List:** `pg_restore --list candidate_baseline_schema.dump > candidate_manifest.list`.
  3. **Render SQL Text:** `pg_restore --schema-only --file=candidate_rendered_schema.sql candidate_baseline_schema.dump`.
  4. **Static Scan Kép:** Thực hiện `grep` rà soát trên cả `candidate_manifest.list` và `candidate_rendered_schema.sql` (tìm kiếm Store IDs hardcode, tên miền Production, `GRANT ALL`, `SECURITY DEFINER`, `CREATE EXTENSION`, hoặc bất kỳ câu lệnh `GRANT/ACL` bất thường nào).
  5. **Quy Tắc Quét ACL Strict:** File candidate rendered SQL **tuyệt đối không được chứa bất kỳ câu lệnh GRANT/ACL nào**. Dynamic fail nếu có `GRANT/ACL`.
  6. **Quy Tắc SECURITY DEFINER Safe search_path:** Các hàm `SECURITY DEFINER` bắt buộc phải có `search_path` cố định an toàn (tuyệt đối cấm `"$user"` và `pg_temp`).

---

## 2. BẢNG MANIFEST REVIEW & ĐIỀU KIỆN PASS/FAIL TRÊN REHEARSAL DATABASE

| Hạng Mục Object (Object Category) | Phạm Vi Cho Phép Trích Xuất (`public.*`) | Yêu Cầu Review Kỹ Thuật Khi Rà Soát Manifest | Điều Kiện PASS / FAIL Candidate |
|---|---|---|---|
| **Bảng & Chế Bản (Tables & Views)** | Toàn bộ các bảng nghiệp vụ thuộc schema `public` | Rà soát tên bảng, đảm bảo không chứa schema `auth.*`, `storage.*`, `realtime.*` | **FAIL** nếu candidate chứa tables thuộc system schemas (`auth`, `storage`, `realtime`). |
| **Phân Quyền (ACLs & Grants)** | Không chứa ACLs (Do dùng `--no-acl`) | File rendered SQL không chứa câu lệnh `GRANT` hoặc `REVOKE` | **FAIL** nếu rendered SQL chứa bất kỳ lệnh `GRANT/ACL` nào. |
| **Hàm & Triggers (Functions & Triggers)** | Các hàm trigger audit/updated_at thông thường | Rà soát toàn bộ `SECURITY DEFINER` functions, cấm `"$user"` và `pg_temp` trong `search_path` | **FAIL** nếu xuất hiện `SECURITY DEFINER` function thiếu fixed safe `search_path`. |
| **Extensions & Types** | Custom types (enums, composite types) | Không chứa câu lệnh `CREATE EXTENSION` chèn trực tiếp trong candidate dump | **FAIL** nếu xuất hiện `CREATE EXTENSION` trong file dump. |

---

## 3. LỆNH BẮT BUỘC TÍNH SHA-256 CHECKSUM (VỚI STRICT EXIT 1 GUARD)

Script kiểm tra và tính checksum bắt buộc phải ngắt tiến trình bằng `exit 1` nếu môi trường không có cả `sha256sum` lẫn `shasum`:

```bash
#!/usr/bin/env bash
set -e

# Kiểm tra công cụ tính SHA-256 (Strict Guard Exit 1):
HAS_HASHER=false

if command -v sha256sum >/dev/null 2>&1; then
  HASHER_CMD="sha256sum"
  HAS_HASHER=true
elif command -v shasum >/dev/null 2>&1; then
  HASHER_CMD="shasum -a 256"
  HAS_HASHER=true
fi

if [ "$HAS_HASHER" = false ]; then
  echo "CRITICAL ERROR: Neither sha256sum nor shasum is available on this system!"
  exit 1
fi

# Thực thi tính checksum SHA-256 cho toàn bộ tài nguyên DDL
$HASHER_CMD candidate_baseline_schema.dump > candidate_baseline_schema.dump.sha256
$HASHER_CMD candidate_manifest.list > candidate_manifest.list.sha256
$HASHER_CMD candidate_rendered_schema.sql > candidate_rendered_schema.sql.sha256

echo "SHA-256 Checksums computed successfully."
```

---

## 4. BẢNG ĐỐI CHIẾU INDEXES VÀ POLICIES CHÍNH XÁC VỚI SCRIPT PREFLIGHT V10

### 4.1 Danh Sách 6 Indexes Dự Kiến (Mã Nguồn Migration V3)

| Tên Index (`public.*`) | Bảng Mục Tiêu | Tính Duy Nhất | Thứ Tự Cột Key (`expected_keys`) | Predicate Chuẩn Hóa (`expected_predicate`) |
|---|---|---|---|---|
| `idx_pos_single_active_session` | `pos_device_sessions` | `true` (UNIQUE) | `store_id, device_id` | `(revoked_at IS NULL)` |
| `idx_pos_sessions_lookup` | `pos_device_sessions` | `false` | `token_hash` | `(revoked_at IS NULL)` |
| `idx_pairing_codes_store` | `store_pairing_codes` | `false` | `store_id, expires_at` | `(used_at IS NULL)` |
| `idx_pos_auth_ip_store` | `pos_auth_attempts` | `false` | `ip_address, store_code, blocked_until` | `NULL` |
| `idx_qr_audit_request` | `qr_audit_logs` | `false` | `request_id, created_at` | `NULL` |
| `idx_qr_requests_channel_idempotency` | `qr_requests` | `true` (UNIQUE) | `channel_id, idempotency_key` | `(idempotency_key IS NOT NULL)` |

### 4.2 Phân Loại Executable vs Deferred Cutover RLS Policies

- **Executable Migration V3 Policies:** Mã SQL thi hành trực tiếp của 3 file migration V3 tạo **0 RLS policies** (Check 88 trong `POST_MIGRATION_V3` xác nhận 0 policies thi hành).
- **Deferred Cutover Policies (Khối Comment Draft):** Các RLS policy cách ly dữ liệu cửa hàng (`pos_sessions_store_isolation`, `qr_requests_store_isolation`, `qr_channels_store_isolation`) được hoãn thi hành và quản lý ở giai đoạn `CUTOVER_READINESS`.

---

## 5. BẢNG ĐỐI CHIẾU CỘT & KIỂU DỮ LIỆU THỰC TẾ VS MIGRATION V3 (EMPIRICAL SCHEMA TRUTH)

| Tên Bảng (`public.*`) | Các Cột Đang Tồn Tại Thực Tế Trên Production | Các Cột MIGRATION V3 Yêu Cầu Nhưng KHÔNG TỒN TẠI / Sai Kiểu | Giải Pháp Sửa Lỗi Thiết Kế (Design Fix Required) |
|---|---|---|---|
| `stores` | `id`, `store_code`, `name`, `status`, `owner_user_id` | `is_active` (KHÔNG TỒN TẠI) | Sửa Migration V3 kiểm tra trạng thái qua `status = 'active'` thay vì `is_active = true`. |
| `user_accounts` | `id`, `phone`, `password_hash`, `display_name` | `store_id`, `quick_pin`, `is_owner` (KHÔNG TỒN TẠI) | `is_owner` thực tế nằm ở `store_members.is_owner`. Cột `quick_pin` cần prerequisite migration tối giản riêng. |
| `store_members` | `id`, `user_id`, `store_id`, `role`, `is_owner` | `user_account_id`, `actions`, `modules` (KHÔNG TỒN TẠI) | Cột liên kết tài khoản là `user_id`. `actions` không tồn tại -> `check_pos_staff_action_permission()` fail-closed. |
| `staff_members` | `id`, `store_id`, `name`, `role`, `pin_hash`, `is_active` | `pin_code` (plain text), `actions`, `modules` (KHÔNG TỒN TẠI) | Cột lưu PIN là `pin_hash` (`UNKNOWN_NEEDS_VERIFICATION` thuật toán hash). `pin_code` plain-text không tồn tại. |
| `ban_zones` | `id` (kiểu **`text`**), `store_id`, `name` | `id` kiểu `uuid` (SAI KIỂU DỮ LIỆU) | Giữ nguyên `id` kiểu `text`. Sửa Migration V3 không ép kiểu `uuid`. Kiểm tra cột NOT NULL trước khi INSERT. |
| `ban_dining_tables` | `id` (kiểu **`text`**), `zone_id` (kiểu **`text`**), `name` (tên bàn chính), `capacity` (sức chứa) | `id`/`zone_id` kiểu `uuid`; `label`/`seats` là cột chính (SAI KIỂU) | Table name chính là `name` (`label` nullable). Capacity chính là `capacity` (`seats` nullable). |
| `ban_sessions` | `id`, `store_id`, `table_id`, `status`, `total_amount` | `staff_id`, `pos_order_id`, `note` (KHÔNG TỒN TẠI) | RPC `send_to_kitchen_qr_v3()` cố ghi vào `staff_id`, `pos_order_id`, `note` sẽ bị crash lỗi missing column. |
| `order_items` | `id`, `order_id`, `product_id`, `qty`, `quantity` | `UNKNOWN_NEEDS_VERIFICATION` giữa `qty` và `quantity` | Cần xác minh đồng bộ cả schema constraints và Flutter/Service code trước khi chọn cột canonical. |

---

## 6. DANH SÁCH BẮT BUỘC BẮT LỖI MIGRATION V3 (BLOCKER DESIGN FIXES)

1. **`migration_kay_public_ordering_v2.sql` hardcode Store ID Production:**
   - File V2 đang chứa Store ID cứng `79fd45e9-14c3-4dd2-81ba-aa288a45b472` và slug `kay`. Bắt buộc phải tách thành file prerequisite generic.
2. **Xung Đột Status CHECK Constraint Trên `qr_requests` Giữa V2 Và V3:**
   - Constraint status gốc trong V2 **không có trạng thái `confirmed`**.
   - Việc V3 thêm CHECK constraint mới có `confirmed` **không vô hiệu hóa CHECK constraint cũ của V2**. UPDATE thành `confirmed` vẫn thất bại do constraint cũ từ chối.
   - Bắt buộc phải thiết kế migration thay thế/drop constraint cũ có kiểm soát, ghi nhận chính xác tên và định nghĩa constraint PRE-state để rollback.
3. **Cảnh Báo Bảo Mật search_path Chứa `pg_temp` Trong Migration V3 (`BLOCKED_STATIC_QC`):**
   - Mã nguồn Migration V3 hiện chứa `SET search_path = public, extensions, pg_catalog, pg_temp;`. Bắt buộc xóa `pg_temp` khỏi search_path trước khi thi hành.
4. **Lỗi Giới Hạn Cột NOT NULL Của `ban_zones` Và `ban_dining_tables`:**
   - Kiểm tra default/nullability thực tế của các cột NOT NULL trước khi kết luận RPC tạo "quầy mang đi" có thể INSERT với số ít cột hiện tại.
5. **Cảnh Báo Thuật Toán Hash PIN Của `staff_members.pin_hash`:**
   - Đánh dấu trạng thái **`UNKNOWN_NEEDS_VERIFICATION`** cho thuật toán hash mã PIN nhân viên.
6. **Thiết Kế Lại Mô Hình Phân Quyền Nhân Viên (Permission Resolver Fix):**
   - V3 không được yêu cầu `store_members.actions` hay `staff_members.actions`.
   - Resolver phân quyền phải được thiết kế khớp với `StaffService.saveDirectPermissions()`, `app_settings` và `store_members.is_owner`.

---

## 7. THỨ TỰ QUY TRÌNH THỰC THI THIẾT KẾ MỚI (REVISED REHEARSAL WORKFLOW PIPELINE)

1. **Bước 1:** Trích xuất candidate dump `pg_dump -Fc --schema-only --no-owner --no-acl --schema=public`.
2. **Bước 2:** Render manifest `pg_restore --list` và rendered SQL `pg_restore --file=...`. Tính toán SHA-256 checksums (với exit 1 guard).
3. **Bước 3:** Thực hiện Static Scan kép rà soát không chứa `GRANT/ACL`, hardcoded secrets hay domains.
4. **Bước 4:** Restore DDL vào **database rehearsal riêng biệt** (`postgres_rehearsal`).
5. **Bước 5 (PRE Run 1):** Chạy `staging_v3_dependency_preflight.sql`. *(Dự kiến `pre_v3_ready = FALSE` do thiếu prerequisite)*.
6. **Bước 6:** Thiết kế và áp dụng các prerequisite migrations đã QC (`product_topping_links`, generic QR V2, minimal `quick_pin`) vào rehearsal.
7. **Bước 7 (PRE Run 2):** Chạy lại `staging_v3_dependency_preflight.sql`. *(Bắt buộc `pre_v3_ready = TRUE` mới được đi tiếp)*.
8. **Bước 8:** Sửa toàn bộ bộ Migration V3 cho đúng schema truth, permission model và xóa `pg_temp` khỏi search_path.
9. **Bước 9:** Static QC lại bộ Migration V3 đã sửa.
10. **Bước 10:** Chạy thử nghiệm Migration V3 đã sửa vào rehearsal database.
11. **Bước 11 (POST Run):** Chạy `staging_v3_dependency_preflight.sql`. *(Bắt buộc `post_v3_ready = TRUE`)*. Chỉ sau khi cả 2 chỉ số PASS 100%, mới đề xuất áp dụng vào Staging chính (`postgres`).

---

## 8. BÁO CÁO TRẠNG THÁI TÁC ĐỘNG HỆ THỐNG

- `Production DDL executed: NO`
- `Production DML executed: NO`
- `Production catalog/schema read: YES`
