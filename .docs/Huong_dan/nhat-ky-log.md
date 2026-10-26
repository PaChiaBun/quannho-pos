---
module: log_viewer
ten: Nhật Ký Log
phien_ban: 1.0.5+20
cap_nhat: 2026-10-23
nguon:
  - lib/screens/log_viewer_screen.dart
  - lib/screens/bug_report_screen.dart (Cài đặt → "Gửi phản hồi")
  - lib/core/utils/app_logger.dart (AppLogger.action, mức INFO/WARNING/ERROR/DEBUG)
  - supabase/migrations/20261023_app_logs_retention_v2.sql (lịch dọn log — ĐÃ ÁP production 23/10 14:26; thay bản v1 20261018 đã bỏ)
---

# Nhật Ký Log

> Xem lại hoạt động và lỗi của app theo thời gian, nhân viên, loại thao tác — dùng để tra sự cố ("ai huỷ bàn lúc mấy giờ", "vì sao không in bill") và gửi cho người hỗ trợ.

## Ai dùng được
- Người có module **Nhật Ký Log** (mặc định có ở Chủ quán và Quản lý; bật trong Modules).

## Màn hình gồm những gì
- Tiêu đề **"Nhật Ký Hoạt Động & Lỗi"**; nút **"Sao chép Logs"**, **"Tải lại"**, **"Xóa log kỹ thuật"**.
- **Bộ lọc**:
  - **"Khoảng thời gian"** (mặc định hôm nay), **"Giờ bắt đầu"**, **"Giờ kết thúc"**.
  - **"Nhân viên"**.
  - **"Loại thao tác"**: 🧾 Hành động nghiệp vụ, 🪑 Món tại bàn, 💰 Thu chi, 🔐 Tài khoản, 🍽️ Đặt món, 💳 Thanh toán, ⚙️ Cài đặt, 🖨️ Máy in, 📦 Kho hàng, 💻 Hệ thống.
  - **"Phân loại Log"**: **Thông tin hoạt động**, **Cảnh báo hệ thống**, **Lỗi nghiêm trọng**, **Gỡ lỗi kỹ thuật**.
- Nút **"Truy xuất Log"** để tải theo bộ lọc.
- Mỗi dòng: thời gian, mức (**Thông tin / Cảnh báo / Lỗi hệ thống / Gỡ lỗi**), nhân viên, nội dung; chạm để xem **"Chi tiết kỹ thuật (Technical Details)"**.

## App ghi lại những gì (ví dụ)
- **Hành động nghiệp vụ**: mở bàn, gửi bếp, huỷ món/huỷ bàn, Quản lý duyệt bằng PIN, thanh toán, in lại bill, món chưa gửi bếp quá 3 phút, bill chưa in sau 30 giây…
- **Lỗi**: tải dữ liệu thất bại, in thất bại, mất kết nối…
- Mỗi dòng kèm tên nhân viên và mã thiết bị.
- Dòng dò định kỳ (polling) đơn/phiếu bếp được ẩn khỏi danh sách cho đỡ rối.

## Các việc thường làm

### 1. Tra một sự cố
Xem lại lỗi máy in (bill, phiếu bếp không in ra) / lỗi hệ thống lúc xảy ra sự cố:
1. Chọn **"Khoảng thời gian"** và giờ quanh lúc xảy ra.
2. Lọc **"Nhân viên"** (nếu biết ai), **"Phân loại Log"** = **Lỗi nghiêm trọng** hoặc **Cảnh báo hệ thống**.
   - Lỗi máy in: chọn **"Loại thao tác"** = **🖨️ Máy in** và **"Phân loại Log"** = **Tất cả** — lỗi in thường ghi ở mức Thông tin hoạt động (dòng có chữ ERROR). Lỗi in phiếu bếp ngay ở Quản lý Bàn chỉ báo trên màn, không ghi log.
3. Bấm **"Truy xuất Log"**, chạm dòng cần xem để đọc chi tiết kỹ thuật.

> Muốn xem hành động nghiệp vụ (in lại bill, duyệt PIN, huỷ bàn…): chọn **"Loại thao tác"** = **🧾 Hành động nghiệp vụ**.

### 2. Gửi log cho người hỗ trợ
- Bấm **"Sao chép Logs"** → "Đã sao chép toàn bộ nhật ký vào Clipboard!" → dán vào tin nhắn.
- Hoặc **Cài đặt → "Gửi phản hồi"** ("Báo lỗi & tự động đính kèm Log kỹ thuật"): chọn **"Loại phản hồi"**, **"Mô tả chi tiết *"**, thêm **"Ảnh chụp màn hình (tuỳ chọn)"** → gửi.

### 3. Xoá nhật ký
- Nút **"Xóa log kỹ thuật"** → **"Xóa log kỹ thuật?"** → **"Xóa log kỹ thuật"** → "Đã xóa log kỹ thuật. Nhật ký nghiệp vụ được giữ lại." Chỉ xoá log kỹ thuật (máy in, hệ thống…); **nhật ký nghiệp vụ luôn được giữ** (hành động nghiệp vụ, thanh toán, đặt món, món tại bàn, thu chi, lương, nhân viên, tài khoản, kho, cài đặt) — máy chủ cũng chặn xoá.
- Nhật ký huỷ bàn/món ở **Báo cáo → Huỷ/Duyệt** là bảng riêng, không bị xoá.

### 4. Máy chủ tự dọn log cũ
Thời hạn giữ log:
- Mỗi đêm 00:40 máy chủ tự xoá **log kỹ thuật cũ hơn 30 ngày**.
- **Nhật ký nghiệp vụ** (thanh toán, thu chi, huỷ, duyệt PIN…) giữ **1 năm**.
- Vì vậy tra lỗi máy in / hệ thống chỉ xem được 30 ngày gần nhất.

