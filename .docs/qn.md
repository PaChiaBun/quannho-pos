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
   * Vào **Cài đặt** (trên thanh Sidebar) -> Chọn **Cấu hình máy in & Tem nhãn** (hoặc vào thông qua trạm in phụ trên Dashboard). Giao diện mới hỗ trợ hiển thị 2 cột trực quan tối ưu cho Tablet & PC.
   * Bật các máy in trạm tương ứng.
   * Chọn hình thức kết nối:
     * **Máy in Hệ thống**: Chọn tên máy in đã cài trên hệ điều hành (USB, Bluetooth, LAN Wifi đã add).
     * **Mạng IP LAN/Wifi**: Có 2 lựa chọn:
       * Nhập trực tiếp địa chỉ IP máy in trạm (ví dụ: `192.168.1.100`, cổng mặc định 9100).
       * Nhấn nút **"Quét" (Auto LAN scan)** để ứng dụng tự động dò tìm và liệt kê các máy in đang hoạt động trong mạng nội bộ, chỉ cần chạm để chọn.
   * Nhấn **"In thử nghiệm"** (nút bấm chuẩn 52px dễ thao tác) để kiểm tra ngay tại chỗ kèm Live Preview thời gian thực hóa đơn hoặc tem dán ly.

### Nguyên lý hoạt động khi Thanh toán:
* **Hóa đơn Khách**: In đầy đủ toàn bộ món tại quầy **Thu Ngân**.
* **Bếp Nóng**: Chỉ in các món bếp nóng (`bep_nong`).
* **Quầy Bar**: Chỉ in các món nước uống (`bep_bar`).
* **Tem dán ly (Stickers)**: Chỉ in tem dán ly cho các món nước quầy bar (`bep_bar`). 
  * Tem được in riêng lẻ theo từng cốc (Ví dụ: order 3 Trà đào sẽ ra 3 nhãn dán Peach Tea riêng biệt kích thước tem nhiệt `50x30mm` để dán lên cốc).

---

## 🔄 3. Tự Động Cập Nhật Ứng Dụng (Windows Auto-update)

Ứng dụng hiện tại đã được tích hợp module kiểm tra và cập nhật phiên bản Windows tự động từ GitHub Releases:

1. **Tự động kiểm tra cập nhật**: 
   * Khi ứng dụng khởi động thành công và truy cập Dashboard, hệ thống sẽ tự động gọi đến GitHub Releases API để kiểm tra xem có phiên bản mới hơn phiên bản đang chạy hay không.
   * Người dùng cũng có thể kiểm tra thủ công bằng cách vào **Cài đặt** -> chọn **Kiểm tra cập nhật**.
2. **Tự động tải về và nâng cấp**: 
   * Nếu có phiên bản mới, app sẽ hiển thị một hộp thoại thông báo. Khi chọn **Cập nhật ngay**, app sẽ tiến hành tải ngầm bản cài đặt `QuanNhoPOS-Setup.exe` mới nhất về máy.
   * Khi tải xong 100%, app tự động khởi chạy bản cài đặt mới ghi đè lên thư mục hiện tại, đồng thời tự động đóng app cũ lại để hoàn tất nâng cấp mà không làm mất dữ liệu của quán.

---

## 🚀 4. Các bước tiếp theo dành cho chủ quán

1. Mở **GitHub Desktop** và kiểm tra các thay đổi mã nguồn đã được dọn dẹp sạch sẽ.
2. Tiến hành **Push** (đẩy) các thay đổi này lên repository GitHub của bạn (bao gồm cả các commit tự động cập nhật).
3. GitHub Actions sẽ tự động kích hoạt build bản Windows mới nhất đi kèm giao diện Tablet Sidebar UI, tính năng quét máy in IP thông minh và cơ chế Tự động cập nhật này.
4. Tải bộ cài từ mục Releases của GitHub về cài đặt (đây là lần cài thủ công cuối cùng). Từ phiên bản tiếp theo, app sẽ tự động hiển thị cập nhật khi có bản mới!
