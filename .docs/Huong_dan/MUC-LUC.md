# Mục lục hướng dẫn sử dụng Quán Nhỏ POS

Kế hoạch: [ke-hoach-trien-khai-boom.md](ke-hoach-trien-khai-boom.md) · Khuôn bài: [TEMPLATE.md](TEMPLATE.md)

| Module | Mã | Tệp | Trạng thái |
|---|---|---|---|
| Bán hàng | `pos` | [ban-hang.md](ban-hang.md) | Bản nháp — chờ Chủ Quán duyệt |
| In Hoá Đơn | `bill_printer` | [in-hoa-don.md](in-hoa-don.md) | Bản nháp — chờ Chủ Quán duyệt |
| QR Gọi Món | `qr_order` | [qr-goi-mon.md](qr-goi-mon.md) | Bản nháp — chờ Chủ Quán duyệt |
| Thu Chi | `finance` | [thu-chi.md](thu-chi.md) | Bản nháp — chờ Chủ Quán duyệt |
| Kho hàng | `kho` | [kho-hang.md](kho-hang.md) | Bản nháp — chờ Chủ Quán duyệt |
| Kho Chuyên Nghiệp | `kho_pro` | [kho-chuyen-nghiep.md](kho-chuyen-nghiep.md) | Bản nháp — chờ Chủ Quán duyệt |
| Quản lý Bàn | `table` | [quan-ly-ban.md](quan-ly-ban.md) | Bản nháp — chờ Chủ Quán duyệt |
| Bếp | `kitchen` | [bep.md](bep.md) | Bản nháp — chờ Chủ Quán duyệt |
| Khách hàng | `loyalty` | [khach-hang.md](khach-hang.md) | Bản nháp — chờ Chủ Quán duyệt |
| Nhân viên | `staff` | [nhan-vien.md](nhan-vien.md) | Bản nháp — chờ Chủ Quán duyệt |
| Chấm công | `chamcong` | [cham-cong.md](cham-cong.md) | Bản nháp — chờ Chủ Quán duyệt |
| Lương | `tinhluong` | [luong.md](luong.md) | Bản nháp — chờ Chủ Quán duyệt |
| Báo cáo | `report` | [bao-cao.md](bao-cao.md) | Bản nháp — chờ Chủ Quán duyệt |
| Báo cáo chuỗi | `chain` | [bao-cao-chuoi.md](bao-cao-chuoi.md) | Bản nháp — chờ Chủ Quán duyệt |
| Vận Hành | `kay_ops` | [van-hanh.md](van-hanh.md) | Bản nháp — chờ Chủ Quán duyệt |
| Nhật Ký Log | `log_viewer` | [nhat-ky-log.md](nhat-ky-log.md) | Bản nháp — chờ Chủ Quán duyệt |

Danh sách lỗi / việc cần sửa gom từ 16 bài: [viec-can-sua.md](viec-can-sua.md)

Gói module theo loại hình quán: [Trà sữa mang đi](goi-tra-sua-mang-di.md) (Giai đoạn 3 — 6 đề xuất chờ duyệt).

**Boom tra hướng dẫn (23/10/2026, chưa phát hành):** bài được cắt thành đoạn bằng `dart run tool/xuat_huong_dan_boom.dart`
→ `assets/boom_help/huong_dan.json` (bỏ front-matter, "Ghi chú cho Chủ Quán", ghi chú phiên bản app; chặn lọt tên kỹ thuật).
Sửa bài → xuất lại + đóng dấu (`dart run tool/dong_dau_huong_dan.dart <bài>.md`); test `test/docs/huong_dan_dong_bo_test.dart`
báo bài nào cần rà khi code đổi.

Rà chéo với code 22/10/2026 (3 vòng QC độc lập): cả 16 bài đã sửa theo code hiện tại (bao-cao-chuoi chỉ sửa nhãn "Ví/khác").

**Khi nạp vào Boom:** công cụ xuất tự cắt front-matter và mục "Ghi chú cho Chủ Quán"; không nạp tệp này, `viec-can-sua.md`, `ke-hoach-trien-khai-boom.md`, `TEMPLATE.md`, `goi-tra-sua-mang-di.md` (xem [kế hoạch](ke-hoach-trien-khai-boom.md)).
