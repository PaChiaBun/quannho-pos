---
module: tinhluong
ten: Lương
phien_ban: 1.0.5+20
cap_nhat: 2026-10-23
nguon:
  - lib/main.dart (_TinhLuongRouteScreen: quản lý vs nhân viên)
  - lib/modules/tinhluong/screens/tinhluong_screen.dart, period_detail_screen.dart, record_detail_screen.dart, staff_salary_config_screen.dart, payroll_report_screen.dart, my_payslip_screen.dart, dispute_sheet.dart
  - lib/modules/tinhluong/repository/tinhluong_repository.dart (markRecordPaid, confirmStaffPaid, recordPayrollExpense), services/payroll_evaluation_service.dart
  - .docs/Ai_Boom/cac-module/quy-chuan-cham-cong-tinh-luong-chuan.md (đặc tả — đối chiếu ở Ghi chú cho Chủ Quán)
---

# Lương

> Cấu hình cách tính lương theo vị trí hoặc từng người, tạo kỳ lương từ dữ liệu chấm công, gửi duyệt – duyệt – trả lương, nhân viên xem phiếu lương, xác nhận đã nhận hoặc khiếu nại.

## Ai dùng được
- Mở module **Tính Lương** (tên ô trên Trang chủ):
  - **Chủ quán** và vai trò **Quản lý** (tên vai trò có "quản lý", "quản trị", "manager", "admin") → màn **quản lý lương**.
  - Mọi vai trò khác — **kể cả khi được giao module Tính lương** (ví dụ "Kế toán / Thu chi") → chỉ thấy màn **"Lương của tôi"** (phiếu của chính mình).
- **Lập kỳ, tính lại, gửi duyệt** (ở màn quản lý lương) và **duyệt OT/ca quên chốt trong Báo cáo lương**: Chủ quán và vai trò Quản lý đều làm được.
- **Duyệt kỳ**: chỉ **Chủ quán**. **Trả lương**: **Chủ quán** hoặc nhân viên mang vai trò tên **đúng là "Quản lý"** — vai trò tên khác (vd "Quản lý nhà hàng") vào được màn quản lý lương nhưng **không thấy nút Trả lương**. **Xác nhận đã nhận**: chỉ chính nhân viên đó (máy chủ cũng chặn).
- **Cấu hình lương**: cần quyền **"Quản lý thiết lập lương"**; người khác thấy "Bạn không có quyền quản lý cấu hình lương".

## Màn hình quản lý gồm những gì
- **"TỔNG QUAN LƯƠNG"**: số **Kỳ lương**, **Đã trả** (x/y — số kỳ đã chốt "Đã trả"); nút **"Tạo kỳ lương"**, **"Xem báo cáo"**, **"Cấu hình lương"** (cũng có ở nút **"Tạo kỳ"**, **"Báo cáo"**, **"Cấu hình"** trên đầu).
- Cảnh báo **"⚠️ Có N khiếu nại. Mở phiếu lương để trả lời."**
- **"Các kỳ lương"**: tên kỳ, từ → đến, **"Tổng lương"**, trạng thái (**"Nháp"**, **"Chờ duyệt"**, **"Đã duyệt"**), nút **"Chỉnh sửa"** (kỳ nháp) / **"Xem chi tiết"**.

## Các việc thường làm

### 1. Cấu hình lương (làm trước khi tạo kỳ)
1. **"Cấu hình lương"** → **"Trung tâm chính sách lương"** ("Thiết lập chung theo vị trí trước, tinh chỉnh riêng cho từng nhân viên sau").
2. Chọn **"Theo vị trí"** (cả nhóm Thu ngân, Phục vụ…) hoặc **"Theo nhân viên"** (từng người). Danh sách lọc **"Đã cấu hình" / "Chưa cấu hình"**.
3. Bấm **"Thiết lập chính sách"** (theo vị trí) hoặc chạm một người, điền:
   - **"1. Phạm vi áp dụng"** — mặc định chỉ bổ sung người **chưa cấu hình**, không đè thiết lập riêng.
   - **"2. Cách tính thu nhập chính"**: **Theo giờ** ("Đơn giá giờ thường (đ/giờ)"), **Cố định** ("Lương cố định mỗi tháng (đ)"), **Cố định + OT**, **Theo ngày** ("Đơn giá ngày (đ/ngày)"), **Tùy chỉnh**; **"Số ngày công chuẩn trong kỳ"** (mặc định 26).
   - **"3. Tăng ca (OT)"**: **"Ngưỡng bắt đầu OT (giờ/ca)"** (mặc định 8), **"Hệ số OT (ví dụ 1.5)"** (mặc định 1.5).
   - **"4. Thưởng & phụ cấp"**: **"Thưởng cố định mỗi kỳ (đ)"**, **"Thưởng đủ ngày công (đ)"**, **"Phụ cấp cố định mỗi kỳ (đ)"**.
   - **"5. Khấu trừ"**: **"Khấu trừ đi muộn (đ/lần)"** (mặc định 50.000).
