---
module: pos
ten: Bán hàng
phien_ban: 1.0.5+20
cap_nhat: 2026-10-23
nguon:
  - lib/screens/pos_screen.dart
  - lib/modules/pos/screens/checkout_sheet.dart
  - lib/modules/pos/providers/pos_providers.dart
  - lib/modules/pos/repository/pos_repository.dart
  - lib/core/providers/app_providers.dart (posProductsProvider)
  - lib/core/widgets/order_detail_dialog.dart, lib/screens/finance_screen.dart (xem chi tiết đơn cũ)
  - supabase/migrations/20261008_fix09_quy_doi_don_vi_cong_thuc.sql (complete_pos_sale_v1 — bản đang chạy trên DB thật)
---

# Bán hàng

> Màn hình gọi món và thu tiền tại quầy: chọn món, ghi chú, gửi bếp, tích điểm cho khách, thanh toán và in hoá đơn.

## Ai dùng được
- Người có module **Bán hàng** trong vai trò (module mặc định bật cho mọi quán). Quán mới tạo, trong các vai trò có sẵn chỉ **Thu ngân** có module này ("Nhân viên" và "Bếp" thì không); Chủ quán thêm module cho vai trò bất kỳ ở **Nhân viên → Vai trò**. Có module này là có **quyền Thanh toán hoá đơn** — kể cả Phục vụ.
- Tắt "Thanh toán hoá đơn" (Nhân viên → Hành động nhạy cảm) hiện **không** chặn nút Thanh toán ở màn Bán hàng; công tắc chỉ chặn thu tiền ở Quản lý Bàn (Thu ngân vẫn thu được) và đơn QR mang đi.
- **Phục vụ** mặc định **không** có quyền "Huỷ đơn hàng" → không bấm được **"Xóa hết"** trong giỏ (xem [Xoá giỏ hàng](#xoá-giỏ-hàng)).
- Chủ quán và Quản lý thấy thêm **tổng tiền hôm nay** trong "Đơn gần đây".
- Giao diện khác nhau theo kích thước màn hình:
  - **Điện thoại**: danh sách món chiếm cả màn hình; giỏ hàng là **thanh nổi ở dưới**, chạm để mở.
  - **Máy tính bảng / PC**: chia hai cột — món bên trái, **giỏ hàng luôn hiện bên phải**.

## Màn hình gồm những gì
- **Thanh trên cùng**: chữ "Bán hàng" + giờ, ngày. Bên phải lần lượt:
  - Nút **đồng hồ quay ngược** (gợi ý khi giữ: "Đối soát thanh toán bị gián đoạn") — xem mục [Đối soát](#đối-soát-thanh-toán-bị-gián-đoạn).
  - Nhãn **"Đơn QR (n)"** — chỉ hiện khi có đơn khách tự gọi qua QR. Màu cam: có đơn mới chờ; xanh: đang xử lý; xám kèm biểu tượng mất sóng: mất kết nối hàng đợi QR.
  - Nút **dấu +**: thêm nhanh món mới vào thực đơn.
  - Nút **giỏ hàng** (hiện số món).
  - Nút **thùng rác**: xoá giỏ (chỉ hiện khi giỏ có món).
- **Dải đỏ khoá QR** (chỉ khi mã QR của quán bị khoá do bị quét phá) — xem hướng dẫn QR Gọi Món.
- **Ô tìm kiếm** (chữ mờ "Tìm món, mã SKU..."): tìm theo tên món hoặc mã SKU, không cần gõ dấu.
- Nút **"Đơn gần đây"**; bên phải có nhãn "Bếp sẵn sàng" khi quán bật module Bếp.
- **Hàng danh mục**: "Tất cả" và các danh mục của quán. Ở "Tất cả", món được nhóm theo danh mục.
- **Lưới món**: mỗi thẻ có tên, giá, số tồn (nếu có theo dõi tồn).

## Các việc thường làm

### Gọi món
1. Chạm vào thẻ món → món bay vào giỏ. Chạm lại để tăng số lượng.
2. Khi món đã có trong giỏ, trên thẻ hiện **[−] xN**: bấm **−** để giảm.
3. Muốn tìm nhanh: gõ tên vào ô tìm kiếm, hoặc chọn danh mục.
4. **Giữ lâu** một thẻ món để mở bảng thêm **nhiều món cùng lúc kèm ghi chú bếp**; chọn số lượng rồi bấm **"Thêm N món vào giỏ"**.

> Món mờ có nhãn **"Hết"** thì không bấm được: món đó đang theo dõi tồn kho, có đặt tồn tối thiểu, và tồn đã về 0. Món không đặt tồn tối thiểu thì vẫn bán bình thường dù tồn âm. Món mờ có nhãn **"Tạm ngưng"** là món đã "Tắt bán" ở Kho hàng: bấm vào báo "<món> đang tạm ngưng bán" — bật bán lại ở Kho hàng.

### Ghi chú món và ghi chú đơn
- **Ghi chú từng món**: trong giỏ, bấm **"Ghi chú"** ở dòng món. Có sẵn các nút chọn nhanh: "Không hành", "Ít đường", "Ít đá", "Không đá", "Thêm sauce", "Chín kỹ", "Không cay", "Thêm phần". Có thể gõ thêm rồi bấm **"Lưu ghi chú"**.
- **Ghi chú cả đơn**: trong giỏ, bấm **"Thêm ghi chú đơn hàng"** → gõ (vd: khách dị ứng hành) → **"Lưu ghi chú"**.

### Gửi bếp trước khi thu tiền
Chỉ dùng khi quán bật module **Bếp**.
1. **Điện thoại:** trên thanh giỏ hàng ở dưới, bấm **"Bếp (n)"** — n là số món chưa gửi. **Máy tính bảng / PC / web:** trong giỏ hàng bên phải, bấm **"Gửi bếp (n món)"** ngay trên nút "Thanh toán".
2. Bảng **"Xác nhận gửi bếp"** hiện danh sách món; có thể ghi chú từng món và **"Ghi chú chung cho bếp (tuỳ chọn)"**.
3. Bấm **"Gửi bếp ngay"**. Thông báo: "Đã gửi bếp đợt X: Mang đi — N món".
4. Giỏ hàng **vẫn giữ nguyên** để thu tiền sau; món đã gửi có nhãn **"đã gửi bếp"**. Gọi thêm món rồi bấm nút gửi bếp lần nữa ("Bếp" trên điện thoại, "Gửi bếp" trên máy tính bảng / PC / web) sẽ gửi **đợt mới** chỉ gồm món chưa gửi. Gửi hết thì nút đổi thành **"Đã gửi hết"** (máy tính bảng / PC / web: **"Đã gửi bếp hết"**).
5. Trong lúc đang gửi, nút gửi bếp bị khoá (máy tính bảng / PC / web hiện **"Đang gửi bếp…"**). Bấm "Thanh toán" lúc này, app báo "Đang gửi bếp — đợi gửi xong rồi thanh toán."

> Nút "Bếp" mờ và báo cần bật module Bếp khi quán chưa bật module này.

### Gắn khách hàng để tích điểm
1. Mở giỏ hàng, ở ô **"SĐT khách hàng (tích điểm)..."** gõ số điện thoại của khách (ít nhất 9 số, đúng như đã lưu trong module Khách hàng) rồi bấm tìm.
2. Tìm thấy: hiện tên khách, **số điểm** và **số dư ví** (nếu có).
3. Không thấy: "Không tìm thấy khách hàng" — khách chưa có trong danh sách; tạo ở module Khách hàng.

### Thanh toán
Khách trả tiền tại quầy (thu ngân tính tiền ở màn Bán hàng):
1. Bấm **"Thanh toán"** (trong giỏ) hoặc ô **tổng tiền màu cam** trên thanh giỏ (điện thoại).
2. Bảng **"Thanh toán"** hiện tóm tắt món. Chọn **"Phương thức"**: "Tiền mặt", "Chuyển khoản", "Thẻ". Nếu khách có ví, có thêm **"Thanh toán bằng Ví"**.
3. Tuỳ chọn giảm giá:
   - **"Điểm thưởng"** — chỉ hiện khi đã gắn khách có điểm và **không** trả bằng ví.
   - **"Khuyến mãi / Voucher"** → **"Chọn mã"** → chọn mã → **"Áp dụng"**. Bỏ mã: **"Gỡ mã"**.
4. Kiểm phần tổng: "Tạm tính", "Giảm giá", "Dùng điểm", **"TỔNG CỘNG"**.
5. Bấm **"Xác nhận • <số tiền>"**.
6. Màn **"Thanh toán thành công!"** kèm số đơn. Hoá đơn tự in nếu quán bật tự in và máy đã cài máy in.
   - Bấm **"In hoá đơn"** để in (lại). Nếu vừa in xong vài giây, app hỏi "Bill vừa được in… In thêm một bản nữa?".
   - Bấm **"Đơn mới"** để bắt đầu khách tiếp theo.

Thanh toán xong, hệ thống tự: ghi **một** khoản thu vào Thu Chi, trừ kho theo công thức (có quy đổi đơn vị), cộng/trừ điểm khách, trừ ví nếu trả bằng ví, đóng các đợt đã gửi bếp.

> **Trả bằng ví**: tiền thưởng (bonus) chỉ được dùng tối đa theo % quy định của khách (mặc định 15% giá trị đơn), phần còn lại trừ vào ví thật. Ví không đủ thì nút đổi thành "⚠️ Ví không đủ — cần thêm tiền mặt" và không cho xác nhận. Không dùng được điểm cùng lúc với ví.
> **Không có giảm giá gõ tay** trong màn Bán hàng; giảm giá chỉ qua voucher hoặc điểm.

### Xem đơn gần đây
1. Bấm **"Đơn gần đây"** dưới ô tìm kiếm.
2. Danh sách đơn **trong hôm nay** của quán: giờ, số đơn, phương thức ("💵 Tiền mặt", "🏦 Chuyển khoản", "💳 Thẻ"), tổng tiền. Chạm một đơn để xem món.
3. Chủ quán / Quản lý thấy thêm **"tổng hôm nay"** ở đầu danh sách.

> Chỉ xem được, không in lại ở đây. **Đơn đã thanh toán hiện không huỷ / hoàn tiền được ở bất kỳ đâu trong app** — nếu thu nhầm, báo Chủ quán xử lý.
> Muốn tìm hoặc **in lại bill cũ**: vào **Báo cáo → tab "Hóa đơn" → "Tra cứu & in lại bill"**. Cần module **Báo cáo** (Phục vụ mặc định không có nên không vào được) và quyền **"Xem lịch sử đơn"**. Ai có module Bán hàng thì có sẵn quyền này; Chủ quán muốn chặn thì tắt "Xem lịch sử đơn" trong Hành động nhạy cảm (khi đó người bấm in lại thấy "Bạn không có quyền in lại bill"). Màn này tải đủ bill của kỳ đang chọn (tối đa 20.000 bill). Bill in lại không còn in các món QR đã bị huỷ.
> Ngay sau khi thanh toán thì in lại bằng nút "In hoá đơn" trên màn "Thanh toán thành công!".

### Thêm nhanh món mới vào thực đơn
1. Bấm nút **dấu +** trên thanh trên cùng (hoặc khi tìm không ra, bấm **"Thêm "<tên>""**).
2. Bảng **"Thêm sản phẩm mới"**: "Tên sản phẩm *", "Giá bán (đ)", "Giá vốn (đ)", danh mục ("Đồ ăn", "Đồ uống", "Tráng miệng", "Combo", "Khác" hoặc danh mục riêng), đơn vị (mặc định "phần").
3. Bấm **"Thêm vào thực đơn"** → "✅ Đã thêm "<tên>" vào thực đơn". Món hiện ngay trong lưới.

> **Phiếu bếp in ra trạm nào** là theo **"Bộ phận chế biến"** của món (Kho hàng → Sửa thông tin món: Bếp Nóng / Bếp Bar / Thu Ngân), **không** theo danh mục. Món thêm nhanh bằng nút dấu + **mặc định là Bếp Nóng** — nếu là đồ uống, vào Kho hàng sửa món và chọn **"Bếp Bar"**.
> Riêng phiếu hiện trên **màn Bếp** khi bấm "Bếp" ở điện thoại: món danh mục "Đồ uống" vào "Bếp nước", món khác vào "Bếp nóng".

### Xoá giỏ hàng
Xoá hết giỏ hàng khi khách đổi ý bỏ hết món:
- Nút **thùng rác** trên thanh trên cùng → hỏi "Xóa giỏ hàng?" → **"Xóa"**.
- Hoặc **"Xóa hết"** trong giỏ — chỉ người có quyền **"Huỷ đơn hàng"** mới bấm được (mặc định Chủ quán, Quản lý, Thu ngân; **Phục vụ không có**); người khác thấy "Bạn không có quyền huỷ đơn hàng". Quyền này chỉ chặn nút "Xóa hết" của giỏ chưa thanh toán, không liên quan đơn đã thu.

### Đối soát thanh toán bị gián đoạn
Dùng khi đang thanh toán thì mất mạng, tắt app hoặc máy treo — không biết tiền đã ghi nhận chưa.
1. Mở lại màn Bán hàng, bấm **"Thanh toán"** hoặc nút **đồng hồ quay ngược** trên thanh trên cùng.
2. Nếu có giao dịch dang dở, app hiện **"Thanh toán chưa đối soát"** kèm số tiền, phương thức. Bấm **"Đối soát / tiếp tục đơn cũ"**.
3. App hỏi máy chủ: nếu đơn **đã thu**, chỉ lấy lại kết quả ("Đã thanh toán: <số đơn>") — **không thu lần hai**, không tự in lại. Nếu chưa, gửi lại đúng giao dịch cũ.
4. Thành công thì giỏ đang hiển thị được xoá để tránh bán lại đơn cũ.

> Không thanh toán lại đơn đó trên máy khác trong lúc đang đối soát. Không có giao dịch dang dở thì app báo "Không có thanh toán đang chờ đối soát".

## Lỗi thường gặp
| Thấy gì trên màn hình | Vì sao | Làm gì |
|---|---|---|
| "<món> đã hết hàng" khi chạm món | Món theo dõi tồn, có tồn tối thiểu và tồn ≤ 0 | Nhập kho hoặc sửa tồn trong Kho hàng |
| "Tải danh sách món thất bại. Hãy chụp lại báo chủ app." | Mất mạng hoặc lỗi tải dữ liệu | Kiểm tra mạng, mở lại màn; còn lỗi thì chụp màn gửi chủ app |
| "Không tìm thấy khách hàng" | SĐT chưa có hoặc gõ khác cách đã lưu | Kiểm tra số, hoặc tạo khách ở module Khách hàng |
| "Máy này chưa được cài máy in hóa đơn nên chưa in. Vào In Hoá Đơn → Máy In & Luật In để chọn máy in." | Máy chưa có máy in / luật in | Cài máy in theo hướng dẫn In Hoá Đơn; đơn vẫn đã thanh toán |
| "In hóa đơn thất bại. Kiểm tra máy in rồi bấm "In hoá đơn"." | Máy in tắt, hết giấy, mất kết nối | Kiểm tra máy in rồi bấm "In hoá đơn" |
| "Kết nối mạng chậm hoặc không ổn định…" | Mạng yếu khi thanh toán | **Không** bấm thanh toán lại ngay; bấm nút đồng hồ để đối soát trước |
| "Lỗi: … Giá món đã đổi. Cập nhật giỏ hàng trước khi thanh toán." | Giá món vừa được sửa trong lúc đang bán | Xoá món đó khỏi giỏ, chọn lại rồi thanh toán |
| "Lỗi: … Đơn hàng chưa đạt giá trị tối thiểu để áp dụng voucher" | Voucher có mức đơn tối thiểu | Gỡ mã hoặc thêm món |
| "Lỗi: … Số dư ví không đủ; chưa ghi nhận thanh toán" | Ví khách thay đổi trong lúc thanh toán | Chọn phương thức khác |
| "Lỗi: … Phiên bếp đã đóng hoặc đã thanh toán…" / "Giỏ hàng thiếu món đã gửi bếp; chưa thu tiền." | Đơn đã gửi bếp bị thay đổi hoặc đã được thu ở nơi khác | Kiểm tra "Đơn gần đây" xem đã thu chưa; chưa thu thì báo quản lý |
| "Gửi bếp thất bại. Hãy chụp lại báo chủ app." | Lỗi mạng hoặc dữ liệu khi gửi bếp | Thử lại; còn lỗi thì chụp màn gửi chủ app |
| "Bạn không có quyền huỷ đơn hàng" | Vai trò không có quyền "Huỷ đơn hàng" (vd Phục vụ) | Dùng nút thùng rác trên cùng, hoặc nhờ Thu ngân/Quản lý |
| Đồ uống thêm bằng nút dấu + lại in ra máy bếp nóng | Món thêm nhanh mặc định "Bộ phận chế biến" = Bếp Nóng | Kho hàng → sửa món → chọn "Bếp Bar" |
| Khách muốn huỷ / hoàn tiền đơn đã thanh toán | App chưa có chức năng huỷ đơn đã thu | Báo Chủ quán |

## Liên quan module khác
- **Thu Chi**: mỗi đơn thanh toán tạo đúng một khoản thu.
- **Kho hàng / Kho Chuyên Nghiệp**: trừ tồn khi thanh toán (không trừ khi mới gửi bếp).
- **Khách hàng**: điểm, ví, voucher.
- **Bếp**: nhận phiếu khi bấm "Bếp" hoặc in phiếu khi thanh toán.
- **In Hoá Đơn**: tự in hoá đơn và phiếu bếp.
- **QR Gọi Món**: nhãn "Đơn QR" trên thanh trên cùng.
- **Báo cáo**: mọi đơn đã thanh toán đi vào báo cáo.

## Ghi chú cho Chủ Quán (không đưa cho khách)

### Khác biệt với bản app cũ (cho Chủ Quán)
- Chữ không dấu: app cũ hiện "Tim mon, ma SKU...", "Bep san sang", thông báo/phiếu bếp ghi "Mang di".
- App cũ trên máy tính bảng / PC / web không có nút "Gửi bếp" (phiếu bếp chỉ in khi thanh toán), không khoá nút "Thanh toán" trong lúc đang gửi bếp, và chưa chặn món "Tạm ngưng" — cập nhật app, hoặc gọi món qua Quản lý Bàn.
- "Tra cứu & in lại bill" chỉ có từ bản 22/10/2026; app cũ chỉ tải tối đa 500 bill mới nhất của kỳ (bản mới tải tối đa 20.000).

Mình phát hiện các điểm sau khi đọc code. Tài liệu trên mô tả **đúng như app đang chạy**; mục có nhãn "ĐÃ SỬA" là đã sửa trong code (chưa phát hành trừ khi ghi khác), phần hướng dẫn ghi rõ "app bản mới, sau 23/10/2026":
1. **Khoá món hết tồn — ĐÚNG THIẾT KẾ (Chủ Quán xác nhận 23/10):** món có đặt tồn tối thiểu mà tồn ≤ 0 thì khoá ("Hết"); món không đặt tồn tối thiểu thì không khoá. `qn.md` ghi khác ("thiếu tồn chỉ cảnh báo") → cần sửa `qn.md` cho khớp. **[ĐÃ SỬA trong app 23/10 — chưa phát hành]** món tạm ngưng bán (`is_available=false`) nay mờ, nhãn "Tạm ngưng", không thêm vào giỏ được — kể cả qua bảng nhấn giữ ("thêm nhiều món", trước đây lọt cả món hết tồn) và nút + của món đã có trong giỏ (`posProductSellable`); máy chủ chưa chặn.
2. **Không có topping ở POS quầy.** Topping chỉ có ở Quản lý Bàn và QR khách. Với quán trà sữa mang đi đây là khoảng trống lớn.
3. **[ĐÃ SỬA trong app 23/10 — chưa phát hành] Nút gửi bếp trên máy tính bảng / PC / web**: Chủ Quán xác nhận bản rộng không có nút gửi bếp (chỉ điện thoại có). Đã thêm nút "Gửi bếp (n món)" vào giỏ hàng bên phải; kiểm trên bản xem trước: mở đúng bảng "Xác nhận gửi bếp". Khi đang gửi: nút hiện "Đang gửi bếp…" và bị khoá (điện thoại cũng khoá); bấm "Thanh toán" lúc đó báo "Đang gửi bếp — đợi gửi xong rồi thanh toán.".
4. **Hai nút xoá giỏ khác quyền**: thùng rác trên cùng ai cũng xoá được; "Xóa hết" trong giỏ cần `pos.cancel_bill` (Phục vụ mặc định không có → nhân viên vẫn xoá được bằng thùng rác).
5. **[ĐÃ SỬA trong app 23/10 — chưa phát hành]** Chữ không dấu trên giao diện: "Tim mon, ma SKU...", "N mon", "Bep san sang", "Can bat Module Bep trong Modules truoc", "Mang di".
6. **Thông báo lỗi máy chủ hiện kèm chữ "Exception:"** (vd "Lỗi: Exception: Giá món đã đổi…") — nên bỏ cho dễ đọc.
7. **Không có giảm giá tay**: `manualDiscount` / `CartNotifier.setDiscount` có nhưng không có ô nhập. Máy chủ (`complete_pos_sale_v1`) nhận `p_discount` nhưng từ chối Quản lý và vai trò lưu quyền theo tên → xem `.docs/ke-hoach-topping-giam-gia-pos.md`.
8. Có code chọn bàn trong POS (`_TablePickerSheet`, `_LocationSelector`) nhưng **không được dùng** — mọi đơn POS là "Mang đi".
9. **In lại bill cũ**: đã làm 22/10 ở Báo cáo → tab "Hóa đơn" (xem `.docs/tinh-nang.md`, mục "Tra cứu & in lại bill cũ"). Chưa có trên bản đang phát hành cho tới lần deploy tiếp theo. Cần module `report` + quyền `pos.view_history`; giới hạn 500 bill/kỳ (`kBillLookupLimit`).
10. **Thêm nhanh món (dấu +) không đặt `station_code`** → `core_product_repository.create` mặc định `'nong'`; phiếu in theo `stationCode` của món nên đồ uống thêm nhanh in ra bếp nóng. Phiếu KDS từ nút "Bếp" điện thoại lại suy trạm theo danh mục "Đồ uống" (`pos_screen.dart` ~1325) — hai quy tắc khác nhau.
11. **Không có chức năng huỷ/hoàn đơn đã thanh toán**: `PosRepository.cancelOrder` có nhưng không được gọi từ màn nào.
12. **Công tắc quyền**: `pos.edit_price` không được kiểm ở đâu; `pos.apply_discount` app không kiểm, chỉ máy chủ kiểm trong `complete_pos_sale_v1` (app chưa bao giờ gửi giảm giá tay) — màn quyền ghi "Chưa có tác dụng" cho cả hai; `pos.cancel_bill` chỉ chặn nút "Xóa hết"; tắt `pos.checkout` (danh sách `action_perms_deny_*`) chỉ chặn ở Quản lý Bàn (`ban_screen.dart`, Thu ngân/Quản lý/Chủ quán bỏ qua qua `isPrivileged`) và QR mang đi (`qr_order_review_sheet.dart`); màn Bán hàng không kiểm, máy chủ cũng không đọc danh sách tắt. Module `pos` hoặc `ban` tự cấp `pos.checkout`. Phục vụ mặc định không có `pos.cancel_bill` / `pos.edit_price` (từ 22/10) nhưng **có** `pos.view_history` (đi kèm module `pos`). Vai trò mặc định quán mới (`store_auth_service.dart` `seedDefaults`): Thu ngân `["pos","ban","report"]`, Nhân viên `["ban"]`, Bếp `["kitchen","ban"]` — các dòng này thắng `kDefaultPerms`.
13. **[ĐÃ SỬA trong app 23/10 — chưa phát hành]** (chi tiết của mục 3 và 5) "Mang di" → "Mang đi" (thông báo gửi bếp, tên phiếu KDS). Nút gửi bếp ở bố cục rộng: `_PanelKitchenSendBtn` trong `_CartPanel` (`pos_screen.dart`). Kế hoạch topping + giảm giá tay: `.docs/ke-hoach-topping-giam-gia-pos.md`.
- **[SỬA 23/10 — chưa phát hành] Lỗi giới hạn 1.000 dòng:** máy chủ chỉ trả 1.000 dòng mỗi lần đọc; màn này trước đây đọc cả bảng của quán rồi lọc ở máy → quán lớn (KAY) nhận toàn dòng cũ. "Đơn gần đây" của KAY chỉ nhận đơn tới 26/7 (hôm 23/10 thực có 47 đơn) → danh sách hôm nay trống. Nay lọc ngày ở máy chủ, có phân trang; lãi trong ngày tính đủ món (chia 100 đơn mỗi lần).
