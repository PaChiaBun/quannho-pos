# Kế hoạch: Gộp "Cấu hình trạm in" và "Máy In & Luật In" thành một màn

> Lập 23/10/2026 theo câu hỏi của Chủ Quán. Trả lời ngắn: **gộp được**, nhưng đụng luồng in ở mọi quán, nên làm thành một đợt riêng có kiểm thử kỹ. Chưa làm — chờ duyệt.

## Hiện trạng
- Cả hai hệ lưu chung một khối cài đặt `app_settings` khoá `qn_printer_profile_v2` (có bản sao trong máy). Ghi bằng `_persistProfileV2` trong `printer_settings_provider.dart`.
  - **4 trạm cũ:** Thu ngân / Bếp nóng / Quầy bar / Tem ly, mỗi trạm chọn một máy in.
  - **Luật in:** danh sách máy in và các luật (theo loại phiếu, khu vực, hình thức, thiết bị, máy dự phòng).
- **Khi in** (`StationPrinterDispatcher` trong `bill_preview_screen.dart`):
  - Thiết lập mới trống (không máy in **và** không luật — `PrintSetup.isEmpty`) thì dùng 4 trạm cũ.
  - Đã khai báo ít nhất một máy in **hoặc** một luật thì **chỉ dùng luật**: loại phiếu nào không có luật sẽ **không in**, và không quay về trạm cũ. Chỉ thêm máy in mà chưa có luật → không phiếu nào in.
- Công tắc **tự in khi thanh toán / tự in bếp / tự mở két** nằm ở màn 4 trạm cũ nhưng áp cho cả hai hệ. Đây là lý do người dùng thấy rối.
- Chuyển từ trạm sang luật hiện chỉ làm tay: nút "Dựng từ cấu hình hiện tại".
- Một số mục **lưu được nhưng lúc in không dùng** (`_pickConfig` chỉ lấy máy in đầu tiên luật chọn): của luật — số bản in, máy in thêm, mẫu in theo luật; của máy in — "có két tiền" (mở két theo công tắc chung), tự cắt giấy, cổng mạng (luôn dùng 9100).
- `bill_printer_hub.dart` còn một bản thứ ba của màn trạm in (`_PrinterSettingsSheet`) không còn lối vào (code chết).

## Thiết kế gộp
Một màn duy nhất **"Cấu hình trạm in"**, thay 2 thẻ ở trang In Hoá Đơn, gồm 4 phần:
1. **Máy in:** danh sách máy (tên, kết nối hệ thống / IP / Sunmi, khổ giấy, két tiền, tự cắt, cỡ chữ, độ đậm), nút **In thử**, **Dò máy trong mạng**.
2. **Trạm in nhanh:** 4 dòng cố định — Hoá đơn + tạm tính, Bếp nóng, Quầy bar, Tem ly — mỗi dòng chọn một máy. Phía sau là 4 luật có mã cố định, nên không còn hai hệ song song.
3. **Luật nâng cao** (thu gọn): theo khu vực / hình thức / thiết bị / máy dự phòng — chính là tab Luật in hiện nay.
4. **Tự động:** tự in khi thanh toán, tự in bếp, tự mở két; cùng phần **Máy chủ in**.

## Chuyển cài đặt cũ tự động (an toàn)
- Khi tải cài đặt: chưa có luật mà có trạm cũ → dựng luật trong bộ nhớ từ trạm cũ (`legacyToPrintSetup`). Chỉ lưu khi Chủ quán bấm Lưu.
- Tiếp tục ghi 4 trường trạm cũ trong 1–2 phiên bản để máy chạy app cũ vẫn in đúng.
- Sửa bộ chuyển đổi trước khi bật:
  - Thêm khổ giấy "theo mẫu" để không đổi cỡ bill (hiện đang ép 80 mm).
  - Map đúng máy Sunmi.
  - Két tiền theo cờ "có két" (máy thu ngân cũ mặc định có két), để giữ đúng hành vi hiện nay.

## Rủi ro
- App cũ bỏ qua luật → phải giữ ghi trạm cũ song song một thời gian.
- Đổi khổ giấy / tỉ lệ in.
- Loại phiếu không có luật sẽ im lặng không in → màn mới phải cảnh báo rõ.
- Luật theo từng máy (`device_bill_*`), cơ chế nhận việc của máy chủ in, bộ chọn hàng đợi `QN-` trên Windows.
- **Không** bật số bản in / nhiều máy đích trong cùng đợt, vì sẽ đổi hành vi in.

## Ước lượng
8–10 tệp:
- `print_rules_screen.dart` thành màn chính.
- `printer_settings_screen.dart` rút gọn.
- `bill_printer_hub.dart`.
- `legacy_print_setup.dart`.
- `print_setup.dart`.
- `printer_settings_provider.dart`.
- `bill_preview_screen.dart`.
- Chữ hướng dẫn trong `checkout_sheet.dart`, `bill_lookup_section.dart`.
- Test.

Cần thử trên máy Windows + máy in thật trước khi phát hành.

## Đã làm ngay (23/10, chưa phát hành)
- Tên trạm hết tiếng Anh: "Thu ngân", "Bếp nóng", "Quầy bar (đồ uống)", "Tem dán ly".
- Phiếu in thử dùng tiếng Việt có dấu, kèm font, nên "Bếp nóng" không còn vỡ chữ. Máy IP in không dấu thay vì ký tự rác.
- Thông báo lỗi tiếng Anh → tiếng Việt (kể cả lỗi khoá in trùng, hướng dẫn cấu hình két trong driver Windows, và hộp cài đặt bỏ đi trong `bill_printer_hub.dart`).
- "NV Order" → "NV gọi món".
- Mẫu bill: "Khu Ẩm Thực", "Mang đi", "Không tiền mặt", "Khách quen", "Nhà hàng sang"; chân bill quán café "Cảm ơn, hẹn gặp lại ☕".
- **Còn lại có chủ đích:** phiếu bếp in qua máy IP (ESC/POS) vẫn **không dấu**, vì máy in nhiệt không có font tiếng Việt. Muốn có dấu phải chuyển sang in dạng ảnh (raster) như bill thu ngân — có thể làm trong đợt gộp này.
