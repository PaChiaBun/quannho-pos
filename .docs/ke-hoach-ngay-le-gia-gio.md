# Kế hoạch: ngày lễ trong bảng giá giờ (đợt 6 lộ trình tính giờ)

Lập 28/11/2026 khi Chủ Quán bảo "làm tiếp đi" (đợt 5 đã commit b7c09e0). Lộ trình: `lo-trinh-tinh-gio.md`. Mở rộng đợt 1 (`ke-hoach-gia-gio-khung-block.md`). **Đụng tiền thật** (máy chủ tính). Viết, thử bản sao, xin Chủ Quán trước khi áp; **áp sau đợt 1** (migration tự kiểm).

## Chủ Quán đã chốt (28/11)

1. Ngày lễ: **khung Lễ luôn thắng**. Vào ngày lễ, giờ nào có khung Lễ thì lấy giá Lễ; giờ không có khung Lễ thì tính như ngày thường. Không phụ thuộc thứ tự kéo khung.
2. Danh sách ngày lễ: **quán tự thêm**, có nút thêm nhanh 1/1, 30/4, 1/5, 2/9 (lần tới của mỗi ngày); Tết âm lịch và ngày khác chọn trên lịch (chọn được nhiều ngày liền). App không tự đoán âm lịch.

## Cách làm

- Bảng `ban_ngay_le` (`store_id`, `ngay` date, `ten`): danh sách ngày lễ **của quán** (dùng chung mọi bàn). RLS: thành viên quán đọc; ghi qua `ban_ngay_le_luu_v1` (Chủ quán / Quản lý; thêm và xoá trong một lần gọi; ngày trong khoảng 7 ngày trước – 3 năm tới; tối đa 500 ngày).
- Khung giá: ô "thứ" nhận thêm **8 = Ngày lễ**. Khung có 8 là khung Lễ; có thể chỉ Lễ, hoặc vừa ngày thường vừa Lễ.
- `qn_tinh_gio_tinh_tien_v2` (thay): mỗi phút, nếu ngày đó (hoặc hôm trước, với khung qua đêm) là ngày lễ thì xét **các khung Lễ trước** theo thứ tự; không khung Lễ nào chứa phút đó thì xét như cũ theo thứ (giá trị 8 không bao giờ trùng thứ 1–7). Ngày của khung = ngày khung BẮT ĐẦU, như đợt 1 (khung Lễ 22:00–02:00 ngày 30/4 phủ tới 02:00 ngày 1/5).
- Quán không có ngày lễ hoặc không có khung Lễ → tính **y như đợt 1** (test hồi quy).
- `ban_gia_gio_luu_v1` (thay): nhận thứ 1–8. Tên dòng hoá đơn không đổi (đã ghi từng đoạn giá).
- Thêm / xoá ngày lễ khi bàn đang chơi: được (quán hay quên thêm sát ngày); lúc thanh toán tính theo danh sách mới. Ghi rõ trong hộp ngày lễ.

App:
- `GiaGioCaiDat.ngayLe` (tập ngày, của quán) gắn vào cài đặt từng bàn; `tinhGioKhungLuc` xét khung Lễ trước, đúng như máy chủ. Bộ ca kiểm dùng chung SQL ↔ Dart.
- Hộp khung giá: dưới bảy ngày thêm dòng bật **"Ngày lễ"**, nút nhanh "Chỉ ngày lễ"; bật Lễ thì hiện các ngày lễ sắp tới + nút "Sửa ngày lễ".
- Hộp **Ngày lễ của quán**: danh sách sắp tới (xoá từng ngày), nút "Thêm nhanh 1/1, 30/4, 1/5, 2/9", "Chọn ngày trên lịch" (một hoặc nhiều ngày liền) kèm ô tên (ví dụ "Tết").
- Phần "Giá theo giờ & làm tròn": khi có khung Lễ thì hiện dòng "Ngày lễ của quán: n ngày sắp tới · Sửa".

## Bộ ca kiểm (SQL ↔ Dart)

30/04/2027 là Thứ Sáu, ngày lễ của quán; 01/05/2027 cũng là ngày lễ; 03/05/2027 Thứ Hai thường. Giá gốc 60.000.

| # | Khung (theo thứ tự) | Chơi | Kỳ vọng |
|---|---|---|---|
| L1 | T2–T6 17–23 = 70.000; Lễ cả ngày = 100.000 (đứng DƯỚI) | 30/4 18:00, 60' | 100.000 (Lễ thắng dù đứng dưới) |
| L2 | như L1 | 03/5 18:00, 60' | 70.000 (ngày thường) |
| L3 | T2–T6 17–23 = 70.000; Lễ 08–12 = 90.000 | 30/4 11:30, 60' | 30' × 90.000 + 30' × 60.000 = 75.000 |
| L4 | như L3 | 30/4 17:30, 60' | 70.000 (giờ không có khung Lễ thì như ngày thường) |
| L5 | Lễ 22:00–02:00 = 120.000 | 30/4 23:00 – 1/5 01:00 | 240.000 (qua đêm tính theo ngày bắt đầu) |
| L6 | Lễ 22:00–02:00 = 120.000, chỉ 30/4 là lễ | 29/4 23:00, 60' | 60.000 (29/4 không lễ) |
| L7 | Lễ 22:00–02:00 = 120.000, chỉ 1/5 là lễ (bỏ 30/4) | 30/4 23:30 – 1/5 00:30 | 60.000: 00:00–02:00 ngày 1/5 là phần qua đêm của khung bắt đầu 30/4 (không lễ); khung ngày 1/5 bắt đầu 22:00 ngày 1/5 |
| L8 | chỉ Lễ, quán không có ngày lễ nào | bất kỳ | như giá gốc |
| L9 | không khung | 2.000 lượt ngẫu nhiên có ngày lễ | khớp công thức cũ |
| L10 | lưu khung thứ 8 qua `ban_gia_gio_luu_v1` | | được; thứ 9 bị từ chối |
| L11 | `ban_ngay_le_luu_v1`: phục vụ | | bị từ chối |
| L12 | thêm 2 ngày + xoá 1 | | còn đúng 1; ngày quá xa bị từ chối; quán khác không thấy |

