---
module: bat_dau
ten: Bắt đầu dùng app
phien_ban: 1.0.6+24
cap_nhat: 2026-11-04
nguon:
  - lib/screens/dashboard_screen.dart (Trang chủ: "Chức năng", "Sửa" / "Xong", "Tắt module", "+ Thêm module")
  - .docs/Huong_dan/*.md (các bài module đã đối chiếu code — bài này chỉ là danh sách việc, chi tiết từng bước xem bài module)
  - .docs/Huong_dan/goi-tra-sua-mang-di.md (gói module gợi ý cho quán trà sữa mang đi)
---

# Bắt đầu dùng app

> Quán mới bắt đầu dùng app nên cài những gì trước, và nên bật module nào theo kiểu quán (mang đi, có bàn, có nhân viên chia ca). Mỗi việc ghi tên bài chi tiết để làm theo từng bước.

## Ai dùng được
- Chủ quán: cài được mọi thứ, bật / tắt module của quán.
- Quản lý: làm được phần lớn việc cài (món, máy in, khách hàng, voucher) tuỳ vai trò được cấp; không bật / tắt module.

## Màn hình gồm những gì
Trang chủ có phần "Chức năng": các ô module đang bật của quán ("… đang bật • Giữ ô để sắp xếp"). Chủ quán thấy nút "Sửa" để bật / tắt module. Mỗi module có bài hướng dẫn riêng; bài này chỉ chỉ ra nên làm việc nào trước.

## Các việc thường làm
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

## Lỗi thường gặp
| Thấy gì trên màn hình | Vì sao | Làm gì |
|---|---|---|
| Không thấy nút "Sửa" ở phần "Chức năng" | Chỉ Chủ quán bật / tắt được module | Nhờ Chủ quán làm |
| "Module Kho đang tắt" ở Báo cáo | Module Kho hàng đã bị tắt | Chủ quán bật lại bằng "Sửa" → "+ Thêm module" |

## Liên quan module khác
- Kho hàng, In Hoá Đơn, Nhân viên & Phân quyền, Quản lý Bàn, QR Gọi Món, Chấm công, Lương, Vận Hành, Kho Chuyên Nghiệp, Khách hàng – Giảm giá – Khuyến mãi, Thu Chi.

## Ghi chú cho Chủ Quán (không đưa cho khách)
- Bài này không có bước bấm riêng; từng bước nằm ở bài module. Khi đổi tên việc trong bài module thì sửa tên ở đây theo.
