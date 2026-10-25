---
module: staff
ten: Nhân viên & Phân quyền
phien_ban: 1.0.5+20
cap_nhat: 2026-10-26
nguon:
  - lib/screens/nhan_vien_screen.dart (danh sách, hồ sơ, gán vai trò, xoá, tab Phân quyền, ca làm việc, hành động nhạy cảm)
  - lib/screens/staff_password_dialog.dart, lib/screens/staff_name_dialog.dart, lib/core/repositories/staff_password_repository.dart (Chủ quán đặt lại mật khẩu / đổi tên nhân viên)
  - lib/screens/role_manager_screen.dart (Vai trò & Phân quyền, gợi ý vai trò F&B, chống trùng, khoá owner)
  - lib/core/services/staff_service.dart (kDefaultPerms, kAllActions, deriveActionPermsFromModules, getEffectiveActionPermissions)
  - lib/screens/settings_screen.dart (Mã kết nối nhân viên, Mã PIN duyệt nhanh), lib/screens/store_setup_screen.dart (Kết nối vào quán)
  - .agents/workflows/qn.md mục "Data, quyền và audit"
---

# Nhân viên & Phân quyền

> Thêm nhân viên vào quán bằng mã quán, gán vai trò, chọn module mỗi vai trò được dùng, cấu hình ca làm việc và mã PIN duyệt nhanh.

## Ai dùng được
- **Chủ quán**: toàn quyền — duyệt, đổi vai trò, xoá bất kỳ ai (trừ chính mình); thấy thêm tab **"Phân quyền"**.
- **Quản lý**: điều phối nhân viên cấp dưới (Thu ngân, Phục vụ, Bếp, Kho, vai trò tuỳ chỉnh). **Không** gán vai trò Quản lý hoặc Chủ quán, **không** xoá Quản lý khác hay Chủ quán. Máy chủ cũng kiểm hai luật này.
- Nhân viên khác: chỉ xem danh sách.

## Cách nhân viên vào quán (không có nút "Thêm nhân viên")
1. Chủ quán mở **Cài đặt → "Mã kết nối nhân viên"** ("Chia sẻ mã này để thêm thành viên vào quán") → sao chép mã quán (dạng `QN-…`) gửi nhân viên.
2. Nhân viên cài app, **đăng ký / đăng nhập** bằng số điện thoại + mật khẩu (trên iPhone chỉ đăng nhập; tạo tài khoản ở Android/Web/Windows).
3. Chọn **"Nhập mã quán"** → điền **"Mã quán"** → **"Kết nối vào quán"**.
4. Nhân viên mới hiện trong danh sách với nhãn **"⚡ MỚI"** / nhóm **"Chưa phân vai trò"**. Chủ quán / Quản lý bấm **"Cấp quyền"** để gán vai trò.

## Màn hình gồm những gì
- **"Nhân Viên"** — "N thành viên • M đang làm ca"; nút **"Quản lý vai trò"**.
- Tab **"Nhân viên"**: ô **"Tìm theo tên hoặc SĐT..."**, lọc theo vai trò và **"Chưa phân vai trò (n)"**; mỗi người hiện vai trò, SĐT, **"Đang làm ca" / "Chưa vào ca"**.
- Tab **"Phân quyền"** (chỉ Chủ quán): danh sách vai trò (số module, nút **"Chỉnh"**), **"Ca làm việc"**, **"Hành động nhạy cảm"**.

## Các việc thường làm

### 1. Gán / đổi vai trò cho nhân viên
1. Chạm nhân viên (hoặc **"Cấp quyền"** với người mới).
2. Mục **"Vai trò & Quyền hạn"** → **"Chọn vai trò cho nhân viên..."** → **"Lưu vai trò"** → "✅ Đã cập nhật vai trò".
3. Nhân viên đang dùng app thấy ngay "🔄 Vai trò của bạn đã đổi sang: …" / "⚡ Quyền truy cập của bạn vừa được cập nhật".

