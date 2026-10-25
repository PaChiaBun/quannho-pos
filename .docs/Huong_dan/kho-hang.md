---
module: kho
ten: Kho hàng
phien_ban: 1.0.5+20
cap_nhat: 2026-10-23
nguon:
  - lib/screens/inventory_screen.dart (danh sách, form món, topping, điều chỉnh, lịch sử)
  - lib/modules/kho/screens/receive_stock_sheet.dart, phieu_nhap_hang_screen.dart, po_detail_screen.dart, supplier_list_screen.dart, supplier_form_screen.dart
  - lib/modules/kho/repository/kho_repository.dart (trạng thái tồn, nhập, huỷ phiếu, giá vốn)
  - lib/modules/quick_notes/quick_notes.dart; ModifierManagerSheet trong lib/screens/ban_screen.dart
  - lib/core/providers/app_providers.dart (posProductsProvider); supabase/migrations/20261013_qr_order_simple_v4.sql (QR lọc is_available)
---

# Kho hàng

> Nơi quản lý **thực đơn và hàng hoá** của quán: thêm/sửa món, giá bán, giá vốn, ảnh, topping, bật/tắt bán; theo dõi tồn kho, nhập hàng, điều chỉnh, phiếu nhập từ nhà cung cấp.

## Ai dùng được
- Người có module **Kho hàng** (module mặc định bật cho quán). Quán mới tạo, các vai trò có sẵn (Thu ngân, Nhân viên, Bếp) đều **chưa** có module này — Chủ quán, Quản lý dùng được; Chủ quán thêm module cho vai trò bất kỳ ở **Nhân viên → Vai trò** (mẫu gợi ý "Bếp", "Kho hàng" khi tạo vai trò mới có sẵn Kho hàng).
- **Xoá món**, **bật/tắt bán hàng loạt**, **đổi danh mục hàng loạt**: cần quyền **"Xoá sản phẩm kho"**. Quyền này **đi kèm module Kho hàng**, nên mặc định mọi người có module Kho đều làm được — Chủ quán muốn chặn thì tắt "Xoá sản phẩm kho" cho vai trò đó trong Hành động nhạy cảm.
- Các thao tác khác (thêm/sửa món, nhập kho, điều chỉnh tồn): ai vào được module đều làm được (xem Ghi chú cho Chủ Quán).

## Màn hình gồm những gì
- **Đầu trang "Kho hàng"**: thống kê **"Sản phẩm"**, **"Sắp hết"**, **"Hết hàng"**, **"Giá trị kho"** (tồn × giá nhập gần nhất). Các nút:
  - **"Biến động kho gần đây"** — xem nhập/xuất mới nhất.
  - **"Ghi chú nhanh"** — cài chip ghi chú (Ít cay, Ít đá…) hiện khi gọi món ở **Quản lý Bàn**.
  - **Bật/tắt phiếu nhập nâng cao** — hiện thêm tab "Phiếu nhập".
  - **"Thêm sản phẩm"**.
- **Các tab**: **"Hàng hoá & Menu"** và **"Cảnh báo"** (sắp hết + hết hàng). Khi **bật phiếu nhập nâng cao** có thêm **"Tất cả"**, **"Nguyên liệu"**, **"Phiếu nhập"**; lúc đó "Hàng hoá & Menu" chỉ còn món bán (chưa bật thì tab này hiện mọi mặt hàng).
- **Ô tìm "Tìm sản phẩm, SKU..."**, lọc theo danh mục, nút **"Chọn"** để chọn nhiều món.
- Mỗi món hiện: tên, danh mục, **tồn / min**, giá bán, trạng thái **"Đang bán" / "Tạm ngưng bán"**, nhãn tồn:
  - **"Hết hàng"** — có đặt tồn tối thiểu và tồn ≤ 0 (màn Bán hàng khoá món này).
  - **"Sắp hết"** — tồn ≤ mức tối thiểu.
  - **"Còn hàng"**.
  - **"Không theo dõi"** — món không đặt tồn tối thiểu (dù tồn âm vẫn bán được).
