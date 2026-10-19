# Thiết kế hệ thống in linh hoạt — Quán Nhỏ POS (bản đề xuất, chưa triển khai)

Ngày: 08/10/2026. Mục tiêu: chủ quán tự cấu hình được việc in (loại máy in, in ở đâu, in gì, mấy bản) mà không cần sửa code; đủ chắc để bán cho nhiều quán. Bản này chỉ là thiết kế, chưa có dòng code nào được viết theo nó (ngoài việc giảm quét lại 3 giây).

## 1. Vấn đề của kiến trúc hiện tại (từ khảo sát code)
- Cấu hình in chỉ có 4 trạm cố định (thu ngân, bếp nóng, bếp bar, tem bar) × 3 trường (tên/IP, loại, bật/tắt), dùng chung cho cả quán.
- Chỉ có 2 loại máy in: `system` (PDF qua gói `printing`) và `network`. Không có Bluetooth/USB/máy in tích hợp (Sunmi).
- Chống in trùng nằm ở bộ nhớ trên từng máy (SharedPreferences), không nằm ở server. Có hai luồng thanh toán in thẳng, không qua bộ nhớ này.
- Không có hàng đợi in, thử lại có giới hạn, số bản, tự cắt giấy theo trạm, cảnh báo in lỗi.
- Tự phục hồi chủ in chỉ có trên Windows.
- Máy chủ in tập trung (Windows) và máy cầm tay là hai chế độ loại trừ nhau, không có "máy này tự in bill của nó".

## 2. Nguyên tắc thiết kế
1. **Một nguồn sự thật trên server**: lệnh in là dữ liệu trong DB (hàng đợi), không phải sự kiện thoáng qua.
2. **Tách "cái gì cần in" khỏi "in bằng gì, ở đâu"**: sinh lệnh in một chỗ; mỗi thiết bị tự nhận phần mình làm được.
3. **Mặc định không đổi gì cho quán đang chạy**: quán KAY giữ nguyên hành vi hiện tại cho đến khi chủ quán chủ động bật tuỳ chỉnh.
4. **Mọi dữ liệu theo `store_id`**, quyền theo module (`printer.manage_*`), có audit.
5. **Không trùng, không mất**: mỗi lệnh in có khóa duy nhất và trạng thái; lỗi thì thử lại, quá giới hạn thì báo.

## 3. Mô hình dữ liệu (đề xuất)
- `print_devices`: thiết bị chạy app (id, tên, nền tảng, khả năng: `builtin_sunmi`, `lan`, `usb`, `bluetooth`, `system`), lần thấy cuối.
- `print_printers`: máy in vật lý do chủ quán đặt tên ("Bill quầy", "Bếp nóng", "V3 của Như"): loại kết nối, địa chỉ/IP, thiết bị phụ trách (nếu là máy in gắn vào thiết bị), khổ giấy (`50mm`/`58mm`/`80mm`/`a4`), bảng mã/ký tự, bật tự cắt, có két hay không.
- `print_rules`: luật định tuyến. Mỗi luật: **loại phiếu** (bill thanh toán, tạm tính, phiếu bếp theo trạm, tem, báo cáo ca, thu/chi) × **điều kiện** (thiết bị nguồn, khu vực/bàn, kênh bán: tại bàn/mang đi/QR, khung giờ) → **đích** (một hay nhiều máy in), số bản, mẫu in, thứ tự ưu tiên, máy in dự phòng.
- `print_jobs`: hàng đợi. Cột chính: `id`, `store_id`, `job_key` (UNIQUE, ví dụ `settlementId:bill`), `type`, `payload`, `printer_id`, `status` (`queued`/`claimed`/`printed`/`failed`/`cancelled`), `claimed_by`, `lease_until`, `attempts`, `last_error`, thời điểm.
- Mọi bảng có RLS cô lập theo quán (cùng chuẩn FIX 04/05).

