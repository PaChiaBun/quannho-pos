# Cung Cách Làm Việc (Quán Nhỏ POS)

Tài liệu này ghi nhận các nguyên tắc thiết kế, cấu trúc thư mục, kiến trúc phần mềm và quy chuẩn lập trình được thống nhất trong dự án Quán Nhỏ POS, đặc biệt là phân hệ In Ấn (Bill Printer).

---

## 1. Nguyên Tắc Thiết Kế Giao Diện (UI/UX)
* **Tương thích đa thiết bị:** Giao diện cấu hình phải hoạt động tốt trên cả Điện thoại (Mobile), Máy tính bảng (Tablet) và Máy tính (PC).
* **Bố cục dạng lưới (Grid Layout) tối giản:** 
  * Các danh mục lựa chọn hoặc chức năng cấu hình lớn cần được đưa về dạng hình chữ nhật nằm ngang gọn gàng.
  * Tỷ lệ khung hình (`childAspectRatio`) lý tưởng trên Tablet/PC là từ `2.0` đến `2.5`, trên Mobile từ `1.5` đến `1.8`.
  * Font chữ tiêu đề và phụ đề trên các thẻ danh mục cần to rõ (`fontSize` từ `13` đến `17`), đảm bảo dễ đọc và dễ chạm trên màn hình cảm ứng của Tablet.

---

## 2. Phân Hệ Thiết Kế In Ấn (Bill Printer Module)
### Phân chia Trạm in độc lập
* Tách biệt hoàn toàn phần thiết kế cấu hình và mẫu in của **Hoá Đơn Thu Ngân**, **Phiếu Bếp Nóng** và **Phiếu Bếp Bar (Bếp Nước)**.
* Mỗi trạm sở hữu một template độc lập được lưu trữ và đồng bộ hóa qua Supabase Database:
  * `billTemplateProvider` cho Hoá đơn.
  * `kitchenTicketTemplateBepNongProvider` cho Bếp Nóng.
  * `kitchenTicketTemplateBepBarProvider` cho Bếp Bar.

### Quy chuẩn In nhiệt (Thermal Printing)
* **Độ sắc nét 100% (Pure Black):** Khi thiết kế file PDF hoá đơn để in nhiệt, tuyệt đối **không sử dụng** các màu xám (`PdfColors.grey600`, `PdfColors.grey700`, v.v.) hay opacity mờ. Mọi văn bản, đường kẻ (divider) và thông tin phụ phải sử dụng màu đen thuần **`PdfColors.black`** để máy in nhiệt đốt kim rõ nét nhất.
* **Logo hoá đơn dạng Base64:** Hình ảnh logo được người dùng tải lên từ thiết bị sẽ được chuyển đổi sang định dạng chuỗi Base64 siêu nhẹ, đồng bộ lên đám mây và kết xuất trực tiếp dưới dạng ảnh Bitmap/MemoryImage trong PDF để tối ưu độ tương thích của máy in.
* **Mã QR Code linh hoạt:** Hỗ trợ 2 chế độ: (1) QR Động tự động điền số tiền hoá đơn và mã đơn hàng `bill.orderNumber`, và (2) QR Tĩnh chỉ chứa thông tin tài khoản ngân hàng để khách tự nhập tiền. Cấu hình này được lưu trong block parameter `qrType` (`dynamic` hoặc `static_amount`).

---

## 3. Quản Lý Trạng Thái & Database
* Sử dụng **Riverpod** làm giải pháp quản lý trạng thái chính trong ứng dụng.
* Tất cả cấu hình tuỳ chỉnh của người dùng phải được lưu và đồng bộ tức thời với cơ sở dữ liệu để tránh mất dữ liệu khi restart app.
