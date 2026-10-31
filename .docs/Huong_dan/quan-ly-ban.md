---
module: table
ten: Quản lý Bàn
phien_ban: 1.0.5+20
cap_nhat: 2026-11-01
nguon:
  - lib/screens/ban_screen.dart (13.278 dòng: sơ đồ bàn, mở bàn, phiên bàn, gọi món, topping/tùy chọn, gửi bếp, huỷ món/huỷ bàn, chuyển/gộp, thanh toán, PIN quản lý)
  - lib/core/repositories/ban_repository.dart
  - supabase/migrations/20261008_fix09_quy_doi_don_vi_cong_thuc.sql (settle_ban_session_v5), 20260902_atomic_settlement_v5.sql (guard_ban_item_financial_change_v5)
---

# Quản lý Bàn

> Sơ đồ bàn theo khu vực; mở bàn, nhiều nhân viên cùng gọi món cho một bàn, gửi bếp theo đợt, in tạm tính, chuyển/gộp bàn, huỷ món có duyệt, và thu tiền cả bàn.

## Ai dùng được
- Người có module **Quản lý Bàn** (mặc định **tắt**, Chủ quán bật trong Modules). Quán mới tạo, cả ba vai trò có sẵn (Thu ngân, Nhân viên, Bếp) đều có module này; Chủ quán thêm/bỏ module cho vai trò bất kỳ ở **Nhân viên → Vai trò**.
- **Thêm/sửa/xoá khu vực và bàn, sắp xếp khu**: cần quyền **"Thêm/Sửa bàn & khu vực"** — đi kèm module Quản lý Bàn, nên mặc định ai có module (kể cả Phục vụ) đều làm được.
- **Thanh toán**: mặc định **ai có module Quản lý Bàn hoặc Bán hàng đều thanh toán được, kể cả Phục vụ**. Chủ quán muốn chặn thì tắt quyền **"Thanh toán hoá đơn"** cho vai trò đó (Nhân viên → Hành động nhạy cảm); khi đó người bấm thấy "Bạn không có quyền "Thanh toán"." Riêng Chủ quán, Quản lý, Thu ngân luôn thanh toán được ở Quản lý Bàn. Công tắc này chỉ hiện khi vai trò có module **Bán hàng**; vai trò chỉ có Quản lý Bàn (vd vai trò "Nhân viên" có sẵn) thì không tắt được — muốn chặn phải bỏ module Quản lý Bàn khỏi vai trò.
- **Huỷ món đã gửi bếp, huỷ bàn**: Chủ quán / Quản lý tự duyệt; nhân viên khác phải nhờ **Quản lý nhập mã PIN 6 số**.
- Gọi món, gửi bếp, chuyển/gộp bàn: mọi nhân viên có module.

## Màn hình gồm những gì
- Tiêu đề **"Quản lý bàn"**; nút đơn QR (**"Đơn gọi món QR"**, kèm số đơn); nút **"Thêm khu vực"**.
- **Dải khu vực**: "Tất cả", từng khu, **"Thêm khu"**. Giữ lâu một khu để kéo đổi thứ tự; chạm đúp để sửa.
- Bộ lọc **"Tất cả bàn" / "Đang có khách" / "Bàn trống"** và cỡ thẻ bàn (To / Vừa / Nhỏ).
- **Thẻ bàn**: tên, **"● Có khách" / "○ Trống"**, số khách, số món, tên nhân viên ("NV: …"), số chỗ, nhãn **"QR (n)"** nếu có đơn QR chờ, cảnh báo đỏ **"⚠ N món chưa gửi bếp"** (chỉ hiện khi món đã nằm chưa gửi **quá 3 phút**).
- Máy tính bảng / PC: cột phải **"Tổng quan"** (Trống, Đang phục vụ, tổng bàn, Số khách) và **"Đang phục vụ"** (bàn có khách, thời gian ngồi, tổng tiền). Nút mũi tên **"Mở bàn"** cạnh mỗi bàn mở bảng phiên bàn; muốn đóng bàn phải **"Thanh toán"** hoặc **"Huỷ bàn"**.
- Nút **"Thêm bàn"**.

## Các việc thường làm

### 1. Thiết lập khu vực và bàn (lần đầu)
1. Bấm **"Bắt đầu thiết lập ngay"** (khi chưa có bàn) hoặc **"Thêm khu vực"**: **"Tên khu vực"** (Trong nhà, Ngoài trời…), **"Biểu tượng"**, **"Màu sắc"** → **"Thêm khu vực"**.
2. **"Thêm bàn"**: **"Tên bàn (vd: Bàn 1, Bàn VIP)"**, **"Khu vực"**, **"Số chỗ ngồi"**.
3. Tạo nhiều bàn một lần: tăng **"Số lượng bàn"** — app tạo "Bàn 1", "Bàn 2"… theo tên gốc.
4. Sửa/xoá: giữ lâu thẻ bàn → **"Sửa thông tin bàn"** (có **"Xoá bàn"**); sửa khu có **"Xoá khu"**.

