---
module: report
ten: Báo cáo
phien_ban: 1.0.5+20
cap_nhat: 2026-10-31
nguon:
  - lib/screens/report_screen.dart (8 tab: Doanh thu, Sản phẩm, Tài chính, Kho, Huỷ/Duyệt, Nhân viên, Voucher, Hóa đơn)
  - lib/core/repositories/dashboard_repository.dart (get_report_stats/daily_revenue/top_products_for_range_v1)
  - lib/screens/einvoice_report_tab.dart, lib/screens/bill_lookup_section.dart (tab Hóa đơn)
  - supabase/migrations/20261104_topping_bao_cao_v1.sql (Top sản phẩm / danh mục đã bán tách topping chọn kèm món)
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
- Nhân viên nào bán nhiều nhất: xem **"Doanh thu theo thu ngân"** ở tab này.
- Xem hôm nay, hôm qua, tháng trước bán được bao nhiêu: mở Báo cáo, tab Doanh thu, chọn kỳ. Trang chủ cũng có "DOANH THU HÔM NAY" cho Chủ quán, Quản lý. Ở Bán hàng, "Đơn gần đây" cũng có tổng hôm nay cho Chủ quán và Quản lý.
- Thẻ **"Tổng doanh thu …"** (ghi đúng kỳ đang xem: "tháng này", "tháng 10/2026", "tuần 26/10–01/11"): số đơn, TB/đơn.
- Biểu đồ **"Doanh thu theo giờ"** (hôm nay) hoặc **"Doanh thu theo ngày"** (tuần/tháng; biểu đồ tháng ghi số ngày dưới cột: 1, 9, 17, 25, 30).
- **"Tóm tắt kỳ này"**: Doanh thu, Số đơn, TB/đơn.
- **"Theo phương thức thanh toán"** (tiền mặt, chuyển khoản, thẻ, tỷ trọng).
- **"Doanh thu theo thu ngân"** (mỗi người: tiền mặt / chuyển khoản / thẻ).
- **"Số bàn phục vụ theo nhân viên"**.
- **"Tổng hợp bán hàng theo ngày"**: bảng Ngày, Số đơn, Doanh thu, Tiền mặt, Chuyển khoản, Khuyến mại.
- Nút **"In báo cáo"**: in/lưu PDF "BÁO CÁO DOANH THU …" (tóm tắt, phương thức thanh toán, theo thu ngân, chi tiết từng ngày).

> Doanh thu tính trên **đơn đã thanh toán** (bán quầy, thanh toán bàn, QR mang đi).

### Sản phẩm
- Món nào bán chạy, lời nhiều nhất coi ở đây: tab này xếp theo doanh thu, chưa xếp theo tiền lời. Muốn xem % lãi từng món: Kho Chuyên Nghiệp, phần Công thức.
- Lọc theo danh mục; **"Top sản phẩm bán chạy"**: số phần, giá trung bình/phần, doanh thu; xếp theo doanh thu, thanh màu dưới mỗi món dài theo doanh thu.
- Topping chọn kèm món cũng có dòng riêng; lọc **"Topping"** để xem riêng.

### Tài chính
- Xem quán lời hay lỗ theo kỳ: thẻ **"LỢI NHUẬN"** / **"ĐANG LỖ"**: Thu nhập, Chi phí, Biên LN.
- **"Kết quả kinh doanh"**: I. Doanh thu từ bán hàng (Tiền hàng; dòng "Tiền thuế GTGT (app chưa tính)" hiện "—" vì app không tính thuế) – II. Chi phí (theo danh mục) – III. Lợi nhuận (I − II), kèm cột **"%"** (tỷ trọng so với doanh thu, ghi kiểu "56,2%"; chưa có thu ghi "—").
- Nhận xét tăng/giảm so với kỳ trước ("Thu nhập tăng X% so với kỳ trước"); kỳ chưa hết thì so cùng khoảng giờ của kỳ trước (1 giờ sáng so với 0:00–1:00 hôm qua), không báo "giảm 100%" mỗi sáng.

> Số liệu lấy từ **Thu Chi** — mọi lưu ý của Thu Chi áp dụng ở đây (ví dụ lương phải ghi tay mới vào chi phí; đơn trả bằng ví không tính vào sổ Thu Chi vì tiền đã ghi thu lúc nạp ví).

### Kho
- Cần bật module Kho ("Module Kho đang tắt — Bật module Kho trong Cài đặt để xem báo cáo nhập hàng").
- **"Nhập hàng <kỳ>"**: số phiếu nhập; **"Sản phẩm nhập nhiều nhất"**.

### Huỷ/Duyệt
- Xem lịch sử huỷ món / huỷ bàn / huỷ hoá đơn và ai duyệt. **"Nhật ký hủy / duyệt"**: tổng tiền thất thoát do huỷ trong kỳ (ghi đúng kỳ đang xem: "hôm nay", "hôm qua" hoặc ngày cụ thể), số lượt huỷ "được kiểm toán".
- Mỗi dòng: **Huỷ bàn / Huỷ hoá đơn / Huỷ món**, người **yêu cầu**, người **duyệt**, **lý do**, số tiền.
- Chạm **"Nhấn để xem chi tiết món huỷ (N)"**: từng món, số lượng, đơn giá, **"Đã trừ hao hụt"** / **"Không trừ kho"**, **"Tổng tiền huỷ"**.

