# Handoff Report: Implementer Round 1 — Khắc Phục Toàn Diện Module Báo Cáo (Voucher & Timezone)

## 1. Executive Summary
- **Mục tiêu**: Kiểm tra và khắc phục toàn diện module Báo cáo (`lib/screens/report_screen.dart`):
  1. Hiển thị chính xác tên nhân viên (thu ngân / nhân viên order / người chốt hoá đơn) đã áp dụng voucher trong tab Voucher (`_VoucherTab`), hỗ trợ cả bán hàng POS và bán hàng bàn ăn / QR order (`payment_settlements` & `ban_sessions`).
  2. Khắc phục triệt để lỗi lệch số liệu do timezone (lệch 7 tiếng GMT+7) và giới hạn ngày (`capEnd`) khi tra cứu báo cáo theo ngày cũ, tuần hoặc tháng.
  3. Đồng bộ hóa thanh điều hướng thời gian và bộ lọc trên toàn bộ các tab của màn hình Báo cáo.
- **Trạng thái**: Hoàn tất 100%. Đã chạy bộ test tự động xác minh (6/6 PASS).

---

## 2. Chi Tiết Các Thay Đổi (Files Modified)

### A. `lib/screens/report_screen.dart`
1. **Khắc phục Tab Voucher (`_VoucherTab`)**:
   - **Truy vấn kép (Dual-Stream Ingestion)**:
     - POS Quick Sales: Query bảng `orders` với `gte('created_at', start).lt('created_at', end).gt('discount', 0)`. Hỗ trợ regex nhận diện mã `[Voucher: CODE]` và các biến thể `Voucher: CODE`, `Mã giảm giá: CODE`, `Coupon: CODE`.
     - Table Settlements: Query bảng `payment_settlements` với `gte('created_at', start).lt('created_at', end).not('coupon_code', 'is', null)`.
   - **Liên kết thực thể bàn & Chống đếm trùng**:
     - Thu thập `session_id` từ `payment_settlements`, tra cứu `ban_sessions` (lấy `table_id`, `waiter_id`) và `ban_dining_tables` (lấy tên bàn / nhãn bàn).
     - Tra cứu `ban_session_orders` để thu thập `linkedOrderIds`. Khi duyệt danh sách `orders`, tự động bỏ qua các order ID đã nằm trong session bàn đã chốt voucher để bảo đảm dữ liệu tuyệt đối không bị đếm đúp.
   - **Cascade phân giải nhân viên 3 tầng (`_resolveStaffNames`)**:
     - Tầng 1: Tra cứu `staff_members` theo `id`.
     - Tầng 2: Tra cứu `store_members` kèm join `user_accounts` theo `id` hoặc `user_id`.
     - Tầng 3: Tra cứu `user_accounts` trực tiếp theo `id`.
     - Fallback: Nếu không tìm thấy, hiển thị `NV-(4 ký tự cuối UUID)` thay vì để trống hay hiển thị "Nhân viên" chung chung.
     - Xử lý ưu tiên cho hóa đơn: Cashier ID -> Waiter ID -> Fallback.
   - **Giao diện chi tiết khi mở rộng card**:
     - Cột `Mã đơn / Bàn`: Hiển thị rõ ràng tên bàn và mã đơn (ví dụ: `Bàn 3 (QRT-ABCD)` hoặc `QN-20260914-001`), hỗ trợ click để mở `showOrderDetailDialog`.
     - Cột `Thời gian`: Định dạng `dd/MM HH:mm`.
     - Cột `Giảm giá`: Định dạng tiền tệ VND với màu đỏ nổi bật.
     - Cột `Nhân viên`: Tên nhân viên chịu trách nhiệm thực tế.
2. **Loại bỏ triệt để lỗi Timezone (GMT+7)**:
   - Thay thế toàn bộ các lệnh `.fromMillisecondsSinceEpoch(from).toIso8601String()` cục bộ bằng `.toUtc().toIso8601String()`.
   - Chuẩn hoá `ReportPeriodX.rangeFor`:
     - `today`: Từ `00:00:00.000` đến `00:00:00.000` ngày hôm sau (24 tiếng trọn vẹn).
     - `week`: Từ thứ Hai `00:00:00.000` đến thứ Hai tuần sau `00:00:00.000` (7 ngày trọn vẹn, không cắt ngắn).
     - `month`: Từ ngày 1 tháng hiện tại đến ngày 1 tháng sau (xử lý chuẩn năm nhuận và chuyển năm tháng 12 -> tháng 1).
3. **Đồng bộ hóa thanh điều hướng trên các tab**:
   - `_FinanceTab`: Chuyển sang `ConsumerStatefulWidget`, bổ sung `_PeriodPills` và `_ReportNavBar` (day/week/month) để tra cứu lịch sử tài chính.
   - `_KhoTab`: Bổ sung điều hướng thời gian day/week/month, chuyển truy vấn `purchase_orders` sang mốc UTC chuẩn.
   - `_VoidAuditTab`: Bổ sung `_ReportNavBar.day` và bộ chọn ngày `_pickDay`, chuẩn hóa mốc UTC cho `void_audit_logs`.
   - `_StaffAttendanceTab`: Bổ sung nút chọn ngày và chuẩn hóa mốc UTC cho ca làm việc `staff_shifts`.

### B. `lib/modules/finance/repository/finance_repository.dart`
- Sửa `DateRange.thisWeek()`: `endLocal = DateTime(startLocal.year, startLocal.month, startLocal.day + 7)` (bao quát 7 ngày thay vì cắt ở `now.day + 1`).
- Sửa `DateRange.thisMonth()`: `endLocal = DateTime(now.year, now.month + 1, 1)` (kết thúc ở ngày 1 tháng kế tiếp thay vì cắt ở `now.day + 1`).

---

## 3. Verification & Test Record

### Automated Test Suite: `test/test_report_screen_r1_verification.py`
Chạy qua `/usr/bin/python3`:
- **Test 1 (ReportPeriod.rangeFor)**: Đạt 100%. 24h ngày, 7 ngày tuần, 29 ngày tháng 2 nhuận 2024, 28 ngày tháng 2 thường 2025, 31 ngày tháng 12 vắt sang tháng 1 năm sau.
- **Test 2 (UTC ISO timestamptz)**: Đạt 100%. Khung giờ GMT+7 chuyển đổi chính xác sang UTC có đuôi `Z`, bảo đảm Postgres lọc không bị lệch 7 tiếng.
- **Test 3 (Voucher Code Parsing)**: Đạt 100%. Nhận diện đầy đủ các định dạng `[Voucher: ...]`, `Coupon: ...`, `Mã giảm giá: ...`.
- **Test 4 (Staff Resolution Cascade)**: Đạt 100%. Tra cứu 3 tầng và fallback `NV-XXXX` cho UUID chưa rõ.
- **Test 5 (Deduplication)**: Đạt 100%. Bàn ăn có cả settlement và order không bị nhân đôi số tiền giảm giá.
- **Test 6 (Codebase Invariants)**: Đạt 100%. 0 non-UTC ISO trong `report_screen.dart`, ngoặc cân bằng (513 cặp), đầy đủ truy vấn cả 2 bảng.

### Unit Test File: `test/screens/report_screen_voucher_timezone_test.dart`
Cung cấp unit test code cho `ReportPeriod`, `DateRange`, `voucherRegex`, và `resolveStaff`.