## 4. Cách chạy
1. Thanh toán/gửi bếp **tạo bản ghi `print_jobs`** (một RPC nguyên tử, `job_key` UNIQUE ⇒ không bao giờ trùng).
2. Mỗi thiết bị chạy **print agent**: nhận lệnh qua Realtime + quét lại 3 giây, **chỉ nhận lệnh gửi tới máy in nó với tới được** (máy in tích hợp của nó, LAN, USB…), bằng cơ chế thuê (`claimed_by` + `lease_until`, kiểu `FOR UPDATE SKIP LOCKED`).
3. In xong cập nhật `printed`; lỗi thì tăng `attempts`, thử lại với độ trễ tăng dần; quá ngưỡng thì `failed` và cảnh báo trên màn hình.
4. Máy chủ in tập trung (Windows) trở thành **một agent như mọi agent khác**, không còn là trường hợp đặc biệt. Máy in LAN có thể được nhiều máy cùng với tới ⇒ tự dự phòng nếu một máy tắt.
5. Máy cầm tay Sunmi V3 là một agent có máy in tích hợp: bill thanh toán tại V3 được luật định tuyến gửi tới "máy in V3 này", Windows không nhận ⇒ không trùng. Nếu V3 in lỗi hoặc tắt, luật có thể định máy in dự phòng.

## 5. Trình điều khiển máy in (driver) cắm thêm được
`PrinterDriver` giao diện chung: `print(job)`, `status()`, `openDrawer()`, `cut()`.
- `SunmiBuiltinDriver` (Android, gọi dịch vụ in tích hợp của Sunmi; cần xác nhận trên V3 thật).
- `LanEscPosDriver` (TCP 9100, in thật không hộp thoại).
- `SystemPdfDriver` (Windows/macOS, như hiện tại).
- Sau này: Bluetooth, USB, máy in đám mây. Thêm loại mới không đụng tới luật hay hàng đợi.

## 6. Màn hình tuỳ chỉnh cho chủ quán
- **Máy in**: thêm/sửa/xoá, in thử, xem trạng thái (sẵn sàng/lỗi/giấy), khổ giấy 50/58/80 mm, tự cắt, mở két.
- **Luật in**: bảng dễ hiểu "Khi … thì in … ra … (… bản)", có mẫu dựng sẵn (Quán cà phê, Quán ăn, Có bếp bar…).
- **Thiết bị**: mỗi thiết bị chọn "máy này in ra đâu", bật/tắt "máy này làm máy chủ in".
- **Mẫu in**: dùng lại thiết kế bill/phiếu bếp hiện có, chọn mẫu theo từng máy in/khổ giấy.
- **Hàng đợi & lịch sử**: xem lệnh đang chờ/lỗi, in lại một bill, hủy lệnh.
- **Cảnh báo**: chuông/thông báo khi in lỗi hoặc máy chủ in mất kết nối.
- **Quyền**: ai được đổi cấu hình in (mặc định chủ quán), có audit.

## 7. Lộ trình đề xuất
| Giai đoạn | Nội dung | Giữ nguyên quán KAY? |
|---|---|---|
| 0 (xong) | Quét lại 3 giây thay vì 15 giây, chặn chồng lượt quét | Có |
| 1 | Driver Sunmi tích hợp + "máy này in ra đâu" theo thiết bị + cờ chống trùng giữa V3 và Windows + khổ 50 mm. Chưa đổi DB lớn | Có (mặc định như cũ) |
| 2 | `print_jobs` + RPC tạo lệnh nguyên tử + agent nhận lệnh có thuê; gộp mọi luồng thanh toán/gửi bếp vào cơ chế này; thử lại + cảnh báo | Chuyển dần, có công tắc quay lại cơ chế cũ |
| 3 | `print_printers` + `print_rules` + màn hình luật in, số bản, dự phòng, nhiều máy in/nhiều quán, mẫu dựng sẵn | Có |
| 4 | Driver Bluetooth/USB/đám mây, báo cáo in, gói thương mại | Có |

