---
module: bill_printer
ten: In Hoá Đơn
phien_ban: 1.0.5+20
cap_nhat: 2026-10-31
nguon:
  - lib/modules/bill_printer/screens/bill_printer_hub.dart
  - lib/modules/bill_printer/screens/print_rules_screen.dart
  - lib/modules/bill_printer/screens/printer_settings_screen.dart
  - lib/modules/bill_printer/screens/print_design_screen.dart (+ bill_designer_v2, kitchen_ticket_designer, label_designer, template_gallery_screen)
  - lib/modules/bill_printer/providers/printer_settings_provider.dart (shouldAutoPrintLocally, claimReceiptPrint)
  - lib/modules/bill_printer/screens/bill_preview_screen.dart (StationPrinterDispatcher.printBill)
  - lib/modules/bill_printer/utils/qn_queue_resolver.dart
  - nhat_ky.md (Công cụ Cài máy in Windows, 18/10/2026; Sunmi không in, 14/10/2026)
---

# In Hoá Đơn

> Cài máy in, quy định phiếu nào in ra máy nào, thiết kế mẫu hoá đơn / phiếu bếp / tem dán ly, mở két tiền.

## Ai dùng được
- Người có module **In Hoá Đơn** trong vai trò (mặc định **tắt**, Chủ quán bật trong Modules). Quán mới tạo, các vai trò có sẵn (Thu ngân, Nhân viên, Bếp) đều **chưa** có module này; Chủ quán thêm module cho vai trò bất kỳ ở **Nhân viên → Vai trò** (mẫu gợi ý "Thu ngân" khi tạo vai trò mới có sẵn In Hoá Đơn).
- Đặt / chuyển **Máy chủ in** cần quyền **"Quản lý Máy chủ in"** (đi kèm module In Hoá Đơn).
- Khác nhau theo nền tảng:
  - **Windows, Android (Sunmi), Mac**: tự in được.
  - **Trình duyệt Web**: **không tự in**; chỉ in thủ công khi bấm nút in. Muốn bill từ web tự ra giấy, cần một máy Windows/Sunmi làm **Máy chủ in**.

## Màn hình gồm những gì
Mở module **In Hoá Đơn** từ Trang chủ:
- Dòng **"Đang in theo: …"** ở đầu trang cho biết quán in theo cách nào: "4 trạm (Cấu Hình Trạm In)" hoặc "Máy In & Luật In – X máy in, Y luật". Nếu hiện **khung đỏ** "Chưa có luật nào in ra máy in đang bật, nên KHÔNG phiếu nào được in…" thì vào "Máy In & Luật In" thêm luật hoặc bật máy in.
- **"Cấu Hình Trạm In"** — cách cũ (4 trạm: Thu ngân, Bếp nóng, Quầy bar (đồ uống), Tem dán ly) + các công tắc tự động + **Máy chủ in**. Quán đã dùng luật in thì màn này chỉ còn **tự động in, tự mở két và máy chủ in** (tiêu đề "Tự Động In & Máy Chủ In").
- **"Máy In & Luật In"** — phần nâng cao: khai báo máy in và luật in theo loại phiếu, số bản, máy dự phòng.
- **"Thiết Kế Mẫu In"** — mẫu Hoá Đơn, Bếp Nóng, Bếp Bar, Tem Dán Ly và mẫu dựng sẵn.
- **"Xem Trước Nhanh"** hoá đơn thu ngân và nút **"Đặt lại mẫu hoá đơn"** (chỉ đưa mẫu hoá đơn thu ngân về mặc định; máy in, phiếu bếp, tem không đổi).

### Hai cách cấu hình — dùng cách nào?
- Khi quán **đã lưu "Máy In & Luật In"** (chỉ cần đã khai báo **một máy in**, kể cả chưa có luật nào), app in **theo luật**; máy in chọn ở 4 trạm cũ **không còn tác dụng**. Màn Cấu Hình Trạm In khi đó ẩn 4 trạm và báo: "Máy in của quán đang chọn ở "Máy In & Luật In". Ở đây chỉ còn: tự động in, tự mở két và máy chủ in." Các công tắc tự động và Máy chủ in vẫn áp dụng.
- Khi **chưa khai báo máy in và chưa có luật** ở "Máy In & Luật In", app in theo 4 trạm cũ. Đã thêm máy in mà chưa tạo luật thì **không phiếu nào in**: tạo luật ngay sau khi thêm máy in.
- Khuyến nghị: dùng **Máy In & Luật In**. Quán đang dùng trạm cũ có thể bấm **"Dựng từ cấu hình hiện tại"** để chuyển sang mà không phải khai báo lại.

