# Kế Hoạch Sửa Đổi & Chuẩn Hoá Modules Điểm Danh & Tính Lương (Quán Nhỏ POS)

Tài liệu này tổng hợp kết quả điều tra sâu toàn bộ hệ thống Điểm danh (Chấm công) và Tính lương (Payroll) của Quán Nhỏ POS theo quy chuẩn `/qn` và các tài liệu nghiệp vụ `.docs/trien-khai-sap-toi.md`, `.docs/Ai_Bum/cac-module/cham-cong.md`, `.docs/Ai_Bum/cac-module/luong.md`.

---

## Tóm Tắt Hiện Trạng & Các Bất Cập Cốt Lõi

Sau khi rà soát toàn bộ source code (`lib/`), DB schema (`supabase/`), và test suites (`test/`), chúng tôi phát hiện hệ thống **chưa đáp ứng được yêu cầu nghiệp vụ thực tế** do 6 nhóm lỗi và lỗ hổng nghiêm trọng sau:

1. **Xung đột cách tính phút đi muộn (`late_minutes`) giữa hai module:**
   - Trong `ShiftTemplateRepository.detectLateArrival()`: Phút muộn tính từ **sau mốc ân hạn** (`lateMinutes = clockIn - deadline`).
   - Trong `TinhLuongRepository.calculateSingleShiftEarnings()` và bài test chuẩn `tinhluong_pure_test.dart`: Phút muộn tính từ **giờ bắt đầu ca** (`lateMinutes = clockIn - expectedStart`).
   - Kết quả: Cùng một ca làm, một bên báo muộn 5 phút, một bên báo muộn 20 phút.

2. **Lỗi toán học nghiêm trọng ở Chế độ lương M4 (Theo ngày): Bị trừ 2 lần tiền khi nghỉ:**
   - Nhân viên làm việc theo ngày công được tính lương: `regularPay = workDays * dailyRate`.
   - Nhưng hệ thống lại tính tiếp: `deductionAbsent = absentDays * dailyRate` và lấy `grossPay = regularPay - deductionAbsent`.
   - **Hậu quả:** Người làm theo ngày không đi làm thì đã không được tính lương ngày đó, nhưng lại bị trừ thêm một lần nữa. Ví dụ: Làm 5 ngày/26 ngày chuẩn với mức 300.000đ/ngày $\rightarrow$ Lương 1.500.000đ, phạt vắng 21 ngày = 6.300.000đ $\rightarrow$ Thực lĩnh nhận 0đ!

3. **Lỗi bỏ sót Đi muộn khi Tạo kỳ lương tự động (`PayrollEvaluationService`):**
   - Trong `PayrollEvaluationService.evaluatePeriod()` (dòng 141): `int staffLateCount = existing?.lateCount ?? 0;`.
   - Trong vòng lặp tổng hợp các ca làm (`shiftsRows`), code hoàn toàn không đếm số lần `is_late` từ bảng `staff_shifts`.
   - **Hậu quả:** Khi tạo một kỳ lương mới lần đầu (`existing == null`), `lateCount` luôn bằng `0` $\rightarrow$ Tiền phạt đi muộn (`deductionLate`) trên bảng lương kỳ luôn bằng 0đ, dù nhân viên đi muộn nhiều lần trong tháng.

4. **Lỗi kỳ lương ngắn hạn (Tuần / Nửa tháng) bị phạt vắng sạch lương ở M2 (Lương tháng):**
   - `absentDays` được tính bằng `expectedDays - workedDays` với `expectedDays` lấy cứng 26 ngày (cấu hình tháng).
   - Khi chủ quán tạo kỳ lương 1 tuần (7 ngày), nhân viên làm đủ 6 ngày vẫn bị tính vắng $26 - 6 = 20\text{ ngày}$ và bị trừ hết sạch lương.

5. **Bất nhất giữa Xem lương từng ca và Tính lương tổng kỳ:**
   - **Giờ OT chưa duyệt:** Ở từng ca bị loại bỏ (0đ), nhưng ở kỳ lương lại được trả lương 1.0x (lương cơ bản).
   - **Quên chốt ca (> 14 tiếng):** Ở từng ca bị phạt trừ 50% tiền ca, nhưng ở kỳ lương thì tính đủ nguyên vẹn toàn bộ số giờ trôi dạt và không bị phạt 50%.

6. **Điểm danh thiếu ràng buộc phân ca & Geofence chưa chặn cứng:**
   - Nhân viên chưa có lịch phân ca vẫn có thể Clock-In tùy ý (và không bao giờ bị tính muộn).
   - Ngoài bán kính quán chỉ hiện cảnh báo chứ không chặn (bấm Tiếp tục là vào ca được).
   - Ra ca (`clockOut`) không kiểm tra GPS.

---

## User Review Required

