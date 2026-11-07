# Kế hoạch: Topping và Giảm giá tay ở màn Bán hàng (POS quầy)

> Lập 23/10/2026 theo yêu cầu Chủ Quán. Chưa làm — chờ duyệt từng phần.

## Hiện trạng (đã kiểm code + máy chủ)

### Topping
- **Quản lý Bàn** và **QR khách** đã có topping:
  - Liên kết món ↔ topping ở bảng `product_topping_links` (Kho hàng → món → "Topping").
  - Bàn chọn bằng `_ToppingPickerSheet` (`lib/screens/ban_screen.dart`), lưu vào `ban_session_items.modifiers_json`, giá dòng đã cộng topping.
  - Khi thanh toán bàn, `settle_ban_session_v5` chép `modifiers_json` sang `order_items`.
- **Bán hàng (quầy)** chưa có:
  - Dòng giỏ (`CartLine`) không có topping.
  - Máy chủ `complete_pos_sale_v1` **tự tính lại giá theo `products.sell_price`**, không nhận topping. Nếu app gửi giá đã cộng topping, máy chủ báo "Giá món đã đổi".
- Hiện quán đang bán topping như **món riêng** (danh mục "Topping": xúc xích thêm, viên thả lẩu thêm…). Cách này vẫn trừ kho và tính tiền đúng, nhưng phiếu bếp không biết topping đi kèm món nào.

### Giảm giá tay
- App đã có sẵn phần lõi: `CartNotifier.setDiscount()` trong `lib/modules/pos/providers/pos_providers.dart`, áp vào tổng tiền, xoá mã voucher nếu có. **Thiếu ô nhập** trên màn thanh toán.
- Máy chủ đã nhận `p_discount`:
  - Ghi nhật ký `pos_manual_discount`.
  - Không cho giảm quá giá trị đơn.
- **Lỗi quyền phía máy chủ** (phải sửa trước khi mở tính năng):
  - Máy chủ chỉ cho giảm giá khi người gọi là chủ quán (`store_members.is_owner`), hoặc có `pos.apply_discount` trong danh sách quyền. Máy chủ **ưu tiên** `staff_members.actions`; chỉ khi cột này trống (NULL) mới đọc `app_settings.action_perms_<mã vai trò>`. Nếu `staff_members.actions` là mảng (kể cả rỗng) không có quyền này thì bị từ chối luôn. Máy chủ không đọc `action_perms_deny_*`.
  - Màn Phân quyền lại lưu theo **tên** vai trò ("Thu ngân"), còn tài khoản mang **mã** ("cashier") → thu ngân bị từ chối dù đã bật quyền.
  - **Quản lý** cũng bị từ chối, vì Quản lý không phải chủ quán và thường không có dòng `action_perms_manager`.
- Công tắc "Áp dụng giảm giá" hiện có ghi chú cam "Chưa có tác dụng".

## Đề xuất

### Phần A — Giảm giá tay (nhỏ, làm trước)
1. **Máy chủ** (migration mới, chạy thử trên bản sao, hỏi trước khi áp):
   - Quyền giảm giá dùng chung cách tính với các chốt khác:
     - Chủ quán/Quản lý luôn được.
     - Vai trò khác tra theo tên vai trò của quán **và** mã vai trò.
     - Tôn trọng danh sách tắt `action_perms_deny_*`.
   - Đặt **trần giảm giá** (vd tối đa X% đơn, Chủ quán chỉnh trong Cài đặt). Quá trần thì cần PIN Quản lý.
2. **App:**
   - Màn thanh toán thêm ô **"Giảm giá"**: nhập số tiền hoặc %, có lý do, chỉ hiện khi có quyền.
   - Bill in ra có dòng giảm giá.
   - Báo cáo Huỷ/Duyệt (hoặc tab Voucher) liệt kê các lần giảm giá tay: ai giảm, bao nhiêu, đơn nào.
   - Bỏ ghi chú cam "Chưa có tác dụng" khi đã gắn kiểm tra thật.
3. **Test:** quyền theo từng vai trò (gồm nhân viên có `staff_members.actions` rỗng và NULL), vượt trần, nhập %, xung đột với voucher (chỉ một trong hai), báo giá lệch (`FINANCIAL_QUOTE_CHANGED`).

Ước lượng: 1 migration nhỏ + 3–4 tệp app.

### Phần B — Topping ở quầy (lớn hơn)
1. **Máy chủ:** mở rộng `complete_pos_sale_v1`, nên làm bản `_v2` để app cũ vẫn chạy.
   - Mỗi dòng nhận `toppings: [{product_id, qty}]`.
   - Máy chủ kiểm topping có trong `product_topping_links` của món.
   - Giá topping lấy từ máy chủ, cộng vào tiền dòng.
   - Trừ kho topping, ghi `order_items.modifiers_json` giống bàn.
2. **App:**
   - Chạm món có topping → mở bảng chọn topping. Dùng lại `_ToppingPickerSheet` của Bàn, tách ra widget chung.
   - Dòng giỏ hiện "+ Trân châu x1"; cùng món khác topping thì là 2 dòng riêng.
   - Phiếu bếp và bill in kèm topping dưới món.
   - Đơn gần đây / in lại bill hiện đủ topping.
3. **Kho:** gắn lối vào cho tab "Nhóm topping" (`_ToppingGroupTab` trong `inventory_screen.dart` đã viết nhưng chưa từng có lối vào) để quy định chọn tối thiểu/tối đa.
4. **Test:** giá, tồn kho topping, idempotency, app cũ gọi `_v1` vẫn chạy, QR / Bàn không đổi.

Ước lượng: 1 migration (hàm v2 + test) + 6–8 tệp app; nên làm sau Phần A.

## Cần Chủ Quán quyết
- Trần giảm giá tay: bao nhiêu %, quá trần có cần PIN Quản lý không?
- Giảm giá cho phép nhập % hay chỉ số tiền?
- Topping ở quầy: giữ song song cách bán topping như món riêng không, hay chuyển hẳn sang gắn vào món?
