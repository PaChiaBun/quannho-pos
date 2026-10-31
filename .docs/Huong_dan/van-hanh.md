---
module: kay_ops
ten: Vận Hành
phien_ban: 1.0.5+20
cap_nhat: 2026-10-23
nguon:
  - lib/modules/ops/screens/ops_screen.dart, ops_staff_screen.dart, ops_manager_dashboard.dart, ops_config_screen.dart, ops_report_screen.dart
  - lib/modules/ops/repository/ops_repository.dart
  - .docs/Ai_Boom/cac-module/van-hanh.md (tài liệu kỹ thuật: bảng, logic lọc việc theo vai trò/ca)
---

# Vận Hành

> Checklist công việc theo ca: nhân viên thấy việc cần làm trong ca của mình, tick xong (có thể bắt chụp ảnh bằng chứng), bàn giao ca; quản lý theo dõi tiến độ trong ngày.

## Ai dùng được
- **Mọi nhân viên** của quán, khi Chủ quán đã bật module **Vận Hành** (mặc định tắt) — không cần giao module này cho vai trò.
- **Nhân viên**: màn **"Nhiệm Vụ Của Tôi"**.
- **Chủ quán / Quản lý**: màn **"Check List Công Việc"** với 3 tab **"Tổng Quan"**, **"Cấu Hình"**, **"Báo Cáo"**.

## Nhân viên thấy việc nào
1. Việc **giao đích danh** cho mình → luôn thấy.
2. Việc gắn **vai trò** → chỉ người cùng vai trò thấy ("Tất cả vai trò" = ai cũng thấy).
3. Việc gắn **ca làm việc** → chỉ hiện trong khung giờ ca đó (hỗ trợ ca qua đêm).
4. Việc có **"Chỉ hiện vào ngày"** → chỉ các thứ đã chọn.

Ca làm việc tạo ở **Nhân viên → Phân quyền → "Ca làm việc"**.

## Các việc thường làm

### 1. Quản lý: tạo checklist
1. **"Cấu Hình"** → tab **"Danh Sách"** → **"Thêm"** (hoặc **"Thêm công việc"**).
2. Điền:
   - **"Tên công việc *"** (vd: Vệ sinh toilet lần 1), **"Mô tả / Hướng dẫn"**.
   - **"Giờ mục tiêu"**: giờ cụ thể (09:00) hoặc **"Cuối ca"**.
   - **"Yêu cầu ảnh bằng chứng"** — nhân viên phải chụp ảnh trước khi tick xong.
   - **"Mức độ ưu tiên"**: Thấp, Thường, Cao, Khẩn.
   - **"Chỉ hiện vào ngày"**: T2…CN (bỏ trống = mọi ngày).
   - **"Vai trò"** (để trống = tất cả), **"Ca làm việc"** (để trống = tất cả ca), **"Assign nhân viên cụ thể"**.
3. Lưu. Thẻ việc hiện giờ mục tiêu, nhãn **"Gắn ca"**, **"N NV"**.
4. Xoá một việc: **"Xoá công việc?"** (nhật ký cũ giữ nguyên). Xoá hết: **"Xoá tất cả"** (không hoàn tác).

### 2. Quản lý: nạp checklist mẫu
- Tab **"Bộ Mẫu"** → **"Checklist chuẩn theo từng vai trò"** → chọn nhóm → **"Nạp"** → "Nạp N việc cho "<vai trò>" thành công". Sau đó sửa lại theo quán.

### 3. Quản lý: xem / chỉnh việc theo vai trò
- Tab **"Phân Quyền"**: xem mẫu việc theo từng vai trò và người được giao đích danh; chạm để sửa.

