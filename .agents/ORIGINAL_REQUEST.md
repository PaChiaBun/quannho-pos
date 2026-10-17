# Original User Request

## Initial Request — 2026-09-13T07:54:51Z

This is a single self-contained fix; keep it small and focused. Kiểm tra chất lượng (QC) đối kháng, rà soát bảo mật chuyên sâu và kiểm chứng toàn diện cho các thay đổi vừa thực hiện liên quan đến luồng đăng nhập nhân viên, Onboarding JWT, RPC tham gia quán `join_store_by_code_v4`, và cập nhật hồ sơ nghiệm thu vào `nhat_ky.md`.

Working directory: /Users/banhbao/Quan Nho/quan_nho
Integrity mode: development

## Requirements

### R1. Rà Soát Đối Kháng & Đảm Bảo Tính Bất Biến Bảo Mật (Adversarial Security & Code Audit)
Thực hiện review đối kháng đa vòng trên các file vừa sửa đổi (`lib/core/services/pos_jwt_auth_service.dart`, `lib/core/services/user_auth_service.dart`, `lib/core/services/supabase_service.dart`, `lib/screens/splash_screen.dart`, `supabase/migrations/20260913_resilient_join_store_by_code_v4.sql`):
- Xác minh nguyên tắc đóng an toàn (fail-closed) 100%: mọi lỗi mạng, lỗi phân quyền, lỗi giải mã JWT, lỗi lưu trữ đều phải từ chối truy cập thay vì cấp nhầm token.
- Kiểm tra tính cô lập dữ liệu quán (`store_id` isolation), RLS policy, và cơ chế fallback trích xuất user_id từ claims JWT trong migration Postgres.
- Đảm bảo các thay đổi không gây gián đoạn phiên làm việc 30 ngày của nhân viên và chủ quán đã có quán.

### R2. Thực Thi Kiểm Thử Khách Quan (Objective Test Verification)
Chạy và kiểm chứng độc lập kết quả của các bộ kiểm thử:
- 37/37 Backend Python tests trong `test/backend/test_pos_jwt_auth_service.py` và `test/backend/test_pos_gateway_server.py`.
- 30/30 Flutter POS JWT & Onboarding tests (`test/core/onboarding_jwt_exchange_test.dart`, `test/core/pos_jwt_auth_service_test.dart`, `test/core/user_auth_service_pos_jwt_test.dart`).
- Toàn bộ suite `test/core/` và Dart static analysis (`dart analyze`) đảm bảo 0 warning, 0 error.

### R3. Cập Nhật Hồ Sơ Nghiệm Thu Nhật Ký Phát Triển (Dev Diary Update)
Ghi nhận kết quả QC đối kháng, danh sách các rủi ro biên đã kiểm chứng và hướng dẫn triển khai an toàn lên `nhat_ky.md`.

## Acceptance Criteria

### Security & Invariant Guardrails
- [ ] Phục hồi `SupabaseService.supabaseAnonKey` khi reset auth, ngăn chặn triệt để lỗi Kong 401 GATEWAY_UNAVAILABLE.
- [ ] Đảm bảo Onboarding JWT luôn được áp dụng vào Supabase client trước khi gọi `join_store_by_code_v4` và `create_store_with_owner_v4`.
- [ ] Onboarding JWT được lưu trữ bền vững qua `SharedPreferences` và được dọn dẹp triệt để khi hoàn tất đổi token hoặc khi đăng xuất.
- [ ] RPC `join_store_by_code_v4` thực thi phân quyền đúng chuẩn (`owner`, vai trò trong `staff_members`, hoặc mặc định `waiter`), từ chối mã quán sai và quán bị khóa.

### Objective Verification
- [ ] 37/37 Backend Python tests chạy thực tế đạt kết quả OK (100% pass).
- [ ] 30/30 Flutter tests về POS JWT Lifecycle & Onboarding đạt kết quả All tests passed.
- [ ] 225+ Flutter core tests không gặp lỗi regression.
- [ ] Static analyzer báo không có lỗi cú pháp hoặc cảnh báo lint.
- [ ] Nhật ký `nhat_ky.md` được cập nhật đầy đủ biên bản nghiệm thu QC.

## 2026-09-14T10:59:19Z

This is a single self-contained fix; keep it small and focused. Kiểm tra và khắc phục toàn diện module Báo cáo (`lib/screens/report_screen.dart`): sửa lỗi không thể xem được nhân viên sử dụng các voucher và sửa lỗi lệch số liệu khi tra cứu báo cáo theo ngày cũ, tuần hoặc tháng.

Working directory: /Users/banhbao/Quan Nho/quan_nho
Integrity mode: development

## Requirements

