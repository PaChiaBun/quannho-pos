// staff_tables.dart
// ─────────────────────────────────────────────────────────────────────────────
// [REMOVED] StaffMembers, StaffShifts, StaffPermissions — Legacy từ v11
//
// Hệ thống nhân viên hiện tại dùng Supabase:
//   - user_accounts     : tài khoản nhân viên (SĐT + mật khẩu)
//   - store_members     : nhân viên thuộc quán nào, role gì
//   - store_roles       : vai trò + danh sách module được phép
//   - staff_shifts      : ca làm việc (Supabase, không phải SQLite)
//
// Xóa v12 → v13 (migration trong app_database.dart):
//   DROP TABLE IF EXISTS staff_members;
//   DROP TABLE IF EXISTS staff_shifts;
//   DROP TABLE IF EXISTS staff_permissions;
// ─────────────────────────────────────────────────────────────────────────────