### 4. Nhân viên: làm checklist
1. Mở **Vận Hành** → **"TIẾN ĐỘ HÔM NAY"** (x / y nhiệm vụ, %), tên ca hiện tại.
2. Việc xếp theo giờ mục tiêu; việc quá giờ có nhãn **"Quá giờ!"** và cảnh báo "N công việc đã quá giờ mục tiêu".
3. Chạm thẻ để xem hướng dẫn; bấm nút hoàn thành để tick xong.
   - Việc **yêu cầu ảnh**: app mở camera, lưu ảnh ("Đang lưu ảnh bằng chứng...") → "✅ Hoàn thành · Ảnh lưu …".
4. **Giữ lâu** một việc để ghi **"Ghi chú sự cố"** (vd: toilet bị tắc, đã báo quản lý) → **"Hoàn thành"** (hoặc **"Bỏ qua"**).
5. Xong hết: **"Hoàn thành!"**.

### 5. Nhân viên: bàn giao ca
1. Cuối ca bấm **"Bàn Giao Ca"** → **"Ghi chú cho ca tiếp theo"**.
2. App báo số việc chưa xong sẽ được ghi nhận.
3. Điền **"⚠️ Vấn đề tồn đọng"** (vd: máy pha cà phê hỏng nút steam) và **"📝 Ghi chú cho ca sau"** (vd: bàn 5 đặt lúc 3pm, hết đường phèn) → **"Xác nhận bàn giao"** → "📋 Bàn giao ca đã lưu!".

4. Ca sau (và quản lý ở tab **"Tổng Quan"**) thấy thẻ **"Bàn giao ca gần nhất"**: người bàn giao, giờ, ⚠️ vấn đề tồn đọng, 📝 ghi chú, "N việc chưa xong lúc bàn giao". Thẻ hiện bàn giao mới nhất trong **24 giờ** (ca đêm bàn giao sang sáng hôm sau vẫn thấy); bàn giao để trống thì không hiện.
5. Nếu lưu không được, ngay trong bảng bàn giao hiện chữ đỏ **"Chưa lưu được bàn giao (máy chủ chưa sẵn sàng hoặc mất mạng). Hãy nhắn trực tiếp cho ca sau / quản lý."** — khi đó nhắn trực tiếp.


### 6. Quản lý: theo dõi trong ngày
- **"Tổng Quan"**: **"TỔNG QUAN HÔM NAY"** (% hoàn thành, Đang làm, Bỏ sót), cảnh báo "N nhân viên có việc quá giờ: …", **"Theo Vai Trò"**, **"Timeline Hôm Nay"**; từng việc: **Hoàn thành / Chưa làm / Bỏ sót**. Hiện chưa có thao tác nào đặt "Bỏ sót" nên số Bỏ sót thường là **0** — việc không làm hiện là "Chưa làm".
- **"Báo Cáo"**: chọn ngày; **"TỔNG QUAN CA HÔM NAY"**; **"Đang Có Việc Chưa Xong"**, **"Hiệu Suất Nhân Viên"** (Hoàn thành / Đang làm / Chậm trễ, "Còn N việc"), **"Theo Vai Trò"**.

## Lỗi thường gặp
| Thấy gì | Vì sao | Làm gì |
|---|---|---|
| "Chưa có công việc nào – Quản lý chưa thiết lập checklist…" | Chưa có việc cho vai trò/ca/ngày này | Quản lý thêm việc hoặc nạp Bộ Mẫu |
| Nhân viên không thấy việc đã tạo | Việc gắn vai trò khác, ca khác, ngày khác | Kiểm tra Vai trò / Ca làm việc / Chỉ hiện vào ngày |
| "✅ Hoàn thành (lưu ảnh thất bại)" | Mạng yếu khi lưu ảnh | Việc vẫn tính xong; báo quản lý nếu cần ảnh |
| "Chưa có dữ liệu hôm nay – Nhân viên chưa bắt đầu…" | Chưa ai tick việc nào | — |
| "Chưa lưu được bàn giao…" (chữ đỏ trong bảng bàn giao) | Mất mạng hoặc máy chủ trục trặc | Thử lại; vẫn lỗi thì nhắn trực tiếp cho ca sau |
| Không thấy thẻ "Bàn giao ca gần nhất" | Chưa ai bàn giao trong 24 giờ, hoặc bàn giao để trống | Nhắn trực tiếp cho ca sau |
| Số "Bỏ sót" luôn 0 | Chưa có thao tác đặt "Bỏ sót" | Xem số "Chưa làm" |

