# Kế hoạch đợt 2: Lịch đặt dạng lưới "giờ × bàn / sân"

Đợt 2 của `lo-trinh-tinh-gio.md`. Lập 28/11/2026 khi Chủ Quán bảo "làm tiếp đi" sau đợt 1 (đợt 1 máy chủ chưa áp). Chỉ sửa app, **không đổi máy chủ** (đọc `ban_dat_truoc` như cũ, lưu qua `ban_dat_truoc_luu_v1` như cũ).

## Vì sao
Màn Lịch đặt hiện là danh sách theo từng bàn: muốn biết "19 giờ còn sân nào trống" phải đọc từng thẻ. Phần mềm sân (ALOBO, Sapo tổ hợp thể thao) dùng lưới giờ × sân để thấy ngay ô trống.

## Làm gì
1. Màn Lịch đặt có hai kiểu xem: **Lưới** (mặc định) và **Danh sách** (như cũ), nút đổi ở góc trên.
2. Lưới: cột giờ bên trái đứng yên; mỗi bàn / sân một cột, tên cột đứng yên khi cuộn dọc; mỗi giờ cao 64 điểm, kẻ vạch nửa giờ. Khung giờ hiện 06:00 – 24:00, nới ra nếu có lượt đặt sớm hơn.
3. Lượt đặt là khối màu theo trạng thái: đã đặt (xanh đậm), đã nhận (xanh lá), huỷ / không đến (xám, gạch ngang). Khối ghi giờ và tên khách; chạm mở hộp lượt đặt như danh sách (sửa, gọi, nhận, huỷ, không đến). Lượt qua nửa đêm cắt ở 24:00, ghi "→ hôm sau".
4. Chạm ô trống: mở hộp đặt với đúng bàn và giờ đó (làm tròn xuống nửa giờ). Ô đã qua giờ thì không mở.
5. Hôm nay có vạch đỏ "bây giờ"; mở màn tự cuộn tới gần giờ hiện tại.
6. Nhiều bàn hơn bề ngang: cuộn ngang, cột rộng tối thiểu 112; màn rộng thì cột giãn đều.

## Chưa làm (để sau)
- Hiện phiên đang chơi (bàn đang có khách) lên lưới.
- Kéo để đổi giờ / đổi bàn của lượt đặt.
- Lịch cố định lặp hàng tuần (đợt 3).

## Kiểm
- Ảnh mẫu lưới 360 và 1024 (ngày cố định 30/11/2030, cùng dữ liệu mẫu như ảnh danh sách).
- Test: vị trí / chiều cao khối theo giờ, cắt qua nửa đêm, ô trống làm tròn nửa giờ.
- Máy ảo + Demo: đổi kiểu xem, chạm khối, chạm ô trống mở hộp đặt đúng bàn / giờ (không lưu); chụp dữ liệu Demo trước / sau.

## Nhật ký

### 28/11 — Viết xong, thử máy ảo, CHƯA commit
- `lib/modules/tinh_gio/lich_luoi.dart`: `LichLuoi` (cột giờ đứng yên, tên cột cuộn ngang theo thân, ô trống `onTapUp` → giờ làm tròn nửa giờ, khối lượt đặt, vạch đỏ hôm nay, tự cuộn tới giờ hiện tại − 1) và các hàm thuần `lichGioDau`, `lichViTriKhoi`, `lichGioCuaO`. Cột rộng tối thiểu 112, màn rộng thì giãn đều.
- `dat_truoc_ui.dart`: `LichDatScreen` mặc định lưới, nút "Xem dạng danh sách / lưới giờ"; chạm ô đã qua báo "Giờ này đã qua"; `DatTruocFormSheet(tuMacDinh:)`.
- Test `test/modules/tinh_gio/lich_luoi_test.dart` (4); ảnh mẫu `lich_luoi_360.png`, `lich_luoi_1024.png`; hai ảnh danh sách dựng lại (thêm nút đổi kiểu xem, lệch đúng góc phải). test/modules/tinh_gio 60/60.
- Máy ảo + Demo: lưới A 1…Bàn 3, chạm 17:00 cột A 1 mở "Đặt · A 1 — Từ 17:00 đến 18:00" (đóng, không lưu); chạm giờ đã qua báo đúng; đổi kiểu xem qua lại; cỡ 1024 sáu cột kín màn. Dữ liệu Demo + số lượt đặt trước / sau giống hệt.

