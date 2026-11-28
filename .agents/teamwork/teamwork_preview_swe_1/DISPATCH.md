## 2026-10-06T09:40:04Z

From: 2f6d1b4b-5ea0-4c68-a200-11debc4ac4c8 (parent)
Mission:
Investigate the root cause and thoroughly fix the issue where new staff members, after self-registering and entering the store code (or scanning QR) via `join_store_by_code_v4` to join store KAy, do not appear in the Staff module (`nhan_vien_screen.dart`).

Key requirements:
1. R1: Trace root cause across `store_members`, `staff_members`, `user_accounts`, RLS policies, `StaffService.getStaffList(storeId)`, UI filters in `nhan_vien_screen.dart`, and Realtime subscription.
2. R2: Thoroughly fix client (`StaffService.dart`, `nhan_vien_screen.dart`) and/or database migration / RPC to ensure all `store_members` appear with accurate name/phone/role, respecting /qn architecture (store isolation, Hierarchy Guard, Lego modules).
3. R3: Add automated unit/widget tests reproducing the issue and verifying the fix. Ensure `flutter analyze` passes with 0 errors and 0 warnings. Update `quan_nho/nhat_ky.md`.