## Các việc thường làm

### 1. Cài máy in trên máy Windows (lần đầu)
1. Cài Quán Nhỏ POS cho Windows trước.
2. Cắm máy in (USB hoặc mạng LAN).
3. Tải **Công cụ Cài máy in** ở trang `quannho.lpm.vn/cai-may-in.html`, chạy và bấm nút **"CÀI MÁY IN"**. Công cụ tự dò máy in, đặt tên `QN-…` theo vai trò (Thu ngân → Bếp → Bar → Tem) và in thử một tờ nhận biết.
4. Mở POS: các trạm đang dùng máy in hệ thống sẽ **tự dùng máy `QN-…`**, không cần chọn lại.

> Nếu cắm nhiều máy, công cụ có thể đoán nhầm vai trò — dùng chức năng đổi vai trò trong công cụ. Máy in không cài được: xem mục "Các phương án khác" trên trang tải công cụ (`quannho.lpm.vn/cai-may-in.html`).

### 2. Thêm máy in (Máy In & Luật In → tab "Máy in")
1. Bấm **"Thêm máy in"**.
2. **"Tên máy in (vd: Bill quầy, Bếp nóng)"**.
3. **"Cách kết nối"**:
   - "Máy in hệ thống (Windows/Mac)" — gõ **đúng tên máy in** như trong Windows/Mac; để trống sẽ **không in được**.
   - "Máy in mạng LAN / Wi-Fi (IP)" — nhập **"Địa chỉ IP"** (vd 192.168.1.242) và **"Cổng"** (thường 9100).
   - "Máy in tích hợp Sunmi" — chỉ in được trên đúng thiết bị Sunmi (Android).
4. **"Khổ giấy"**: 50 / 58 / 80 mm.
5. Tuỳ chỉnh: **tỉ lệ cỡ chữ** (giảm khi bill bị cụt mép), **độ đậm** (Sunmi), **"Chữ đậm dạng bán đậm"**, **"Tự cắt giấy"**, **"Có két tiền gắn kèm"**.
6. Bấm **"Xong"**, rồi **"Lưu"** ở góc trên.
7. Bấm **"In thử"** ở máy in vừa thêm để kiểm giấy và kết nối (in thử được cả khi chưa bấm Lưu; không lưu gì).

### 3. Tạo luật in (tab "Luật in")
Luật nói: *loại phiếu nào → in ra máy nào → mấy bản*.
1. Bấm **"Thêm luật"** (phải có ít nhất một máy in).
2. **"Loại phiếu"**: Hóa đơn thanh toán, Phiếu tạm tính, Phiếu bếp nóng, Phiếu bếp bar, Tem / nhãn dán ly, Báo cáo.
3. **"Chỉ áp dụng cho hình thức"** (không chọn = tất cả): Ăn tại bàn, Mang đi, Đặt qua QR, Giao hàng.
4. **"Chỉ khi thao tác trên thiết bị này"** — bật nếu luật chỉ dành cho máy đang cầm.
5. **"In ra máy"**, **"Số bản"**, **"Máy dự phòng (khi máy trên bị tắt)"**.
6. **"Ưu tiên"**: số nhỏ chạy trước; luật cụ thể hơn thắng khi bằng nhau.
7. **"Xong"** → **"Lưu"**.

> **Loại phiếu nào không có luật thì sẽ KHÔNG in.** Sau khi chuyển sang luật in, kiểm tra đủ luật cho hoá đơn, tạm tính, bếp nóng, bếp bar, tem.
> Muốn quay về 4 trạm cũ: **"Bỏ thiết lập mới"** rồi **"Lưu"**.

### 4. Thiết lập nhanh cho máy cầm tay (Sunmi) — "Máy này in bill ra"
Trong Máy In & Luật In, phần **"Thiết lập nhanh"** chọn cách in **hoá đơn và phiếu tạm tính** khi thao tác trên máy đang cầm (bếp, bar không đổi):
- **"Dùng máy Win làm máy in"** — bill ra máy in quầy; máy này không tự in.
- **"Dùng máy POS cầm tay làm máy in"** — bill ra máy in gắn trong máy này; máy Windows tự nhường, không in trùng.
- **"Dùng song song 2 máy"** — mỗi bill ra 2 bản: một ở máy này, một ở máy in quầy.

