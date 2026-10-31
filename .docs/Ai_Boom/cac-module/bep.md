# 👨‍🍳 Module: Bếp (Kitchen)

**Trạng thái:** ✅ Hoàn thành
**Cập nhật:** 14/05/2026

---

## Mục Đích
Màn hình chuyên dụng cho bếp — nhận phiếu gọi món và cập nhật trạng thái chế biến theo thời gian thực.

## Tính Năng Chính
- Giao diện Kanban 3 cột: **Chờ làm → Đang làm → Xong**
- Nhận phiếu gọi món realtime từ Bàn (không cần F5)
- Cập nhật trạng thái từng phiếu bằng 1 nút
- Thông báo âm thanh khi có đơn mới (chuông 1 tiếng)
- Thông báo âm thanh khi xong (chuông 2 tiếng ngắn)
- Báo động khi phiếu chờ quá 30 phút (âm thanh khẩn cấp)
- Xem ghi chú đặc biệt từng món
- In phiếu bếp (PDF 80mm) từ bất kỳ phiếu nào
- Lọc theo trạm: Tất cả / Bếp nóng / Bar nước
- Thống kê ngày: tổng phiếu, phiếu xong, thời gian trung bình

## Thông Báo Huỷ Món (Void Notice)

> **Khi nhân viên huỷ món đã gửi → bếp thấy banner đỏ ngay lập tức.**

Banner "THÔNG BÁO SỬA ĐƠN" hiển thị:
- Tên món bị huỷ + tên bàn
- Lý do huỷ (Khách đổi ý / Nhầm / Hết món / Khác)
- Tên nhân viên thực hiện
- Tự động biến mất sau **30 giây** hoặc bấm "Đã hiểu ✓"

**Lưu ý:** Nhân viên sẽ đồng thời báo bếp qua bộ đàm — banner chỉ là xác nhận thêm.

## Kết Nối Module Khác
- **← Bàn:** Gửi bếp → phiếu xuất hiện ngay ở cột "Chờ làm"
- **← Bàn:** Huỷ món → banner đỏ thông báo
- **→ Bàn:** Phiếu xong → nhân viên nhận snackbar "Món đã sẵn sàng!"

## Thiết Kế Cho Màn Hình Bếp
- Font lớn, dễ đọc từ xa (tablet dựng đứng)
- Nền tối (#0D1117) — không chói mắt trong bếp
- Màu phân biệt rõ: Đỏ (chờ) / Vàng (đang làm) / Xanh (xong)
- Kanban 3 cột trên tablet/desktop, Tab trên mobile

## Câu Hỏi Thường Gặp
- *"Bếp không nhận được phiếu?"* → Kiểm tra kết nối internet + quyền module Bếp đã bật cho role
- *"Xem ghi chú của khách?"* → Hiện ngay trong card phiếu, phía dưới tên món
- *"Tắt tiếng chuông?"* → Nhấn icon 🔊 góc phải trên AppBar → chuyển sang 🔇
- *"In phiếu bếp?"* → Nhấn 🖨️ trên card phiếu bất kỳ → xem trước → in hoặc chia sẻ
- *"Phiếu quá 30 phút?"* → App tự phát báo động + viền đỏ nháy trên card
- *"Nhân viên báo huỷ món nhưng bếp không thấy?"* → Kiểm tra bếp đang mở đúng màn hình Bếp + có mạng
