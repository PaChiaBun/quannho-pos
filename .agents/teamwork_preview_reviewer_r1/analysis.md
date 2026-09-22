# Báo Cáo Phân Tích Kỹ Thuật Đối Kháng & Kiểm Chứng Bảo Mật (Adversarial Audit & Analysis)

**Vị trí**: Reviewer Round 1 (`reviewer@swe_light`, `qa@swe_light`)  
**Workspace**: `/Users/banhbao/Quan Nho/quan_nho`  
**Mục tiêu**: Kiểm tra chất lượng (QC) đối kháng, rà soát bảo mật chuyên sâu và kiểm chứng toàn diện cho các thay đổi liên quan đến luồng đăng nhập nhân viên, Onboarding JWT, RPC tham gia quán `join_store_by_code_v4`, và RPC tạo quán `create_store_with_owner_v4`.

---

## 1. Bản Chất Nghiệp Vụ & Bối Cảnh Lỗi Hệ Thống

Hệ thống POS Quán Nhỏ chia người dùng đăng nhập thành 2 nhóm trạng thái:
1. **Người dùng đã có quán (Nhân viên / Chủ quán cũ)**:
   - Đăng nhập thành công sẽ được cấp ngay một **POS JWT** có thời hạn **30 ngày** (`ttl_seconds=2592000`), gắn liền với `store_id` cụ thể.
   - Các truy vấn qua PostgREST client đều được bảo vệ bằng RLS policy dựa trên `store_id`.
2. **Người dùng mới chưa có quán (Nhân viên mới tự đăng ký hoặc vừa tạo tài khoản)**:
   - Không thể cấp ngay POS JWT vì chưa xác định được `store_id`.
   - POS JWT Gateway cấp một **Onboarding JWT** có thời hạn **10 phút** (`ttl_seconds=600`, `token_use="onboarding"`).
   - Người dùng được chuyển hướng đến `StorePickerScreen` để thực hiện một trong hai hành động:
     * **Nhân viên**: Nhập mã kết nối `QN-XXXX` -> gọi RPC `join_store_by_code_v4` -> đổi Onboarding JWT lấy POS JWT của quán qua `exchangeStoreJwt`.
     * **Chủ quán**: Nhập tên quán -> gọi RPC `create_store_with_owner_v4` -> tạo quán mới và nhận POS JWT vai trò `owner`.

### Các Lỗ Hổng & Điểm Nghẽn Ban Đầu (Gốc rễ 2 sự cố thiết bị nhân viên 2026-09-13):
1. **Lỗi Kong 401 GATEWAY_UNAVAILABLE khi reset auth**:
   - `applyAuthToSupabase(null)` trước đây gọi `client.rest.setAuth(null)`, PostgREST client bị xóa Authorization header. Các request tiếp theo gửi qua Kong API Gateway bị từ chối 401 Unauthorized do thiếu anon key.
2. **Lỗi 401 UNAUTHORIZED khi gọi RPC `join_store_by_code_v4`**:
   - Onboarding JWT sau khi cấp chưa được nạp vào Supabase client (`applyAuthToSupabase(effectiveOnboardingJwt)`), nên request PostgREST gửi lên RPC bị xem là unauthenticated (`auth.uid() IS NULL`).
3. **Mất phiên Onboarding khi reload**:
   - Onboarding JWT ban đầu chỉ lưu trong biến RAM tĩnh `_activeOnboardingJwt`. Nếu người dùng refresh trang hoặc trình duyệt reload ở màn StorePicker, token bị biến mất.

---

## 2. Phát Hiện Khiếm Khuyết Đối Kháng Của Reviewer (Adversarial Defects Discovered)

Sau khi rà soát từng dòng mã và thử nghiệm phá vỡ logic (breaking analysis), Reviewer phát hiện 5 khiếm khuyết trong bản triển khai ban đầu:

### Lỗ hổng 1: `requestOnboardingJwt()` không thực thi Fail-Closed khi gặp lỗi mạng hoặc HTTP error
- **Input**: Gọi `requestOnboardingJwt()`, server trả mã HTTP 401/403/500, trả response non-JSON, hoặc kết nối mạng bị ném ngoại lệ (`catch (_)`).
- **Expected**: Toàn bộ Onboarding JWT cũ phải bị xóa sạch khỏi RAM và `SharedPreferences` (`await clearOnboardingJwt()`), đồng thời Supabase client auth phải được reset an toàn về anon key (`await applyAuthToSupabase(null)`).
- **Actual**: Đầu hàm chỉ gọi hàm đồng bộ `clearActiveOnboardingJwt()` (chỉ xóa RAM, không xóa SharedPreferences). Khi có ngoại lệ hoặc lỗi server, hàm `return` ngay mà không dọn dẹp `SharedPreferences` và không reset Supabase client, khiến token onboarding hỏng/cũ vẫn tồn tại trong storage và auth state không nhất quán.
- **Root cause**: Thiếu fail-closed cleanup trong các khối error branch và catch block của `requestOnboardingJwt()`.
- **Khắc phục**: 
  * Chuyển đầu hàm sang `await clearOnboardingJwt()`.
  * Thêm `await clearOnboardingJwt(); await applyAuthToSupabase(null);` vào mọi nhánh lỗi (non-JSON, HTTP status != 200, và catch block).