### 2. Mở bàn
1. Chạm bàn trống → bảng mở bàn: chỉnh **"Số khách"** (sức chứa chỉ để tham khảo, có thể thêm ghế).
2. Bấm **"Mở bàn"** → bảng phiên bàn mở ra.

### 3. Gọi món
1. Trong bàn bấm **"Gọi món ngay"** (bàn chưa có món) hoặc **"Thêm món"**.
2. Tìm **"Tìm sản phẩm, thức uống..."** hoặc chọn danh mục; chạm món để thêm.
3. Món có thêm lựa chọn: bấm **"Tùy chọn"** trên thẻ món (máy màn hẹp như Sunmi: nút nhỏ nằm cạnh giá, chạm tên món cũng mở; thêm món không làm thẻ giãn ra nên các món bên dưới không dời chỗ):
   - **"🥗 Topping tùy chọn"** — tăng/giảm số lượng từng topping.
   - **"✨ Tùy chọn hương vị"** — các tùy chọn món (mức cay, thêm món…) và chip ghi chú nhanh.
   - **"Ghi chú"** — ghi chú riêng ("vd: ít rau, không cay...").
4. Món **"TẠM HẾT"** (đã tắt bán hoặc hết tồn): app hỏi **"Món tạm hết"** → **"Vẫn thêm"** nếu chắc còn.
5. **"Xem chi tiết"** để kiểm lại → **"Xác nhận • Thêm N món"**.

> Nhiều nhân viên gọi cùng một bàn được; mỗi món ghi tên người thêm. Gọi món **chưa** gửi bếp.

### 4. Gửi bếp
1. Gửi bếp ở bàn: bấm **"Gửi bếp (N)"** — N là số món chưa gửi. Gửi xong: "Đã gửi bếp Đợt X — N món".
2. Trạng thái từng món: **"Đã gửi"** → **"Đang làm"** → **"Bếp xong"**.
3. Món chưa gửi quá 3 phút: cảnh báo "⚠ N món CHƯA gửi bếp quá 3 phút — bấm "Gửi bếp" để bếp làm."
4. Bếp báo xong: app hiện "<bàn>: Món ăn đã sẵn sàng!".

> Cần bật module **Bếp**. Nếu tắt: "KHÔNG gửi bếp được: module Bếp đang tắt trên quán này…". Phiếu bếp tự in nếu đã cài máy in (xem In Hoá Đơn).

### 5. Sửa, giảm, huỷ món
- **Món chưa gửi bếp**: dùng nút **− / +** để sửa số lượng, hoặc nút thùng rác để xoá — không cần duyệt.
- **Món đã gửi bếp**: **không có nút − / +**, nên **không giảm số lượng được**. Muốn bớt (vd gửi 3 ly, khách chỉ lấy 2): **huỷ cả món** theo các bước dưới (cần Quản lý duyệt), rồi gọi lại đúng số lượng và gửi bếp lại.
- **Huỷ món đã gửi bếp** (bấm nút **thùng rác** ở dòng món):
  1. App cảnh báo theo trạng thái ("📋 Món đã gửi bếp", "⚠️ Bếp đang làm món này!", "⚠️ Món này bếp đã làm xong!").
  2. Chọn **"Lý do huỷ *"**: Khách đổi ý, Nhân viên nhập nhầm, Hết món…
  3. Món đang làm/đã xong: công tắc **"Trừ kho nguyên liệu (hao hụt)"** **bật sẵn** — tắt đi nếu nguyên liệu chưa bị dùng. Món mới gửi, bếp chưa làm: không có công tắc và không trừ kho.
  4. **"Huỷ món"** → Quản lý duyệt: Chủ quán/Quản lý tự duyệt; người khác (kể cả Thu ngân) phải nhờ **Quản lý nhập mã PIN**.
  5. "❌ Đã huỷ "<món>" — bếp đã được thông báo". Có ghi nhật ký huỷ.

### 6. In tạm tính
- Trong bàn bấm **"In tạm tính"** → "Đã gửi lệnh in tạm tính"; trong màn thu tiền → "Đã gửi lệnh in tạm tính (<số tiền>đ)". Phiếu ghi "TẠM TÍNH - CHƯA THANH TOÁN".
- Bấm liên tục bị chặn vài giây: "Đang in tạm tính, vui lòng chờ vài giây rồi mới bấm lại."

