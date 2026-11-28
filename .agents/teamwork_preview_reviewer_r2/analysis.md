# Phân Tích Kỹ Thuật QC Đối Kháng — Reviewer Round 2 (teamwork_preview_reviewer_r2)

## 1. Mục Tiêu & Phạm Vi Kiểm Chứng
Kiểm tra đối kháng độc lập, rà soát bảo mật chuyên sâu và kiểm chứng toàn diện cho:
- `lib/core/services/pos_jwt_auth_service.dart`: Quản lý lifecycle POS JWT & Onboarding JWT, fail-closed rollback, và token validation.
- `lib/core/services/user_auth_service.dart`: Luồng đăng nhập, tham gia quán `joinStoreByCode`, tạo quán `createStore`, khôi phục phiên `restoreSessionOnStartup`.
- `lib/core/services/supabase_service.dart`: Khởi tạo & phục hồi `supabaseAnonKey`.
- `lib/screens/splash_screen.dart`: Điều hướng chính xác giữa `/home`, `/store_picker`, `/auth`.
- `supabase/migrations/20260913_resilient_join_store_by_code_v4.sql`: Migration Postgres cho `join_store_by_code_v4` và `create_store_with_owner_v4`.
- `services/pos_jwt_auth_service.py` & `services/pos_gateway_server.py`: Backend gateway auth handlers.

## 2. Phát Hiện & Khiếm Khuyết Tìm Thấy Qua Đối Kháng (Defects & Root Causes)

### Khiếm khuyết 1: Cú pháp `?storeId` bất thường trong `test/core/onboarding_jwt_exchange_test.dart`
- **Hiện tượng**: Dòng 38 sử dụng cú pháp `'store_id': ?storeId,` trong Map literal.
- **Nguyên nhân**: Null-aware map elements là tính năng thử nghiệm; trong môi trường biên dịch chuẩn không có flag thử nghiệm, cú pháp này gây lỗi phân tích cú pháp (parse error).
- **Khắc phục**: Chuyển thành cú pháp chuẩn `if (storeId != null) 'store_id': storeId,`.

### Khiếm khuyết 2: Thiếu kiểm tra `exp > iat` trong giải mã JWT (`isTokenValid` & `isOnboardingTokenValid`)
- **Hiện tượng**: Token có thể có `exp <= iat` (thời điểm hết hạn trước hoặc bằng thời điểm phát hành) nếu chỉ kiểm tra `exp > now + 30`.
- **Nguyên nhân**: Thiếu ràng buộc `exp > issuedAt` trên client Dart và backend Python.
- **Khắc phục**:
  - Bổ sung `exp > issuedAt` trong `isTokenValid` và `isOnboardingTokenValid` (Dart).
  - Bổ sung `payload.get("exp", 0) <= payload.get("iat", 0)` trong `verify_and_decode_hs256_jwt` (Python).

### Khiếm khuyết 3: `createStore` trong `UserAuthService` thiếu hỗ trợ `rpcOverride` và không truyền `errorCode`
- **Hiện tượng**: Khi gọi `UserAuthService.createStore()`, nếu `_db == null` hàm lập tức báo lỗi mạng mà không kiểm tra `rpcOverride`, khiến unit test không thể mô phỏng luồng tạo quán; đồng thời khi RPC trả lỗi, `CreateStoreResult.error` không truyền `errorCode`.
- **Nguyên nhân**: Sự bất đối xứng so với `joinStoreByCode` đã được trang bị `rpcOverride`.
- **Khắc phục**: Bổ sung `rpcOverride` check, bọc `StoreAuthService.seedDefaults(db, storeId)` với `if (db != null)`, và truyền `errorCode` từ RPC.

### Khiếm khuyết 4: `create_store_with_owner_v4` không bắt trùng `store_code` khi người dùng truyền mã tường minh
- **Hiện tượng**: Nếu truyền `p_store_code` tùy chọn bị trùng lặp trong `public.stores`, hàm ném unhandled Postgres duplicate key exception thay vì trả mã lỗi 409 chuẩn.
- **Khắc phục**: Thêm pre-check `SELECT EXISTS` và trả về `status: 409, error_code: 'STORE_CODE_EXISTS'`.

### Khiếm khuyết 5: Thiếu Unit Test cho `createStore` với Onboarding JWT
- **Hiện tượng**: Suite test chỉ kiểm thử `joinStoreByCode` và `register`, bỏ quên luồng `createStore` của chủ quán mới.
- **Khắc phục**: Bổ sung Test #16 (Tạo quán thành công, áp dụng onboarding token, gọi RPC và đổi POS JWT) và Test #17 (Fail-closed khi onboarding token hết hạn) vào `test/core/user_auth_service_pos_jwt_test.dart`.

### Khiếm khuyết 6: Thiếu Unit Tests cho các ranh giới giải mã JWT trong Python backend
- **Hiện tượng**: `test_pos_jwt_auth_service.py` thiếu kiểm thử cho trường hợp onboarding token mang `store_id` lậu, thiếu `store_id` khi exchange, dùng algorithm `none`, và `exp <= iat`.
- **Khắc phục**: Bổ sung Tests #24, #25, #26, #27 vào `test_pos_jwt_auth_service.py`.

## 3. Tổng Kết Đánh Giá Tính Bất Biến (Invariant Evaluation)
- **Fail-Closed 100%**: Mọi lỗi mạng, token hỏng, lỗi apply auth đều dọn sạch storage và phục hồi `supabaseAnonKey`.
- **Data Isolation**: Store ID được enforce từ server-side PostgreSQL và PostgREST claims.
- **30-Day Session Persistence**: POS JWT giữ nguyên 30 ngày, Splash screen không xóa session người dùng khi offline/token hết hạn.