### 2. Hồ sơ nhân viên
- Trong chi tiết: **"Mô tả công việc"**, **"Ngày bắt đầu"** → **"Lưu hồ sơ"**.
- **"Cấu hình lương (Module Lương)"** → **"⚙️ Mở Cấu Hình Lương Nâng Cao"** (lương giờ/ngày/tháng, OT, đi muộn — xem bài Lương).

### 3. Xoá nhân viên khỏi quán
- Chi tiết nhân viên → **"Xóa"** → "Xoá <tên>?" → **"Xoá"**. Người đó mất quyền vào quán ngay; nếu đang mở app sẽ thấy "Bạn đã bị xoá khỏi quán".

### 3b. Đặt lại mật khẩu cho nhân viên (chỉ Chủ quán)
1. Nhân viên → chọn tên nhân viên → **"Đặt lại mật khẩu"** (nút nằm dưới "Lưu vai trò" / "Xóa", chỉ Chủ quán thấy).
2. Gõ **"Mật khẩu mới"** (ít nhất 8 ký tự) và **"Nhập lại mật khẩu mới"** → **"Lưu mật khẩu mới"**.
3. Báo mật khẩu mới **trực tiếp** cho nhân viên. Mật khẩu cũ hết dùng ngay; máy nhân viên đang đăng nhập sẽ phải đăng nhập lại khi phiên hết hạn.
- Quản lý **không** đặt lại được mật khẩu. Không đặt lại được mật khẩu của Chủ quán hay của chính mình (tự đổi: Cài đặt → **"Đổi mật khẩu"**).
- Nhân viên còn làm ở quán của **người khác**, hoặc **chưa từng tự đăng nhập vào quán bằng app** → không đổi được từ đây → nhờ hỗ trợ qua Cài đặt → **"Gửi phản hồi"** hoặc Hotline.
- Chủ quán quên mật khẩu của chính mình → Cài đặt → **"Khôi phục / Quên mật khẩu"** (Hotline gọi lại đúng số đăng ký, cấp mật khẩu tạm).

### 3c. Đổi tên nhân viên (chỉ Chủ quán) và tự đổi tên của mình
1. Nhân viên → chọn tên nhân viên → **"Đổi tên"** (cạnh nút "Đặt lại mật khẩu", chỉ Chủ quán thấy).
2. Gõ tên mới (2–50 ký tự) → **"Lưu tên"**. Tên mới hiện ở danh sách nhân viên, chấm công, lương…
   Máy nhân viên đang mở app thấy tên mới sau khi đăng nhập lại.
- Cùng điều kiện như đặt lại mật khẩu: Quản lý **không** đổi được; nhân viên còn làm ở quán của **người khác** hoặc **chưa từng tự đăng nhập vào quán bằng app** → nhân viên tự đổi.
- **Ai cũng tự đổi tên của mình** (kể cả Chủ quán): Cài đặt → **"Tên hiển thị"** → gõ tên mới → lưu.

### 4. Tạo / sửa vai trò
1. **"Quản lý vai trò"** → màn **"Vai trò & Phân quyền"**.
2. Cách nhanh — **"Gợi ý nhanh"** / **"Đề xuất vai trò F&B thực tế"** (1-chạm), chia 4 nhóm:
   - Vận hành Quầy & Bàn: Thu ngân, Phục vụ, Tiếp thực (Runner), Lễ tân.
   - Bếp & Pha Chế: Bếp chính, Phụ bếp, Pha chế (Barista).
   - Quản Trị & Kho Vận: Quản lý nhà hàng, Thủ kho.
   - Văn Phòng & Phụ Trợ: Kế toán / Thu chi, Bảo vệ, Tạp vụ.
   Mỗi gợi ý kèm mô tả công việc và module gợi ý; vai trò đã có hiện "✓ Đã có".
