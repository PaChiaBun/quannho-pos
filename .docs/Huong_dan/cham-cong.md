---
module: chamcong
ten: Chấm công
phien_ban: 1.0.5+20
cap_nhat: 2026-10-23
nguon:
  - lib/screens/chamcong_screen.dart (vào/ra ca, selfie, GPS, định vị quán, xem quản lý, chi tiết ca, OT, quên chốt, gán lại, xoá ca, lương tích luỹ)
  - .docs/Ai_Boom/cac-module/quy-chuan-cham-cong-tinh-luong-chuan.md (quy chuẩn tính lương — xem bài Lương)
---

# Chấm công

> Nhân viên bấm VÀO CA / RA CA, chụp selfie tại quán, app ghi vị trí GPS; Chủ quán / Quản lý xem ai đang làm, lịch sử ca, duyệt tăng ca và xử lý ca quên chốt. Mỗi ca tự tính tiền vào lương.

## Ai dùng được
- Người có module **Chấm công** (mặc định **tắt**; vai trò Thu ngân, Phục vụ, Bếp, Kho có sẵn).
- **Nhân viên**: chấm công cho chính mình, xem ca và lương tích luỹ của mình.
- **Chủ quán / Quản lý**: thấy ca của mọi người, cài **định vị quán**, duyệt OT, xác nhận ca quên chốt, gán lại tên, xoá ca rác.
  - Lưu ý: màn này chỉ nhận chế độ quản lý khi vai trò tên **đúng là "Quản lý"**. Vai trò đặt tên khác như **"Quản lý nhà hàng"**, "Quản lý ca" sẽ chỉ thấy màn nhân viên — khi đó đổi vai trò sang "Quản lý" hoặc nhờ Chủ quán xử lý.

## Màn hình gồm những gì
**Nhân viên:**
- Nút tròn lớn **"VÀO CA"** / **"RA CA"**; khi đang làm hiện **"Thời gian đang làm"** chạy giờ; chưa vào hiện "Chưa vào ca – Nhấn để bắt đầu ca làm việc".
- Thống kê **"Ca hôm nay"**, **"Giờ hôm nay"**, **"Giờ tuần"**.
- Thẻ **"LƯƠNG TÍCH LŨY THÁNG …"**: số ca, Tổng giờ, Ghi nhận/OT, Khấu trừ.
- **"Lịch sử ca"** của mình.

**Chủ quán / Quản lý:**
- Lọc **"Hôm nay" / "Tuần này" / "Tháng này"**, chuyển tuần/tháng trước-sau, **"Làm mới"**.
- Thống kê: Đang làm, số ca, **Tổng giờ**.
- **"Đang làm ca"** (ai đang ở quán) và **"Lịch sử ca"** nhóm theo từng nhân viên ("N ca · Xh làm việc").
- Mỗi ca hiện giờ vào → ra và nhãn vị trí: **"✓ Ở quán"**, **"⚠️ Lệch …m"**, **"⚠️ Không GPS"**.
- Nút **"Cài đặt định vị quán"** trên đầu màn hình.

## Các việc thường làm

### 1. Cài vị trí quán (Chủ quán / Quản lý, làm một lần)
1. Đứng tại quán, bấm **"Cài đặt định vị quán"** → **"Định vị của quán"**.
2. Bấm **"Lấy vị trí hiện tại của quán"** (cần bật GPS và cho phép vị trí), hoặc nhập tay **"Vĩ độ (Latitude)"**, **"Kinh độ (Longitude)"**.
3. **"Địa chỉ / Ghi chú vị trí quán"**, **"Bán kính cho phép (mét)"** (mặc định **200**).
4. **"Lưu cài đặt"** → "Đã lưu cấu hình định vị của quán."

### 2. Vào ca (nhân viên)
1. Bấm **"VÀO CA"**.
2. Chụp **selfie trực tiếp** bằng camera — không chọn ảnh có sẵn, không vào ca được nếu không có ảnh.
3. App lấy vị trí. Nếu xa quán hơn bán kính: hỏi **"Định vị lệch phạm vi"** — bấm **"Tiếp tục"** thì ca vẫn được ghi nhưng **gắn cờ "Lệch vị trí"** gửi chủ quán; **"Hủy"** để không vào ca.
4. Thành công: "Đã vào ca lúc HH:mm".

### 3. Ra ca
1. Bấm **"RA CA"** → **"Xác nhận ra ca"** ("Thời gian làm việc và tiền ca sẽ được ghi nhận tự động") → **"Ra ca"**.
2. Màn **"ĐÃ RA CA THÀNH CÔNG"**: **"CỘNG VÀO LƯƠNG CA NÀY"** gồm lương giờ làm, tăng ca (nếu đã duyệt), **"KHẤU TRỪ & LÝ DO LỖI"** (đi muộn…), và **"Lương tích lũy tháng"**. Bấm **"Đã hiểu"**.

> **Quên bấm Ra ca hơn 14 giờ**: ca bị đánh dấu **"🔴 Quên chốt ca (>14h) - Trừ 50% lương"** cho tới khi quản lý xác nhận.

### 4. Xem chi tiết một ca (Chủ quán / Quản lý)
- Chạm ca: tên nhân viên, **"🟢 Đang làm việc" / "⚪ Đã kết thúc ca"**, **ảnh selfie**, **"Vào ca:"**, **"Ra ca:"**, **"Vị trí Check-in:"**, **"Khoảng cách quán:"** ("✓ Chuẩn vị trí quán (cách …m)" hoặc "⚠️ Lệch vị trí (cách quán …m)").

