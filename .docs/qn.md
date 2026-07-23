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

## 🚀 4. Thống Kê Số Bàn Theo Phục Vụ & Bộ Lọc Trạng Thái Bàn Trực Quan

Chúng ta đã hoàn thành nâng cấp module Quản Lý Bàn và Báo Cáo Doanh Thu với các tính năng:

### 1. Thống Kê Số Bàn Theo Phục Vụ (Tab Báo Cáo):
* Tích hợp theo dõi `waiter_id` (nhân viên order/mở bàn) đồng bộ xuyên suốt từ phiên bàn ăn (`ban_sessions`) đến hóa đơn thanh toán (`orders`).
* Hiển thị bảng **"Số bàn phục vụ theo nhân viên"** kế bên bảng xếp hạng thu ngân, hiển thị dạng thanh phần trăm tiến trình màu tím trực quan.
* Giao diện Responsive chia thành 3 cột cân đối trên màn hình lớn PC/Tablet.

### 2. Bộ Lọc Trạng Thái Bàn Trực Quan (Màn hình Quản Lý Bàn):
* Thêm thanh bộ lọc trạng thái viên thuốc (Filter Chips) với các tùy chọn: **Tất cả bàn**, **Đang có khách 🔴**, **Bàn trống 🟢** để thu ngân dễ dàng lọc và nắm bắt toàn diện tình hình quán chỉ với 1 chạm.
* Gỡ bỏ giới hạn số khách tiêu chuẩn khi mở bàn, cho phép tăng số lượng khách thoải mái và tự do thêm ghế phụ.

### 3. Tối Ưu Bảo Mật RLS (Row Level Security):
* Tích hợp Header động `x-store-id` tự động gửi từ Client App bất cứ khi nào đăng nhập/chuyển quán.
* Cấu hình các luật bảo mật dòng cách ly quán tuyệt đối trên cơ sở dữ liệu Supabase qua hàm SQL an toàn `public.current_store_id()`.

---

---

## 🏦 5. Phân Tách Quỹ Tiền Mặt & Tiền Gửi (Chuẩn CUKCUK) & Xuất Excel Kế Toán

Ứng dụng hiện tại hỗ trợ quản lý tài chính thông minh theo chuẩn mực quản trị dòng tiền kế toán thực tế:

### 1. Phân Tách 3 Tab Quản Lý:
* **Tất cả**: Thống kê doanh thu, chi phí, lợi nhuận gộp chung của cả quán.
* **Tiền mặt**: Quản lý dòng tiền mặt két tại quầy thu ngân.
* **Tiền gửi**: Quản lý tài khoản ngân hàng nhận chuyển khoản và thanh toán thẻ.

### 2. Tự Động Phân Bổ Dòng Tiền:
* Mọi hóa đơn bán hàng POS và tại Bàn được tự động ghi nhận vào Quỹ Tiền mặt (nếu trả tiền mặt) hoặc Quỹ Tiền gửi (nếu chuyển khoản/thẻ).
* Logic trả lương nhân viên mặc định chuyển khoản (Quỹ tiền gửi), chi nhập kho được ghi nhận đúng quỹ chi trả thực tế (và tự động hoàn lại đúng quỹ đó khi đơn nhập kho bị hủy bỏ).

### 3. Xuất Báo Cáo CSV Kiểm Soát Lũy Kế (Running Balance):
* Nút **Tải báo cáo** ở góc phải danh sách giao dịch cho phép xuất Excel/CSV UTF-8.
* Tự động tính toán số tiền **Tồn đầu kỳ** (số tiền dư trước ngày bắt đầu bộ lọc) và điền cột **Số tiền còn lại** (Tồn quỹ lũy kế tăng/giảm chạy liên tục theo từng giao dịch) chuẩn kế toán để thủ quỹ và kế toán đối soát 100%.

---

## 🌐 6. Quy Trình Deploy Web Bản Sản Xuất (VPS `quannho.lpm.vn/pos`)

Ứng dụng web đã được đưa lên VPS chạy trực tiếp:

### 1. Biên Dịch Web:
* Lệnh build Flutter Web hỗ trợ thư mục con `/pos/`:
  ```bash
  flutter build web --release --base-href "/pos/" --no-tree-shake-icons
  ```

### 2. Cấu Hình Nginx trên VPS (`45.32.104.228`):
* Cấu hình Nginx tách biệt subdomain `quannho.lpm.vn` tại `/etc/nginx/sites-available/lpm.vn` để phục vụ thư mục con `/pos` và hỗ trợ SPA routing (tránh lỗi 404 khi tải lại trang F5):
  ```nginx
  location /pos {
      root /var/www/quannho;
      index index.html;
      try_files $uri $uri/ /pos/index.html;
  }
  ```


---

## 🗄️ 8. Đồng Bộ Hoá Thiết Lập Máy In Thiết Bị Độc Lập Lên Supabase (Device-isolated Cloud Sync)

Để giải quyết triệt để lỗi không in được và xung đột cấu hình giữa nhiều thiết bị, toàn bộ mô-đun thiết lập máy in đã được nâng cấp lưu trữ lên đám mây 100%:

### 1. Phân tách theo UUID Thiết bị:
* Cấu hình máy in của từng máy (PC Thu ngân, Tablet, Điện thoại) được lưu trữ riêng biệt trên Supabase bảng `app_settings` dưới định dạng khóa: `qn_station_printers_<device_id>`.
* Việc này giúp mỗi máy có một cấu hình độc lập hoàn toàn, không bao giờ bị ghi đè chéo hoặc làm mất tên máy in của nhau.

