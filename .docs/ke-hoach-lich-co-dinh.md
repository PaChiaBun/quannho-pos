# Kế hoạch đợt 3: Lịch cố định — đặt lặp hàng tuần

Đợt 3 của `lo-trinh-tinh-gio.md`, lập 28/11/2026 khi Chủ Quán duyệt đợt 2 và bảo "làm tiếp". Khách quen của sân bóng, cầu lông, pickleball thường thuê cố định ("thứ 3, thứ 5, 18–20 giờ, cả tháng"); hiện phải đặt từng buổi.

## Làm gì
1. **Máy chủ** (một migration + hoàn tác + test, thử bản sao; áp phải xin Chủ Quán):
   - Cột `ban_dat_truoc.chuoi_id` (uuid, null = lượt lẻ). Các buổi của một lịch cố định cùng `chuoi_id`.
   - `ban_dat_truoc_lap_v1(quán, bàn, tên khách, sđt, giờ bắt đầu buổi đầu, số phút, các thứ, đến ngày, ghi chú, cọc, bỏ qua buổi trùng)`: sinh các buổi từ ngày của giờ bắt đầu tới "đến ngày" (tính cả ngày đó), đúng các thứ đã chọn, cùng giờ đồng hồ Việt Nam; bỏ buổi đã qua. Khoá theo bàn rồi kiểm trùng TẤT CẢ buổi. Có buổi trùng mà chưa cho bỏ qua → không ghi gì, trả danh sách buổi trùng (app hỏi "Bỏ qua các buổi trùng?"). Tối đa 120 buổi, khoảng tối đa 366 ngày, mỗi buổi 15 phút – 24 giờ.
   - `ban_dat_truoc_huy_chuoi_v1(quán, chuỗi, từ lúc)`: huỷ các buổi còn chờ khách (`da_dat`) của chuỗi từ buổi đó trở đi. Buổi đã nhận / đã qua giữ nguyên.
   - Quyền như hàm đặt hiện có (`verify_staff_qr_membership_v4`, quyền thanh toán).
   - Sửa / huỷ / nhận từng buổi vẫn dùng các hàm cũ (buổi giữ `chuoi_id`).
2. **App:**
   - Hộp đặt: thêm "Lặp lại hàng tuần" (tắt mặc định) → chọn thứ (mặc định thứ của ngày đặt), "Đến ngày" (nút nhanh 4 tuần / 8 tuần / 3 tháng), dòng đếm "8 buổi: T3, T5 từ 02/12 tới 26/12".
   - Lưu lặp: gọi hàm mới; trùng thì hỏi bỏ qua, đồng ý thì gọi lại với bỏ qua.
   - Khối / dòng lượt đặt thuộc chuỗi có biểu tượng lặp; hộp lượt đặt thêm "Huỷ các buổi sau của lịch cố định" (từ buổi này).
3. **Tài liệu:** bài tinh-gio.md, kien-truc-data.md.

## Kiểm
- SQL: sinh đúng số buổi / đúng thứ / đúng giờ VN; bỏ buổi đã qua; trùng → không ghi gì + danh sách; bỏ qua trùng → ghi phần còn lại cùng chuỗi; vượt 120 buổi / 366 ngày / thứ sai / đến ngày trước ngày đầu → từ chối; huỷ chuỗi từ một buổi chỉ huỷ `da_dat` từ đó; phục vụ không quyền thanh toán bị chặn; hai hàm cũ vẫn chạy (bộ test đặt trước cũ PASS).
- Dart: đếm / liệt kê buổi trước khi gửi (khớp máy chủ).
- Máy ảo + Demo: mở hộp, bật lặp, xem dòng đếm, KHÔNG lưu (máy chủ chưa áp).

## Nhật ký