### R1. Khắc Phục Dữ Liệu & Hiển Thị Nhân Viên Áp Dụng Voucher
Sửa đổi logic hiển thị và đối soát voucher tại tab Voucher (`_VoucherTab`):
- Đảm bảo trích xuất và hiển thị chính xác tên nhân viên (thu ngân / nhân viên order / người chốt hoá đơn) đã áp dụng từng voucher thay vì hiển thị tên mặc định hoặc bị rỗng.
- Hỗ trợ đầy đủ dữ liệu từ cả hai luồng bán hàng: bán nhanh mang về (POS checkout) và thanh toán tại bàn (`ban_sessions` / `payment_settlements`).
- Đảm bảo danh sách chi tiết các đơn sử dụng voucher mở rộng xem được mã đơn, thời gian, số tiền giảm và nhân viên thực hiện.

### R2. Chuẩn Hóa Múi Giờ & Khắc Phục Sai Lệch Số Liệu Lịch Sử (Timezone & Date Range)
Khắc phục triệt để lỗi tính toán mốc thời gian truy vấn giữa Client (GMT+7) và Supabase `timestamptz`:
- Loại bỏ việc dùng chuỗi ISO địa phương không có múi giờ (`.toIso8601String()`) khi truy vấn các cột `timestamptz` (`created_at`, `clock_in`, `recorded_at`), chuyển sang sử dụng chuẩn UTC ISO (`.toUtc().toIso8601String()`) để toàn bộ các đơn hàng trong ngày (từ 00:00:00 đến 23:59:59 giờ địa phương) được lấy đầy đủ và không bị dịch chuyển 7 tiếng.
- Chuẩn hóa hàm tính khoảng thời gian `rangeFor` cho cả 3 chế độ (ngày, tuần, tháng) khi xem các mốc thời gian trong quá khứ, đảm bảo điểm chặn mốc kết thúc (`end`) phản ánh trọn vẹn chu kỳ lịch sử thay vì bị cắt gọt sai lệch.
- Đảm bảo tính nhất quán số liệu giữa các tab: Doanh thu, Sản phẩm, Tài chính, Kho, Huỷ/Duyệt, Nhân viên, và Voucher.

### R3. Đồng Bộ Trải Nghiệm Điều Hướng Thời Gian Lịch Sử Giữa Các Tab
- Bổ sung hoặc đồng bộ thanh điều hướng thời gian (chọn ngày cũ, tuần cũ, tháng cũ) trên các tab còn thiếu hoặc bị gắn cứng ngày hiện tại (như Kho, Tài chính, Huỷ/Duyệt).
- Giữ trạng thái kỳ lọc hoặc cho phép người dùng chuyển đổi linh hoạt mà không làm sai lệch số liệu thống kê tổng quan.

## Verification Resources
- Test suite hiện có: `test/` (chạy `flutter test` hoặc `dart test`).
- Bộ phân tích mã tĩnh: `dart analyze` để đảm bảo 0 warning, 0 error.
- Đồng bộ CodeGraph: `/Users/banhbao/.local/bin/codegraph sync .`

## Acceptance Criteria

### Voucher & Theo Dõi Nhân Viên
- [ ] Tab Voucher hiển thị đúng số đơn áp mã, tổng tiền giảm và danh sách chi tiết từng đơn kèm tên nhân viên chịu trách nhiệm áp voucher.
- [ ] Dữ liệu voucher tổng hợp chính xác từ cả đơn hàng POS trực tiếp lẫn đơn thanh toán bàn ăn.

### Nhất Quán Dữ Liệu Lịch Sử & Múi Giờ
- [ ] Khi chọn xem lại ngày cũ bất kỳ (hôm qua, ngày cụ thể trong tuần/tháng trước), biểu đồ doanh thu và bảng tổng hợp phản ánh chính xác 100% dữ liệu từ 00:00:00 đến 23:59:59 của ngày đó theo giờ Việt Nam.
- [ ] Khi chọn xem tuần cũ hoặc tháng cũ, tổng doanh thu và danh sách đơn hàng không bị mất đơn ở đầu kỳ hoặc cuối kỳ do lệch múi giờ UTC.
- [ ] Số liệu giữa biểu đồ Doanh thu và bảng Thống kê chi tiết bán hàng hoàn toàn khớp nhau khi tra cứu lịch sử.

### Code Quality & Static Analysis
- [ ] Chạy `dart analyze` đạt kết quả 0 issues (0 warning, 0 error).
- [ ] Không làm phá vỡ các tính năng sẵn có của module Báo cáo (in ấn PDF bill báo cáo, xem biểu đồ, lọc danh mục).
- [ ] Cập nhật kết quả nghiệm thu và giải pháp kỹ thuật vào nhật ký phát triển `nhat_ky.md`.

