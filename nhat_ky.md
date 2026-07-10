# Nhật Ký Thay Đổi & Phát Triển (Quán Nhỏ POS)

Tài liệu này ghi lại lịch sử cập nhật và các mốc phát triển quan trọng của dự án Quán Nhỏ POS.

---

## [2026-07-09] - Phân Hệ In Ấn & Giao Diện Hub

### Cập nhật & Tối ưu hoá
* **Tách rời Trạm thiết kế phiếu bếp:** 
  * Tách biệt hoàn toàn tính năng thiết kế mẫu in bếp thành hai màn hình độc lập: **Thiết Kế Phiếu Bếp Nóng** và **Thiết Kế Phiếu Bếp Bar** (Bếp Nước).
* **Tải ảnh Logo hóa đơn (Base64):**
  * Hỗ trợ tải ảnh từ thư viện thiết bị, tự động mã hóa Base64 và lưu trữ đồng bộ lên cơ sở dữ liệu.
  * Hiển thị ảnh Base64 mượt mà trên cả giao diện xem trước (Flutter Widget) lẫn bản in PDF thực tế.
* **In mã QR VietQR thực tế (Linh hoạt Động/Tĩnh):**
  * Thay thế mã QR tĩnh bằng mã QR động chuẩn VietQR được sinh bằng `pw.BarcodeWidget` trong PDF.
  * Tích hợp mã tài khoản ngân hàng, tên chủ tài khoản, số tiền hóa đơn và nội dung chuyển khoản tự động theo mã đơn hàng (`orderNumber`).
  * **Hỗ trợ chế độ QR Tĩnh:** Cho phép chuyển đổi linh động qua parameter `qrType` sang dạng QR Tĩnh không điền sẵn số tiền (khách hàng tự nhập số tiền khi quét) phục vụ đa dạng nhu cầu thanh toán của cửa hàng.
* **Menu Hub dạng lưới chữ nhật gọn gàng:**
  * Chuyển đổi toàn bộ Menu In Ấn thành dạng lưới ô hình chữ nhật dẹt (`childAspectRatio` từ `1.6` đến `2.2`) giúp hiển thị tối ưu trên Tablet và máy tính.
  * Tăng kích thước font chữ tiêu đề (`fontSize: 17`) và phụ đề (`fontSize: 13`) trên menu để bố cục cân đối và dễ tương tác.
* **Tối ưu hóa chất lượng in nhiệt (Contrast Fix):**
  * Thay thế toàn bộ mã màu xám (`PdfColors.grey`) thành màu đen thuần (`PdfColors.black`) trong module tạo PDF hóa đơn/phiếu bếp để đảm bảo hóa đơn in ra sắc nét 100%, không bị mờ nhạt.
* **Tách biệt bộ Chọn mẫu in (Template Gallery):**
  * Tách bộ chọn mẫu in dựng sẵn thành 3 Tab riêng biệt: **Hoá Đơn**, **Bếp Nóng**, **Bếp Nước (Bar)**.
  * Tự động chọn sẵn mẫu in đầu tiên khi mở màn hình để khung xem trước và nút **"Dùng mẫu này"** (Save & Apply) luôn hiển thị trực quan cho người dùng.
  * Thu nhỏ kích thước các thẻ mẫu in sang dạng lưới 4 cột nhỏ gọn trên Tablet/PC để bố cục hiển thị thanh thoát.