## Lỗi thường gặp
| Thấy gì | Vì sao | Làm gì |
|---|---|---|
| "Vui lòng chọn bộ lọc và nhấn nút "Truy xuất Log" để tải nhật ký." | Chưa bấm tải | Bấm "Truy xuất Log" |
| "Không tìm thấy bản ghi nhật ký nào." | Bộ lọc quá hẹp / không có log | Mở rộng thời gian, chọn "Tất cả" |
| "Tải nhật ký thất bại. Hãy chụp lại báo chủ app." | Mạng / máy chủ | Thử lại |
| "Không có nhật ký để sao chép!" | Danh sách trống | Truy xuất trước |
| "Xóa nhật ký thất bại. Hãy chụp lại báo chủ app." | Mạng / máy chủ | Thử lại |

## Liên quan module khác
- **Mọi module**: đều ghi log.
- **Báo cáo → Huỷ/Duyệt**: nhật ký huỷ có duyệt (bảng riêng, không bị xoá khi xoá log).
- **Cài đặt → Gửi phản hồi**: gửi lỗi kèm log.

## Ghi chú cho Chủ Quán (không đưa cho khách)

### Khác biệt với bản app cũ (cho Chủ Quán)
- App cũ có nút "Xóa sạch" (→ "Xác nhận xóa" → "Xóa hết") thay cho "Xóa log kỹ thuật". Máy chủ chặn xoá log nghiệp vụ nên trên app cũ thao tác này báo "Xóa nhật ký thất bại" khi có log nghiệp vụ — là đúng; cập nhật app để dùng nút mới.
- App cũ chưa có nhóm "🧾 Hành động nghiệp vụ" trong "Loại thao tác" — xem ở "Tất cả".
- Máy chủ tự dọn log (log kỹ thuật 30 ngày, nghiệp vụ 1 năm) bắt đầu chạy từ 23/10/2026.

1. **[ĐÃ SỬA 22/10 — máy chủ ĐÃ áp `20261022_khoa_xoa_nhat_ky_v1.sql` lúc 21:52; app mới chưa phát hành]** Lỗi cũ: **"Xóa sạch" xoá toàn bộ `app_logs` của quán trên máy chủ**, gồm cả log kiểm toán `tag='action'` mức critical (in lại bill, duyệt PIN quản lý, huỷ bàn, bill chưa in…). Quản lý (mặc định có module) làm được — có thể xoá dấu vết. Nên chỉ cho xoá log kỹ thuật, giữ log `action` theo lịch lưu trữ.
   Nhóm được bảo vệ hiện tại (`kProtectedLogTags` ↔ `app_log_is_protected_tag`): action, checkout, order, auth, ban_items, finance, payroll, staff, staff_shift_audit, payroll_staff_confirm, kho, settings, inventory (3 nhóm cuối thêm bằng `20261022_cung_co_p0_v2.sql`, ĐÃ áp production 22/10 23:05; app bản mới cũng không xoá 3 nhóm này). Bảng huỷ có duyệt là `void_audit_logs`.
2. **[ĐÃ SỬA trong code 22/10, chưa phát hành]** Bộ lọc "Loại thao tác" thiếu nhóm `action` (và `ban_items`, `finance`) — nay đã có "🧾 Hành động nghiệp vụ", "🪑 Món tại bàn", "💰 Thu chi".
3. **Lịch tự dọn log — ĐÃ ÁP production 23/10/2026 14:26; đã dọn lần đầu 132.149 dòng log kỹ thuật > 30 ngày (log nghiệp vụ giữ nguyên 32.072 dòng). Lịch đêm ĐÃ CÀI: `quannho-log-purge.timer` 00:40 giờ VN mỗi đêm (`db-fix/cai_lich_don_log.sh`).** Bản v1 (`20261018_app_logs_retention_v1.sql`) **bỏ**: viết cứng 5 tag giữ lâu, thiếu finance/payroll/staff/kho/settings/inventory → log kiểm toán Thu Chi, Lương, Kho sẽ bị xoá sau 30 ngày. Bản v2 (`20261023_app_logs_retention_v2.sql`, 23/10) dùng chung `app_log_is_protected_tag()` với khoá nhật ký: log kỹ thuật (máy in, hệ thống, bếp…) giữ 30 ngày, log nghiệp vụ giữ 365 ngày; chặn gọi với số ngày quá ngắn; chỉ quản trị VPS gọi (app không gọi được). File migration không xoá gì — lịch chạy hằng đêm phải gắn riêng trên VPS (systemd timer 00:40). Chạy thử trên bản sao 13/13 PASS. Áp bằng `db-fix/don_log_v2_ap_dung.sh`. Lưu ý: cả lần dọn là một transaction (chia lô chỉ để câu lệnh nhỏ) — chạy giờ vắng. Số liệu 23/10: ~218.000 dòng log, 77 MB, ~73% là log máy in; lần chạy đầu sẽ xoá ~132.000 dòng log kỹ thuật > 30 ngày (máy in ~113.000, hệ thống ~13.600, bếp ~5.200).
4. **[ĐÃ SỬA trong app 22/10, chưa phát hành]** Hộp xác nhận "Xóa log kỹ thuật?" từng ghi "(máy in, hệ thống, cài đặt…)" dù nhóm `settings` được bảo vệ — nay bỏ "cài đặt" khỏi danh sách xoá được.
5. **MỞ (để sau — chờ đăng nhập JWT; không đưa vào v3 vì sẽ làm mất log đăng xuất):** chính sách INSERT của `app_logs` là `WITH CHECK (true)` → ghi được log vào quán khác; log nghiệp vụ giả mạo lại không xoá được do trigger bảo vệ. Xem viec-can-sua P0 #43.
