# Tiến Độ Thực Hiện — Reviewer Round 2 (Report Screen Module)

## Trạng Thái Công Việc

- [x] **Bước 1: Hiểu Yêu Cầu & Rà Soát Độc Lập**:
  * Đọc hiểu yêu cầu từ `<original_task>` trước khi xem prior attempt.
  * Phân tích các yêu cầu R1 (nhân viên voucher), R2 (UTC & khoảng thời gian lịch sử), R3 (đồng bộ điều hướng ngày/tuần/tháng không vỡ layout trên 7 tab).

- [x] **Bước 2: Phá Mã (Break It) & Phát Hiện Khiếm Khuyết Đối Kháng**:
  * Chạy test suite đối kháng: phát hiện lỗi cú pháp AST ngoặc tại dòng 2040 `report_screen.dart` (`AssertionError: Mismatched ) at line 2040, col 9, expected ( for [ from line 1892, col 21`).
  * Phát hiện race condition out-of-order trên tất cả 6 tab stateful (`_RevenueTab`, `_ProductTab`, `_KhoTab`, `_VoidAuditTab`, `_StaffAttendanceTab`, `_VoucherTab`) khi bấm liên tục nút lùi/tiến `<` / `>`.
  * Phát hiện unmounting vỡ thanh điều hướng ngày/tuần/tháng khi tải hoặc gặp lỗi trong `_FinanceTab`, `_KhoTab`, `_StaffAttendanceTab`.
  * Phát hiện biến instance state bị mutate trực tiếp trong hàm async `_VoucherTabState._load()` và `_StaffAttendanceTabState._load()` trước khi `setState` được gọi.
  * Phát hiện `_StaffAttendanceTab` dùng `ChoiceChip` không chuẩn, thiếu nút lùi tiến ngày tuần tháng `<` / `>`.
  * Phát hiện unsafe casting `s['id'] as String` và `DateTime.parse()` gây sập app với dữ liệu thực tế.

- [x] **Bước 3: Sửa Đổi & Gia Cố (Fix)**:
  * Khắc phục AST bracket balance: bổ sung `],` đóng `Column.children` bị thiếu trước khi đóng `Column` và `statsA.when`.
  * Thêm `int _loadRequestId = 0;` và sequence guard `if (!mounted || requestId != _loadRequestId) return;` trên cả 6 tab stateful.
  * Chuyển `_PeriodPills` và `_ReportNavBar` lên vị trí bền vững (persistent top level) trong `_FinanceTab`, `_KhoTab`, `_StaffAttendanceTab`, lồng trạng thái loading/error xuống dưới body.
  * Chuẩn hóa bộ tích lũy cục bộ `int totalOrders = 0; double totalDiscount = 0;` trong `_VoucherTabState._load()` và commit nguyên tử trong `setState`.
  * Đồng bộ `_StaffAttendanceTab` sang `_PeriodPills` và `_ReportNavBar` hỗ trợ ngày/tuần/tháng với các nút `<` và `>`.
  * Bọc an toàn `?.toString()` và `DateTime.tryParse()` chống crash `TypeError` và `FormatException`.
  * Bổ sung dynamic `periodLabel` khi xuất báo cáo in nhiệt hoặc PDF.

- [x] **Bước 4: Kiểm Chứng Lại (Re-verify)**:
  * Chạy `test/test_report_screen_r1_verification.py`: **10/10 tests PASS 100%**.
  * Kiểm tra toàn bộ cân bằng ngoặc đơn, ngoặc vuông, ngoặc nhọn AST trên toàn bộ 5046 dòng `report_screen.dart`: **Hoàn toàn cân bằng**.
  * Xác minh `git diff`: Không còn bất kỳ file rác hay chỉnh sửa ngoài phạm vi nào.