### 7. Chuyển bàn / gộp bàn
- **"Chuyển"**: chọn bàn **trống** → **"Chuyển sang <bàn>"** → "Chuyển bàn thành công!". Bàn đang có khách không chuyển sang được.
- **"Gộp bàn"**: chọn bàn **đang có khách** (nhãn "🔗 Gộp món") → **"Gộp <bàn này> vào <bàn kia>"** → "Gộp bàn thành công!".

### 8. Thanh toán cả bàn
1. Bấm **"Thanh toán"** → màn **"Thu tiền"** với **"TỔNG TIỀN CẦN THU"**.
2. Tuỳ chọn:
   - **"Phí dịch vụ / Ship"** — nhập phí thêm.
   - **"Khách hàng (tích điểm)"** — nhập SĐT; có điểm thì **"Dùng điểm"**.
   - **"Khuyến mãi / Voucher"** → **"Chọn mã"** → **"Áp dụng"** (bỏ: **"Gỡ mã"**).
   - Chưa có ô giảm giá tay — muốn bớt tiền cho khách: dùng mã giảm giá (voucher).
3. **"Hình thức thanh toán"**: **"Tiền mặt"**, **"Chuyển khoản"**, **"Thẻ"** (không có ví).
   - Tiền mặt: nhập **"Tiền mặt của khách"** → app tính **"TIỀN THỐI LẠI:"** hoặc **"Còn thiếu:"**.
   - Chuyển khoản: hiện **"QUÉT MÃ QR ĐỂ CHUYỂN KHOẢN"** theo tài khoản ngân hàng khai trong mẫu hoá đơn (In Hoá Đơn → Thiết kế → khối QR Code).
4. **"Xác nhận"** → **"Thanh toán thành công!"**. Hệ thống ghi thu, trừ kho theo công thức, cộng/trừ điểm, đóng bàn — tất cả trong một lần.
5. Nếu máy chủ tính lại giảm giá/phụ phí khác màn hình: hộp **"Báo giá hóa đơn thay đổi"** → **"Xác nhận & Thanh toán"** hoặc **"Hủy bỏ"**.
6. Bill tự in nếu đã cài (máy Sunmi mà quán chưa chọn máy in bill thì tự in ra máy in liền thân, xem `in-hoa-don.md`).
   - In lỗi: màn thành công báo **ngay** "Bill CHƯA in. Kiểm tra máy in bill." → **"IN LẠI BILL"**. Máy in không trả lời sau 30 giây cũng báo như vậy.
   - Máy chưa cài máy in hoá đơn: báo "Máy này chưa được cài máy in hóa đơn nên chưa in…", không có nút in lại.
   - Đóng màn khi bill chưa in: dòng đỏ "Bill <bàn> CHƯA in…" hiện **10 giây** (có nút ✕), tự tắt khi chuyển sang màn khác (vd Bếp).

> Mất mạng lúc thanh toán: mở lại và thanh toán lại — máy chủ nhận ra lần trước, **không thu hai lần**.

### 9. Huỷ bàn (khách bỏ về, mở nhầm)
1. Trong bàn bấm **"Huỷ bàn"**.
2. **Bàn chưa có món đang làm / đã xong** (trường hợp thường):
   1. Hỏi **"Huỷ bàn?"** ("Tất cả món đã gọi sẽ bị xoá.") → **"Huỷ bàn"**.
   2. Quản lý duyệt: Chủ quán/Quản lý tự duyệt; người khác nhờ **Quản lý nhập mã PIN**.
   3. Chọn **"Lý do huỷ bàn *"**: Khách đổi ý, Mở nhầm bàn, Gộp/Chuyển bàn.
3. **Bàn đã có món đang làm / đã xong** (huỷ khẩn cấp):
   1. Cảnh báo **"Huỷ bàn khẩn cấp?"** → **"Tiếp tục"**.
   2. Quản lý duyệt (PIN nếu người bấm không phải Chủ quán/Quản lý).
   3. Chọn lý do hao phí (Khách bỏ trốn / bùng bill, Bếp làm sai món / hỏng đồ…) và tích **"Tôi xác nhận chịu trách nhiệm cho các món đã chế biến bị huỷ bỏ."** → **"Đồng ý huỷ bàn"**. (Trường hợp này không hỏi "Lý do huỷ bàn *" riêng.)
4. Hệ thống ghi nhật ký huỷ, huỷ phiếu bếp, báo bếp.
5. Lỗi giữa chừng: "Hủy bàn CHƯA hoàn tất (…). Bàn vẫn mở — kiểm tra mạng rồi hủy lại, hoặc báo chủ quán."