3. Tự tạo: **"Tạo vai trò"** → **"Tên vai trò"**, **"Biểu tượng"**, **"Màu vai trò"**, **"Quyền truy cập module"** → **"Tạo vai trò"**.
4. App tự nhận diện tên (có dấu/không dấu/viết tắt/tiếng Anh) ra loại vai trò, hiện trong ngoặc vuông: Thu ngân [cashier], Phục vụ [waiter], Bếp [kitchen] (màn hiện "Bếp / Bar"), Kho [stock], Quản lý [manager]. Tên không nhận ra được (vd "Pha chế", "Bar") hiện "tùy chỉnh [<tên viết thường>]".
   - Trùng tên vai trò đã có: bị chặn ("⚠️ Trùng lặp…").
   - Tên mang nghĩa Chủ quán: **không tạo được** ("⛔ Không thể tạo vai trò "Chủ quán" (owner)").
5. Sửa module một vai trò: chạm vai trò (hoặc **"Chỉnh"** ở tab Phân quyền) → bật/tắt **"Module được phép truy cập"** → **"Lưu quyền"**.
6. Xoá vai trò: **"Xoá vai trò?"** → **"Xoá"**. Nhân viên đang mang vai trò đó được chuyển sang **vai trò đầu tiên còn lại trong danh sách mà không phải Chủ quán/Quản lý**; nếu không còn vai trò nào như vậy, app **không cho xoá** và nhắc đổi vai trò cho từng nhân viên trước.

**Module chọn được cho vai trò**: Bán hàng, Kho hàng, Kho CN, Quản lý bàn, Bếp, Thu chi, Báo cáo, Điểm thưởng, Nhân viên, Chấm công, Tính lương, Vận Hành, Nhật Ký Log, Máy in.

### 5. Module quyết định quyền thao tác
Bật module nào cho vai trò thì vai trò đó **tự có** các quyền đi kèm:

| Module | Quyền tự có |
|---|---|
| Bán hàng | Thanh toán, huỷ đơn, giảm giá, sửa giá, xem lịch sử đơn (vai trò **Phục vụ**: không kèm huỷ đơn, sửa giá) |
| Quản lý bàn | Thêm/sửa bàn & khu vực, thanh toán |
| Kho hàng / Kho CN | Sửa số lượng tồn, xoá sản phẩm kho |
| Thu chi | Xem toàn bộ thu chi |
| Báo cáo | Xem báo cáo doanh thu |
| Tính lương | Xem toàn bộ lương, thiết lập lương, chốt lương, ghi nhận đóng góp |
| Máy in | Quản lý Máy chủ in |

- **Chủ quán và Quản lý** luôn có mọi quyền thao tác.
- Vai trò tên có "thu ngân"/"quầy" luôn có thanh toán, giảm giá, xem lịch sử đơn.

### 6. Hành động nhạy cảm (tab Phân quyền)
- **"Chọn vai trò"** → bật/tắt từng hành động → **"Lưu quyền cho "<vai trò>""** → "Đã lưu quyền cho "<vai trò>"".
- Màn chỉ hiện công tắc của **module mà vai trò đã được giao** (ví dụ vai trò không có module Kho thì không thấy công tắc Kho).
- Công tắc hiện **đúng quyền thực tế** của vai trò (gồm cả quyền có nhờ module). **Tắt** một công tắc rồi lưu là nhân viên vai trò đó **mất quyền** ngay cả khi vẫn có module. Cài đặt lưu theo tên vai trò của quán (ví dụ "Phục vụ") áp đúng cho nhân viên mang vai trò đó.
- Tác dụng thực tế của một số công tắc:
  - **Huỷ đơn hàng**: hiện chỉ chặn nút **"Xóa hết"** giỏ hàng chưa gửi ở Bán hàng. Huỷ món đã gửi bếp / huỷ bàn vẫn theo luồng duyệt PIN của Quản lý.
  - **Sửa giá bán**, **Áp dụng giảm giá**, **Xem toàn bộ thu chi**: **chưa có tác dụng** — app chưa kiểm ở đâu; công tắc có ghi chú màu cam "Chưa có tác dụng…".
  - **Thanh toán hoá đơn**: tắt thì vai trò đó không thu tiền được ở **Quản lý Bàn** (riêng Thu ngân vẫn thu được) và ở **đơn QR mang đi**; màn **Bán hàng** chưa kiểm quyền này nên vẫn thanh toán được. Ghi chú cam: "Chỉ chặn thu tiền ở Quản lý Bàn (Thu ngân vẫn thu được) và đơn QR mang đi; màn Bán hàng chưa kiểm quyền này."