### 2. Tự động lưu không cần nút bấm (Smart Auto-save):
* Hệ thống tích hợp `FocusNode` tự động phát hiện khi ô nhập IP mất focus (người dùng gõ xong và bấm ra ngoài hoặc chuyển sang trạm in khác) để tự động đẩy lệnh lưu `upsert` lên Supabase.
* Tránh tình trạng spam request lên database khi người dùng đang gõ phím.

### 3. Sửa lỗi Realtime in ngầm (Print Server):
* Chuyển đổi bộ lọc dữ liệu Realtime in ấn từ database filter (`PostgresChangeFilter` vốn lỗi khi so khớp UUID của store) sang bộ lọc Client-side của Dart. Đảm bảo 100% nhận diện lệnh in ngầm ngay lập tức khi nhân viên gửi đơn từ điện thoại/máy tính bảng.

---

## 📊 10. Hệ Thống Nhật Ký Log Hoạt Động Toàn Diện (Audit Log & Errors Cloud Tracker)

Hệ thống ghi nhận toàn bộ hoạt động nghiệp vụ của nhân viên và các lỗi kỹ thuật phát sinh theo thời gian thực trực tiếp lên đám mây Supabase:

### 1. Cách truy cập & Giao diện:
* Module được tách biệt thành một Tab độc lập tên **`Nhật ký`** (📝) ngay ngoài menu điều hướng chính (Chỉ tài khoản **Chủ quán/Quản lý** mới nhìn thấy).
* Thiết kế dạng dòng thời gian (Timeline) trực quan kèm biểu tượng: Đặt món (🍽️), Thanh toán (💳), Chấm công (🖐️), Cài đặt máy in (⚙️), Lỗi (❌).

### 2. Bộ lọc tối ưu:
* **Bộ lọc khoảng ngày** & **Bộ lọc theo từng Nhân viên** cụ thể.
* **Nút "Truy xuất Log" thủ công**: Chỉ tải dữ liệu khi bấm nút để tránh làm nặng hệ thống.

### 3. QUY TẮC XỬ LÝ SỰ CỐ (KHÔNG ĐOÁN MÒ):
* **Bắt buộc**: Bất cứ khi nào app xảy ra lỗi (ví dụ: máy in bill không chạy, không đặt được món, lỗi đồng bộ...), chủ quán hoặc kỹ thuật viên **chỉ cần vào trực tiếp tab Nhật ký log** này để kiểm tra.
* Bảng log hiển thị rõ ràng nội dung lỗi kỹ thuật chi tiết (Technical Details / StackTrace) và thông tin thiết bị lỗi, giúp định vị chính xác nguyên nhân để sửa ngay lập tức mà không cần phỏng đoán.

---

## 🚀 11. Các bước tiếp theo dành cho chủ quán

1. Tiến hành **Push** các thay đổi mã nguồn này lên repository GitHub của bạn.
2. Bản nâng cấp này sẽ tự động cập nhật đồng bộ lên cả phiên bản Web và App di động khi đóng gói bản dựng tiếp theo!

---

## 🗄️ 12. Hạ Tầng Cơ Sở Dữ Liệu Self-Hosted & Quy Chuẩn Tra Cứu (Self-Hosted Supabase Architecture)

### 1. Domain & Đường Tuyến Gateway (Nginx Proxy Routing):
* **Supabase Studio:** `https://quannho-db.lpm.vn` (Phục vụ giao diện quản trị Studio port 3003, hỗ trợ SSL Let's Encrypt).
* **API REST Gateway:** `https://quannho.lpm.vn/supabase/` (Proxy đường dẫn ưu tiên `location ^~ /supabase/` trực tiếp tới Kong Gateway port 8000).
* **Ứng dụng POS Web:** `https://quannho.lpm.vn/pos/` (Chạy ứng dụng Flutter Web từ thư mục `/var/www/quannho/pos`).

### 2. Quy Chuẩn Tra Cứu Bảng Nhân Viên (`staff_members`):
* Danh sách toàn bộ nhân viên thuộc quán được quản lý tập trung tại bảng **`public.staff_members`** (`id`, `store_id`, `name`, `role`, `phone`, `is_active`, `hourly_rate`).
* Tất cả các repository & screen (`DashboardRepository`, `ReportScreen`, `PosRepository`, `BanRepository`) đều bắt buộc tra cứu tên nhân viên theo `staff_members.id` $\rightarrow$ `staff_members.name` để tránh bị rơi vào lỗi hiển thị mặc định *"Nhân viên ẩn"*.

### 3. Bảng Ghi Vết Nhật Ký Hệ Thống (`app_logs`):
* Bảng nhật ký hoạt động được khởi tạo chuẩn hóa tại **`public.app_logs`** (`id`, `store_id`, `device_id`, `staff_name`, `level`, `tag`, `message`, `details`, `created_at`).
* Đã cấu hình phân quyền bảo mật RLS `app_logs_all` và reload Schema Cache Kong API Gateway (`NOTIFY pgrst, 'reload schema'`).

### 4. Quy Trình Audit & Dọn Dẹp Dữ Liệu Thử Nghiệm:
* Thứ tự xóa dữ liệu thử nghiệm chuẩn Foreign Key CASCADE để tránh lỗi liên kết mồ côi:
  1. `kitchen_tickets` (Phiếu bếp)
  2. `ban_sessions` (Phiên bàn)
  3. `orders` (Hóa đơn)
  4. `finance_records` (Thu chi)
  5. `stock_movements` (Xuất nhập kho)
* Kết quả dọn dẹp ngày 06/07 - 12/07: Đã dọn dẹp toàn bộ dữ liệu test, bảo vệ 100% dữ liệu thực tế từ 13/07/2026 trở đi với 0 bản ghi lỗi mồ côi.