### 10. Đơn QR tại bàn
- Khách gọi qua QR → thẻ bàn có nhãn **"QR (n)"**; nút đơn QR trên đầu màn hình mở danh sách. Duyệt theo bài **QR Gọi Món**; món vào phiên của bàn, thu tiền cùng bàn.

## Lỗi thường gặp
| Thấy gì | Vì sao | Làm gì |
|---|---|---|
| "Bạn không có quyền "Thêm bàn"." / "…"Thêm khu vực"." | Thiếu quyền quản lý sơ đồ bàn | Nhờ Chủ quán/Quản lý |
| "Bạn không có quyền "Thanh toán"." | Chủ quán đã tắt quyền "Thanh toán hoá đơn" cho vai trò này | Nhờ thu ngân, hoặc Chủ quán bật lại quyền |
| Không thấy nút − / + ở món đã gửi bếp | Món đã gửi bếp không giảm số lượng được | Huỷ cả món (cần Quản lý duyệt) rồi gọi lại đúng số lượng |
| "Mã PIN Quản lý không đúng" | Nhập sai PIN | Quản lý nhập lại |
| "KHÔNG gửi bếp được: module Bếp đang tắt…" | Module Bếp tắt | Bật module Bếp |
| "⚠️ Gửi bếp thất bại. Hãy chụp lại báo chủ app." | Lỗi mạng | Thử lại; món chưa gửi vẫn còn trong bàn |
| "🖨️ Không in được phiếu bếp: …" | Máy in bếp lỗi | Kiểm tra máy in; bếp vẫn thấy món trên màn Bếp |
| "Danh sách món vừa được cập nhật theo máy chủ. Kiểm tra lại tổng tiền." | Có người vừa thêm/sửa món | Xem lại rồi thanh toán |
| "Báo giá tiếp tục thay đổi. Vui lòng mở lại màn hình thanh toán." | Dữ liệu đổi liên tục | Đóng và mở lại màn thu tiền |
| "Chưa thiết lập thông tin ngân hàng ở mục In hóa đơn…" | Chưa khai tài khoản ở khối QR Code của mẫu hoá đơn | Khai trong Thiết Kế Mẫu In → Hoá Đơn |
| "⚠️ Bàn X đang có khách, không thể chuyển sang." | Chuyển sang bàn có khách | Dùng "Gộp bàn" |
| "Thanh toán thất bại. Hãy chụp lại báo chủ app." | Lỗi máy chủ/mạng | Thử lại; không thu hai lần |

## Liên quan module khác
- **Bếp**: nhận phiếu, cập nhật trạng thái món.
- **In Hoá Đơn**: phiếu bếp, tạm tính, bill; tài khoản VietQR lấy từ mẫu hoá đơn.
- **QR Gọi Món**: đơn khách tự gọi tại bàn.
- **Khách hàng**: tích điểm, voucher.
- **Thu Chi / Kho**: ghi thu, trừ kho khi thanh toán; hao hụt khi huỷ món.

## Ghi chú cho Chủ Quán (không đưa cho khách)

### Khác biệt với bản app cũ (cho Chủ Quán)
- Trước bản 22/10/2026: huỷ món mới gửi (bếp chưa làm) vẫn có thể trừ kho. App cũ còn ghi khoản chi "Giá vốn NL" vào Thu Chi khi huỷ món có công thức; bản mới chỉ trừ kho.