### 28/11 — Máy chủ viết xong (bản sao đạt, CHƯA ÁP), app viết xong, thử máy ảo, CHƯA commit
- Migration `20261128_dat_truoc_lich_co_dinh.sql` (+ ROLLBACK), test `supabase/tests/dat_truoc_lich_co_dinh_test.sql` 19 điểm. Bản sao: 19/19; `ban_dat_truoc_v1_test` 40, `ban_tinh_gio_v1_test` 50 TẤT CẢ PASS; hoàn tác chạy được (bỏ cột, bộ đặt trước cũ vẫn PASS). Script `db-fix/dat_truoc_lich_co_dinh_ap_dung.sh`.
- App: `DatTruoc.chuoiId`; `cacBuoiLap` (đếm buổi như máy chủ); `DatTruocRepository.datLap`, `huyChuoi`; máy chủ chưa có hàm → "Máy chủ chưa có lịch cố định…". Hộp đặt: "Lặp lại hàng tuần (khách quen)", các thứ, đến ngày (4 tuần / 8 tuần / 3 tháng / chọn ngày), dòng đếm, nút "Đặt N buổi"; trùng thì hộp "N buổi trùng giờ" → "Bỏ qua, đặt … buổi còn lại". Hộp lượt đặt: "Huỷ riêng buổi này", "Huỷ buổi này và các buổi sau". Khối lưới có biểu tượng lặp.
- Test `test/modules/tinh_gio/lich_co_dinh_test.dart` (5), ảnh mẫu `dat_lap_360.png`; test/modules/tinh_gio 66/66.
- Máy ảo + Demo: ô 18:00 A 1 → bật lặp → "4 buổi · T7 · 18:00–19:00 · 28/11 → 19/12" → "Đặt 4 buổi" → báo "Máy chủ chưa có lịch cố định…", không ghi gì. Dữ liệu Demo + số lượt đặt trước / sau giống hệt.

### 28/11 — Sửa theo Chủ Quán ("Sửa đợt 3" → "làm hết đi")
- Công tắc lặp theo màu app (xanh đậm); xem trước 6 buổi đầu ("T3 03/12"…, "+N buổi").
- Nút nhanh thêm "Hết tháng này", "Hết tháng sau" (thuê cả tháng).
- Hộp báo trùng ghi ngày, giờ buổi, khách trùng và giờ của lượt trùng, dòng "Đặt được N buổi không trùng".
- Hộp lượt đặt: "Lịch cố định · buổi i/n · thứ · tới dd/mm" (`chuoiDatProvider` → `DatTruocRepository.docChuoi`); xác nhận huỷ ghi số buổi sẽ huỷ và khoảng ngày.
- Kiểu danh sách: biểu tượng lặp cạnh dòng lượt đặt.
- Ảnh mẫu mới `luot_dat_chuoi_360.png`, `dat_lap_360.png` dựng lại; test/modules/tinh_gio 67/67. Máy ảo: có hai nút hết tháng, đếm buổi đúng; dữ liệu Demo trước / sau giống hệt.

### 28/11 18:18 — ĐÃ ÁP production

Chủ Quán: "Áp cả 5 đợt ngay". `DRYRUN=1 bash db-fix/dat_truoc_lich_co_dinh_ap_dung.sh` trên máy chủ thật PASS (tự huỷ), rồi `bash db-fix/dat_truoc_lich_co_dinh_ap_dung.sh`: sao lưu, áp, test PASS. Mốc hoàn tác `quannho_before_*_20261128_181842.dump` (trong /root/quannho-backups); hoàn tác: `ROLLBACK=1 bash db-fix/dat_truoc_lich_co_dinh_ap_dung.sh`.

### 28/11 18:44 — Sửa nóng trên production: đặt lặp từ app luôn lỗi

Thử thật trên Demo: bấm "Đặt 4 buổi" báo "Chưa làm được, kiểm tra mạng rồi thử lại"; nhật ký app: `PostgrestException DELETE requires a WHERE clause (21000)`. PostgREST trên máy chủ bật **safeupdate**: `DELETE FROM _qn_buoi;` (xoá bảng tạm) bị chặn. Test SQL chạy bằng psql không có safeupdate nên bản sao lẫn test sau áp đều không bắt được. Sửa: `20261128_dat_truoc_lap_where_true.sql` (chỉ thêm `WHERE true`; cũng sửa trong `20261128_dat_truoc_lich_co_dinh.sql`). Tái hiện trên máy chủ trong giao dịch tự huỷ (trước lỗi, sau chạy), Chủ Quán cho áp, sao lưu `quannho_before_lap_where_true_20261128_184429.dump`, áp, test PASS. Năm bộ test mới (đợt 1, 3, 4, 6, 7) thêm `LOAD 'safeupdate';` ngay sau `BEGIN;` — chạy lại trên máy chủ: chỉ đợt 3 vấp (trước khi sửa), các đợt khác PASS. Sau sửa: Demo đặt 4 buổi T7 05/12 → 26/12, huỷ cả chuỗi, đúng.