- Menu **"Thao tác"** của từng món: **"Sửa thông tin món"**, **"Nhập kho"**, **"Điều chỉnh tồn kho"**, **"Lịch sử xuất nhập"**, **"Cấu hình Topping"**, **"Tùy chọn món (Modifiers)"**, **"Xóa món"**.

## Các việc thường làm

### 1. Thêm món / nguyên liệu
1. Bấm **"Thêm sản phẩm"** → **"Thêm sản phẩm mới"**.
2. Điền:
   - **"Tên sản phẩm *"**.
   - **"Giá bán (đ) *"** (nguyên liệu thì không bắt buộc), **"Giá vốn (đ)"**.
   - **"Tồn tối thiểu (cảnh báo)"** — để 0 nếu không cần theo dõi tồn.
   - **"Bộ phận chế biến"**: **Bếp Nóng**, **Bếp Bar** hoặc **Thu Ngân** — quyết định phiếu in ra trạm nào (không phụ thuộc danh mục). Món thêm nhanh từ màn Bán hàng (nút dấu +) mặc định Bếp Nóng — đồ uống nhớ sửa lại thành Bếp Bar.
   - **"Danh mục"**: Đồ ăn, Đồ uống, Tráng miệng, Combo, **Nguyên liệu**, hoặc **"Thêm"** danh mục riêng.
   - **"Đơn vị"**: phần, ly, tô, cái, hộp, lon, chai, gói, kg, g, ml, lít.
   - **"Ảnh sản phẩm"**: **"Thư viện"**, **"Camera"** hoặc **"Tìm ảnh từ Cook.ai.vn"**.
3. Bấm **"Thêm sản phẩm"**.

> Chọn danh mục **"Nguyên liệu"** thì món nằm ở tab Nguyên liệu (khi đã bật phiếu nhập nâng cao) và **không hiện** ở màn Bán hàng (trừ khi có giá bán). Danh mục khác nằm ở tab Hàng hoá & Menu.

### 2. Topping (trà sữa, cơm thêm…)
1. Tạo topping như một sản phẩm: chọn chip **"Topping"**, đặt giá và **"Đơn vị topping"** (viên, phần, ml, g, muỗng, thìa).
2. Gắn topping vào món: ở món chính chọn **"Cấu hình Topping"** → chạm topping để **"Đã gắn"**; hoặc ở topping dùng mục **"🍜 Gắn vào món"**.
3. Topping hiện khi gọi món ở **Quản lý Bàn** và khi khách gọi qua **QR**. **Màn Bán hàng (quầy) chưa có topping.**

### 3. Tùy chọn món (Modifiers) và Ghi chú nhanh
- **"Tùy chọn món (Modifiers)"** → **"Cài đặt tùy chọn món"**: thêm dòng gồm **Nhóm**, **Tên tùy chọn**, **+Giá**. Ví dụ: Nhóm "Mức cay" → "Cấp độ 2" → 0đ; Nhóm "Thêm món" → "Thêm Mực" → 15.000đ. Nhân viên bấm chọn khi order ở Quản lý Bàn, không cần gõ.
- **"Ghi chú nhanh"** (nút trên đầu trang): bộ chip ghi chú cho món; món chưa gán dùng bộ mặc định theo loại đồ ăn / đồ uống.

### 4. Quy cách pha chế (mua theo lon/hộp, trừ theo ml/g)
Với nguyên liệu mua theo đơn vị lớn mà công thức dùng theo ml/g (vd sữa đặc 1 lon = 385 g):
1. Sửa nguyên liệu → mục **"Quy cách pha chế (Dung tích / Khối lượng)"**.
2. Nhập **"1 <đơn vị> = <số> ml/g"**.
3. Lưu. Công thức ở Kho Chuyên Nghiệp sẽ trừ kho đúng theo quy đổi.

