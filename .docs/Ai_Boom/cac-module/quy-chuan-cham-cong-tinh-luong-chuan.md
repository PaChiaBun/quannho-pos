# 📋 BỘ QUY CHUẨN ĐẶC TẢ NGHIỆP VỤ: CHẤM CÔNG & TÍNH LƯƠNG QUÁN NHỎ POS

> **Phiên bản:** v1.0 — Chuẩn hoá sau phỏng vấn chi tiết (`/grill-me`)  
> **Áp dụng:** Toàn bộ hệ thống Quán Nhỏ POS (Mobile, Tablet, Web, Server RPC)  
> **Cập nhật:** Tháng 09/2026

---

## MỤC LỤC
1. [Module Điểm Danh (Chấm Công)](#1-module-điểm-danh-chấm-công)
2. [Chính Sách Tăng Ca (OT)](#2-chính-sách-tăng-ca-ot)
3. [Chính Sách Nghỉ Phép & Vi Phạm Vắng Mặt](#3-chính-sách-nghỉ-phép--vi-phạm-vắng-mặt)
4. [Các Chế Độ Lương & Thưởng Chuyên Cần](#4-các-chế-độ-lương--thưởng-chuyên-cần)
5. [Quy Trình Phê Duyệt Kỳ Lương](#5-quy-trình-phê-duyệt-kỳ-lương)
6. [Chính Sách Ứng Lương (Salary Advance)](#6-chính-sách-ứng-lương-salary-advance)
7. [Chi Trả Lương, Đối Soát & Khiếu Nại (Disputes)](#7-chi-trả-lương-đối-soát--khiếu-nại-disputes)
8. [Cơ Chế Quản Lý Lịch Sử Mức Lương (Salary Versioning)](#8-cơ-chế-quản-lý-lịch-sử-mức-lương-salary-versioning)

---

## 1. MODULE ĐIỂM DANH (CHẤM CÔNG)

### 1.1. Kiểm soát vị trí GPS (Geofencing)
- **Bán kính cho phép:** Cấu hình theo từng cửa hàng (`stores.attendance_radius`, mặc định 100m – 200m).
- **Quy tắc khi ngoài bán kính:** 
  - Hệ thống **cho phép** nhân viên tiếp tục bấm Vào ca, nhưng tự động đánh dấu cờ `is_location_flagged = true` và ghi lại khoảng cách lệch thực tế (`distance_meters`).
  - Ca làm này chuyển sang trạng thái chờ Quản lý/Chủ quán duyệt: **bắt buộc Quản lý hoặc Chủ quán xác nhận hợp lệ thì mới được tính giờ công vào bảng lương**.

### 1.2. Vào ca khi chưa có lịch phân ca (Auto-match Shift)
- Khi nhân viên bấm Vào ca nhưng chưa có lịch phân công trong ngày trên `shift_assignments`:
  - Hệ thống tự động so sánh giờ vào ca thực tế với danh sách các ca làm việc đang kích hoạt (`shift_templates`) của quán.
  - Tự động gán nhân viên vào ca có giờ bắt đầu gần nhất, tính giờ công và tính phút đi muộn (nếu có) hoàn toàn tự động.

### 1.3. Hỗ trợ ca gãy và nhiều ca trong một ngày
- Cho phép phân nhiều ca cho 1 nhân viên trong cùng một ngày (ví dụ: Ca trưa 10:00 – 14:00 và Ca tối 17:00 – 22:00).
- Nhân viên thực hiện bấm **Vào ca** và **Ra ca** độc lập cho từng ca.
- Mỗi ca tính công, kiểm tra đi muộn, về sớm và tính tiền riêng biệt.

### 1.4. Quy tắc tính phút đi muộn (`late_minutes`)
- Mỗi ca có thời gian ân hạn (`late_grace_minutes`, ví dụ 15 phút).
- Khi nhân viên vào ca trong thời gian ân hạn ($\le \text{grace}$): Được tính là đúng giờ (`is_late = false`, `late_minutes = 0`).
- Khi nhân viên vào ca vượt quá thời gian ân hạn:
  $$\text{late\_minutes} = \text{clockInTime} - \text{shiftStartTime}$$
  *(Tính từ giờ bắt đầu ca chuẩn. Ví dụ ca 08:00, ân hạn 15p, đến lúc 08:20 thì tính muộn 20 phút).*

---

## 2. CHÍNH SÁCH TĂNG CA (OT)

### 2.1. Cách xác định giờ Tăng ca
- Giờ OT phát sinh khi nhân viên làm việc vượt quá giờ kết thúc của ca làm được phân công (`clockOutTime > expectedEndTime`):
  $$\text{overtime\_hours} = \frac{\text{clockOutTime} - \text{expectedEndTime}}{60\text{ phút}}$$
- Phần giờ làm trước mốc `expectedEndTime` được tính vào Giờ làm việc bình thường (`regular_hours`).

### 2.2. Quy trình duyệt Tăng ca
- Giờ OT tự động chuyển vào danh sách **Chờ Quản lý duyệt**.
- Khi Quản lý/Chủ quán duyệt và nhập lý do tăng ca:
  $$\text{overtime\_pay} = \text{overtime\_hours} \times \text{hourlyRate} \times \text{ot\_multiplier}$$
- Nếu Quản lý từ chối hoặc chưa duyệt OT: Phần giờ này không được hưởng hệ số tăng ca và bị chặn không cho trôi vào lương.

---

## 3. CHÍNH SÁCH NGHỈ PHÉP & VI PHẠM VẮNG MẶT

### 3.1. Xác định Vắng ca không phép (Unauthorized Absence)
- Vi phạm vắng mặt chỉ phát sinh khi: Nhân viên có lịch phân ca (`shift_assignment`) hợp lệ nhưng **không check-in** và **không có đơn xin nghỉ phép đã được duyệt** cho ca đó.
- Không suy đoán vắng mặt từ chênh lệch ngày công chuẩn kỳ vọng.

### 3.2. Chế tài xử lý
- Nhân viên **không được nhận lương** của ca bị vắng.
- Đồng thời bị khấu trừ một khoản phạt vắng không phép cố định (`deduction_per_unauthorized_absent`, cấu hình từ 100.000đ – 200.000đ/ca tùy chính sách quán).
- Quản lý có quyền đề xuất miễn phạt có lý do chính đáng; Chủ quán là người quyết định cuối cùng.

---

## 4. CÁC CHẾ ĐỘ LƯƠNG & THƯỞNG CHUYÊN CẦN

### 4.1. Định nghĩa 5 chế độ lương (M1 – M5)
- **M1 (Theo giờ):** $\text{regularPay} = \text{regularHours} \times \text{hourlyRate}$.
- **M2 (Lương cố định tháng):** $\text{regularPay} = \text{baseSalary}$. Đơn giá giờ OT quy đổi: $\frac{\text{baseSalary}}{\text{expectedDays} \times 8}$.
- **M3 (Cố định + OT giờ):** Lương nền cố định + Giờ OT tính theo đơn giá giờ riêng (`hourlyRate`).
- **M4 (Theo ngày công):** $\text{regularPay} = \text{workDays} \times \text{dailyRate}$. **Tuyệt đối không trừ kép khoản phạt vắng mặt vào tiền ngày công.**
- **M5 (Tùy chỉnh):** Kết hợp các thành phần theo thỏa thuận (Lương nền + Tiền giờ + Tiền ngày).

### 4.2. Tiêu chuẩn Thưởng chuyên cần (`attendance_bonus`)
Nhân viên được nhận thưởng chuyên cần khi đáp ứng đồng thời cả 2 điều kiện:
1. Số ngày công thực tế $\ge$ Số ngày công chuẩn của kỳ ($\text{workDays} \ge \text{expectedDays}$).
2. Số lần vi phạm đi muộn trong kỳ $\le 1\text{ lần}$ (đi muộn từ 2 lần trở lên sẽ bị hủy thưởng chuyên cần của kỳ đó).

---

## 5. QUY TRÌNH PHÊ DUYỆT KỲ LƯƠNG

### 5.1. Quy trình phân tầng 2 bước
1. **Bước 1 (Lập & Rà soát):** Quản lý hoặc Chủ quán tạo kỳ lương, hệ thống tự động tổng hợp ca chấm công, đối soát các mục cảnh báo (ca chưa chốt, OT chờ duyệt, lệch vị trí). Quản lý xử lý xong bấm **"Gửi duyệt"** (`status = pending_review`).
2. **Bước 2 (Chốt duyệt):** Chỉ **Chủ quán (Owner)** có quyền bấm **"Duyệt kỳ lương"** (`status = approved`). Khi đã duyệt, toàn bộ số liệu bị khóa bất biến (`locked_at = now()`), không ai được phép sửa đổi trực tiếp.
*(Nếu quán không có Quản lý, Chủ quán được quyền tự lập và tự duyệt trực tiếp).*

---

## 6. CHÍNH SÁCH ỨNG LƯƠNG (SALARY ADVANCE)

### 6.1. Hạn mức ứng lương (Trần cứng 50%)
- Nhân viên gửi yêu cầu ứng lương kèm lý do trực tiếp trên app.
- **Hạn mức tối đa được duyệt:** Không vượt quá **50%** số lương thực tế đã tích lũy từ các ca làm việc hợp lệ trong kỳ tính đến thời điểm yêu cầu (sau khi đã trừ các khoản ứng trước đó chưa hoàn trả).

### 6.2. Luồng phê duyệt & Khấu trừ tự động
- Quản lý xem xét và đề xuất $\rightarrow$ Chủ quán duyệt chi tiền mặt hoặc chuyển khoản $\rightarrow$ Hệ thống tự động ghi nhận một khoản khấu trừ ứng lương vào kỳ lương kế tiếp của nhân viên cho đến khi tất toán hết.

---

## 7. CHI TRẢ LƯƠNG, ĐỐI SOÁT & KHIẾU NẠI (DISPUTES)

### 7.1. Đa dạng hình thức chi trả (Split Payment)
- Hỗ trợ chi trả bằng: **Tiền mặt**, **Chuyển khoản**, hoặc **Kết hợp cả hai** (ví dụ phiếu lương 8 triệu: chi 5 triệu chuyển khoản + 3 triệu tiền mặt).
- Phần chuyển khoản lưu mã giao dịch và ảnh chụp ủy nhiệm chi / biên lai.

### 7.2. Thời hạn đối soát & Giải quyết khiếu nại (3 ngày)
- Sau khi quán ghi nhận "Đã chi lương", phiếu lương cá nhân của nhân viên kích hoạt đồng hồ đếm ngược **3 ngày**.
- Nhân viên có 2 lựa chọn:
  - **"Đã nhận đủ lương"** $\rightarrow$ Hệ thống chuyển trạng thái phiếu sang `paid` và lưu biên nhận điện tử.
  - **"Khiếu nại sai lệch"** $\rightarrow$ Nhân viên chọn mục thắc mắc (giờ làm, OT, tiền thưởng, tiền phạt) và nhập nội dung. Quản lý đối chiếu ca làm và đề xuất hướng bù/trừ; Chủ quán duyệt quyết định xử lý để đưa khoản chênh lệch vào kỳ lương tiếp theo.

---

## 8. CƠ CHẾ QUẢN LÝ LỊCH SỬ MỨC LƯƠNG (SALARY VERSIONING)

### 8.1. Nguyên tắc ngày hiệu lực (`effective_from`)
- Mọi thay đổi về chính sách hoặc mức lương của nhân viên (ví dụ tăng đơn giá giờ từ 25.000đ lên 30.000đ) bắt buộc phải gắn với ngày hiệu lực (`effective_from`).
- **Mức lương mới chỉ áp dụng cho các ca làm việc phát sinh từ ngày hiệu lực trở đi.**
- Toàn bộ ca làm việc và kỳ lương trong quá khứ được bảo toàn 100% mức lương cũ, tuyệt đối không bị tính toán lại khi có cập nhật chính sách mới.
