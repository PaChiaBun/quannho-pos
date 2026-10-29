---
module: loyalty
ten: Khách hàng – Giảm giá – Khuyến mãi
phien_ban: 1.0.5+20
cap_nhat: 2026-10-23
nguon:
  - lib/screens/loyalty_screen.dart (Khách, Ví, Thưởng, Gói nạp, Khuyến mãi / Voucher)
  - lib/modules/loyalty/repository/loyalty_repository.dart (nạp ví, gói nạp, phần thưởng)
  - lib/modules/pos/screens/discount_management_screen.dart (voucher)
  - lib/screens/settings_screen.dart ("Cài đặt điểm thưởng" — loyalty_rate)
  - supabase/migrations/20261008_fix09_quy_doi_don_vi_cong_thuc.sql (tích/đổi điểm, trừ ví, voucher khi thanh toán)
---

# Khách hàng – Giảm giá – Khuyến mãi

> Danh sách khách thân thiết, tích điểm theo chi tiêu, ví trả trước có thưởng nạp, phần thưởng đổi điểm và mã giảm giá (voucher).

## Ai dùng được
- Người có module **Khách hàng** (tên trên Trang chủ: "Khách hàng & Khuyến mãi"; mặc định **tắt**).
- **Tạo / sửa / xoá voucher**: chỉ Chủ quán hoặc Quản lý ("Chỉ Chủ quán hoặc Quản lý mới có quyền thiết lập voucher."). Vai trò phải tên **đúng là "Quản lý"** — vai trò tên khác như "Quản lý nhà hàng" cũng bị chặn.
- Thêm khách, phần thưởng, gói nạp: ai vào được module đều làm được.
- **Nạp ví**: cần quyền **"Thanh toán hoá đơn"** (Chủ quán, Quản lý và vai trò có quyền thu tiền); thiếu quyền sẽ thấy "Bạn không có quyền thu tiền (pos.checkout)".

## Màn hình gồm những gì
- Đầu trang **"Khách hàng thân thiết"** – "Loyalty & Ví điện tử": số **Khách**, **Có điểm**, **Điểm active**, **Đã đổi**.
- 5 tab:
  - **"Khách"** — danh sách khách (tìm "Tìm khách hàng..."), hạng, điểm, tổng chi. Nút **"Thêm khách"**.
  - **"Ví"** — "Tổng ví thật" (tiền thật đã nạp), "Tổng bonus"; từng khách có nút **"Nạp"**.
  - **"Thưởng"** — danh sách phần thưởng đổi bằng điểm.
  - **"Gói nạp"** — các mức nạp được tặng thêm %. Nút **"Thêm gói"**.
  - **"Khuyến mãi / Voucher"** — mã giảm giá.

## Cách tính điểm, hạng, ví
- **Tích điểm** (điểm tích luỹ): mỗi đơn thanh toán có gắn khách được cộng `tổng tiền ÷ mức tích` điểm (làm tròn xuống). Mặc định **10.000đ = 1 điểm**; đổi ở **Cài đặt → "Cài đặt điểm thưởng"** ("đ = 1 điểm") → **"Lưu cài đặt"**.
- **Dùng điểm** khi thanh toán: mỗi điểm trừ **1.000đ** (mặc định, hiện chưa có chỗ đổi trong app).
- Mỗi lần thanh toán có gắn khách còn cộng **tổng chi** và **số lần** ghé.
- **Hạng** (chỉ để hiển thị, chưa có ưu đãi tự động): **Đồng 🥉** < 50 điểm, **Bạc 🥈** từ 50, **Vàng ⭐** từ 200, **VIP 💎** từ 500.
- **Ví**: gồm **tiền thật** khách đã nạp và **bonus** được tặng. Khi trả bằng ví ở **Bán hàng**: bonus chỉ dùng tối đa **15%** giá trị đơn (mặc định), phần còn lại trừ tiền thật. Không dùng điểm cùng lúc với ví. **Quản lý Bàn chưa trả được bằng ví.**

## Các việc thường làm