### 5. Bật / tắt bán (hết món tạm thời)
1. Bấm **"Chọn"** → chọn các món → **"Tắt bán"** (hoặc **"Bật bán"**).
2. Món tắt bán hiện **"Tạm ngưng bán"**:
   - **QR**: khách **không thấy** món.
   - **Quản lý Bàn**: món có nhãn **"TẠM HẾT"**; nhân viên chọn sẽ được hỏi **"Món tạm hết"** → **"Vẫn thêm"** nếu chắc chắn còn.
   - **Bán hàng (quầy)**: món mờ, nhãn **"Tạm ngưng"**, bấm vào báo "<món> đang tạm ngưng bán" và **không thêm được**.

### 6. Nhập kho nhanh một món
1. Menu món → **"Nhập kho"** → bảng **"Nhập hàng"**.
2. Nhập số lượng, đơn giá nhập, chọn NCC (tuỳ chọn), chọn **"Trả bằng: Tiền mặt / Chuyển khoản"** → lưu.
3. Kết quả: tồn tăng, giá nhập gần nhất được cập nhật, **Thu Chi tự ghi một khoản chi** "Nhập hàng: <tên>" vào **đúng quỹ đã chọn**.

### 7. Phiếu nhập hàng (nhiều món, có nhà cung cấp)
1. Bật phiếu nhập nâng cao (nút trên đầu trang) → tab **"Phiếu nhập"** → **"Tạo phiếu"**.
2. Màn **"Phiếu nhập hàng"**: **"Thêm sản phẩm"** (tìm món, thấy tồn hiện tại), nhập **"Số lượng"**, **"Đơn giá nhập"** (có gợi ý giá lần trước), xem **"= Thành tiền"**; chọn nhà cung cấp, **"Trả bằng: Tiền mặt / Chuyển khoản"**, **"Ngày nhập hàng"**, ghi chú, ảnh hoá đơn.
3. Bấm **"XÁC NHẬN"** → "Nhập hàng thành công — N sản phẩm".
4. Kết quả: tồn tăng; **giá vốn tính lại theo bình quân**; Thu Chi ghi **một khoản chi** "Nhập hàng <số phiếu> — <NCC>" vào quỹ đã chọn.
5. Xem lại: tab Phiếu nhập lọc **Tất cả / Hôm nay / Tuần này / Tháng**, theo NCC, hoặc **"Đã huỷ"**. Chạm **"Xem chi tiết"**.
6. **"Chỉnh sửa phiếu"**: chỉ sửa ghi chú, nhà cung cấp, ảnh hoá đơn — **kho và tài chính không đổi**.
7. **Huỷ phiếu**: **"Huỷ phiếu nhập?"** → lý do (không bắt buộc) → **"Huỷ phiếu"**. Hệ thống trừ lại tồn và ghi một khoản **thu** "Huỷ nhập hàng …" để hoàn tiền về đúng quỹ. Không huỷ được nếu tồn hiện tại không đủ để trừ lại.
8. **Nhà cung cấp**: mục **"Quản lý nhà cung cấp"** → **"Thêm NCC"**, sửa, xoá.

### 8. Điều chỉnh tồn (kiểm kho, hư hỏng)
1. Menu món → **"Điều chỉnh tồn kho"**.
2. Chọn **"− Xuất kho"** hoặc **"+ Thêm vào"**, nhập số lượng.
3. Lý do: **"Điều chỉnh tồn kho"**, **"Hao hụt"**, **"Hư hỏng"**, **"Chuyển kho"**.
4. **"Xác nhận"**. Điều chỉnh **không** ghi thu chi.

### 9. Xem lịch sử một món
- Menu món → **"Lịch sử xuất nhập"** → **"Lịch sử biến động"**: từng lần nhập, bán, điều chỉnh, huỷ, kèm thời gian và ghi chú.