Trước đó cần khai báo **máy in tích hợp**: bấm **"Thêm máy in tích hợp của máy này"** (chỉ hiện trên Android), rồi **"In thử máy in tích hợp"** để kiểm giấy và tiếng Việt. Chọn xong bấm **"Lưu"**.

> Gợi ý cho Sunmi V3: độ đậm "Vừa" (3) và hạ "Mật độ in" trong Cài đặt máy in của máy xuống 80%. Chữ mờ → kéo sang Đậm; chữ bết → kéo về Mảnh.

### 5. In tem dán ly
1. Trong Máy In & Luật In, phần **"Tem dán ly"** → chọn **"Máy in tem dán ly"** (hoặc "Không in tem").
2. Mỗi ly in **một tem**; 2 ly cùng món → 2 tem (1/2, 2/2).
3. Đổi khổ tem và nội dung ở **Thiết Kế Mẫu In → Tem Dán Ly** (nút **"Thiết kế tem"**). Khi thêm máy in tem, chọn đúng khổ giấy decal.

### 6. Bật/tắt tự động in và mở két
Trong **Cấu Hình Trạm In** (mục "Tuỳ Chọn Tự Động"; quán dùng luật in thì các công tắc nằm ngay đầu màn "Tự Động In & Máy Chủ In"):
- **"In khi thanh toán"** — in hoá đơn khi bán thành công.
- **"In khi báo chế biến"** — gửi phiếu đến trạm bếp và nhãn ly.
- **"Tự động mở két tiền"** — mở két khi in hoá đơn thanh toán.

### 7. Máy chủ in (Print Server)
Dùng khi quán có nhiều máy bán (web, điện thoại) nhưng chỉ **một máy Windows/Sunmi nối máy in**. Máy chủ in nhận và in bill thay cho các máy khác; mỗi bill chỉ một máy được in (chống in trùng).
1. Trên máy sẽ làm máy chủ (Windows/Sunmi, **không phải trình duyệt**): **Cấu Hình Trạm In** → khung **"Định tuyến máy chủ in (Print Server)"**.
2. Bấm **"Đặt thiết bị này làm máy chủ in"**, rồi bật công tắc định tuyến.
3. Đổi máy chủ: trên máy mới bấm **"Chuyển máy chủ sang thiết bị này"** → **"Chuyển máy chủ"**. Thôi làm máy chủ: **"Dừng/trả vai trò máy chủ in"**.
4. Khung hiện **"Máy chủ in hiện tại"** (máy nào đang làm chủ) và **"Thiết bị này: LÀ MÁY CHỦ IN / Không phải máy chủ in"**.

> Máy chủ in phải **luôn mở app** thì mới in được bill của máy khác. Khi đã bật định tuyến mà máy chủ tắt hoặc mất kết nối, **các máy khác không tự in thay** (trừ máy có luật "Máy này in bill ra" riêng) — bill chỉ ra lại khi máy chủ mở lại. Mở máy chủ trước giờ bán.

### 8. Thiết kế mẫu in
**Thiết Kế Mẫu In** có 4 tab: **Hoá Đơn**, **Bếp Nóng**, **Bếp Bar**, **Tem Dán Ly**.
- **Hoá Đơn**: chọn **"Khổ giấy"**, bật/tắt và sắp xếp các khối (Tên quán, Logo, Địa chỉ, SĐT, Thông tin đơn, Tên bàn, Danh sách món, Tổng tiền, Phương thức TT, Điểm thưởng, QR Code, Văn bản tự do, Lời cảm ơn…). Khối "Danh sách món", "Tổng tiền" là **bắt buộc**. Thêm khối: **"Thêm block"**. Xem lại các thiết kế trước đây: nút **"Lịch sử thiết kế"**.
- **Bếp Nóng / Bếp Bar**: **"Khổ Giấy"**, **"Tiêu Đề Phiếu"** (vd PHIẾU BẾP, BAR NƯỚC), **"Hiển Thị Trên Phiếu"** (Tên bàn / Mang đi, Số thứ tự đơn, Thời gian gọi món, Ghi chú đặc biệt, Đường kẻ phân cách, In đậm tên món, Tên nhân viên order), **"Cỡ Chữ"**.
- **Tem Dán Ly**: **"Khổ Tem"**, **"Hiển Thị Trên Tem"** (Số đơn, Tên bàn / Mang đi, Thứ tự ly (1/2), Ghi chú / topping, Giờ gọi món…), **"Cỡ Chữ"**.
- Có sẵn **mẫu dựng sẵn**: chọn mẫu → **"Dùng mẫu này"**. Mọi thay đổi phải bấm **"Lưu"**.