### 1. Thêm khách
1. Tab Khách → **"Thêm khách"** → **"Thêm khách hàng"**.
2. **"Tên khách hàng *"**, **"Số điện thoại"** (dùng để tra khi thanh toán), **"Email"**, **"Ghi chú"** → **"Lưu khách hàng"**.
3. Sửa: chạm khách → nút **"Sửa thông tin"** → **"Lưu thay đổi"**. Xoá: **"Xoá"** (khách bị ẩn, lịch sử giao dịch vẫn giữ).

> Khi thanh toán, nhân viên gõ đúng số điện thoại đã lưu để gắn khách (Bán hàng: ô "SĐT khách hàng (tích điểm)..."; Bàn: "Khách hàng (tích điểm)").

### 2. Xem chi tiết khách
- Chạm khách: điểm hiện có, **"Tổng chi"**, **"Số lần"**, **"Điểm tích"**, **"Lịch sử điểm"** (+ tích / − đổi, theo thời gian).

### 3. Tạo gói nạp (khuyến khích nạp ví)
1. Tab **"Gói nạp"** → **"Thêm gói"** (hoặc **"Tải gói mặc định"** khi chưa có).
2. **"Tên gói (VD: Gói Vàng)"**, **"Nạp từ (đ)"**, **"% Bonus"** → **"Thêm gói"**.
3. Khi nạp, hệ thống tự áp **gói phù hợp nhất** với số tiền và tính bonus.

### 4. Nạp tiền vào ví cho khách
1. Tab **"Ví"** → nút **"Nạp"** ở dòng của khách → **"Nạp tiền — <tên khách>"**, thấy số dư hiện tại. Khách **chưa có tiền trong ví** (nạp lần đầu): bấm **"Nạp ví cho khách"** ở đầu tab Ví → tìm theo tên hoặc số điện thoại → chọn khách. Chi tiết khách không có nút nạp.
2. Chọn gói hoặc nhập **số tiền**; app hiện "Áp dụng: <gói> (+X% bonus)".
3. **"Thời hạn bonus"**: 6 tháng, 12 tháng (mặc định), 2 năm, Không hạn.
   - Nếu lần nạp này **có thưởng** và chọn **một thời hạn**, hạn dùng của **toàn bộ** số bonus khách đang có (cả bonus cũ) được đặt lại theo thời hạn mới.
   - Lần nạp **không có thưởng**, hoặc chọn **"Không hạn"**, thì giữ nguyên hạn bonus hiện có của khách.
4. **"Khách trả bằng:"** **Tiền mặt** hoặc **Chuyển khoản**.
5. Kiểm **"Khách trả"**, **"Thưởng tặng"**, **"Tổng dùng được"** → **"Xác nhận nạp <số tiền>"**. Số tiền nạp từ 1.000đ đến 100.000.000đ.
6. Kết quả: ví tăng; **Thu Chi tự ghi thu** "Nạp ví: …" vào đúng quỹ đã chọn. Bonus do máy chủ tính theo gói nạp; nếu gói vừa đổi, app báo "Gói nạp vừa thay đổi…" — đóng và mở lại màn nạp.
7. Lỗi hiện **ngay trong bảng nạp** (ô đỏ phía trên nút). Khi đang gửi, bảng không đóng được.
8. Mất mạng lúc nạp: app báo "Chưa rõ đã nạp hay chưa do mất kết nối. Bấm "Xác nhận nạp" lại ngay trên bảng này — hệ thống không nạp trùng."
   - **Không đóng bảng**, bấm lại **"Xác nhận nạp"** ngay trên bảng đó — hệ thống không nạp trùng.
   - Nếu lần bấm trước thực ra đã nạp xong mà nhân viên đã đổi số tiền/quỹ, app báo "Lần bấm trước (lúc mất mạng) ĐÃ nạp với số tiền/quỹ cũ. Đóng bảng, kiểm tra số dư ví của khách trước khi nạp thêm."
   - **Đã đóng bảng rồi mở lại = một lần nạp mới.** Luôn kiểm tra số dư ví của khách trước khi nạp lại, để tránh nạp hai lần.

