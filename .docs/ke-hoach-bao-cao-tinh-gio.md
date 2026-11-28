# Kế hoạch đợt 5: Báo cáo tính giờ riêng trong module

> 28/11 tối: không còn màn riêng — là khối cuối Báo cáo → Doanh thu (xem Nhật ký).

Đợt 5 của `lo-trinh-tinh-gio.md`, bắt đầu 28/11/2026 khi Chủ Quán bảo "làm tiếp đi" (đợt 4 đã commit 5979af1). **Chỉ đọc**, không sửa máy chủ, không đụng tiền.

## Dữ liệu có sẵn (đọc máy chủ 28/11)
- `ban_sessions`: `gio_bat_dau` (phiên tính giờ), `status` (`closed` = đã thanh toán, `cancelled`), `opened_at`, `closed_at`, `table_id`.
- `ban_session_items`: dòng tiền giờ có `gio_tu`, `gio_den`, `subtotal`; dòng món khác không có `gio_tu`. Dòng còn lại sau khi phiên đóng.
- Production 28/11: 12 phiên tính giờ (đều ở Demo), 10 đã thanh toán.

## Làm gì
1. Nút **"Báo cáo"** cạnh "Lịch đặt" ở màn Tính giờ → màn "Báo cáo tính giờ".
2. Chọn khoảng: Hôm nay / 7 ngày / 30 ngày / Tháng này (tính theo giờ thanh toán `closed_at`).
3. Ô tổng: số lượt chơi, tổng giờ chơi, tiền giờ, tiền món kèm (đồ uống, đồ ăn), tỉ lệ tiền giờ / tổng, trung bình mỗi lượt (thời lượng, tiền).
4. **Giờ đông khách**: 24 cột theo giờ trong ngày, mỗi cột = % bàn tính giờ đang có khách trung bình trong giờ đó (phút chơi rơi vào giờ đó ÷ (60 × số ngày × số bàn tính giờ)).
5. **Theo ngày**: tiền giờ + món kèm từng ngày.
6. **Theo bàn**: lượt, giờ chơi, tiền giờ, món kèm, giờ chơi trung bình mỗi ngày; xếp theo tiền giờ.
7. Phiên huỷ không tính. Số tiền là trước giảm giá / phụ thu của hoá đơn (giảm giá gắn cả hoá đơn, không chia được cho giờ và món) — ghi rõ dưới màn.

## Kiểm
- Dart: chia phút vào từng giờ (vắt qua nửa đêm, vắt nhiều giờ), tổng hợp theo bàn / ngày, khoảng không có lượt.
- Ảnh mẫu màn báo cáo (điện thoại 360), dữ liệu giả.
- Máy ảo + Demo: mở báo cáo 30 ngày, so số với truy vấn chỉ đọc trên máy chủ.

## Nhật ký

### 28/11 — Viết xong, thử máy ảo + Demo, CHƯA commit
- `lib/modules/tinh_gio/bao_cao_tinh_gio.dart`: `chiaPhutTheoGio`, `tongHopTinhGio`, `ghepLuotChoi`, `docLuotChoi` (phiên `closed` có `gio_bat_dau`, theo `closed_at`; dòng đọc theo lô 200 phiên), màn `BaoCaoTinhGioScreen` (4 ô tổng, Giờ đông khách, Theo ngày, Theo bàn).
- Nút biểu đồ cạnh "Lịch đặt" ở màn Tính giờ, chỉ hiện cho Chủ quán / Quản lý / Thu ngân / người có quyền `report.view` (cùng luật tab Báo cáo).
- Test `bao_cao_tinh_gio_test.dart` 5; ảnh mẫu `bao_cao_tinh_gio_360.png`; test/modules/tinh_gio 80/80.
- Máy ảo + Demo, 30 ngày: 10 lượt, 116 giờ 17 phút, tiền giờ 6.494.000 đ, món kèm 355.000 đ — khớp truy vấn chỉ đọc trên máy chủ (10 | 6.977 phút | 6.494.000 | 355.000). Sửa sau khi xem: mũi tên quay lại bị chìm (đặt iconTheme), chữ ngày ở 30 ngày quá nhỏ (cho tràn thay vì thu nhỏ).
- Bài tinh-gio.md: mục "Báo cáo tính giờ" + một dòng lỗi.

### 28/11 tối — chuyển vào Báo cáo → Doanh thu
- Chủ Quán đổi hai lần: bỏ nút biểu đồ và màn `BaoCaoTinhGioScreen` ở màn Tính giờ; báo cáo là khối `BaoCaoTinhGioKhoi` cuối tab **Doanh thu** của module Báo cáo, cùng kỳ Hôm nay / Tuần này / Tháng này (`khoangTuKy`, cắt ở hôm nay), chỉ hiện khi bật module (`tinhGioModuleActiveProvider`). Quyền xem theo quyền vào Báo cáo như cũ. Commit eef493f → 1f4d09d.
- QC 28/11 21:45 trên Demo: hôm nay 8 lượt / 532.000 tiền giờ / 310.000 món, khớp máy chủ; bàn bị gộp không thành lượt thừa (phiên nguồn không ở trạng thái `closed`). "Giờ chơi" là giờ đã tính tiền: lượt đặt trước tính tới hết khung đặt, gói tính đúng phút chơi.