### Nhân viên
- Tổng **Ca làm**, **Giờ công**, **Đi trễ**, **Lệch vị trí**.
- Từng người: số ca, số giờ, nhãn **"🕒 N trễ"**, **"⚠️ N ca lệch"**, **"📍 N ko GPS"** hoặc **"✓ Đầy đủ"**.

### Voucher
- Xem voucher / mã giảm giá đã dùng: số lần dùng là **Tổng đơn áp mã**, **Tổng tiền giảm**; danh sách theo mã: Mã đơn / Bàn, Nhân viên, Thời gian, Giảm giá.

### Hóa đơn
- Khách nói tính dư, tính thiếu tiền: tra đúng bill ở đây xem từng món và số tiền.
- Kỳ **"Hôm nay"** có thanh ‹ › để lùi về hôm qua hoặc chạm vào ngày để chọn (sau 0 giờ vẫn in lại được bill tối qua). Từ Bán hàng › "Đơn gần đây" (hôm nay chưa có đơn), nút "Xem bill hôm qua" mở thẳng tab này ở ngày hôm qua.
- **"Tra cứu & in lại bill"**: tìm bill đã thanh toán theo số đơn, tên bàn (không cần dấu) hoặc số tiền; chạm để xem chi tiết (bảng mở ngay, món giống nhau gộp một dòng, có topping); nút máy in để **in lại** (bill có dòng "BẢN IN LẠI", có topping, món giống nhau gộp một dòng, ghi nhật ký người in). Màn này tải đủ bill trong kỳ đang chọn (tối đa 20.000 bill); không thấy bill thì chọn đúng ngày của bill.

## Lỗi thường gặp
| Thấy gì | Vì sao | Làm gì |
|---|---|---|
| "Chưa có giao dịch hôm nay" / "Chưa có doanh thu kỳ này" | Chưa có đơn đã thanh toán | Kiểm tra kỳ đang chọn |
| "Module Kho đang tắt" | Chưa bật Kho | Bật module Kho |
| "Không tải được nhật ký kiểm toán" / "Không tải được dữ liệu kho" | Mạng / máy chủ | Bấm "Thử lại" |
| Lợi nhuận khác Thu Chi | Hai màn đang xem kỳ/quỹ khác nhau | Chọn cùng kỳ; Thu Chi xem "Tất cả" quỹ |
| "In báo cáo thất bại. Hãy chụp lại báo chủ app." | Lỗi tạo PDF / máy in | Thử lại hoặc lưu PDF |
| Không thấy nút Báo cáo chuỗi | Không phải Chủ quán | — |
| Nhân viên không thấy nút, ô Báo cáo | Vai trò chưa có module Báo cáo | Chủ quán thêm module ở "Tạo / sửa vai trò" |
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
7. **[ĐÃ SỬA 04/11 — CHỜ ÁP DB] Topping chọn kèm món không được đếm.** Topping chọn ở "Tùy chọn" (Bàn, QR) nằm trong `order_items.modifiers_json` của dòng món, không thành dòng đơn riêng; `get_top_products_for_range_v1`, `get_sold_categories_for_range_v1` và `boom_sales_raw_v1` chỉ cộng dòng đơn → trân châu chỉ được đếm khi bán lẻ ở quầy (báo thiếu), tiền topping cộng vào món chính (quán demo 03/11: Trà đào 6 phần 215.000 đ, TB 35.833 đ/phần; đúng là 210.000 đ + trân châu 1 phần 5.000 đ), bộ lọc không có "Topping". Migration `20261104_topping_bao_cao_v1.sql` tách mỗi topping thành dòng riêng (bàn: `qty` = tổng dòng; QR: `quantity` × số món — cùng cách trừ kho), tiền = giá × số phần, trừ khỏi món chính (tổng không đổi); đơn cũ còn lưu topping nên số các kỳ trước cũng đúng lại. App (đường dự phòng khi gọi máy chủ lỗi, bộ lọc danh mục, Boom trên máy) tính cùng cách (`toppingSales` trong `string_utils.dart`). Bản sao cục bộ: bản cũ test FAIL (Trà 235.000), bản mới PASS; 50.000 dòng món chạy ~0,13 giây (cũ ~0,05). Áp: Chủ Quán chạy `db-fix/topping_bao_cao_ap_dung.sh` (`DRYRUN=1` để thử). QC 04/11: đơn QR thật (`qr_price_items_v4` dựng lại) ghi topping `{"id","price","quantity"}` KHÔNG có "type" — bản đầu lọc `type = 'topping'` nên vẫn sót topping QR; nay nhận cả dạng có "quantity" (tuỳ chọn hương vị không có cả hai), bước lọc nhanh đổi từ chữ "topping" sang khoá "id"; test dùng đúng dạng QR thật.
