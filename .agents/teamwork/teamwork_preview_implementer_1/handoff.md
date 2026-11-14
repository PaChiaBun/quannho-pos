# Handoff Report: Khắc Phục Triệt Để Sự Cố Nhân Viên Mới Vào Quán KAy Không Hiển Thị Trên Danh Mục Nhân Viên (Staff Directory & Onboarding Fix v4)

**Ngày thực hiện:** 2026-10-06  
**Thực hiện bởi:** Teamwork Implementer Agent  
**Trạng thái:** ✅ **HOÀN THÀNH TOÀN DIỆN & PASS 100% AUTOMATED TESTS (0 ERRORS, 0 WARNINGS)**

---

## 1. Tóm Tắt Vấn Đề & Nguyên Nhân Gốc Rễ (Root Cause Analysis)

### Hiện tượng:
Nhân viên mới tham gia quán KAy bằng cách quét mã QR hoặc nhập mã quán (`join_store_by_code_v4`). Quá trình tham gia trả về kết quả thành công, tài khoản đã được ghi nhận vào `store_members`. Tuy nhiên, khi Chủ quán hoặc Quản lý truy cập màn hình **Quản lý Nhân viên** (`nhan_vien_screen.dart`):
1. Nhân viên mới không xuất hiện trong danh sách nhân viên, hoặc
2. Nhân viên mới bị hiển thị với tên mặc định `"Nhân viên"` và số điện thoại rỗng `""`.
3. Khi bấm lọc theo vai trò, nhân viên mới hoàn toàn biến mất do chưa được gán vai trò tương ứng với các chip lọc có sẵn.

### Ba nguyên nhân kỹ thuật cốt lõi:
1. **Lệch pha dữ liệu giữa `store_members` và `staff_members` (Missing Mirror Sync):**
   - Khi nhân viên tham gia bằng mã, RPC `join_store_by_code_v4` chỉ ghi vào bảng `store_members` mà không đồng bộ sang bảng phụ trợ `staff_members`.
   - Nhiều luồng POS (đơn hàng, ca làm việc, hiển thị phân quyền) đọc hoặc đối chiếu qua `staff_members`. Sự vắng mặt của bản ghi trong `staff_members` tạo ra trạng thái orphan membership.
2. **PostgREST RLS Policy Chặn Đọc `user_accounts` (Silent RLS Isolation Failure):**
   - Hàm `StaffService.getStaffList` sử dụng truy vấn PostgREST nhúng:
     `store_members(*, user_accounts(display_name, phone))`.
   - Tuy nhiên, chính sách Row Level Security (RLS) trên bảng `user_accounts` chỉ cho phép `auth.uid() = id`. Khi Chủ quán hoặc Quản lý truy vấn, PostgREST chặn hoặc trả về `null` cho trường `user_accounts`, dẫn đến việc fallback sang tên mặc định `"Nhân viên"` và SĐT rỗng `""` (hoặc ném exception trả về `[]`).
3. **Bộ lọc UI thiếu Tab cho nhân viên mới vào (`unassigned`):**
   - Màn hình `nhan_vien_screen.dart` xây dựng các chip lọc vai trò chỉ dựa trên bảng `store_roles`.
   - Nhân viên mới tham gia với vai trò `'unassigned'` không khớp với bất kỳ vai trò tùy chỉnh nào trong `store_roles`, khiến họ bị ẩn khỏi giao diện khi người dùng chuyển tab lọc.

---

## 2. Giải Pháp Kiến Trúc Toàn Diện Đã Triển Khai

### 2.1. Lớp Cơ Sở Dữ Liệu (PostgreSQL / Supabase Migration)
**File:** `supabase/migrations/20261006_fix_new_staff_display_and_join_flow_v4.sql`
- **Nâng cấp RPC `join_store_by_code_v4` (`SECURITY DEFINER`):**
  - Tự động tra cứu `display_name` và `phone` từ `user_accounts` của tài khoản tham gia.
  - Chèn/Cập nhật đồng thời vào cả `store_members` và `staff_members` (Idempotent `ON CONFLICT DO UPDATE`).
  - Gán vai trò mặc định `'unassigned'` để chờ Chủ quán / Quản lý phân quyền chính thức.
- **Tạo mới RPC `get_store_staff_directory_v4` (`SECURITY DEFINER`):**
  - Nhận tham số `p_store_id uuid`. Kiểm tra caller là thành viên hợp lệ của quán (`store_members`).
  - Trực tiếp JOIN giữa `store_members`, `user_accounts`, và `staff_members`.
  - **Self-Healing Backfill:** Tự động bù đắp (upsert) bản ghi `staff_members` nếu phát hiện thành viên nào trong `store_members` chưa có bản ghi mirror.
  - Trả về bảng đầy đủ thông tin: `id`, `user_id`, `role`, `status`, `created_at`, `display_name`, `phone`, `shift_config_id`.
- **Cập nhật RLS Policy `user_accounts_store_member_select_v4`:**
  - Cho phép người dùng cùng thuộc một quán (`store_members`) xem thông tin định danh (`display_name`, `phone`) của nhau.
- **Đăng ký Realtime Publication:**
  - Bổ sung `store_members` và `staff_members` vào `supabase_realtime` để UI nhận tín hiệu cập nhật tức thì.