## Nhật ký

### 28/11 — Máy chủ: viết xong, bản sao đạt, CHƯA ÁP

- `supabase/migrations/20261128_gia_gio_ngay_le.sql` (+ `_ROLLBACK`): bảng `ban_ngay_le`, ràng buộc thứ 1–8, `qn_tinh_gio_tinh_tien_v2` xét khung Lễ trước, `ban_gia_gio_luu_v1` nhận thứ 8 (còn lại nguyên văn đợt 1), `ban_ngay_le_luu_v1`. Hoàn tác: hai hàm về nguyên văn đợt 1, khung chỉ-Lễ bị xoá, khung vừa thường vừa Lễ bỏ phần Lễ, bỏ bảng.
- Test `supabase/tests/gia_gio_ngay_le_test.sql` 16 điểm (bộ ca ở trên + lưu). Test đợt 1 ca L5 đổi "thứ 8 không hợp lệ" thành thứ 9.
- Bản sao (`chuoi_stage_dryrun.sh`, TAG=ngay_le, áp đợt 1 + đợt 6): ngày lễ 16/16; khung giá đợt 1, tính giờ v1, đặt trước v1, tên dòng 5/5 TẤT CẢ PASS; chạy hoàn tác rồi khung giá đợt 1 + tính giờ v1 vẫn PASS, bảng ngày lễ mất. Bản sao đã xoá.
- Kịch bản áp `db-fix/gia_gio_ngay_le_ap_dung.sh` (backup → áp → test). Chưa chạy, chờ Chủ Quán.

### 28/11 — App: viết xong

- `gia_gio.dart`: `kThuNgayLe`, `soNgay`, `NgayLe`, `KhungGia.chuaNgayLe`, `GiaGioCaiDat.ngayLe`; `tinhGioKhungLuc` xét khung Lễ trước, đúng như máy chủ. Test `test/modules/tinh_gio/gia_gio_ngay_le_test.dart` (bộ ca chung + hồi quy 2.000 lượt).
- `ngayLeProvider` đọc `ban_ngay_le` (từ tuần trước), gắn vào cài đặt từng bàn; máy chủ chưa có bảng → rỗng, tính như đợt 1.
- Hộp khung giá: dòng bật "Ngày lễ" (tóm tắt ngày sắp tới, nút sửa), nút nhanh "Chỉ ngày lễ" (nút nhanh khác giữ nguyên Ngày lễ). Phần "Giá theo giờ & làm tròn": câu "khung có ngày lễ luôn được ưu tiên" + dòng "Ngày lễ của quán: n ngày sắp tới · Sửa".
- Hộp "Ngày lễ của quán" (`ngay_le_ui.dart`): danh sách sắp tới, bỏ từng ngày, thêm nhanh 01/01, 30/04, 01/05, 02/09, chọn trên lịch tối đa 15 ngày liền kèm tên. Lưu ngay mỗi lần (`BanRepository.luuNgayLe`).
- Khối ĐANG TÍNH GIỜ: "(ngày lễ, khung …)" khi khung Lễ đang áp.
- Ảnh mẫu `gia_gio_khung_le.png`, `gia_gio_ngay_le.png`; `gia_gio_co_khung.png` dựng lại (thêm khung Ngày lễ). test/modules/tinh_gio 89/89.
- Hướng dẫn `tinh-gio.md`: mục "Giá ngày lễ", 4 dòng lỗi; xuất lại `huong_dan.json`.
- Máy ảo + Demo (bản release): hộp khung giá có dòng Ngày lễ, "Chỉ ngày lễ" bật đúng, báo đỏ "Quán chưa có ngày lễ nào"; hộp Ngày lễ của quán mở, thêm nhanh 01/01/2027 → "Máy chủ chưa có ngày lễ. Báo chủ app cập nhật máy chủ." (máy chủ chưa áp); lịch chọn ngày mở được. Không bấm Lưu giá giờ. Dữ liệu Demo trước / sau giống hệt. Chưa thử: lưu thật, khối đang chạy giờ vào ngày lễ (chờ áp máy chủ).

### 28/11 18:15 — ĐÃ ÁP production

Chủ Quán: "Áp cả 5 đợt ngay". `DRYRUN=1 bash db-fix/gia_gio_ngay_le_ap_dung.sh` trên máy chủ thật PASS (tự huỷ), rồi `bash db-fix/gia_gio_ngay_le_ap_dung.sh`: sao lưu, áp, test PASS. Mốc hoàn tác `quannho_before_*_20261128_181507.dump` (trong /root/quannho-backups); hoàn tác: `ROLLBACK=1 bash db-fix/gia_gio_ngay_le_ap_dung.sh`.