- Vai trò **Phục vụ** có Bán hàng mặc định không có Huỷ đơn hàng và Sửa giá bán — tác dụng thực tế duy nhất là **không bấm được "Xóa hết"** giỏ hàng. Vai trò khác như "Tiếp thực (Runner)", "Lễ tân" không tính là Phục vụ.
- Chủ quán và Quản lý luôn đủ quyền — chọn vai trò Quản lý sẽ thấy dòng "Chủ quán và Quản lý luôn có đủ mọi quyền — không tắt được ở đây." thay cho các công tắc.
- Nhân viên cần **mở lại app** (hoặc đăng nhập lại) để nhận quyền mới.

### 7. Ca làm việc
1. Tab Phân quyền → **"Ca làm việc"** ("Nhân viên ca nào thấy việc ca đó") → **"Thêm ca"**.
2. Chọn nhanh **Ca Sáng 6–14h, Ca Chiều 14–22h, Ca Tối 17–23h, Ca Khuya 22–6h** hoặc nhập **"Tên ca"**, **"Bắt đầu"**, **"Kết thúc"**, **"Màu ca"** → **"✓ Tạo ca"**.
3. Gán người: trong ca → thêm nhân viên ("Thêm vào <ca>", chọn người chưa có ca). Ca dùng cho việc cần làm theo ca ở module Vận Hành.

### 8. Mã PIN duyệt nhanh (Chủ quán / Quản lý)
- **Cài đặt → "Mã PIN duyệt nhanh (6 số)"** → nhập **"Mã PIN mới (6 chữ số)"** và xác nhận → **"Lưu mã PIN 6 số"**.
- Dùng khi nhân viên huỷ món đã gửi bếp hoặc huỷ bàn: Quản lý nhập PIN ngay trên máy nhân viên. PIN **chỉ để duyệt**, không dùng đăng nhập.

## Lỗi thường gặp
| Thấy gì | Vì sao | Làm gì |
|---|---|---|
| Nhân viên kết nối mã quán mà không thấy module nào | Chưa được gán vai trò | Chủ quán/Quản lý bấm "Cấp quyền" |
| "Quản lý không được phép gán vai trò Quản lý" | Luật phân cấp | Nhờ Chủ quán |
| "Quản lý không được phép xóa Quản lý khác" | Luật phân cấp | Nhờ Chủ quán |
| "Không thể gán vai trò Chủ quán" | Vai trò Chủ quán bị khoá | — |
| "Vui lòng chọn vai trò cho nhân viên" | Chưa chọn vai trò khi lưu | Chọn vai trò |
| "⚠️ Chưa có vai trò nào phù hợp trong quán." | Quán chưa tạo vai trò | Tạo vai trò ở "Quản lý vai trò" |
| Tắt quyền rồi mà nhân viên vẫn làm được | Nhân viên chưa mở lại app; hoặc công tắc đó chưa có tác dụng (Sửa giá bán, Áp dụng giảm giá, Xem toàn bộ thu chi), hoặc chỉ chặn một phần (Thanh toán hoá đơn không chặn màn Bán hàng và không chặn Thu ngân thu tiền bàn; Huỷ đơn hàng chỉ chặn "Xóa hết" giỏ hàng) | Nhắc nhân viên mở lại app (hoặc đăng nhập lại); xem ghi chú cam trên công tắc |
| Phục vụ không bấm được "Xóa hết" giỏ hàng | Mặc định Phục vụ không có quyền Huỷ đơn hàng | Chủ quán bật "Huỷ đơn hàng" ở "Hành động nhạy cảm" |
| Không thấy công tắc nào đó ở "Hành động nhạy cảm" | Vai trò chưa được giao module tương ứng | Giao module cho vai trò trước |
| Nhân viên thấy "Bạn đã bị xoá khỏi quán" | Đã bị xoá | Liên hệ quản lý |
| Không thấy nút "Đặt lại mật khẩu" | Chỉ Chủ quán thấy; không hiện cho Chủ quán / chính mình | Nhờ Chủ quán |
| Không thấy nút "Đổi tên" | Chỉ Chủ quán thấy; không hiện cho Chủ quán / chính mình | Tự đổi: Cài đặt → "Tên hiển thị" |
| "Nhân viên này còn làm ở quán khác…" | Người đó thuộc cả quán của người khác | Gửi phản hồi / gọi Hotline |
| "Mật khẩu phải từ 8 đến 72 ký tự." / "Hai lần nhập mật khẩu không giống nhau." | Nhập sai | Gõ lại |

