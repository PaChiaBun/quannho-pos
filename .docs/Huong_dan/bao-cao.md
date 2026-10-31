---
module: report
ten: Báo cáo
phien_ban: 1.0.5+20
cap_nhat: 2026-10-31
nguon:
  - lib/screens/report_screen.dart (8 tab: Doanh thu, Sản phẩm, Tài chính, Kho, Huỷ/Duyệt, Nhân viên, Voucher, Hóa đơn)
  - lib/core/repositories/dashboard_repository.dart (get_report_stats/daily_revenue/top_products_for_range_v1)
  - lib/screens/einvoice_report_tab.dart, lib/screens/bill_lookup_section.dart (tab Hóa đơn)
---

# Báo cáo

> Xem doanh thu, món bán chạy, lãi lỗ, nhập hàng, lịch sử huỷ, chấm công, voucher và tra cứu / in lại bill — theo ngày, tuần, tháng.

## Ai dùng được
- Người có module **Báo cáo** (mặc định bật; vai trò Quản lý, Thu ngân có sẵn).
- Biểu tượng **"Báo cáo chuỗi cửa hàng"** trên đầu chỉ hiện với **Chủ quán**.
- In lại bill (tab Hóa đơn) cần quyền xem lịch sử đơn.

## Màn hình gồm những gì
- Đầu trang **"Báo cáo"** + ngày; hai thẻ lớn **"Hôm nay"** (doanh thu, số đơn) và **"Tháng N"** (doanh thu lũy kế); dòng **Chi phí**, **Lợi nhuận**, **TB/đơn**.
- Nút **"Báo cáo chuỗi cửa hàng"** (Chủ quán) và làm mới.
- 8 tab: **Doanh thu**, **Sản phẩm**, **Tài chính**, **Kho**, **Huỷ/Duyệt**, **Nhân viên**, **Voucher**, **Hóa đơn**.
- Mỗi tab chọn kỳ **"Hôm nay" / "Tuần này" / "Tháng này"** và nút ‹ › để lùi/tiến (hôm qua, tuần trước…), hoặc chạm nhãn kỳ để chọn ngày/tuần/tháng.
- Máy tính bảng / PC: cột phải **"KPI hôm nay"** (Doanh thu, Số đơn, TB/đơn, Chi phí, Lợi nhuận, Biên LN), **"Huỷ Bàn / Huỷ Bill"** (lượt, tiền huỷ), **"Tháng N"** (doanh thu lũy kế).

## Từng tab

### Doanh thu
- Thẻ **"Tổng doanh thu …"**: số đơn, TB/đơn.
- Biểu đồ **"Doanh thu theo giờ"** (hôm nay) hoặc **"Doanh thu theo ngày"** (tuần/tháng).
- **"Tóm tắt kỳ này"**: Doanh thu, Số đơn, TB/đơn.
- **"Theo phương thức thanh toán"** (tiền mặt, chuyển khoản, thẻ, tỷ trọng).
- **"Doanh thu theo thu ngân"** (mỗi người: tiền mặt / chuyển khoản / thẻ).
- **"Số bàn phục vụ theo nhân viên"**.
- **"Tổng hợp bán hàng theo ngày"**: bảng Ngày, Số đơn, Doanh thu, Tiền mặt, Chuyển khoản, Khuyến mại.
- Nút **"In báo cáo"**: in/lưu PDF "BÁO CÁO DOANH THU …" (tóm tắt, phương thức thanh toán, theo thu ngân, chi tiết từng ngày).

> Doanh thu tính trên **đơn đã thanh toán** (bán quầy, thanh toán bàn, QR mang đi).

### Sản phẩm
- Lọc theo danh mục; **"Top sản phẩm bán chạy"**: số phần, giá trung bình/phần, doanh thu.

### Tài chính
- Xem quán lời hay lỗ theo kỳ: thẻ **"LỢI NHUẬN"** / **"ĐANG LỖ"**: Thu nhập, Chi phí, Biên LN.
- **"Kết quả kinh doanh"**: I. Doanh thu từ bán hàng (Tiền hàng; dòng "Tiền thuế GTGT (app chưa tính)" hiện "—" vì app không tính thuế) – II. Chi phí (theo danh mục) – III. Lợi nhuận (I − II), kèm tỷ trọng.
- Nhận xét tăng/giảm so với kỳ trước ("Thu nhập tăng X% so với kỳ trước").

> Số liệu lấy từ **Thu Chi** — mọi lưu ý của Thu Chi áp dụng ở đây (ví dụ lương phải ghi tay mới vào chi phí; đơn trả bằng ví không tính vào sổ Thu Chi vì tiền đã ghi thu lúc nạp ví).

### Kho
- Cần bật module Kho ("Module Kho đang tắt — Bật module Kho trong Cài đặt để xem báo cáo nhập hàng").
- **"Nhập hàng <kỳ>"**: số phiếu nhập; **"Sản phẩm nhập nhiều nhất"**.

### Huỷ/Duyệt
- Xem lịch sử huỷ món / huỷ bàn / huỷ hoá đơn và ai duyệt. **"Nhật ký hủy / duyệt"**: tổng tiền thất thoát do huỷ trong kỳ, số lượt huỷ "được kiểm toán".
- Mỗi dòng: **Huỷ bàn / Huỷ hoá đơn / Huỷ món**, người **yêu cầu**, người **duyệt**, **lý do**, số tiền.
- Chạm **"Nhấn để xem chi tiết món huỷ (N)"**: từng món, số lượng, đơn giá, **"Đã trừ hao hụt"** / **"Không trừ kho"**, **"Tổng tiền huỷ"**.