### 9. Két tiền
- Két cắm dây (cổng RJ11) vào **máy in hoá đơn thu ngân**.
- Thử két (quán in theo 4 trạm): Cấu Hình Trạm In → trạm **Thu ngân** → **"Mở két tiền"**. Quán đã dùng luật in hiện **chưa có nút thử mở két bằng tay** — thử bằng một đơn tiền mặt.
- Máy in mạng (IP): app gửi lệnh mở két trực tiếp. Máy in hệ thống Windows: app gửi lệnh qua máy in; nếu không mở, cấu hình "Cash Drawer" trong driver máy in.

### 10. In thử
- Máy In & Luật In → tab "Máy in": nút **"In thử"** ở từng máy in.
- Máy in ở 4 trạm cũ (quán chưa dùng luật in): **"In thử nghiệm"** trong từng trạm.
- Máy in tích hợp Sunmi: **"In thử máy in tích hợp"**.
- Máy in mạng: **"Quét"** để dò máy in cổng 9100 trong cùng Wi-Fi, chạm IP để chọn, **"Lưu IP"**.

## Lỗi thường gặp
| Thấy gì | Vì sao | Làm gì |
|---|---|---|
| "Máy này chưa được cài máy in hóa đơn nên chưa in. Vào In Hoá Đơn → Máy In & Luật In để chọn máy in." | Máy đang thao tác không có máy in hoá đơn / không có luật in hoá đơn | Thêm máy in + luật "Hóa đơn thanh toán", hoặc đặt Máy chủ in |
| Bán trên **web** mà không ra bill | Trình duyệt không tự in | Đặt một máy Windows/Sunmi làm **Máy chủ in** và giữ app luôn mở |
| Một loại phiếu (vd phiếu bar) không in | Đang dùng luật in nhưng thiếu luật cho loại phiếu đó | Thêm luật cho loại phiếu đó, bấm Lưu |
| Bill bị cụt mép / chữ quá to | Khổ giấy hoặc cỡ chữ không hợp | Sửa máy in: đúng khổ giấy, giảm tỉ lệ cỡ chữ |
| Chữ mờ hoặc bết (Sunmi) | Độ đậm chưa hợp | Đổi độ đậm; bật "Chữ đậm dạng bán đậm" nếu chữ đậm bị loe |
| "Bill … CHƯA in sau 30 giây. Kiểm tra máy in bill." (khi thanh toán bàn) | Máy in chậm, tắt hoặc hết giấy | Kiểm tra máy in rồi bấm **"IN LẠI BILL"** trên thông báo |
| Máy cài lại app thì không tự in bill nữa | Luật "Máy này in bill ra" ra máy LAN/Bluetooth gắn với mã của máy cũ (cài lại app là đổi mã). Luật chỉ in ra máy in tích hợp Sunmi thì Sunmi tự nhận lại, không bị | Vào In Hoá Đơn → chọn lại ở "Máy này in bill ra" rồi **"Lưu"** |
| "Máy in đang được dùng trong một luật, hãy sửa luật trước." | Xoá máy in đang được luật dùng | Sửa/xoá luật trước rồi mới xoá máy in |
| "Không thể đăng ký. Đã có thiết bị khác làm máy chủ in." | Quán đã có máy chủ in | Dùng "Chuyển máy chủ sang thiết bị này" |
| "Bạn không có quyền quản lý máy chủ in (printer.manage_server)." | Vai trò không có quyền "Quản lý Máy chủ in" | Nhờ Chủ quán/Quản lý |
| Đồ uống in ra máy bếp nóng thay vì bar | "Bộ phận chế biến" của món đang là Bếp Nóng (món thêm nhanh ở Bán hàng mặc định Bếp Nóng) | Kho hàng → sửa món → chọn "Bếp Bar" |
| Két không mở với máy in USB trên Windows | Driver máy in chưa bật két | Cấu hình "Cash Drawer" trong driver, hoặc dùng máy in mạng |
| In ra 2 bill giống nhau | Hiếm: mạng lỗi lúc giành quyền in, app chọn in để không mất bill | Bỏ một bản; nếu lặp lại thường xuyên thì báo chủ app |