### Lỗ hổng 2: `requestPosJwt()` lưu token trước khi kiểm tra và lọt token rỗng do điều kiện `token.isNotEmpty`
- **Input**: Server trả về `{"success": true, "pos_jwt": ""}` hoặc token rác không đúng cấu trúc JWT / sai `store_id`.
- **Expected**: Token phải bị từ chối ngay lập tức, không ghi vào disk, thực hiện rollback và trả mã lỗi `502 INVALID_TOKEN_RESPONSE` hoặc `AUTH_APPLICATION_FAILED`.
- **Actual**: 
  1. `storePosJwt(token)` được gọi trước khi `isTokenValid(token, expectedStoreId: storeId)` kiểm tra, ghi rác vào disk.
  2. Điều kiện rollback ghi: `if (!applied && token.isNotEmpty)`. Khi `token == ""`, `applied` là `false`, nhưng `token.isNotEmpty` cũng là `false`, làm cho mệnh đề `!applied && token.isNotEmpty` trả về `false`! Kết quả: Hàm bỏ qua hoàn toàn bước rollback và trả về `success: true` với token rỗng!
- **Root cause**: Thiếu pre-storage validation và đặt điều kiện rollback sai logic.
- **Khắc phục**:
  * Kiểm tra `if (!isTokenValid(token, expectedStoreId: storeId))` TRƯỚC KHI gọi `storePosJwt(token)`.
  * Thay `if (!applied && token.isNotEmpty)` bằng `if (!applied)`.

### Lỗ hổng 3: `storeOnboardingJwt()` ghi token hỏng vào `SharedPreferences`
- **Input**: Gọi `storeOnboardingJwt(token)` với token đã hết hạn hoặc không hợp lệ.
- **Expected**: Không lưu token hỏng vào SharedPreferences, dọn sạch storage nếu token không đạt chuẩn.
- **Actual**: `setActiveOnboardingJwt(token)` từ chối lưu vào RAM (gọi `clearActiveOnboardingJwt()`), nhưng `storeOnboardingJwt` vẫn tiếp tục gọi `prefs.setString(_kPosOnboardingJwtStorageKey, token)` ghi đè token hỏng vào `SharedPreferences`.
- **Root cause**: Thiếu kiểm tra điều kiện `isOnboardingTokenValid(token)` trong `storeOnboardingJwt()`.
- **Khắc phục**: Kiểm tra `if (isOnboardingTokenValid(token))` trước khi ghi; nếu không hợp lệ gọi `await clearOnboardingJwt()`.

### Lỗ hổng 4: `getStoredOnboardingJwtFor()` không thanh trừng (purge) token đã hết hạn
- **Input**: User có Onboarding JWT lưu trong `SharedPreferences` đã quá hạn 10 phút.
- **Expected**: Khi đọc thấy token hết hạn, hệ thống cần chủ động dọn dẹp (`remove`) khỏi storage để tránh tích tụ dữ liệu rác.
- **Actual**: Hàm chỉ kiểm tra `isOnboardingTokenValid(token)` rồi trả về `null`, để nguyên token hết hạn trong storage.
- **Root cause**: Thiếu eager purge logic trong accessor.
- **Khắc phục**: Thêm nhánh `else { await prefs.remove(_kPosOnboardingJwtStorageKey); }`.

### Lỗ hổng 5: Thiếu cơ chế trích xuất resilient claims trong `create_store_with_owner_v4`
- **Input**: Chủ quán mới đăng ký tài khoản, nhận Onboarding JWT, sau đó bấm "Tạo quán mới" gọi `create_store_with_owner_v4`.
- **Expected**: RPC trích xuất được `user_id` từ claims của Onboarding JWT và tạo quán thành công.
- **Actual**: Migration `20260913_resilient_join_store_by_code_v4.sql` ban đầu chỉ cập nhật fallback cho `join_store_by_code_v4`, bỏ quên `create_store_with_owner_v4`. Nếu PostgREST không bind `auth.uid()` từ custom claims, chủ quán mới sẽ gặp lỗi 401 `UNAUTHORIZED` tương tự nhân viên.
- **Root cause**: Phạm vi migration chưa bao quát toàn bộ các RPC sử dụng Onboarding JWT.
- **Khắc phục**: Bổ sung định nghĩa nguyên tử `create_store_with_owner_v4` với cơ chế đa tầng `auth.uid()` -> `request.jwt.claims ->> 'sub'` vào file migration `supabase/migrations/20260913_resilient_join_store_by_code_v4.sql`.

---

## 3. Bản Đồ Invariant & Bằng Chứng Kiểm Thử

1. **Kong Anon Key Invariant**:
   - Khi `applyAuthToSupabase(null)` được gọi (lúc logout hoặc reset), token được truyền vào PostgREST và Realtime client là `SupabaseService.supabaseAnonKey`. Header `Authorization: Bearer <anon_key>` luôn luôn hiện diện.
2. **Onboarding JWT Scope & Expiry**:
   - TTL Onboarding JWT là 600 giây (10 phút).
   - Kiểm tra `token_use == 'onboarding'`, `store_id == null`, `aud == 'authenticated'`.
3. **POS JWT 30-Day TTL**:
   - TTL POS JWT là 2,592,000 giây (30 ngày), kiểm chứng độc lập qua test backend Python #23 (`test_23_default_pos_jwt_ttl_is_30_days`).
4. **Backend Python Test Suite**:
   - Chạy thực tế: 38/38 tests PASS 100% trong 0.015s.
