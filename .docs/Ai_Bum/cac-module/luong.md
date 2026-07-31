# 💰 Module: Lương

**Trạng thái:** ✅ Đang vận hành  
**Cập nhật:** 30/07/2026

---

## Mục Đích

Giúp chủ quán thiết lập chính sách, tạo kỳ lương từ dữ liệu chấm công, rà soát sai lệch, duyệt và ghi nhận thanh toán minh bạch.

Tên hiển thị thương mại luôn là **Lương**. “Thân – Tâm – Tuệ” chỉ là định hướng quản trị con người, không phải tên module và không được dùng trực tiếp làm căn cứ khấu trừ.

## Luồng Sử Dụng Chính

1. Vào **Cấu hình lương** và thiết lập chính sách chung theo vị trí.
2. Nếu một người có thỏa thuận riêng, chuyển sang **Theo nhân viên** để ghi đè.
3. Chọn **Tạo kỳ lương**; hệ thống tổng hợp giờ/công từ Chấm công.
4. Xử lý các mục **Cần rà soát**: thiếu cấu hình, quên chốt ca, OT chờ duyệt.
5. Kiểm tra chi tiết từng nhân viên rồi **Gửi duyệt**.
6. Sau khi duyệt, ghi nhận **Đã trả**; hệ thống đồng bộ khoản chi sang Thu Chi.

## Cấu Hình Chính Sách

- **M1 — Theo giờ:** giờ làm hợp lệ × đơn giá giờ.
- **M2 — Cố định:** lương cơ bản theo kỳ.
- **M3 — Cố định + OT:** lương cơ bản cộng tiền tăng ca.
- **M4 — Theo ngày:** số ngày/công hợp lệ × đơn giá ngày.
- **M5 — Tùy chỉnh:** kết hợp lương nền, đơn giá giờ/ngày và OT theo thỏa thuận.

Mỗi chính sách có các nhóm riêng:

- **Cách tính lương:** mức nền, đơn giá, số ngày chuẩn.
- **Thưởng & phụ cấp:** thưởng cố định, chuyên cần, phụ cấp.
- **OT:** ngưỡng tính, hệ số và yêu cầu duyệt.
- **Khấu trừ:** chỉ áp dụng các quy tắc đã cấu hình rõ ràng.

Mặc định ưu tiên chính sách theo vị trí. Cấu hình riêng theo nhân viên chỉ ghi đè cho đúng người được chọn.

## Báo Cáo Và Rà Soát

- Bảng báo cáo cho phép tìm tên, lọc vị trí/trạng thái và sắp xếp.
- Chạm tên nhân viên để xem chi tiết giờ thường, OT, thưởng/phụ cấp, khấu trừ và thực lĩnh.
- Cột **Cần rà soát** tập trung các lỗi có thể làm sai lương.
- Hệ thống chặn gửi duyệt khi chưa tải được trạng thái sẵn sàng hoặc còn lỗi bắt buộc.

## Lưu Ý Kỹ Thuật

- Dữ liệu cấu hình: `staff_salary_configs`, cô lập theo `store_id` và bật RLS.
- Client chỉ có quyền `SELECT`, `INSERT`, `UPDATE`; không cấp `DELETE` hoặc `TRUNCATE`.
- Migration chuẩn: `supabase/payroll_salary_config_migration.sql`.
- Không đổi các khóa nội bộ `tinhluong.*`, tên model/RPC cũ nếu chưa có kế hoạch tương thích dữ liệu.

## Câu Hỏi Thường Gặp

- *“Nên cấu hình từng người hay từng vị trí?”* → Thiết lập theo vị trí trước; chỉ dùng cấu hình riêng khi nhân viên có thỏa thuận khác.
- *“M5 dùng khi nào?”* → Khi cách trả lương cần kết hợp nhiều thành phần mà M1–M4 chưa đáp ứng.
- *“Vì sao chưa gửi duyệt được?”* → Mở “Cần rà soát” và xử lý thiếu cấu hình, quên chốt ca hoặc OT đang chờ duyệt.
- *“Số tiền báo cáo từ đâu?”* → Từ ca làm hợp lệ, chính sách hiệu lực của nhân viên và các khoản điều chỉnh trong kỳ.
