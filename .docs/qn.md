# Tóm tắt Công việc & Hướng dẫn Cấu hình Quán Nhỏ POS

Tài liệu này ghi lại thông tin quan trọng về các cập nhật lớn của dự án Quán Nhỏ POS, đặc biệt là quy trình đóng gói Windows, sửa lỗi thư viện C++ Runtime và tính năng phân chia trạm in bếp tự động.

---

## 💻 1. Đóng gói Windows & Sửa Lỗi C++ Runtime

Ứng dụng hiện tại đã được cấu hình tự động đóng gói (CI/CD) qua GitHub Actions mỗi khi đẩy thẻ phiên bản mới (ví dụ: `v1.0.2`).

### Cách thức hoạt động của Trình cài đặt (.exe):
1. **Kiểm tra Registry**: Trình cài đặt tự động kiểm tra xem máy khách đã cài đặt `Microsoft Visual C++ 2015-2022 Redistributable` chưa.
2. **Tự động tải xuống**: Nếu thiếu tệp tin hệ thống (như `MSVCP140.dll`), bộ cài đặt sẽ tự động tải file `vc_redist.x64.exe` trực tiếp từ máy chủ Microsoft.
3. **Cài đặt ngầm**: Cài đặt ngầm ẩn dưới chế độ `/install /quiet /norestart` trước khi cài app POS vào máy.
4. **Kết quả**: Khách hàng cài app là chạy được ngay, không bị báo lỗi DLL.

### Cấu hình Responsive Tablet:
Mã nguồn giao diện Sidebar Navigation (cho Tablet/PC) đã được khôi phục thành công. Ứng dụng tự động nhận biết:
* **Điện thoại**: Hiện Bottom Navigation (thanh điều hướng dưới).
* **Tablet / Máy tính**: Hiện Navigation Rail (thanh điều hướng bên trái).

---

## 🖨️ 2. Hệ Thống Phân Trạm In & Tem Nhãn Dán Ly

Chúng ta đã nâng cấp module in bill để hỗ trợ chia và điều hướng in bill tự động cho 4 trạm:

### Cách thiết lập cho Quán:
1. **Cấu hình Sản Phẩm**:
   * Vào **Kho Hàng** -> **Sửa sản phẩm** -> chọn **Bộ phận chế biến**:
     * **Bếp Nóng** (Món ăn xào nấu, có lửa).
     * **Bếp Bar** (Sinh tố, trà sữa, cafe).
     * **Thu Ngân** (Các mặt hàng đóng gói sẵn không cần làm, chỉ in hoá đơn thanh toán).
2. **Thiết lập Máy In**:
   * Vào **Cài đặt** -> **In Hoá Đơn** -> Chọn **Cấu Hình Máy In & Tem Dán Ly**.
   * Bật các máy in trạm tương ứng.
   * Chọn hình thức kết nối:
     * **Máy in Hệ thống**: Chọn tên máy in đã cài trên hệ điều hành (USB, Bluetooth, LAN Wifi đã add).
     * **Mạng IP LAN/Wifi**: Điền trực tiếp địa chỉ IP máy in trạm (cổng 9100).
   * Nhấn **"In thử nghiệm"** để kiểm tra ngay tại chỗ.

### Nguyên lý hoạt động khi Thanh toán:
* **Hóa đơn Khách**: In đầy đủ toàn bộ món tại quầy **Thu Ngân**.
* **Bếp Nóng**: Chỉ in các món bếp nóng (`bep_nong`).
* **Quầy Bar**: Chỉ in các món nước uống (`bep_bar`).
* **Tem dán ly (Stickers)**: Chỉ in tem dán ly cho các món nước quầy bar (`bep_bar`). 
  * Tem được in riêng lẻ theo từng cốc (Ví dụ: order 3 Trà đào sẽ ra 3 nhãn dán Peach Tea riêng biệt kích thước tem nhiệt `50x30mm` để dán lên cốc).

---

## 🚀 3. Các bước tiếp theo dành cho chủ quán

1. Mở **GitHub Desktop** và kiểm tra các thay đổi mã nguồn đã được dọn dẹp sạch sẽ.
2. Tiến hành **Push** (đẩy) các thay đổi này lên repository GitHub của bạn.
3. GitHub Actions sẽ tự động kích hoạt build bản Windows mới nhất đi kèm giao diện Tablet Sidebar UI và toàn bộ tính năng trạm in bếp thông minh này.
4. Tải bộ cài từ mục Releases của GitHub về cài đặt và trải nghiệm!