### Nhân viên
- Tổng **Ca làm**, **Giờ công**, **Đi trễ**, **Lệch vị trí**.
- Từng người: số ca, số giờ, nhãn **"🕒 N trễ"**, **"⚠️ N ca lệch"**, **"📍 N ko GPS"** hoặc **"✓ Đầy đủ"**.

### Voucher
- Xem voucher / mã giảm giá đã dùng: số lần dùng là **Tổng đơn áp mã**, **Tổng tiền giảm**; danh sách theo mã: Mã đơn / Bàn, Nhân viên, Thời gian, Giảm giá.

### Hóa đơn
- **"Tra cứu & in lại bill"**: tìm bill đã thanh toán theo số đơn, tên bàn (không cần dấu) hoặc số tiền; chạm để xem chi tiết; nút máy in để **in lại** (bill có dòng "BẢN IN LẠI", ghi nhật ký người in). Màn này tải đủ bill trong kỳ đang chọn (tối đa 20.000 bill); không thấy bill thì chọn đúng ngày của bill.

## Lỗi thường gặp
| Thấy gì | Vì sao | Làm gì |
|---|---|---|
| "Chưa có giao dịch hôm nay" / "Chưa có doanh thu kỳ này" | Chưa có đơn đã thanh toán | Kiểm tra kỳ đang chọn |
| "Module Kho đang tắt" | Chưa bật Kho | Bật module Kho |
| "Không tải được nhật ký kiểm toán" / "Không tải được dữ liệu kho" | Mạng / máy chủ | Bấm "Thử lại" |
| Lợi nhuận khác Thu Chi | Hai màn đang xem kỳ/quỹ khác nhau | Chọn cùng kỳ; Thu Chi xem "Tất cả" quỹ |
| "In báo cáo thất bại. Hãy chụp lại báo chủ app." | Lỗi tạo PDF / máy in | Thử lại hoặc lưu PDF |
| Không thấy nút Báo cáo chuỗi | Không phải Chủ quán | — |
| Không tìm thấy bill cũ ở tab Hóa đơn | Kỳ đang chọn không chứa ngày của bill | Chọn đúng ngày của bill |

## Liên quan module khác
- **Bán hàng / Quản lý Bàn / QR**: nguồn doanh thu.
- **Thu Chi**: nguồn tab Tài chính và chi phí.
- **Kho hàng**: phiếu nhập.
- **Quản lý Bàn**: nhật ký huỷ.
- **Chấm công**: tab Nhân viên.
- **Khách hàng**: tab Voucher.
- **Báo cáo chuỗi**: so sánh nhiều cửa hàng (Chủ quán).

## Ghi chú cho Chủ Quán (không đưa cho khách)

### Khác biệt với bản app cũ (cho Chủ Quán)
- "Tra cứu & in lại bill" chỉ có từ bản phát hành sau 22/10/2026. App cũ chỉ tải 500 bill mỗi kỳ — quán đông xem tháng có thể không thấy bill cũ; cập nhật app hoặc chọn kỳ ngắn hơn. Bản mới tải tối đa 20.000 bill/kỳ.
- App cũ tính trùng đơn trả bằng ví khi xem "Tất cả" (vừa khoản nạp ví vừa khoản bán bằng ví) — bản mới đã sửa.

1. **[SỬA 23/10 — app chưa phát hành]** Dòng thuế GTGT trong "Kết quả kinh doanh" trước ghi cố định **0đ** (dễ hiểu là đã tính, thuế bằng 0). Nay ghi **"2. Tiền thuế GTGT (app chưa tính)"** với giá trị **"—"**. App vẫn **không tính thuế**; "Tiền hàng" = toàn bộ doanh thu.
2. Tab Tài chính dựa trên Thu Chi nên kế thừa các lỗi số liệu đã ghi ở bài Thu Chi: ví tính hai lần ở "Tất cả" (đã sửa trong app mới 23/10, chưa phát hành), lương chưa tự ghi chi (chờ quyết). "Giá vốn NL" khi huỷ món: app bản mới (sau 23/10/2026, chưa phát hành) không ghi nữa; 58 phiếu cũ của Kay (ghi trùng thật) đã gạch bỏ trên production 23/10 (lưu ở `finance_record_deletions`, khôi phục được); 6 phiếu của 3 quán nhỏ đã khôi phục lại vì không phải ghi trùng.
3. Bàn bị đóng bằng nút "X" cũ (trước khi vá 22/10) **không có trong nhật ký Huỷ/Duyệt** vì không ghi audit — số "thất thoát do huỷ" của các kỳ trước có thể thấp hơn thực tế.
4. Quyền `report.view` không chặn tab nào trong màn Báo cáo — ai vào được là xem được mọi tab (kể cả doanh thu theo thu ngân, lợi nhuận). Nhưng nó **mở thêm** tab Báo cáo ở thanh điều hướng (`main.dart:1244,1275`) cho vai trò có quyền này dù không được giao module Báo cáo; Thu ngân luôn có tab này (fail-safe).
5. Tab Voucher tra cứu tên nhân viên bằng nhiều truy vấn nối tiếp; kỳ dài có thể chậm.
6. **[ĐÃ SỬA 23/10 — chưa phát hành]** Tra cứu bill trước giới hạn 500/kỳ; nay tải theo trang 1.000 tới `kBillLookupLimit = 20000`, bỏ dòng trùng nếu có bill mới vào giữa lúc tải. "Kết quả kinh doanh" trước chỉ cộng 1.000 phiếu Thu Chi (quán đông thiếu số) — đã sửa, xem `thu-chi.md` mục 2b.