### 5. Phần thưởng đổi điểm
1. Tab **"Thưởng"** → **+** → **"Thêm phần thưởng"**.
2. **"Chọn mẫu nhanh"** (☕ Cà phê miễn phí 50 điểm, 🥤 Nước uống 30, 🎁 Giảm 10% 100, 🍜 Phần ăn 200, 🎂 Bánh sinh nhật 150) hoặc tự nhập **"Tên phần thưởng *"**, **"Điểm yêu cầu *"**, mô tả → **"Thêm phần thưởng"**.

> Danh sách phần thưởng hiện **chỉ để tham khảo**: chưa có nút đổi thưởng trừ điểm. Muốn trừ điểm cho khách, dùng **"Dùng điểm"** khi thanh toán (trừ tiền theo 1.000đ/điểm).

### 6. Tạo mã giảm giá (voucher) — Chủ quán / Quản lý
1. Tab **"Khuyến mãi / Voucher"** → **"Thêm mã mới"** → **"Thêm mã giảm giá mới"**.
2. **"Mã Voucher (Viết liền không dấu)"**, **"Mô tả ngắn gọn"**.
3. **"Loại giảm giá"**: **"Phần trăm (%)"** hoặc **"Tiền mặt (đ)"** → **"Mức giảm"**.
4. **"Đơn tối thiểu (đ)"**, **"Mức giảm tối đa (đ) - Để trống nếu không giới hạn"**, hạn dùng (**"Chọn ngày"**).
5. **"Lưu Voucher"**. Sửa / tắt / xoá mã trong danh sách (**"Xóa mã giảm giá"**).
6. Nhân viên áp mã khi thanh toán: **"Khuyến mãi / Voucher"** → **"Chọn mã"** → **"Áp dụng"**. Máy chủ kiểm lại mã còn hiệu lực, hạn dùng và đơn tối thiểu.

## Lỗi thường gặp
| Thấy gì | Vì sao | Làm gì |
|---|---|---|
| "Không tìm thấy khách hàng" khi thanh toán | SĐT gõ khác lúc lưu, hoặc khách chưa có | Kiểm tra số; thêm khách ở module |
| Không thấy phần "Điểm thưởng" khi thanh toán | Khách chưa có điểm, hoặc đang chọn trả bằng ví | Bỏ chọn ví, hoặc tích thêm điểm |
| "⚠️ Ví không đủ — cần thêm tiền mặt" | Ví không đủ (bonus chỉ dùng tối đa 15%) | Chọn phương thức khác |
| "Đơn hàng chưa đạt giá trị tối thiểu để áp dụng voucher" | Chưa đủ đơn tối thiểu | Thêm món hoặc gỡ mã |
| "Mã giảm giá đã hết hạn sử dụng" / "…chưa đến thời gian áp dụng" / "…đang bị vô hiệu hóa" | Mã ngoài thời gian / đã tắt | Kiểm tra mã ở tab Voucher |
| "Không có voucher khả dụng lúc này" | Chưa có mã còn hiệu lực | Tạo mã mới |
| "Quyền truy cập bị từ chối" ở tab Voucher | Không phải Chủ quán / vai trò tên đúng "Quản lý" (vd "Quản lý nhà hàng" cũng bị chặn) | Nhờ Chủ quán hoặc Quản lý |
| "Chưa rõ đã nạp hay chưa do mất kết nối…" | Mất mạng lúc gửi | Giữ nguyên bảng, bấm "Xác nhận nạp" lại ngay — không nạp trùng |
| "Lần bấm trước (lúc mất mạng) ĐÃ nạp với số tiền/quỹ cũ…" | Lần trước đã nạp xong, sau đó đổi số tiền/quỹ | Đóng bảng, kiểm tra số dư ví rồi mới nạp thêm |
| "Bạn không có quyền thu tiền (pos.checkout)" | Thiếu quyền Thanh toán hoá đơn | Nhờ Chủ quán / Quản lý nạp |
| "Số tiền nạp phải là số nguyên từ 1.000đ đến 100.000.000đ" | Số tiền ngoài giới hạn | Nhập lại số tiền |
| "Gói nạp vừa thay đổi…" | Chủ quán vừa sửa gói nạp | Đóng và mở lại màn nạp |