Giai đoạn 1 đủ để V3 chạy được trong vài ngày; giai đoạn 2–3 là phần "thương mại hoá".

## 8. Rủi ro và điều chưa biết
- **Chưa kiểm chứng** gói/dịch vụ in tích hợp của Sunmi V3 (gói `sunmi_printer_plus` chỉ ghi đã thử V2 Pro). Cần máy V3 thật.
- **Chưa kiểm chứng** `Printing.directPrintPdf` trên Android và cách Android xử lý in nền.
- Chuyển sang hàng đợi là thay đổi lớn ở đường thanh toán/gửi bếp: phải thử kỹ, có công tắc quay lại, triển khai ngoài giờ bán.
- Khổ 50 mm: bề rộng in thực tế (khoảng 40–42 mm?) cần đo trên máy.
- Mọi migration DB mới theo quy trình FIX: viết + thử trong transaction + ROLLBACK, backup, Chủ Quán tự áp.

## 9. Việc cần Chủ Quán quyết
1. Có đi theo hướng "hàng đợi trên server + nhiều agent" (giai đoạn 2–3) hay chỉ làm giai đoạn 1 trước?
2. Có máy V3 để thử không, và có thể cho một bản APK test không?
3. Có cần máy in LAN dự phòng khi máy Windows tắt (ý nghĩa của "agent dự phòng") không?

## 10. Tham khảo cách các hệ thống khác thiết kế (nghiên cứu 08/10/2026)
Nguồn: trang trợ giúp của Toast, Square, Lightspeed, Loyverse, StoreHub, Sapo. Chưa tìm được tài liệu chính thức của KiotViet và iPOS về phần này.
- **Toast**: 2 lớp. (1) Gán "trạm chế biến" cho menu/nhóm/món/tùy chọn thêm; (2) "luật định tuyến" chồng lên theo hình thức phục vụ hoặc khu vực (ví dụ mang đi chuyển sang trạm khác). Có công cụ xem trước một món sẽ đi máy in nào. Cần quyền riêng để sửa cấu hình bếp.
- **Square**: "hồ sơ máy in" (printer profile) đồng bộ giữa mọi thiết bị: chọn loại phiếu (phiếu order, hóa đơn, tem) và nhóm món cho từng máy in; có tuỳ chọn "gồm cả nhóm món tạo sau". Phản hồi người dùng: đổi cấu hình trong giờ bán rất dễ sai ⇒ nên chỉnh lúc vắng.
- **Lightspeed**: tách 3 thứ: máy in, "hồ sơ in" (loại phiếu nào ra máy nào, số bản, **máy in chính + máy dự phòng**), "trung tâm sản xuất" (nhóm kế toán/món nào đi trạm nào, có thể là màn hình bếp). Mẫu in tách riêng. Mẹo: đặt IP tĩnh cho máy in LAN.
- **Loyverse / StoreHub**: nhóm máy in bếp (đặt tên theo vị trí) + chọn danh mục món cho từng nhóm; **một máy in dùng cho nhiều trạm** (ra nhiều phiếu), in từng món riêng hoặc cả đơn; in tự động khi lưu đơn mở.
- **Sapo**: ứng dụng "Cấu hình mẫu in" với hơn 80 biến thông tin; bật/tắt in tem theo hình thức phục vụ (tại bàn, mang đi, giao hàng, đối tác); in lại đơn đã giao; áp mẫu in cho tất cả chi nhánh.

Bài học cho Quán Nhỏ POS: (1) gắn máy in theo **nhóm món** + **hình thức phục vụ**; (2) hồ sơ in đồng bộ mọi thiết bị, có **máy dự phòng** và **số bản**; (3) cho một máy in nhận nhiều trạm; (4) có **xem trước đường đi** của một món; (5) mẫu in có biến thông tin và áp cho nhiều chi nhánh; (6) khoá sửa cấu hình bằng quyền, cảnh báo khi sửa trong giờ bán.