> [!IMPORTANT]
> **Quyết định 1: Quy tắc chốt số phút đi muộn (`late_minutes`)**
> Khi nhân viên vào ca trễ vượt quá thời gian ân hạn (Ví dụ: Ca 08:00, ân hạn 15p đến 08:15, nhân viên bấm vào ca lúc 08:20):
> - **Phương án A (Khuyến nghị - Đúng chuẩn F&B & Test suite):** Tính muộn **20 phút** (tính từ giờ bắt đầu ca 08:00).
> - **Phương án B:** Tính muộn **5 phút** (tính từ sau mốc ân hạn 08:15).

> [!IMPORTANT]
> **Quyết định 2: Sửa công thức M4 (Theo ngày)**
> - Chế độ M4 không áp dụng `deductionAbsent = absentDays * dailyRate` (vì lương đã trả đúng theo số ngày đi làm thực tế).
> - Tiền phạt nghỉ chỉ áp dụng nếu nhân viên nghỉ không phép có phân ca (unauthorized absence penalty cố định).

> [!IMPORTANT]
> **Quyết định 3: Tỷ lệ ngày công chuẩn theo độ dài kỳ lương**
> - Khi kỳ lương là Tuần (7 ngày) hoặc Nửa tháng (15 ngày), `expectedDays` sẽ được tự động quy đổi tương ứng theo số ngày của kỳ thay vì áp cứng 26 ngày của tháng.

---

## Proposed Changes

### Component 1: Điểm danh (Chấm công)

#### [MODIFY] [shift_template_repository.dart](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/modules/tinhluong/repository/shift_template_repository.dart)
- Sửa `detectLateArrival`: Khi `clockInTime.isAfter(deadline)`, tính `lateMinutes = clockInTime.difference(expectedStart).inMinutes;` để đồng nhất với `calculateSingleShiftEarnings` và `tinhluong_pure_test.dart`.
- Bổ sung kiểm tra ca làm gần nhất khi một nhân viên có nhiều ca phân công trong ngày hoặc làm việc theo ca xoay.

#### [MODIFY] [staff_service.dart](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/core/services/staff_service.dart)
- Cập nhật `clockIn`: Lưu chính xác `is_late`, `late_minutes`, và `assignment_id` ngay khi tạo bản ghi.
- Đảm bảo khi tự động kết ca do quên đóng, ghi nhận cờ `is_forgot_clockout = true` để kích hoạt đúng điều kiện khấu trừ 50% tiền ca.

---

### Component 2: Tính lương (Payroll Evaluation & Calculation)

#### [MODIFY] [payroll_evaluation_service.dart](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/modules/tinhluong/services/payroll_evaluation_service.dart)
- Đếm chính xác số lần `is_late` và tổng số phút muộn từ các ca làm trong kỳ:
  ```dart
  int staffLateCount = 0;
  for (final s in shifts) {
    if (s.isLate) staffLateCount++;
  }
  ```
- Xử lý giờ OT chưa duyệt đồng nhất với `calculateSingleShiftEarnings`: chỉ tính OT pay và regular pay theo giờ làm hợp lệ đã phê duyệt.
- Xử lý ca quên chốt ca (`checkIsForgotClockout`): Áp dụng phạt 50% tiền ca theo đúng quy chế.
- Quy đổi `expectedDays` theo số ngày thực tế của kỳ lương nếu kỳ lương nhỏ hơn 1 tháng.

#### [MODIFY] [tinhluong_repository.dart](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/modules/tinhluong/repository/tinhluong_repository.dart)
- Sửa hàm `calculatePayroll` cho chế độ **M4**: Không trừ `deductionAbsent = absentDays * dailyRate` vào lương ngày công.
- Đồng nhất công thức OT cho **M2** và **M3**: sử dụng `expectedDays` thay vì hardcode 26 ngày.

---

### Component 3: Kiểm thử tự động (Unit Tests)

#### [MODIFY] [tinhluong_pure_test.dart](file:///Users/banhbao/Quan%20Nho/quan_nho/test/modules/tinhluong/tinhluong_pure_test.dart)
- Thêm unit test kiểm tra M4 không bị trừ kép lương ngày công khi có ngày vắng.
- Thêm unit test kiểm tra `PayrollEvaluationService` tính đúng `lateCount` từ các ca làm thực tế.
- Thêm unit test kiểm tra kỳ lương 7 ngày (tuần) không bị phạt trừ sạch lương của M2.
- Thêm unit test kiểm tra `detectLateArrival` khớp chính xác với `calculateSingleShiftEarnings`.

---

## Verification Plan

### Automated Tests
Chạy toàn bộ bộ test tính lương và điểm danh để xác nhận 100% tests pass:
```bash
flutter test test/modules/tinhluong/tinhluong_pure_test.dart
flutter test test/modules/tinhluong/staff_salary_config_repo_test.dart
flutter test test/modules/tinhluong/payroll_srm_repository_test.dart
```

### Static Analysis
Kiểm tra static analysis không phát sinh warning/error:
```bash
dart analyze lib/modules/tinhluong lib/core/services/staff_service.dart
```

### Synchronization với Graphify & CodeGraph
```bash
codegraph affected lib/modules/tinhluong/services/payroll_evaluation_service.dart
graphify update .
```