4. **"Áp dụng cho người chưa cấu hình"** (theo vị trí) hoặc **"Lưu cấu hình"** (từng người).

> Mở nhanh từ hồ sơ nhân viên: Nhân viên → chạm người → **"⚙️ Mở Cấu Hình Lương Nâng Cao"**.

### 2. Tạo kỳ lương
1. **"Tạo kỳ lương"** → **"Tạo kỳ lương mới"**: **"Tên kỳ lương"** (tự điền "Tháng M/YYYY"), **"Từ ngày"**, **"Đến ngày"** → **"Tạo kỳ lương"**.
2. Hệ thống tổng hợp ca chấm công và tính lương từng người theo cấu hình (bản nháp, "Dữ liệu chốt tại thời điểm tạo/tính lại").

### 3. Rà soát và gửi duyệt
1. Mở kỳ: **"TỔNG QUỸ LƯƠNG"**, tổng công/giờ, số người có ca, đã trả bao nhiêu; lọc theo vị trí, **"Tìm theo tên nhân viên..."**, **Tất cả / Chưa trả / Chờ xác nhận / Đã trả**.
2. Mỗi người: **"THỰC LĨNH"**, **"THU NHẬP"** (lương cơ bản, tăng ca OT, thưởng thêm, thưởng doanh thu, phụ cấp), **"KHẤU TRỪ"** (đi muộn, nghỉ không phép, khấu trừ khác).
3. App kiểm tra kỳ đã sẵn sàng chưa. Nếu **"Kỳ lương chưa sẵn sàng"**, lý do có thể là:
   - "N nhân viên chưa được cấu hình lương"
   - "N ca làm chưa chốt hoặc quên chốt ca"
   - "N ca làm có OT đang chờ duyệt"
   → Xử lý (cấu hình lương; chốt ca / duyệt OT ở Chấm công hoặc Báo cáo lương) rồi bấm **"Tính lại"**.
4. Ca hoặc cấu hình thay đổi sau khi tạo kỳ: hiện **"Dữ liệu đã thay đổi"** kèm số tiền chênh → **"Cập nhật"**.
5. **"Tính lại"** → **"Tính lại kỳ lương?"** (tính lại toàn bộ theo ca và cấu hình MỚI NHẤT, ghi đè bản ghi chưa khoá) → **"Tính lại"**.
6. Sẵn sàng: **"Gửi duyệt"** → "✅ Đã gửi duyệt kỳ lương". Kỳ chuyển **"Chờ duyệt"**.

### 4. Duyệt kỳ
- **Chủ quán** mở kỳ **Chờ duyệt** → **"Duyệt kỳ"** → "✅ Đã duyệt kỳ lương". Kỳ **"Đã duyệt"**: số liệu bị khoá (máy chủ chặn sửa/xoá phiếu, không mở lại được).

### 5. Trả lương
1. Kỳ **Đã duyệt** → **Chủ quán hoặc Quản lý** ở từng nhân viên (phiếu chưa trả) bấm **"Trả lương"** → **"Trả lương nhân viên"**: chọn **"Tiền mặt"**, **"Chuyển khoản"** hoặc **"MoMo"**.
   - Cách khác: chạm phiếu nhân viên → **"XÁC NHẬN TRẢ LƯƠNG NHÂN VIÊN"** → chọn cách trả.
   - Nút trả lương chỉ hiện với Chủ quán hoặc tài khoản vai trò tên đúng "Quản lý", và chỉ ở phiếu **chưa trả**.
2. "✅ Đã trả lương cho <tên>". Phiếu chuyển sang **chờ nhân viên xác nhận**: nhãn **"⏳ Chờ NV xác nhận"**, nằm ở bộ lọc **"Chờ xác nhận"**; nhân viên bấm xác nhận đã nhận thì sang **"Đã trả"**.
3. Khi **mọi nhân viên** (có lương) đã xác nhận nhận lương, **Chủ quán** thấy dải **"Mọi nhân viên đã xác nhận nhận lương."** → **"Chốt kỳ đã trả"** → **"Chốt kỳ"**. Kỳ chuyển **"Đã trả"** và khoá hẳn. Không thấy dải → kéo xuống để tải lại.

> Trả lương **chưa tự ghi khoản chi vào Thu Chi** — ghi tay ở Thu Chi ("− Ghi chi", danh mục "Lương nhân viên") để sổ quỹ đúng.