## Liên quan module khác
- **Nhân viên**: vai trò, ca làm việc, người được giao.
- **Chấm công**: ca hiện tại của nhân viên.

## Ghi chú cho Chủ Quán (không đưa cho khách)

### Khác biệt với bản app cũ (cho Chủ Quán)
- App cũ hiện "Mức độ ưu tiên" bằng tiếng Anh (Low, Normal, High, Critical) và chưa có thẻ "Bàn giao ca gần nhất" — cập nhật app.

0. (Chuyển từ phần hướng dẫn 23/10) **Lưu ý (23/10/2026):** trước 14:06 ngày 23/10 máy chủ **chưa có bảng lưu bàn giao** — mọi lần bấm "Xác nhận bàn giao" trước đó đều **không lưu gì**. Từ 14:06 23/10 máy chủ đã lưu được (kể cả từ bản app đang dùng). Thẻ "Bàn giao ca gần nhất" và chữ báo lỗi chỉ có ở bản app mới (chưa phát hành) — bản đang dùng lưu được nhưng chưa hiện thẻ.
1. **[SỬA 23/10 — app chưa phát hành; migration ĐÃ ÁP production 23/10 14:06]** Bảng `ops_shift_handovers` **chưa từng tồn tại trên production** → mọi lần "Xác nhận bàn giao" đều lỗi, app nuốt lỗi (nhân viên tưởng đã lưu). Đã sửa app: báo lỗi trong bảng bàn giao; thẻ "Bàn giao ca gần nhất" (24 giờ) ở màn nhân viên và Tổng Quan quản lý (`OpsHandoverCard`, `opsLatestHandoverProvider` — đọc lỗi thì ẩn thẻ, không vỡ màn). Migration `20261023_ops_ban_giao_ca_v1.sql` tạo bảng: cách ly theo quán, app chỉ thêm + đọc (không sửa/xoá), người tạo (id + tên hiển thị) và giờ tạo do máy chủ đóng dấu (không giả tên/giờ được), ghi chú ≤ 2000 ký tự; đã chạy thử trên bản sao (15/15 PASS). Áp bằng `db-fix/ban_giao_ca_ap_dung.sh`. Bảng bàn giao không đóng được khi đang lưu; thẻ hiện tối đa 4 dòng mỗi mục.
2. **Trạng thái "Bỏ sót" không có nút nào đặt** (`markMissed` không được gọi) — số "Bỏ sót" trên Tổng Quan/Báo Cáo nhiều khả năng luôn bằng 0; việc không làm chỉ hiện "Chưa làm".
3. Chế độ quản lý xác định theo tên vai trò `owner`/`manager` ở client.
4. **[SỬA 23/10]** Mức độ ưu tiên đổi sang tiếng Việt: Khẩn / Cao / Thường / Thấp (cả nút chọn và nhãn trên thẻ việc).
- **[SỬA 23/10 — chưa phát hành] Lỗi giới hạn 1.000 dòng:** máy chủ chỉ trả 1.000 dòng mỗi lần đọc; màn này trước đây đọc cả bảng của quán rồi lọc ở máy → quán lớn (KAY) nhận toàn dòng cũ. Việc hôm nay (nhân viên và Tổng Quan quản lý) của KAY (2.030 dòng) chỉ nhận dòng tới 10/8 → không hiện việc hôm nay (KAY ngừng dùng Vận hành sau 18/10, có thể vì lỗi này). Nay lọc ngày ở máy chủ.
