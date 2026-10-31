# DISPATCH

## 2026-09-14T11:00:28Z

You are the SWE Light orchestrator (`teamwork_preview_swe`).

Your Working Directory: `/Users/banhbao/Quan Nho/quan_nho/.agents/teamwork_preview_swe_2`
Project Root: `/Users/banhbao/Quan Nho/quan_nho`
Original Request File: `/Users/banhbao/Quan Nho/quan_nho/.agents/ORIGINAL_REQUEST.md` (see section `## 2026-09-14T10:59:19Z`)

## Mission
Kiểm tra và khắc phục toàn diện module Báo cáo (`lib/screens/report_screen.dart`): sửa lỗi không thể xem được nhân viên sử dụng các voucher và sửa lỗi lệch số liệu khi tra cứu báo cáo theo ngày cũ, tuần hoặc tháng.

## Key Requirements
1. **R1. Khắc Phục Dữ Liệu & Hiển Thị Nhân Viên Áp Dụng Voucher**:
   - Sửa đổi logic hiển thị và đối soát voucher tại tab Voucher (`_VoucherTab`).
   - Đảm bảo trích xuất và hiển thị chính xác tên nhân viên (thu ngân / nhân viên order / người chốt hoá đơn) đã áp dụng từng voucher thay vì hiển thị tên mặc định hoặc bị rỗng.
   - Hỗ trợ đầy đủ dữ liệu từ cả hai luồng bán hàng: bán nhanh mang về (POS checkout) và thanh toán tại bàn (`ban_sessions` / `payment_settlements`).
   - Đảm bảo danh sách chi tiết các đơn sử dụng voucher mở rộng xem được mã đơn, thời gian, số tiền giảm và nhân viên thực hiện.

2. **R2. Chuẩn Hóa Múi Giờ & Khắc Phục Sai Lệch Số Liệu Lịch Sử (Timezone & Date Range)**:
   - Khắc phục triệt để lỗi tính toán mốc thời gian truy vấn giữa Client (GMT+7) và Supabase `timestamptz`.
   - Loại bỏ việc dùng chuỗi ISO địa phương không có múi giờ (`.toIso8601String()`) khi truy vấn các cột `timestamptz` (`created_at`, `clock_in`, `recorded_at`), chuyển sang sử dụng chuẩn UTC ISO (`.toUtc().toIso8601String()`) để toàn bộ các đơn hàng trong ngày (từ 00:00:00 đến 23:59:59 giờ địa phương) được lấy đầy đủ và không bị dịch chuyển 7 tiếng.
   - Chuẩn hóa hàm tính khoảng thời gian `rangeFor` cho cả 3 chế độ (ngày, tuần, tháng) khi xem các mốc thời gian trong quá khứ, đảm bảo điểm chặn mốc kết thúc (`end`) phản ánh trọn vẹn chu kỳ lịch sử thay vì bị cắt gọt sai lệch.
   - Đảm bảo tính nhất quán số liệu giữa các tab: Doanh thu, Sản phẩm, Tài chính, Kho, Huỷ/Duyệt, Nhân viên, và Voucher.

3. **R3. Đồng Bộ Trải Nghiệm Điều Hướng Thời Gian Lịch Sử Giữa Các Tab**:
   - Bổ sung hoặc đồng bộ thanh điều hướng thời gian (chọn ngày cũ, tuần cũ, tháng cũ) trên các tab còn thiếu hoặc bị gắn cứng ngày hiện tại (như Kho, Tài chính, Huỷ/Duyệt).
   - Giữ trạng thái kỳ lọc hoặc cho phép người dùng chuyển đổi linh hoạt mà không làm sai lệch số liệu thống kê tổng quan.

## Verification & Acceptance
- Tab Voucher hiển thị đúng số đơn áp mã, tổng tiền giảm và danh sách chi tiết từng đơn kèm tên nhân viên chịu trách nhiệm.
- Dữ liệu voucher tổng hợp chính xác từ cả đơn hàng POS trực tiếp lẫn đơn thanh toán bàn ăn.
- Khi chọn xem lại ngày cũ bất kỳ (hôm qua, ngày cụ thể trong tuần/tháng trước), biểu đồ doanh thu và bảng tổng hợp phản ánh chính xác 100% dữ liệu từ 00:00:00 đến 23:59:59 của ngày đó theo giờ Việt Nam.
- Khi chọn xem tuần cũ hoặc tháng cũ, tổng doanh thu và danh sách đơn hàng không bị mất đơn ở đầu kỳ hoặc cuối kỳ do lệch múi giờ UTC.
- Số liệu giữa biểu đồ Doanh thu và bảng Thống kê chi tiết bán hàng hoàn toàn khớp nhau khi tra cứu lịch sử.
- Chạy `dart analyze` đạt kết quả 0 issues (0 warning, 0 error).
- Toàn bộ bài test liên quan pass 100%.
- Không làm phá vỡ các tính năng sẵn có của module Báo cáo (in ấn PDF bill báo cáo, xem biểu đồ, lọc danh mục).
- Cập nhật nhật ký phát triển `nhat_ky.md`.
- Đồng bộ CodeGraph nếu cần: `/Users/banhbao/.local/bin/codegraph sync .`
