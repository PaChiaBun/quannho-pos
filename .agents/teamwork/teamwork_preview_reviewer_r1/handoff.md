# Adversarial Review & Quality Assurance Report — Staff Onboarding & Display V4

## 1. What the Prior Attempt Got Wrong

1. **Analysis Compiler Warnings in UI (`nhan_vien_screen.dart`)**:
   - **Input**: Run `flutter analyze lib/screens/nhan_vien_screen.dart`.
   - **Expected**: 0 compiler warnings, adhering strictly to requirement R3.
   - **Actual**: 9 compiler warnings detected (`dead_null_aware_expression`, `unused_import`, `unused_element`, `non_constant_identifier_names`, etc.).
   - **Root Cause**: The prior attempt left unreferenced legacy widgets (`_EmptyStaff`, `_InfoChip`), unused imports (`PermLog`, `StoreRoleService`), unused constant `_moduleNames`, dead null check on `session.role`, and uppercase private helper name `_FilterChip`.

2. **Placeholder Name Masking Real Identity (`staff_service.dart`)**:
   - **Input**: User self-registers with display name "Bảo Linh" in `user_accounts`, but previous or default `staff_members` record had placeholder name `'Nhân viên'` or `'Nhân viên mới'`.
   - **Expected**: Display the actual user name "Bảo Linh".
   - **Actual**: The null-coalescing check `(profile?['name'] as String?) ?? ...` evaluated `'Nhân viên'` as truthy, masking the real `user_accounts.display_name`. If telephone was available, it fell back to `'NV 090xxxxxxx'`, or otherwise `'Nhân viên mới'`.
   - **Root Cause**: Defective precedence logic in `StaffService.getStaffList` that didn't treat placeholder strings as empty/fallback triggers.

3. **Empty String Phone Masking (`staff_service.dart` & `20261006_fix_new_staff_display_and_join_flow_v4.sql`)**:
   - **Input**: `staff_members.phone` contains empty string `""` while `user_accounts.phone` has a valid number `"0902222222"`.
   - **Expected**: Fallback to `user_accounts.phone`.
   - **Actual**: Dart `??` and SQL `COALESCE` evaluated `""` as non-null, discarding the valid phone number and leaving it blank.
   - **Root Cause**: Failure to use `trim().isNotEmpty` in Dart and `NULLIF(..., '')` in SQL.

4. **Role Filter Collision on Unassigned Members (`nhan_vien_screen.dart`)**:
   - **Input**: Filter chip selected for a role whose string is empty or contains unassigned keywords.
   - **Expected**: Unassigned staff should only match 'all' and 'unassigned' chips, never standard or custom role chips.
   - **Actual**: `m.role.toLowerCase() == roleFilter.toLowerCase()` could collide if unassigned synonyms matched custom role names.
   - **Root Cause**: Missing explicit `!isUnassigned` guard in role matching logic.

5. **Risk of HTTP 414 URI Too Long (`staff_service.dart`)**:
   - **Input**: Store with over 100 members where direct query fallback is invoked.
   - **Expected**: Safe chunked queries to `user_accounts`.
   - **Actual**: Single unchunked `.inFilter('id', missingUserIds.toList())` could generate URLs exceeding max HTTP header limits.
   - **Root Cause**: Lack of query chunking on direct batch lookup.

6. **Missing Widget Test for Onboarded Staff UI**:
   - **Input**: Automated test suite.
   - **Expected**: Component/widget-level verification of `NhanVienScreen` rendering new staff card and unassigned chips.
   - **Actual**: Prior attempt only wrote 7 non-widget unit tests.
   - **Root Cause**: Prior attempt omitted widget test implementation.

---

## 2. What I Changed