### 10. Xoá món, đổi danh mục hàng loạt
- **"Xóa món"** (hoặc chọn nhiều → **"Xóa (N) món"**) → **"Xác nhận xóa"**. Món chuyển sang trạng thái đã xoá; **doanh thu và hoá đơn cũ vẫn giữ**.
- Chọn nhiều → **"Đổi danh mục"** → chọn danh mục có sẵn hoặc **"Nhập danh mục mới"** → **"Cập nhật"**.

## Tồn kho tự thay đổi khi nào
| Việc | Tồn | Thu Chi |
|---|---|---|
| Thanh toán bán hàng (quầy, bàn, QR mang đi) | Trừ (theo công thức nếu có) | Thu |
| Gửi bếp | **Không** trừ | — |
| Nhập kho / Phiếu nhập | Cộng | Chi |
| Huỷ phiếu nhập | Trừ lại | Thu hoàn |
| Điều chỉnh tồn | Cộng/trừ | — |
| Huỷ món bếp **đang làm / đã xong** ở Quản lý Bàn (công tắc "Trừ kho nguyên liệu (hao hụt)" **bật sẵn**) | Trừ nguyên liệu theo công thức (hao hụt) | — (không ghi Thu Chi) |
| Huỷ món bếp đang làm / đã xong, người huỷ **tắt** "Trừ kho nguyên liệu (hao hụt)" | Không đổi | — |
| Huỷ món mới gửi, bếp **chưa làm** | Không đổi | — |
| Xoá món **chưa gửi bếp** | Không đổi | — |

## Lỗi thường gặp
| Thấy gì | Vì sao | Làm gì |
|---|---|---|
| Món mờ "Hết" ở Bán hàng, không bấm được | Món có tồn tối thiểu và tồn ≤ 0 | Nhập kho hoặc điều chỉnh tồn |
| Tồn âm | Bán món không đặt tồn tối thiểu (không khoá) | Kiểm kho, điều chỉnh tồn |
| "… chỉ còn N — không đủ để hoàn kho M" khi huỷ phiếu | Hàng đã bán bớt | Điều chỉnh tồn trước, hoặc không huỷ phiếu |
| Phiếu bếp in sai trạm | "Bộ phận chế biến" của món chưa đúng (món thêm nhanh ở Bán hàng mặc định Bếp Nóng) | Sửa món, chọn Bếp Nóng / Bếp Bar |
| "Không tìm thấy ảnh phù hợp trong thư viện" | Cook.ai không có ảnh món đó | Chụp hoặc chọn ảnh từ máy |
| "Gắn topping thất bại. Hãy chụp lại báo chủ app." | Lỗi mạng/máy chủ | Thử lại |
| "Không thể kết nối máy chủ (Máy chủ bận hoặc lỗi mạng). Vui lòng thử lại." | Mạng chập chờn | Thử lại sau |

## Liên quan module khác
- **Bán hàng / Quản lý Bàn / QR Gọi Món**: lấy thực đơn, giá, ảnh, topping, trạng thái bán từ đây.
- **Thu Chi**: nhập hàng ghi chi, huỷ phiếu ghi thu hoàn.
- **Kho Chuyên Nghiệp**: công thức món (định lượng nguyên liệu), trừ kho theo công thức.
- **In Hoá Đơn**: "Bộ phận chế biến" quyết định phiếu bếp nóng / bếp bar.
- **Báo cáo → Kho**: giá trị kho, cảnh báo.

## Ghi chú cho Chủ Quán (không đưa cho khách)

### Khác biệt với bản app cũ (cho Chủ Quán)
- App cũ hiện "Hết hàng" cho món "Không theo dõi" khi tồn ≤ 0.
- App cũ chưa chặn món "Tạm ngưng bán" ở màn Bán hàng (quầy) — đã "Tắt bán" mà quầy vẫn bán được thì máy đó còn app cũ, cần cập nhật app.
- App cũ không có lựa chọn "Trả bằng: Tiền mặt / Chuyển khoản" khi nhập kho / phiếu nhập — khoản chi luôn ghi vào quỹ Tiền mặt.
- App cũ: huỷ món bếp đang làm / đã xong (món có công thức) ghi thêm khoản chi "Giá vốn NL" vào Thu Chi; bản mới chỉ trừ kho. Trước bản 22/10/2026, huỷ món mới gửi (bếp chưa làm) vẫn có thể trừ kho.

