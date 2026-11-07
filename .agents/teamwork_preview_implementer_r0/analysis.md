# Phân Tích Kỹ Thuật Chuyên Sâu & Rà Soát Bảo Mật Đối Kháng (Adversarial Security Audit)

## 1. Mục Tiêu & Phạm Vi Rà Soát
Đánh giá toàn diện các thay đổi liên quan đến:
1. Luồng đăng nhập nhân viên mới (Onboarding JWT) và chuyển đổi phiên làm việc quán (`exchangeStoreJwt`).
2. Sửa lỗi Kong Gateway 401 (`GATEWAY_UNAVAILABLE`) do mất `SupabaseService.supabaseAnonKey` khi reset auth.
3. Cơ chế áp dụng Onboarding JWT vào Supabase client trước khi gọi RPC `join_store_by_code_v4` và `create_store_with_owner_v4`.
4. Migration Postgres `20260913_resilient_join_store_by_code_v4.sql` với cơ chế trích xuất đa tầng `user_id` (`auth.uid()` -> `request.jwt.claims ->> 'sub'`).
5. Đảm bảo tính bất biến bảo mật: Fail-closed 100%, cô lập dữ liệu quán (`store_id` isolation), bảo toàn phiên làm việc 30 ngày của nhân viên/chủ quán đã có quán.

## 2. Kết Quả Rà Soát Đối Kháng (Adversarial Review)

### 2.1. Nguyên Tắc Đóng An Toàn (Fail-Closed)
- **Trong `pos_jwt_auth_service.dart`**:
  - `applyAuthToSupabase`: Khi gặp bất kỳ exception nào trong quá trình setAuth, hàm bắt lỗi trong khối `try/catch` và trả về `false`.
  - `requestPosJwt`: Bọc transactional apply và storage với rollback compensation. Nếu áp dụng thất bại (`!applied`), lập tức xóa token khỏi storage (`clearPosJwt`) và khôi phục Supabase client về `supabaseAnonKey`.
  - `exchangeStoreJwt`: Khi token nhận về không hợp lệ (`!isTokenValid`), hoặc khi lưu storage ném lỗi (như `ThrowingSecureStorage`), hoặc khi server trả mã 401/403, toàn bộ onboarding token và store POS JWT đều bị xóa triệt để (`clearOnboardingJwt`, `clearPosJwt`), Supabase client trả về anon key.
  - Khi server trả 503 (`REPLAY_STORE_UNAVAILABLE`), onboarding token được giữ lại có chủ đích để hỗ trợ cơ chế retry của người dùng, không xóa oan phiên onboarding đang hợp lệ.

### 2.2. Phục Hồi `SupabaseService.supabaseAnonKey`
- **Trước đây**: Khi `applyAuthToSupabase(null)` được gọi, code thực hiện `client.rest.setAuth(null)` và `client.realtime.setAuth(null)`. Điều này khiến PostgREST header bị mất hoàn toàn API key và Authorization header. Kong Gateway chặn ngay với HTTP 401 Unauthorized, làm các truy vấn tiếp theo bị coi là `GATEWAY_UNAVAILABLE`.
- **Hiện tại**: `applyAuthToSupabase(null)` gán `client.rest.setAuth(SupabaseService.supabaseAnonKey)` và `client.realtime.setAuth(SupabaseService.supabaseAnonKey)`. Mọi request nặc danh hợp lệ tiếp tục được phép đi qua Kong Gateway tới PostgREST theo đúng chính sách RLS `anon`.

### 2.3. Áp Dụng Onboarding JWT Trước Khi Gọi RPC
- **Trong `user_auth_service.dart`**:
  - `joinStoreByCode`: Trước khi gọi `db.rpc('join_store_by_code_v4', ...)`, code gọi:
    ```dart
    final applied = await posJwtService.applyAuthToSupabase(
      effectiveOnboardingJwt,
      allowOnboardingToken: true,
    );
    ```
    Nếu áp dụng thất bại, trả ngay `AUTH_APPLICATION_FAILED` (Fail-closed), không thực hiện RPC trong trạng thái thiếu xác thực.
  - `createStore`: Tương tự, gọi `applyAuthToSupabase` với `allowOnboardingToken: true` trước khi gọi `create_store_with_owner_v4`.

### 2.4. Lưu Trữ Bền Vững Onboarding JWT Qua `SharedPreferences`
- Bổ sung `storeOnboardingJwt`, `getStoredOnboardingJwtFor`, `clearOnboardingJwt` vào `PosJwtAuthService`.
- Khi nhân viên ở màn hình `StorePickerScreen`, nếu người dùng tải lại trang web hoặc reload app, `getStoredOnboardingJwtFor(userId)` đọc lại token từ `SharedPreferences`, kiểm tra tính hợp lệ `isOnboardingTokenValid` và khớp `sub == userId` trước khi cấp phát lại.
- Khi hoàn tất đổi token thành công sang store POS JWT (`exchangeStoreJwt`) hoặc khi gọi `logout()`, `clearOnboardingJwt()` dọn sạch token khỏi cả RAM và SharedPreferences.

### 2.5. Phân Quyền & Bảo Mật RPC `join_store_by_code_v4`
- Migration `20260913_resilient_join_store_by_code_v4.sql`:
  - Trích xuất `auth.uid()` trước; nếu null (do PostgREST JWT context chưa ánh xạ), fallback đọc `request.jwt.claims ->> 'sub'`. Nếu cả hai đều null, trả về 401 `UNAUTHORIZED`.
  - Kiểm tra mã quán `upper(trim(p_store_code))`. Nếu rỗng trả 400 `MISSING_STORE_CODE`.
  - Kiểm tra tồn tại quán trong `public.stores`. Nếu không tìm thấy, trả 404 `STORE_NOT_FOUND`.
  - Kiểm tra trạng thái quán `v_store.status IN ('suspended', 'deleted')`. Nếu bị khóa/ngừng, trả 403 `STORE_INACTIVE`.
  - Phân quyền chính xác:
    + Nếu user là `owner_user_id` của quán: Gán role `owner`, `is_owner = true`.
    + Nếu user có trong `public.staff_members` (theo id hoặc sđt tài khoản): Kế thừa vai trò từ `staff_members.role`.
    + Nếu không có trong danh sách chỉ định trước: Gán vai trò mặc định `waiter`, `is_owner = false`.
  - `SECURITY DEFINER` với `SET search_path = public, extensions, pg_temp` ngăn chặn triệt để lỗ hổng path poisoning.
  - `REVOKE ALL FROM PUBLIC` và `GRANT EXECUTE TO anon, authenticated`.

### 2.6. Bảo Toàn Phiên Làm Việc 30 Ngày Cho Nhân Viên & Chủ Quán
- `services/pos_jwt_auth_service.py` phát hành POS JWT với `ttl_seconds=2592000` (30 ngày).
- `UserAuthService.restoreSessionOnStartup()` kiểm tra tính hợp lệ của token và nạp lại vào Supabase client mà không làm gián đoạn phiên làm việc.
- `splash_screen.dart` đã loại bỏ lệnh `sessionProvider.clear()` khi khôi phục session thất bại, ngăn chặn việc xóa oan số điện thoại và tên hiển thị đã lưu của nhân viên.