### 5. Duyệt tăng ca (OT)
- Ca vượt **"Ngưỡng bắt đầu OT"** trong cấu hình lương của nhân viên đó (mặc định 8 giờ) mà chưa duyệt hiện **"🟡 Chờ Quản lý duyệt OT"**. Trong chi tiết ca bấm **"Duyệt Tăng Ca (OT)"** → nhập **"Lý do tăng ca (bắt buộc)"** → xác nhận. Ca hiện **"🟢 OT đã duyệt (…)"** và phần tăng ca được tính tiền.

### 6. Xử lý ca quên chốt
- Chi tiết ca → **"Xác nhận ca quên chốt"** → nhập **"Lý do điều chỉnh (bắt buộc)"** → ca hiện "🛡️ Điều chỉnh bởi …" và **khôi phục lương** (không bị trừ 50%).

### 7. Gán lại tên / xoá ca rác
- **"Gán lại tên nhân viên"** → **"Gán ca này cho nhân viên:"** chọn người → "✅ Đã gán ca cho nhân viên …" (dùng khi chấm nhầm máy/nhầm tài khoản).
- **"Xoá ca rác / ca thử này"** → **"Xoá ca làm việc này?"** → **"Xoá"**.

## Lỗi thường gặp
| Thấy gì | Vì sao | Làm gì |
|---|---|---|
| **"Yêu cầu chụp ảnh trực tiếp"** | Chưa cho phép camera / huỷ chụp | Cấp quyền Camera cho app rồi bấm lại |
| **"Tải ảnh thất bại"** | Mạng yếu khi gửi ảnh | Kiểm tra Wi-Fi/4G, bấm **"Thử lại"** |
| **"Định vị lệch phạm vi"** | Đang xa quán hơn bán kính, hoặc GPS trong nhà kém | Ra gần cửa/ngoài trời cho GPS bắt rồi thử; hoặc "Tiếp tục" (bị gắn cờ) |
| Ca hiện **"⚠️ Không GPS"** | Máy tắt GPS / từ chối quyền vị trí | Bật GPS và cho phép vị trí |
| "Dịch vụ định vị (GPS) trên thiết bị đang tắt…" (khi cài định vị quán) | GPS tắt | Bật GPS hoặc nhập toạ độ tay |
| "Quyền truy cập vị trí bị từ chối…" | Chưa cho phép vị trí | Cấp quyền hoặc nhập toạ độ tay |
| "Vui lòng chọn cửa hàng trước khi thiết lập định vị." | Chưa chọn quán | Chọn quán rồi làm lại |
| Ca bị trừ 50% | Quên Ra ca > 14 giờ | Quản lý "Xác nhận ca quên chốt" |
| Quản lý mở Chấm công chỉ thấy ca của mình | Tên vai trò không đúng "Quản lý" (vd "Quản lý nhà hàng") | Đổi vai trò sang "Quản lý" |
| "Chưa có ảnh chụp selfie ca này" | Ca tạo trước khi bắt buộc chụp ảnh live, hoặc ảnh lỗi | — |

## Liên quan module khác
- **Lương**: mỗi ca tính tiền theo cấu hình lương (giờ/ngày/tháng, OT, đi muộn); duyệt và chốt bảng lương.
- **Nhân viên**: ca làm việc mẫu, hồ sơ, cấu hình lương từng người.
- **Vận Hành**: việc theo ca.

## Ghi chú cho Chủ Quán (không đưa cho khách)

### Khác biệt với bản app cũ (cho Chủ Quán)
- App cũ dùng mốc OT cố định 8 giờ thay vì "Ngưỡng bắt đầu OT" của từng nhân viên: ca dưới 8 giờ vượt ngưỡng OT (ví dụ ngưỡng 6 giờ) không có nút duyệt ở Chấm công — duyệt ở Lương → "Báo cáo lương".

1. **Vị trí lệch vẫn vào ca được** (chỉ gắn cờ) — chống gian lận dựa vào việc chủ quán xem cờ "Lệch …m" và ảnh selfie.
2. **Không có GPS vẫn vào ca được** (gắn "⚠️ Không GPS").
3. Phân quyền màn này so **đúng nguyên chuỗi** vai trò `owner` / `manager` / `quản lý` ở client (`chamcong_screen.dart:55-59`, 156, 2159, 2683), không dùng `canonicalRole`, không theo quyền `tinhluong.*` — "Quản lý nhà hàng" (gợi ý F&B) hay vai trò tuỳ chỉnh có quyền lương sẽ không thấy chế độ quản lý. Khác với màn Lương (dùng `canonicalRole`).
4. Hai test cũ `attendance_location_config_test` đang lỗi câu chữ (nhật ký 10/10, 17/10) — chưa sửa.
5. **[ĐÃ SỬA trong app 23/10 — chưa phát hành]** Mốc "Chờ Quản lý duyệt OT" từng cố định 8 giờ → nay theo `otThresholdHours` của cấu hình lương từng người (`_otThresholdProvider`, `shiftHasOvertime`: OT khi tổng giờ > ngưỡng — đúng công thức `calculateSingleShiftEarnings`). Chấm công và Lương giờ thống nhất. Test cũ `attendance_location_config_test` (lỗi câu chữ) đã sửa theo câu hiện tại.