### 6. Nhân viên xem phiếu, xác nhận, khiếu nại
1. Nhân viên mở **Tính Lương** → **"Lương của tôi"**: các kỳ đã gửi duyệt / đã duyệt / đã trả; **Tổng giờ**, **Tăng ca**, ngày nghỉ, số lần muộn, **"Thực lĩnh"**; chạm để xem **"Chi tiết khoản lương"** và **"Chấm công"**.
2. Khi quản lý đã trả: "Quản lý đã chuyển … qua …" → bấm **"✅ XÁC NHẬN ĐÃ NHẬN ĐỦ LƯƠNG"** → "✅ Đã xác nhận thành công". Nếu lỗi, app báo đúng lý do (ví dụ "Chỉ nhân viên nhận lương được xác nhận đã nhận.").
3. Sai: **"Phản hồi / Khiếu nại"** → **"Gửi phản hồi / khiếu nại"** → chọn **"Vấn đề là gì?"** (giờ làm, OT, thưởng, khấu trừ sai, khác…) → **"Mô tả chi tiết vấn đề..."** (≤ 500 ký tự) → **"Gửi khiếu nại"**. Trạng thái "Đang chờ quản lý phản hồi".
4. Quản lý: mở phiếu nhân viên → **"Trả lời khiếu nại"** → **"Trả lời"**.

### 7. Báo cáo lương
- **"Báo cáo lương"**: tab **"Tổng Quan Kỳ"** (Tổng Nhân Viên Làm Việc, Tổng Số Giờ Tích Lũy, Chi Phí Lương Ca Tạm Tính) và **"Theo Nhân Viên"**. Duyệt OT / xác nhận ca quên chốt ngay tại đây (cần quyền).
- Trong kỳ: **"Báo cáo KPI"**.

## Lỗi thường gặp
| Thấy gì | Vì sao | Làm gì |
|---|---|---|
| "Không thể gửi duyệt" – "Kỳ lương chưa sẵn sàng do còn các vấn đề sau…" | Thiếu cấu hình / ca chưa chốt / OT chờ duyệt | Xử lý từng mục rồi "Tính lại" |
| Không vào được màn quản lý lương, chỉ thấy "Lương của tôi" | Không phải Chủ quán / vai trò Quản lý (có module Tính lương vẫn chưa đủ) | Nhờ Chủ quán hoặc Quản lý |
| Không thấy nút "Duyệt kỳ" / "Trả lương" | Duyệt kỳ chỉ Chủ quán; trả lương chỉ Chủ quán hoặc vai trò tên đúng "Quản lý" (vd "Quản lý nhà hàng" không trả được); hoặc kỳ chưa đúng trạng thái; hoặc phiếu đã trả | Nhờ Chủ quán; trả lương chỉ khi kỳ Đã duyệt |
| "❌ Lỗi khi duyệt kỳ lương: Chỉ Chủ quán được duyệt / chốt kỳ lương." / "❌ Chỉ Chủ quán hoặc Quản lý được trả lương." | Máy chủ chặn đúng quyền | Nhờ đúng người |
| Đã bấm Trả lương mà phiếu vẫn ở "Chờ xác nhận" | Đang chờ nhân viên xác nhận đã nhận | Nhắc nhân viên mở "Lương của tôi" bấm xác nhận |
| Kỳ đã trả hết mà vẫn "Đã duyệt" | Chưa chốt kỳ, hoặc còn người chưa xác nhận | Chủ quán bấm "Chốt kỳ đã trả" khi mọi người đã xác nhận |
| "Chỉ nhân viên nhận lương được xác nhận đã nhận." | Người khác bấm xác nhận thay | Để chính nhân viên đó xác nhận |
| "Kỳ lương đã duyệt, số liệu bị khoá." | Kỳ đã duyệt | Không sửa được; chênh lệch đưa vào kỳ sau |
| "Bạn không có quyền quản lý cấu hình lương" | Thiếu quyền thiết lập lương | Nhờ Chủ quán |
| "❌ Bạn không có quyền duyệt lương." (Báo cáo lương) | Thiếu quyền | Nhờ Chủ quán |
| Nhân viên thấy "Chưa có kỳ lương nào sẵn sàng" | Kỳ còn nháp, chưa gửi duyệt | Quản lý "Gửi duyệt" |
| "Vui lòng nhập tên kỳ lương" | Bỏ trống tên | Nhập tên |
| Lương ít bất thường | Ca quên chốt bị trừ 50%, hoặc tính ngày vắng | Xác nhận ca quên chốt ở Chấm công; kiểm tra ngày công chuẩn |
| Sổ Thu Chi không có khoản lương | Trả lương chưa tự ghi chi | Ghi tay ở Thu Chi |

## Liên quan module khác
- **Chấm công**: nguồn giờ làm, OT, đi muộn, quên chốt.
- **Nhân viên**: vị trí, hồ sơ, mở cấu hình lương.
- **Thu Chi**: ghi tay khoản chi lương.

## Ghi chú cho Chủ Quán (không đưa cho khách)