## Liên quan module khác
- **Bán hàng / Quản lý Bàn**: tự in hoá đơn khi thanh toán, phiếu tạm tính, phiếu bếp.
- **Bếp / Kho hàng**: phiếu ra máy bếp nóng hay bếp bar theo **"Bộ phận chế biến"** của từng món (Kho hàng → Sửa thông tin món), không theo danh mục.
- **QR Gọi Món**: in mã QR (poster) và phiếu khi duyệt đơn.
- **Báo cáo**: tab "Hóa đơn" → "Tra cứu & in lại bill" (in lại bill cũ, chỉ hoá đơn thu ngân). Cần module Báo cáo và quyền "Xem lịch sử đơn" (ai có module Bán hàng thì có sẵn quyền này; Chủ quán tắt được trong Hành động nhạy cảm). Màn này tải đủ bill của kỳ đang chọn (tối đa 20.000 bill) — không thấy bill thì chọn đúng ngày của bill. Lỗi "Không đọc được chi tiết bill này. Kéo xuống để tải lại rồi thử lại." → kéo danh sách xuống để tải lại. Món QR đã huỷ không còn in trên bill in lại.

## Ghi chú cho Chủ Quán (không đưa cho khách)

### Khác biệt với bản app cũ (cho Chủ Quán)
- App cũ ghi tên 4 trạm khác (có chữ tiếng Anh) và ghi "Máy chủ owner" thay cho "Máy chủ in hiện tại".
- "Tra cứu & in lại bill" chỉ có từ bản sau 22/10/2026; app cũ chỉ tải tối đa 500 bill mới nhất của kỳ (chọn kỳ ngắn hơn để tìm bill cũ hơn), bản mới tải tối đa 20.000.

1. **Hai hệ cấu hình chồng nhau** (4 trạm cũ và Luật in): đã có máy in **hoặc** luật trong thiết lập mới (`PrintSetup.isEmpty` = không máy in **và** không luật) thì 4 trạm cũ **bị bỏ qua hoàn toàn**, loại phiếu không có luật sẽ **không in** (chỉ khai báo máy in mà chưa có luật → không in gì). Chủ Quán hỏi gộp (23/10) → kế hoạch gộp thành một màn "Cấu hình trạm in": `.docs/ke-hoach-gop-cau-hinh-tram-in.md` (chờ duyệt, cần thử máy in thật).
2. **[ĐÃ SỬA trong app 23/10 — chưa phát hành]** Chữ tiếng Anh / không dấu: tên trạm ("Thu ngân", "Bếp nóng", "Quầy bar (đồ uống)", "Tem dán ly"), phiếu in thử tiếng Việt có dấu kèm font (trước đây "Bếp Nóng" in ra vỡ chữ; máy IP in ký tự rác — nay in không dấu), "Máy chủ in hiện tại", thông báo lỗi (kể cả lỗi khoá in trùng, hướng dẫn cấu hình két trong driver), "NV gọi món", tên mẫu bill. **Còn có chủ đích:** phiếu bếp in qua máy IP (ESC/POS) không dấu vì máy in nhiệt không có font — muốn có dấu phải in dạng ảnh (nằm trong kế hoạch gộp).
3. **Web không tự in** là giới hạn nền tảng; quán chỉ dùng web phải có máy chủ in.
4. Công cụ Cài máy in và việc POS tự dùng máy `QN-…` **chưa được thử trên máy Windows/máy in thật tại KAY** (theo nhật ký 18/10).
5. Công tắc tự động in nằm ở màn 4 trạm cũ nhưng vẫn áp dụng cho luật in — người dùng khó đoán.
6. Quyền "Quản lý Máy chủ in" = `printer.manage_server`; thông báo lỗi trên màn hình vẫn hiện nguyên mã này.
7. Phiếu bếp in theo `products.station_code` (chuẩn hoá bằng `normalizeStationCode`); món thêm nhanh ở POS (dấu +) luôn lưu `'nong'`.