## Liên quan module khác
- **Mọi module**: quyền vào module theo vai trò.
- **Chấm công / Lương**: ca, cấu hình lương theo nhân viên.
- **Quản lý Bàn**: PIN duyệt huỷ món/huỷ bàn.
- **Vận Hành**: việc theo ca.
- **Cài đặt**: mã kết nối nhân viên, mã PIN.

## Ghi chú cho Chủ Quán (không đưa cho khách)

### Khác biệt với bản app cũ (cho Chủ Quán)
- Trước bản 22/10/2026: tắt công tắc ở Hành động nhạy cảm không làm mất quyền nếu vai trò vẫn có module đi kèm. Tắt quyền rồi mà nhân viên vẫn làm được thì kiểm tra máy nhân viên còn chạy app cũ không — cập nhật app.
- Trước bản 22/10/2026: xoá vai trò có thể không chuyển được nhân viên của các vai trò chuẩn (Thu ngân, Phục vụ, Bếp, Kho) — trên máy còn app cũ, đổi vai trò cho từng người trước khi xoá.

1. **[ĐÃ SỬA trong app 22/10 — chưa phát hành]** Lỗi cũ: "Hành động nhạy cảm" chỉ cộng thêm quyền (`merged = override ∪ derivedPerms`), màn hình chỉ đọc phần đã lưu nên công tắc "tắt" mà nhân viên vẫn có quyền nhờ module. Nay: màn hiện quyền thực tế; lưu thì quyền-có-nhờ-module-mà-bị-tắt ghi vào `app_settings.action_perms_deny_<vai trò>`; `getEffectiveActionPermissions` trừ danh sách này ở mọi nhánh. **Còn:** máy chủ không đọc danh sách tắt — tắt "Thanh toán hoá đơn" chỉ chặn ở app (Bàn trừ Thu ngân, QR mang đi; POS quầy không kiểm `pos.checkout`). `qr_staff_ctx_v4` cho thu tiền nếu: owner/manager/admin, mã `cashier`, tên chứa "thu ngân"/"quầy"/"quản lý", vai trò có module **`pos`** (không xét `ban`), hoặc `action_perms_<mã vai trò>` chứa `pos.checkout`. Lưu ý: máy chủ so `store_roles.name` với **mã** vai trò của tài khoản, nên "Phục vụ" (mã `waiter`) có Bán hàng vẫn có thể bị từ chối thu tiền/nạp ví. Quyền vẫn lưu ở `app_settings` và **mọi nhân viên ghi được** các khoá `action_perms_*` qua API (xem viec-can-sua P0 #39) (quy chuẩn `qn.md` muốn tách). **Thêm (rà lại 22/10):** màn Phân quyền lưu theo tên vai trò của quán ("Phục vụ", "Thu ngân") nhưng tài khoản giữ mã vai trò ("waiter", "cashier") nên cài đặt đã lưu (cả bật thêm lẫn tắt) không bao giờ được đọc cho các tài khoản này; nay `roleSettingKeys` tìm theo mã vai trò → tên vai trò của quán trùng tên/cùng loại → loại chuẩn. Hệ quả: các quán đã từng bật thêm quyền cho "Thu ngân" (3 quán) sẽ thấy quyền đó có hiệu lực khi lên app mới. Cài đặt theo tên vai trò của quán được ưu tiên hơn cài đặt cũ lưu theo mã vai trò.
2. **[ĐÃ SỬA trong app 22/10 — chưa phát hành; đính chính]** Vai trò Phục vụ (`waiter`: "Phục vụ", "Chạy bàn", "waiter"…) có Bán hàng mặc định không có `pos.cancel_bill` và `pos.edit_price`. **Nhưng** `pos.edit_price` không được kiểm ở đâu trong app, còn `pos.cancel_bill` chỉ chặn nút "Xóa hết" giỏ chưa gửi ở POS → tác dụng thực tế duy nhất: Phục vụ không bấm được "Xóa hết". Không phải "Phục vụ không huỷ bill / sửa giá được nữa". Production lúc sửa: 1 vai trò Phục vụ có Bán hàng.
2a. **Công tắc chưa có tác dụng** (không có chỗ nào trong app kiểm): `pos.edit_price` (Sửa giá bán), `pos.apply_discount` (Áp dụng giảm giá — POS cũng chưa có giảm giá tay), `finance.view_all` (Xem toàn bộ thu chi). App hiện ghi chú cam "Chưa có tác dụng…". `pos.checkout` chỉ được kiểm ở `ban_screen.dart:4223` (bỏ qua với owner/manager/cashier) và `qr_order_review_sheet.dart:680,983`; POS quầy không kiểm.
2b. Màn chỉ hiện công tắc khi tiền tố quyền khớp module của vai trò (`nhan_vien_screen.dart` ~3884). **[ĐÃ SỬA trong app 23/10 — chưa phát hành]** "Quản lý Máy chủ in" nay hiện khi vai trò có module In hoá đơn (`bill_printer`); "Thanh toán hoá đơn" hiện cả với vai trò chỉ có module Bàn. **Còn:** vai trò tên "Thu ngân" luôn được thêm `pos.checkout` / `printer.manage_server` dù không có module tương ứng — khi đó công tắc không hiện nên không tắt được (hành vi cũ). Vai trò Quản lý vẫn được liệt kê nhưng màn hiện dòng nhắc thay cho công tắc, vì `getEffectiveActionPermissions` luôn trả mọi quyền cho manager.
3. Danh sách module của vai trò **không có QR Gọi Món và Báo cáo chuỗi** — các module này theo công tắc quán / Chủ quán, không phân theo vai trò.
4. Vai trò tên chứa "thu ngân" tự có **Quản lý Máy chủ in**.
5. Có tab **"Ca/Lịch sử ca"** (`_ShiftsTab`) đã viết nhưng không gắn vào màn Nhân viên.
6. **Xoá vai trò** (`StaffService.deleteRole`): bản cũ chuyển nhân viên bằng `.eq('role', roleName)` nên tài khoản giữ mã vai trò (`waiter`, `cashier`…) không được chuyển, và vai trò thay thế là vai trò đầu danh sách (có thể là Quản lý). App bản mới (sau 22/10): khớp cả tên lẫn mã vai trò, không bao giờ chuyển vào owner/manager, không còn vai trò an toàn thì chặn xoá.
7. **Quản lý gán được vai trò tự tạo kiểu "Quản lý nhà hàng"**: máy chủ (`admin_update_staff_role_v4`) chỉ chặn đúng `manager`/`owner` sau `normalize_role_code_v4` (so khớp nguyên chuỗi), nhưng app coi mọi tên chứa "quản lý" là manager (`canonicalRole`) → vai trò này có đủ mọi quyền thao tác trong app. Xem viec-can-sua P1 #47.
8. **[KIỂM 23/10 — câu cũ SAI, đã bỏ khỏi bài]** Bài từng ghi "quyền dữ liệu nhạy cảm qua AI Boom không tự cấp cho Quản lý". Code không có quyền nào cho Boom: ai mở được Boom (nút giữa thanh dưới, mọi vai trò) đều hỏi được doanh thu hôm nay, so sánh, món bán chạy/chậm, hàng sắp hết, ai đang trong ca (`boom_read_only_data_service.dart` đọc thẳng `orders`, `products`, `staff_shifts` theo quán). Ghi ở viec-can-sua #52.