### Khác biệt với bản app cũ (cho Chủ Quán)
- App cũ: "Đã trả" ở Tổng quan lương luôn là 0; không có bộ lọc "Chờ xác nhận" — phiếu đã bấm Trả lương vẫn nằm ở "Chưa trả", không có nhãn "⏳ Chờ NV xác nhận".
- App cũ không có "Chốt kỳ đã trả": kỳ trả hết vẫn mãi ở "Đã duyệt" — cập nhật app rồi chốt kỳ.
- App cũ chưa chặn ở phía app việc người khác bấm xác nhận đã nhận thay nhân viên (máy chủ vẫn chặn).

1. **Trả lương không ghi vào Thu Chi**: hàm `recordPayrollExpense` có sẵn (có chống trùng) nhưng **không được gọi ở đâu**. Bài Thu Chi đã đính chính. Thêm nữa, hàm này mặc định `fund_type='transfer'` — không khớp quỹ `cash`/`bank` của Thu Chi, nếu bật lên sẽ không hiện khi lọc Tiền mặt/Tiền gửi.
2. **[ĐÃ SỬA 22/10 — máy chủ ĐÃ áp lúc 22:10; app mới chưa phát hành]** Lỗi cũ: ai có module Tính lương đều duyệt và trả được lương; máy chủ không khoá kỳ đã duyệt (gọi API sửa được số tiền, tự đánh dấu đã nhận). Sửa: `20261022_khoa_duyet_tra_luong_v1.sql` (trigger `guard_payroll_periods_v1` / `guard_payroll_records_v1`): duyệt/chốt kỳ chỉ Chủ quán; kỳ đã duyệt khoá số liệu; trả lương chỉ Chủ quán/Quản lý và chỉ sau duyệt; xác nhận đã nhận chỉ đúng nhân viên (hoặc Chủ quán). App ẩn nút theo vai trò, báo lỗi dễ hiểu; "Xác nhận đã nhận" không còn báo thành công khi lỗi. **Còn:** khi kỳ còn nháp, ai vào được quán vẫn sửa được phiếu qua API (số liệu được Chủ quán rà khi duyệt).
3. **Lệch đặc tả, chưa làm:** ứng lương (mục 6), trả lương tách tiền mặt + chuyển khoản và lưu biên lai (7.1), hạn 3 ngày xác nhận (7.2), lịch sử mức lương theo ngày hiệu lực (mục 8 — đổi cấu hình rồi "Tính lại" sẽ áp mức mới cho cả kỳ), phạt vắng không phép theo lịch phân ca (mục 3).
4. **Ngày nghỉ được suy ra** = ngày công chuẩn − ngày đã làm (`payroll_evaluation_service`), trong khi đặc tả cấm suy vắng mặt từ chênh lệch ngày công.
5. **"Ghi nhận đóng góp" (SRM)** có repository và quyền (`tinhluong.srm_*`) nhưng **không có màn hình** dùng.
6. Màn quản lý lương mở theo `canonicalRole` ở `main.dart` (`_TinhLuongRouteScreen`): owner / manager (tên chứa quản lý, quản trị, manager, admin) / đúng chữ `accountant` hoặc `ketoan`. `canonicalRole` không bao giờ trả `accountant`/`ketoan` cho tên tiếng Việt → vai trò "Kế toán / Thu chi" (gợi ý F&B) chỉ thấy "Lương của tôi" dù có module và quyền `tinhluong.approve_payroll`.
7. **[ĐÃ SỬA trong app 23/10 — chưa phát hành]** Kỳ từng không bao giờ thành "Đã trả" → nay Chủ quán "Chốt kỳ đã trả" khi mọi phiếu có lương ở `paid` (`_canClosePeriodPaid`, `updatePeriodStatus(id, 'paid')`; máy chủ cho owner approved→paid). Dải chỉ cập nhật khi tải lại màn kỳ.
8. **[ĐÃ SỬA trong app 23/10 — chưa phát hành]** Phiếu `pending_staff_confirm` có nhãn "⏳ Chờ NV xác nhận" và bộ lọc "Chờ xác nhận" (trước bị tính vào "Chưa trả").
9. Nút trả lương: app chỉ hiện cho owner hoặc tài khoản có mã vai trò đúng `manager`/`admin` (khớp máy chủ `payroll_actor_v1`), và chỉ với phiếu `pending`. Vai trò "Quản lý nhà hàng" (tên tự tạo, `canonicalRole` = manager) vào màn quản lý lương, có `tinhluong.approve_payroll` (lập/gửi kỳ) nhưng không trả lương được.
10. Quyền "Chốt bảng lương" thực tế không tắt được cho ai vào được màn quản lý lương: chỉ owner/manager (theo `canonicalRole`) vào được, và `getEffectiveActionPermissions` luôn trả mọi quyền cho hai loại này (bỏ qua danh sách tắt).