1. **`lib/screens/nhan_vien_screen.dart`**:
   - Cleaned up all 9 compiler warnings: removed unused imports (`PermLog`, `StoreRoleService`), removed dead constant `_moduleNames`, removed dead null check on `session.role`, deleted dead code widgets (`_EmptyStaff`, `_InfoChip`, `_fmtMoney`).
   - Renamed `_FilterChip` to `_filterChip` to follow Dart naming conventions.
   - Hardened `_roleFilter` matching logic: ensured `isUnassigned` staff strictly match only `'all'` and `'unassigned'`.
   - Added friendly label `'Chưa cập nhật SĐT'` in italics when phone is blank.
   - Standardized error handling in shift management with `AppLogger.error` and user-friendly SnackBar messages.

2. **`lib/core/services/staff_service.dart`**:
   - Fixed identity resolution precedence in `StaffService.getStaffList`: prioritizes non-placeholder names over `'Nhân viên'` and `'Nhân viên mới'`, both from joined and direct `user_accounts` queries.
   - Fixed phone resolution: checks `isNotEmpty` instead of simple `??` to allow proper fallback when `staff_members.phone` is `""`.
   - Added chunked batching (`chunkSize = 80`) when querying `user_accounts` for missing IDs.
   - Safely parsed `shiftConfigId: m['shift_config_id']?.toString()`.
   - Added `assignShiftConfig` helper.
   - Enhanced `broadcastHandlerOverride` callback to accept test overrides and avoid uninitialized Supabase assertions during tests.

3. **`supabase/migrations/20261006_fix_new_staff_display_and_join_flow_v4.sql`**:
   - Updated `join_store_by_code_v4`: used `COALESCE(NULLIF(v_caller_phone, ''), ...)` to prevent erasing valid phones with empty strings.
   - Updated `get_store_staff_directory_v4`: added `service_role` caller bypass; prioritized real `display_name` over placeholder names; applied `NULLIF` to prevent blank phone overwrites.

4. **`test/core/staff_onboarding_and_display_test.dart`**:
   - Expanded test suite from 7 to 10 automated tests:
     - Test 8: Verified real identity precedence over placeholder names in directory mapping.
     - Test 9: Verified unassigned staff never falsely match standard or custom role filters.
     - Test 10: Complete `WidgetTester` test for `NhanVienScreen` rendering new staff card, "Chưa phân vai trò (2)" chip, and role filtering.
     - Enhanced Test 6: Verified real-time broadcast notification dispatch upon role update.

5. **`quan_nho/nhat_ky.md`**:
   - Updated development log with full adversarial review findings, hardening details, and 100% test pass record.

---

## 3. Verification Record

- **Deep Verification (ran actual tests):**
  - `flutter test test/core/staff_onboarding_and_display_test.dart` $\rightarrow$ **10/10 tests PASS (100%)**.
  - `flutter test test/core/staff_membership_admin_test.dart test/core/staff_manager_hierarchy_guard_test.dart` $\rightarrow$ **10/10 tests PASS (100%)**.
  - Combined suite run: `flutter test test/core/staff_membership_admin_test.dart test/core/staff_manager_hierarchy_guard_test.dart test/core/staff_onboarding_and_display_test.dart` $\rightarrow$ **20/20 tests PASS (100%)**.
  - `flutter analyze --no-fatal-infos lib/screens/nhan_vien_screen.dart lib/core/services/staff_service.dart test/core/staff_onboarding_and_display_test.dart` $\rightarrow$ **0 ERRORS, 0 WARNINGS** (exit code 0).
- **Shallow Verification (manual only):**
  - None; all logic was verified via automated Dart unit and widget tests.
- **Unverified aspects:**
  - Live execution on the remote Supabase PostgreSQL database instance requires applying the migration SQL script (`20261006_fix_new_staff_display_and_join_flow_v4.sql`) on production.

---

## 4. Known Issues

- **Shallow Verification**: Remote production Supabase database deployment is pending migration execution by devops/host administrator.
- **Minor Robustness Risk**: None identified within touched code.

---

## 5. Remaining Risk & Next Step

- **Remaining Risk**: Very low. All client fallbacks (direct PostgREST query + multi-tier identity resolution) work even if the RPC has not been migrated on the server yet.
- **Next Step**: Apply migration `20261006_fix_new_staff_display_and_join_flow_v4.sql` to production Supabase database and verify realtime reflection on live Web POS / Android devices.