1. **"Tắt bán" mỗi nơi xử lý một kiểu**: QR ẩn món; Bàn chỉ cảnh báo "TẠM HẾT" và cho "Vẫn thêm" (chờ Chủ Quán quyết có khoá hẳn không); **Bán hàng: [ĐÃ SỬA trong app 23/10 — chưa phát hành]** khoá món tạm ngưng như `qn.md`. Máy chủ (`complete_pos_sale_v1`) chưa chặn món tạm ngưng.
2. **[ĐÃ SỬA trong app 23/10 — chưa phát hành]** Nhập hàng từng luôn ghi quỹ Tiền mặt — nay "Nhập kho" và "Phiếu nhập hàng" có chọn "Trả bằng: Tiền mặt / Chuyển khoản" (`buildPurchaseFundPicker`, `receiveStock(fundType:)`); huỷ phiếu hoàn về đúng quỹ cũ.
3. **Quyền sửa kho chưa được áp dụng**: `kho.edit_item` / `kho.edit_quantity` được kiểm trong code nhưng không chặn nút nào — ai có module đều sửa giá, điều chỉnh tồn được. Xoá và thao tác hàng loạt kiểm `kho.delete_item` ("Xoá sản phẩm kho"), nhưng `deriveActionPermsFromModules` cấp quyền này cho mọi vai trò có module `kho`/`kho_pro` → thực tế Thu ngân, Thủ kho đều xoá được trừ khi Chủ quán tắt.
4. **Nhóm topping** (`_ToppingGroupTab`: tên nhóm, chọn tối thiểu/tối đa, áp dụng cho nhiều món) đã viết nhưng **không có lối vào** trong app.
5. **Tùy chọn món (Modifiers)** và **Ghi chú nhanh** chỉ dùng ở Quản lý Bàn; màn Bán hàng dùng danh sách ghi chú cố định riêng.
6. **[ĐÃ SỬA trong app 23/10 — chưa phát hành]** Món không đặt tồn tối thiểu luôn "Không theo dõi" (trước: tồn ≤ 0 hiện "Hết hàng" trong khi quầy vẫn bán). `StockItem.status` kiểm `minStock` trước; số đếm tab "Cảnh báo" và ô "Hết hàng" cũng chỉ tính món có tồn tối thiểu (trước đây tab "Cảnh báo" còn đếm trùng hết hàng + sắp hết).
7. Vai trò mặc định: quán mới được tạo sẵn Thu ngân `["pos","ban","report"]`, Nhân viên `["ban"]`, Bếp `["kitchen","ban"]` (`store_auth_service.dart` `seedDefaults`) → không vai trò có sẵn nào có `kho`. `kDefaultPerms` (cashier, stock có `kho`) chỉ dùng khi không có dòng vai trò khớp. Mẫu tạo vai trò (`role_manager_screen.dart`): "Bếp" và "Kho hàng" có `kho`, "Thu ngân" không. Bài cũ ghi "Thu ngân, Thủ kho có sẵn" — sai với quán mới.
8. Tab "Tất cả" và "Nguyên liệu" chỉ hiện khi bật phiếu nhập nâng cao (`inventory_screen.dart` ~777–790).
- **[SỬA 23/10 — chưa phát hành] Lỗi giới hạn 1.000 dòng:** máy chủ chỉ trả 1.000 dòng mỗi lần đọc; màn này trước đây đọc cả bảng của quán rồi lọc ở máy → quán lớn (KAY) nhận toàn dòng cũ. "Lịch sử nhập xuất" và lịch sử từng món của KAY (20.709 phiếu kho) chỉ nhận phiếu tới 15/9 (hôm 23/10 thực có 162 phiếu). Nay lấy phiếu mới nhất ở máy chủ.