## Liên quan module khác
- **Bán hàng / Quản lý Bàn**: gắn khách, tích/dùng điểm, voucher; trả bằng ví (chỉ Bán hàng).
- **Thu Chi**: nạp ví ghi thu; bán bằng ví ghi quỹ "ví" (xem lưu ý tính hai lần ở bài Thu Chi).
- **Cài đặt**: mức tích điểm.
- **Báo cáo → Voucher**: thống kê mã đã dùng.

## Ghi chú cho Chủ Quán (không đưa cho khách)

### Khác biệt với bản app cũ (cho Chủ Quán)
- App cũ không nạp ví lần đầu được (không có nút "Nạp ví cho khách"), không có lựa chọn "Khách trả bằng: Chuyển khoản" và luôn ghi khoản thu nạp ví vào quỹ Tiền mặt.

1. **[ĐÃ SỬA 22/10 — máy chủ ĐÃ áp `20261022_nap_vi_an_toan_v1.sql` lúc 21:48; app mới chưa phát hành]** Nạp ví qua RPC `topup_customer_wallet_v1` (khoá dòng, bonus tính ở máy chủ, kiểm quyền thu tiền qua `qr_staff_ctx_v4`, chọn quỹ cash/bank). Mã chống trùng: **một mã cho mỗi lần mở bảng nạp** (`'topup:<uuid>'`), không gắn với số tiền/quỹ/thời hạn; bảng không vuốt đóng được và không đóng được khi đang gửi; lỗi hiện trong bảng. Lỗi cũ: nạp chạy ở client kiểu đọc rồi ghi (`topUpWallet`), hai máy nạp cùng lúc có thể mất một lần nạp, bấm lại khi mạng chập chờn có thể nạp hai lần. **Còn:** đóng bảng rồi mở lại là mã mới → vẫn có thể nạp trùng nếu nhân viên không kiểm số dư; client cũ vẫn sửa thẳng số dư được (đợt sau chặn).
2. **[ĐÃ SỬA cùng mục 1]** Trước đây nạp ví luôn ghi quỹ Tiền mặt; nay chọn Tiền mặt / Chuyển khoản.
2a. **Hạn bonus — cần Chủ Quán quyết định** (hành vi có từ trước, chưa đổi): chọn một thời hạn khi nạp sẽ đặt lại hạn của **toàn bộ** số dư bonus (kể cả bonus cũ sắp hết hạn được kéo dài, hoặc bonus cũ hạn dài bị rút ngắn); chọn "Không hạn" thì giữ hạn hiện có. Cần chốt: mỗi lần nạp có hạn riêng, hay giữ như hiện tại.
3. **Phần thưởng (tab Thưởng) chưa đổi được**: không có luồng trừ điểm theo phần thưởng.
4. **Mức quy đổi điểm khi dùng (1.000đ/điểm)** và **giới hạn bonus ví (15%)** không có chỗ chỉnh trong app.
5. **Hạng khách** chỉ hiển thị, không gắn ưu đãi.
6. Quản lý Bàn không trả được bằng ví (đã nêu ở bài Quản lý Bàn).
- **[SỬA 23/10 — chưa phát hành] Lỗi giới hạn 1.000 dòng:** máy chủ chỉ trả 1.000 dòng mỗi lần đọc; màn này trước đây đọc cả bảng của quán rồi lọc ở máy → quán lớn (KAY) nhận toàn dòng cũ. Danh sách khách, ô chọn khách ở Bán hàng, "khách nhiều điểm", thống kê điểm, lịch sử điểm/ví của quán > 1.000 khách bị thiếu (hiện chỉ các quán thử: 38.594 / 16.042 / 1.101 khách; quán thật đều < 1.000). Nay tải đủ theo trang; "khách nhiều điểm" sắp ở máy chủ. Quán rất nhiều khách (hàng chục nghìn) sẽ tải chậm — khi có quán thật như vậy cần chuyển tìm khách sang máy chủ.