1. **ĐÃ VÁ trong code (22/10, chưa phát hành):** nút "X" ở cột "Đang phục vụ" từng đóng phiên bàn mà KHÔNG thanh toán, không lý do, không duyệt, không audit (`ban_repository.closeSession`). Nay nút đổi thành **"Mở bàn"** (mở bảng phiên), hàm `closeSession` đã xoá; test `test/screens/ban_close_session_guard_test.dart` chặn tái phát. **Lớp máy chủ: ĐÃ áp production 22/10 20:27** (`20261022_chan_dong_phien_ban_v1.sql`, 15/15 PASS trên production, tự ROLLBACK). App cũ bấm nút "X" trên bàn còn món nay bị máy chủ từ chối (hiện lỗi chung). Còn mở: siết "Huỷ bàn" bắt buộc có audit khi mọi máy đã lên ≥ 1.0.5+16.
2. **Giảm số lượng món đã gửi bếp (P0-4) — ghi chú cũ KHÔNG chính xác.** Trên giao diện, món đã gửi bếp (`da_gui`/`dang_lam`/`xong`) **không có nút −/+** (`ban_screen.dart` ~5799 `if (!_isItemSent)`), nên nhân viên không giảm được qua app; chỉ huỷ cả món (có duyệt/PIN). Hộp "Giảm số lượng?" nếu có đường nào mở tới thì từ 22/10 cũng bắt `_verifyManagerApproval` như huỷ. **Lỗ hổng thật chỉ ở máy chủ:** ai gọi API vẫn sửa được `ban_session_items.quantity` trực tiếp. (Đính chính 23/10: màn Bếp không có nút huỷ phiếu — `cancelTicket` không ai gọi, đã bỏ.) **[ĐÃ ÁP production 23/10/2026 15:42 — Chủ Quán duyệt; 62/62 PASS trên production] Chốt máy chủ:** `20261023_khoa_huy_mon_da_gui_v1.sql` (áp bằng `db-fix/khoa_huy_mon_ap_dung.sh`; hoàn tác `ROLLBACK=1`). Món đã gửi bếp: huỷ / giảm chỉ khi người gọi là Chủ quán/Quản lý, hoặc có quản lý vừa nhập PIN (lượt duyệt ghi lúc `verify_manager_quick_pin_v4` đúng PIN, hạn 5 phút, 1 request, 1 bàn); giảm phải đúng đơn giá × số lượng; xoá / tăng / đổi giá / kéo về "chưa gửi" bị chặn hẳn; món đã huỷ khoá số liệu (bếp bản cũ ghi đè trạng thái → máy chủ giữ "huy", không báo lỗi). Huỷ bàn bằng đổi thẳng trạng thái khi còn món đã gửi cũng cần duyệt. Chặn dòng số lượng/tiền âm (từng trừ được bill). Máy chủ tự ghi sổ `ban_item_void_server_logs` (ai làm, ai duyệt, trước/sau, số tiền; app chỉ đọc). `void_audit_logs`, `ban_session_void_logs`: app chỉ thêm, không sửa/xoá. Tương thích bản 1.0.5 (app cũ luôn hỏi PIN trước khi ghi). Bản sao production: 62/62 PASS + hoàn tác khớp; QC độc lập. App (chưa phát hành): bếp không ghi đè món đã huỷ, bỏ `cancelTicket` không dùng. **Còn hở:** máy chưa JWT giả được id Chủ quán qua header (#33); `kitchen_tickets` / `kitchen_ticket_items` vẫn sửa/xoá được qua API.
3. **Chuyển / gộp bàn không kiểm quyền**.
4. **Hai nơi khai tài khoản ngân hàng**: Bàn dùng khối QR trong mẫu hoá đơn; QR mang đi dùng "Chuyển khoản tại quầy" của module QR. Dễ khai một nơi quên nơi kia.
5. **Thanh toán bàn không có ví** — khác Bán hàng quầy.
6. **"Tắt bán" ở Bàn chỉ cảnh báo** ("Món tạm hết" → "Vẫn thêm"), không chặn.
7. **[ĐÃ SỬA 23/10 — chưa phát hành]** Lỗi chữ trên form thêm bàn "Têm bàn…" → "Tên bàn sẽ được dùng nguyên, vd: \"Bàn 5\"".
8. ~~Chữ "session" trên giao diện ("Đóng session …?")~~ — chuỗi này không còn trong code từ khi bỏ nút "X" (22/10).
9. **[ĐÃ SỬA trong app 22/10 — chưa phát hành]** Lỗi cũ: huỷ món "đã gửi" (bếp chưa làm) vẫn trừ kho hao hụt — `deductAsLoss` mặc định `true` trong khi công tắc chỉ hiện với `dang_lam`/`xong`, nên `_deductStockForWastage` trừ kho và (món có công thức) ghi chi "Giá vốn NL" dù chưa nấu. Nay `deductAsLoss = showWastageOption` (cả `_removeItem` và `_updateItemQty`): món chỉ mới gửi thì không trừ; đang làm/đã xong thì công tắc hiện, bật sẵn.
10. Quyền: module `ban` tự cấp `ban.manage_structure` và `pos.checkout` (`deriveActionPermsFromModules`) → Phục vụ mặc định thêm/xoá bàn và thanh toán được; tắt `pos.checkout` chỉ chặn trong app ở Bàn và QR mang đi, Thu ngân/Quản lý/Chủ quán luôn được ở Bàn (`isPrivileged`). Công tắc ở Hành động nhạy cảm chỉ hiện khi vai trò có module `pos` (`nhan_vien_screen.dart` ~3886–3893 lọc theo tiền tố) → vai trò chỉ có `ban` (vd "Nhân viên" `["ban"]` tạo sẵn ở `seedDefaults`) không có cách tắt thanh toán.
