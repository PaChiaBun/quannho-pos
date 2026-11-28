# 🛒 Module: Bán Hàng (POS)

**Trạng thái:** ✅ Hoàn thành
**Cập nhật:** 29/04/2026

---

## Mục Đích
Tạo đơn hàng nhanh, quản lý giỏ hàng, thanh toán. Đây là module **trung tâm** của toàn bộ hệ thống.

## Tính Năng Chính
- Chọn món từ thực đơn (phân loại theo danh mục)
- Tìm kiếm món nhanh
- Thêm ghi chú riêng cho từng món
- Điều chỉnh số lượng bằng nút +/−
- Xem giỏ hàng, tính tổng tiền
- Thanh toán → tạo đơn → ghi doanh thu

## Kết Nối Module Khác
- **→ Thu Chi:** Thanh toán xong → tự ghi 1 khoản "Thu" (badge "Auto")
- **→ Báo cáo:** Mọi đơn hàng → vào dữ liệu báo cáo
- **→ Bếp:** Gọi món → phiếu xuất hiện realtime trên màn Bếp
- **→ Quản lý Bàn:** Có thể gán đơn vào bàn cụ thể
- **→ Kho:** Trừ nguyên liệu nếu có cấu hình công thức
- **→ Điểm Tích:** Cộng điểm cho khách sau thanh toán

## Câu Hỏi Thường Gặp
- *"Làm sao thêm món mới?"* → Cài đặt → Thực đơn → Thêm món
- *"Khách muốn hủy đơn?"* → Mở đơn → nhấn Hủy đơn
- *"Áp dụng giảm giá?"* → Chỉnh tay ở mục tổng tiền khi thanh toán
- *"Tách hóa đơn?"* → Tính năng đang phát triển