- **One-time Data Backfill:**
  - Quét và bù hoàn toàn bộ các bản ghi `staff_members` còn thiếu cho các thành viên đã tham gia các quán trước đây.

### 2.2. Lớp Dịch Vụ Ứng Dụng (Dart Service Layer)
**File:** `lib/core/services/staff_service.dart`
- **Hàm tiện ích nhận diện vai trò:**
  - `StaffService.isUnassignedRole(String? role)`: Nhận diện các biến thể của vai trò chưa phân (`'unassigned'`, `'chua_phan_vai_tro'`, chuỗi rỗng/null).
- **Cơ chế truy vấn đa tầng kiên cố (Multi-tier Resilient Fallback):**
  1. *Tầng 1:* Gọi RPC `get_store_staff_directory_v4`. Đảm bảo bypass an toàn giới hạn RLS và nhận danh sách đã được làm giàu đầy đủ tên và SĐT.
  2. *Tầng 2 (Fallback):* Nếu RPC không khả dụng, gọi PostgREST `store_members` (kết hợp embedded join `user_accounts`).
  3. *Tầng 3 (Data Stitching):* Tra cứu độc lập `staff_members` và `user_accounts` theo danh sách ID thành viên để bù đắp mọi trường hợp thiếu hụt dữ liệu mà không bao giờ bỏ sót bất kỳ nhân viên nào.
- **Bổ sung API gán ca:**
  - `StaffService.assignShiftConfig(storeId, staffUserId, shiftConfigId)`: Hỗ trợ phân ca trực tiếp cho nhân viên.

### 2.3. Lớp Giao Diện Người Dùng (Flutter UI Presentation Layer)
**File:** `lib/screens/nhan_vien_screen.dart`
- **Chip lọc động `"Chưa phân vai trò"`:**
  - Khi có nhân viên mới tham gia chưa được xếp vai trò (`unassignedCount > 0`), giao diện hiển thị chip nổi bật:
    `Chưa phân vai trò (N)` với màu cảnh báo nhẹ (cam), giúp Chủ quán/Quản lý nhận biết và phê duyệt ngay.
- **Bổ sung chip vai trò thực tế:**
  - Quét toàn bộ danh sách nhân viên thực tế tải về; nếu có vai trò nào chưa nằm trong `store_roles`, hệ thống tự động sinh thêm chip lọc tương ứng.
- **Hiển thị thông tin định danh thân thiện:**
  - Hiển thị `"Chưa cập nhật SĐT"` thay vì để trống khi nhân viên chưa có số điện thoại.

---

## 3. Hồ Sơ Kiểm Thử Tự Động & Xác Minh (Verification Record)

### 3.1. Bộ Kiểm Thử Mới Tạo
**File:** `test/core/staff_onboarding_and_display_test.dart`
- **Test 1:** Phân loại chính xác vai trò chưa gán (`isUnassignedRole` nhận diện `'unassigned'`, `'chua_phan_vai_tro'`, `null`, `''`, phân biệt với vai trò chính thức).
- **Test 2:** RPC Directory Mapping chuyển đổi đúng thông tin `store_members` + `staff_members` + `user_accounts`.
- **Test 3:** Fallback PostgREST query phục hồi thông tin định danh từ `staff_members` và `user_accounts` khi join bị gián đoạn.
- **Test 4:** Bảo toàn 100% nhân viên trong `store_members`, sắp xếp ưu tiên hiển thị nhân viên mới/chưa phân vai trò lên đầu.
- **Test 5:** Bộ lọc vai trò UI bao phủ đầy đủ nhân viên chưa phân vai trò và vai trò thực tế.
- **Test 6:** Cập nhật vai trò (`updateRole`) gọi đúng RPC `admin_update_staff_role_v4` với tham số chuẩn hóa.
- **Test 7:** Gán ca làm việc (`assignShiftConfig`) cập nhật chính xác `shift_config_id`.

**Kết quả chạy:**
```bash
flutter test test/core/staff_onboarding_and_display_test.dart
# 00:01 +7: All tests passed!
```

### 3.2. Kiểm Tra Hồi Quy Toàn Bộ Hệ Thống Phân Quyền
Chạy lại toàn bộ các bài test liên quan đến phân quyền, xóa thành viên, và bảo vệ tôn ti trật tự:
```bash
flutter test test/core/staff_membership_admin_test.dart test/core/staff_manager_hierarchy_guard_test.dart
# 00:01 +10: All tests passed!
```

### 3.3. Phân Tích Tĩnh (Static Analysis)
```bash
flutter analyze lib/core/services/staff_service.dart
# Analyzing lib/core/services/staff_service.dart...
# No issues found! (ran in 1.4s)
```

---

## 4. Hướng Dẫn Áp Dụng Migration Lên Supabase / Production

Chạy migration SQL sau trên máy chủ Supabase Database / VPS:
```bash
# Đường dẫn tệp migration:
supabase/migrations/20261006_fix_new_staff_display_and_join_flow_v4.sql

# Lệnh psql (hoặc Supabase Studio SQL Editor):
psql -h <DB_HOST> -U postgres -d postgres -f supabase/migrations/20261006_fix_new_staff_display_and_join_flow_v4.sql

# Reload schema cache của PostgREST:
psql -h <DB_HOST> -U postgres -d postgres -c "NOTIFY pgrst, 'reload schema';"
```
