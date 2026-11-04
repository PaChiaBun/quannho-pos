---
module: bat_dau
ten: Bắt đầu dùng app
phien_ban: 1.0.6+24
cap_nhat: 2026-11-04
nguon:
  - lib/screens/dashboard_screen.dart (Trang chủ: "Chức năng", "Sửa" / "Xong", "Tắt module", "+ Thêm module")
  - .docs/Huong_dan/*.md (các bài module đã đối chiếu code — bài này chỉ là danh sách việc, chi tiết từng bước xem bài module)
  - .docs/Huong_dan/goi-tra-sua-mang-di.md (gói module gợi ý cho quán trà sữa mang đi)
  - lib/core/providers/app_providers.dart (dữ liệu 100% trên máy chủ: không có bán không mạng)
  - lib/screens/store_plan_notice.dart, supabase/migrations/20261027_quan_tri_dot1_ho_so_goi.sql (dùng thử 14 ngày, tự gia hạn 30 ngày)
  - lib/screens/settings_screen.dart ("Cài đặt hệ thống", bút chì sửa tên quán), lib/modules/bill_printer/screens/block_config_sheet.dart (ô "Tên quán")
---

# Bắt đầu dùng app

> Quán mới bắt đầu dùng app nên cài những gì trước, và nên bật module nào theo kiểu quán (mang đi, có bàn, có nhân viên chia ca). Mỗi việc ghi tên bài chi tiết để làm theo từng bước.

## Ai dùng được
- Chủ quán: cài được mọi thứ, bật / tắt module của quán.
- Quản lý: làm được phần lớn việc cài (món, máy in, khách hàng, voucher) tuỳ vai trò được cấp; không bật / tắt module.

## Màn hình gồm những gì
Trang chủ có phần "Chức năng": các ô module đang bật của quán ("… đang bật • Giữ ô để sắp xếp"). Chủ quán thấy nút "Sửa" để bật / tắt module. Mỗi module có bài hướng dẫn riêng; bài này chỉ chỉ ra nên làm việc nào trước.

## Các việc thường làm
### Mới tải, mới cài app xong: bắt đầu từ đâu, làm gì đầu tiên
1. Đăng ký hoặc đăng nhập bằng số điện thoại và mật khẩu (trên iPhone chỉ đăng nhập; tạo tài khoản ở Android, Web hoặc Windows).
2. Chưa có quán thì tạo quán; nhân viên của quán có sẵn thì nhập mã quán.
3. Thêm vài món và giá bán: ở Bán hàng, bấm nút dấu + trên thanh trên cùng.
4. Bán thử 1 đơn: ở Bán hàng, chạm món rồi bấm "Thanh toán".
5. Sau đó cài máy in và thêm nhân viên nếu cần (xem việc 1 ngay dưới).

### 1. Cài theo kiểu quán (quán mới nên làm gì trước)
**Việc cần làm trước (mọi quán):**
1. Thêm món và giá bán: bài Kho hàng, việc "Thêm món / nguyên liệu". Nhập luôn giá vốn mỗi món nếu biết để Báo cáo tính được lời.
2. Cài máy in bill: máy cầm tay Sunmi dùng "Thiết lập nhanh cho máy cầm tay (Sunmi)" (bài In Hoá Đơn); máy Windows dùng "Cài máy in trên máy Windows (lần đầu)".
3. Thêm nhân viên và gán vai trò: bài Nhân viên & Phân quyền, việc "Gán / đổi vai trò cho nhân viên".
4. Bán thử 1 đơn ở Bán hàng, in thử bill, rồi xem lại ở Báo cáo.

Lưu ý: Thu Chi tự ghi tiền bán hàng; tiền chi (nguyên liệu, mặt bằng, điện nước, lương) phải ghi phiếu chi thì Báo cáo và Bé Boom mới tính đúng thu − chi.

**Quán cà phê / trà sữa bán mang đi:**
1. Topping (trân châu, thạch…): bài Kho hàng, việc "Topping (trà sữa, cơm thêm…)".
2. Size, đường, đá: bài Kho hàng, việc "Tùy chọn món (Modifiers) và Ghi chú nhanh".
3. Tem dán ly cho đơn mang đi: bài In Hoá Đơn, việc "In tem dán ly".
4. Hết nguyên liệu tạm thời: bài Kho hàng, việc "Bật / tắt bán (hết món tạm thời)".
5. Quán chỉ bán mang đi thì KHÔNG cần Quản lý Bàn; có thể tắt module này (xem việc 7).

**Quán ăn / quán có bàn phục vụ tại chỗ:**
1. Khu vực và bàn: bài Quản lý Bàn, việc "Thiết lập khu vực và bàn (lần đầu)".
2. Khách tự gọi món bằng mã QR dán ở bàn: bài QR Gọi Món, việc "Bật QR và dán mã ở quán".
3. Có bếp / quầy pha riêng: dùng module Bếp; muốn đồ ăn in ra bếp, đồ uống in ra quầy bar thì bài In Hoá Đơn, việc "Thêm máy in" rồi "Tạo luật in".

**Quán có nhân viên chia ca:**
1. Chấm công bằng điện thoại: bài Chấm công, việc "Cài vị trí quán" (Chủ quán / Quản lý làm một lần), rồi nhân viên "Vào ca".
2. Trả lương theo giờ hoặc theo tháng: bài Lương, việc "Cấu hình lương (làm trước khi tạo kỳ)".
3. Việc mở cửa / đóng cửa mỗi ngày: bài Vận Hành, việc "Quản lý: tạo checklist" hoặc "Quản lý: nạp checklist mẫu".

**Muốn biết lời lỗ thật từng món:**
1. Ghi giá vốn khi thêm món (bài Kho hàng) — cách nhanh nhất.
2. Món pha chế / nấu từ nhiều nguyên liệu, muốn bán xong tự trừ kho: bài Kho Chuyên Nghiệp, việc "Chuẩn bị nguyên liệu (ở Kho hàng)" rồi "Tạo công thức món"; nồi nước dùng, cốt pha sẵn dùng "Bán thành phẩm".
3. Nhập hàng từ mối quen: bài Kho hàng, việc "Phiếu nhập hàng (nhiều món, có nhà cung cấp)"; cài mức tồn tối thiểu cho từng nguyên liệu để app báo sắp hết.

**Giữ khách quen:**
1. Lưu khách khi thanh toán để tích điểm: bài Khách hàng – Giảm giá – Khuyến mãi, việc "Thêm khách".
2. Đổi điểm lấy quà: việc "Phần thưởng đổi điểm".
3. Mã giảm giá: việc "Tạo mã giảm giá (voucher)". Khách nạp tiền trước vào ví: việc "Tạo gói nạp".

### 2. Bật / tắt module trên Trang chủ (Chủ quán)
1. Ở Trang chủ, phần "Chức năng", bấm "Sửa".
2. Muốn tắt module không dùng: nhấn dấu "–" trên ô module → "Tắt module". Dữ liệu được giữ nguyên, bật lại lúc nào cũng được.
3. Muốn bật thêm: bấm "+ Thêm module" và chọn module.
4. Bấm "Xong" để lưu.

> Lưu ý: tắt module là tắt cho cả quán — nhân viên cũng không thấy module đó nữa. Nhân viên không có nút "Sửa" (thấy "Nhân viên không có quyền chỉnh sửa").

### 3. Mất mạng có bán được không
Không. App cần mạng (wifi hoặc 4G) mới bán được, vì đơn được ghi lên máy chủ; app chưa có chế độ bán không mạng.
1. Cúp wifi: bật 4G trên máy hoặc phát mạng từ điện thoại khác rồi bán tiếp.
2. Đang thanh toán thì mất mạng: đừng bán lại đơn đó. Có mạng thì làm theo bài Bán hàng, việc "Đối soát thanh toán bị gián đoạn"; app không thu hai lần.
3. Mất mạng lâu: ghi đơn ra giấy, có mạng thì nhập lại vào app. Đơn nhập lại mang giờ lúc nhập.

### 4. Đổi máy mới, đổi điện thoại, cài lại app: dữ liệu có mất không, có phải nhập lại món không
Không mất. Món, đơn, báo cáo, nhân viên nằm trên máy chủ, không nằm trong điện thoại, nên đổi máy, máy hư hay cài lại app đều còn nguyên.
1. Cài app trên máy mới, đăng nhập đúng số điện thoại và mật khẩu cũ. Quên mật khẩu: bài Nhân viên & Phân quyền, việc "Quên mật khẩu khi chưa đăng nhập được".
2. Máy mới có in bill: chọn lại ở "Máy này in bill ra" rồi bấm "Lưu" (bài In Hoá Đơn).
3. Máy cũ đang làm máy chủ in: trên máy mới bấm "Chuyển máy chủ sang thiết bị này" (bài In Hoá Đơn, việc "Máy chủ in").

### 5. App có mất phí không, giá bao nhiêu, dùng thử và gia hạn
Quán mới được dùng thử 14 ngày.
1. Còn 3 ngày hoặc đã hết hạn, Trang chủ hiện dải nhắc cho Chủ quán.
2. Bấm "Gia hạn thêm 30 ngày" trên dải nhắc để dùng tiếp miễn phí.
3. Hỏi giá hoặc gói của quán: gọi Hotline 0927 55 8888.

### 6. Đổi, sửa tên quán (tên cửa hàng) in trên hoá đơn, bill
1. Tên trên hoá đơn: mở In Hoá Đơn → "Thiết Kế Mẫu In" → tab "Hoá Đơn" → khối "Tên quán" → gõ vào ô "Tên quán" → "Lưu".
2. Muốn thêm logo: xem bài In Hoá Đơn, việc "Thiết kế mẫu in".
3. Tên ở Cài đặt: Trang chủ → ô tròn góc trên bên phải → "Cài đặt hệ thống" → nút bút chì cạnh tên quán → sửa → "Lưu thay đổi". Tên trên Trang chủ không đổi theo cách này; cần đổi thì gọi Hotline 0927 55 8888.

## Lỗi thường gặp
| Thấy gì trên màn hình | Vì sao | Làm gì |
|---|---|---|
| Không thấy nút "Sửa" ở phần "Chức năng" | Chỉ Chủ quán bật / tắt được module | Nhờ Chủ quán làm |
| "Module Kho đang tắt" ở Báo cáo | Module Kho hàng đã bị tắt | Chủ quán bật lại bằng "Sửa" → "+ Thêm module" |

## Liên quan module khác
- Kho hàng, In Hoá Đơn, Nhân viên & Phân quyền, Quản lý Bàn, QR Gọi Món, Chấm công, Lương, Vận Hành, Kho Chuyên Nghiệp, Khách hàng – Giảm giá – Khuyến mãi, Thu Chi.

## Ghi chú cho Chủ Quán (không đưa cho khách)
- Bài này phần lớn chỉ dẫn sang bài module; khi đổi tên việc trong bài module thì sửa tên ở đây theo.
- Việc 5 cố ý không ghi giá gói: gói tin này đi cả vào app App Store / CH Play, nơi không được hiện giá hay đường dẫn trả tiền (`billing_platform.dart`).
- Việc 6 mô tả app đang phát hành: bút chì chưa đổi tên trên Trang chủ. Mã nguồn đã sửa (04/11), chờ bản app kế tiếp. Khi phát hành bản đó: sửa việc 6 thành "bút chì đổi tên ở mọi nơi" rồi đăng lại gói; đăng sớm thì app cũ sẽ nghe sai.
