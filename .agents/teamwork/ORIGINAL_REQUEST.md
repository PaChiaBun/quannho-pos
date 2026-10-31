# Original User Request

## Initial Request — 2026-10-06T09:38:32Z

This is a single self-contained fix; keep it small and focused. Yêu cầu nhóm: Đội ngũ tập trung (Small focused team) theo chỉ định của người dùng.

Điều tra nguyên nhân gốc rễ và khắc phục triệt để sự cố nhân viên mới sau khi tự đăng ký và nhập mã quán (hoặc quét QR) tham gia vào quán KAy nhưng không hiển thị trong danh sách của module Nhân viên (`nhan_vien_screen.dart`).

Working directory: `/Users/banhbao/Quan Nho/quan_nho`
Integrity mode: development

## Context & Baseline

- Dự án: Quán Nhỏ POS (Flutter / Supabase / PostgreSQL).
- Pilot thực tế: Quán KAy.
- Quy chuẩn nghiệp vụ: Onboarding nhân viên tự phục vụ 100% (nhân viên tự đăng ký tài khoản rồi dùng mã quán/quét QR qua RPC `join_store_by_code_v4`). Bảng `store_members` là nguồn sự thật duy nhất (Single Source of Truth) cho tư cách thành viên và vai trò tại quán.
- Triệu chứng: Nhân viên đã thực hiện tham gia vào quán KAy thành công, nhưng khi Chủ quán/Quản lý mở module Nhân viên (`nhan_vien_screen.dart`), nhân viên mới hoàn toàn không xuất hiện trong danh sách.

## Requirements

### R1. Truy vết nguyên nhân gốc rễ sự cố ẩn nhân viên mới
- Xác định điểm nghẽn tại sao bản ghi thành viên mới sau khi gọi `join_store_by_code_v4` không hiển thị được qua `StaffService.getStaffList(storeId)`.
- Phân tích tương tác giữa các bảng: `store_members` (nơi lưu tư cách thành viên), `staff_members` (hồ sơ nhân sự phụ trợ), và `user_accounts` (thông tin tài khoản người dùng, tên hiển thị, SĐT).
- Kiểm tra các rào cản tiềm ẩn:
  1. Câu truy vấn `db.from('store_members').select('..., user_accounts(...)')` có bị chặn bởi RLS policies của `user_accounts` khi người gọi truy vấn là Chủ quán/Quản lý khác `auth.uid()` hay không.
  2. Bảng `staff_members` có bị lệch/thiếu bản ghi khi nhân viên vào quán qua mã mà chưa được tạo profile hay không.
  3. Bộ lọc giao diện trong `nhan_vien_screen.dart` (lọc role filter chips `_roleFilter`, lọc `_isUnassignedStaff`, hoặc tìm kiếm `_query`) có vô tình lọc mất nhân viên mới hay không.
  4. Cơ chế Realtime subscription (`shiftsChannel`) có kích hoạt reload khi có bản ghi mới trong `store_members` hay không.

### R2. Khắc phục triệt để lỗi hiển thị nhân viên mới
- Sửa đổi mã nguồn client (`StaffService.dart`, `nhan_vien_screen.dart`) và/hoặc migration CSDL / RPC backend để đảm bảo:
  1. Mọi thành viên có trong `store_members` của quán KAy đều phải được nạp đầy đủ vào danh sách `StaffMember`.
  2. Hiển thị đúng thông tin định danh (họ tên, số điện thoại, vai trò) kể cả khi chưa có dòng trong `staff_members` hoặc khi truy vấn liên kết `user_accounts` bị hạn chế bởi chính sách RLS.
  3. Chủ quán và Quản lý có thể xem, chỉnh sửa vai trò, phân ca và quản lý thành viên mới này mà không gặp lỗi.
- Đảm bảo tuân thủ nghiêm ngặt các nguyên tắc kiến trúc `/qn`:
  - Cô lập tuyệt đối dữ liệu theo `store_id`.
  - Giữ vững rào chắn phân cấp quản lý (Hierarchy Guard: Quản lý không thể tự nâng quyền hoặc gán vai trò Owner/Manager).
  - Phân quyền Lego Modules là nguồn sự thật duy nhất (`store_roles.modules`).

### R3. Bộ kiểm thử tự động & Xác minh chất lượng
- Xây dựng unit test / widget test tự động mô phỏng chính xác kịch bản: nhân viên mới gia nhập quán bằng mã, nạp danh sách `StaffService.getStaffList`, và render trên giao diện module Nhân viên.
- Chạy kiểm thử tĩnh `flutter analyze` bảo đảm 0 lỗi, 0 cảnh báo.
- Cập nhật nhật ký phát triển `quan_nho/nhat_ky.md` ghi nhận chi tiết nguyên nhân gốc và giải pháp theo tiêu chuẩn `/qn`.

## Acceptance Criteria

### Tính năng & Hiển thị
- [ ] Nhân viên mới sau khi tham gia quán KAy bằng mã quán (`join_store_by_code_v4`) hiển thị ngay lập tức trong module Nhân viên (`nhan_vien_screen.dart`).
- [ ] Tên hiển thị và số điện thoại của nhân viên mới hiển thị đúng, không bị gán mặc định thành rỗng hoặc làm ẩn thẻ nhân viên.
- [ ] Khi chuyển đổi các tab bộ lọc vai trò (Tất cả, Chưa phân vai trò, hoặc vai trò cụ thể), nhân viên mới hiển thị đúng nhóm tương ứng.
- [ ] Chủ quán / Quản lý có thể thực hiện đổi vai trò, xóa/thu hồi quyền hoặc phân ca cho nhân viên mới mà không phát sinh lỗi.

### An toàn & Kiến trúc
- [ ] Bảo toàn nguyên tắc bảo mật: RLS phân quyền theo quán (`store_id`), không rò rỉ dữ liệu giữa các quán.
- [ ] Không phá vỡ rào chắn phân cấp quản lý (Hierarchy Guard) và cơ chế Lego Modules.

### Kiểm thử & Verification
- [ ] Bộ kiểm thử tự động (Unit / Contract test) cho luồng `getStaffList` và hiển thị nhân viên mới đạt 100% PASS.
- [ ] `flutter analyze` đạt 0 lỗi biên dịch và 0 cảnh báo lint.
- [ ] Báo cáo điều tra nguyên nhân gốc và giải pháp được cập nhật đầy đủ vào `quan_nho/nhat_ky.md`.
