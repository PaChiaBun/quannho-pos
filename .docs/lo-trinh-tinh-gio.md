# Lộ trình lớn: module Các hoạt động tính giờ

Lập 28/11/2026 theo lời Chủ Quán "lập nguyên phần kế hoạch lớn đi rồi thực hiện dần", từ phần đối chiếu với Sapo, KiotViet, PosApp, Vietbill, POS365, ALOBO (cùng ngày). Kế hoạch gốc của module (đã làm): `ke-hoach-ban-tinh-gio.md`. Mỗi đợt có kế hoạch chi tiết riêng khi bắt đầu; đợt sau chỉ bắt đầu khi đợt trước đã thử xong.

## Hiện có (tới 28/11)

Tính theo phút, giá riêng từng bàn, làm tròn lên 1.000 đ, máy chủ chốt giờ; sơ đồ tự co giãn (điện thoại / máy tính bảng / máy tính) có đồng hồ, giờ vào, người mở bàn, số món, cảnh báo quá 6 giờ, tổng tiền giờ đang chạy; khối "ĐANG TÍNH GIỜ" trong bàn; một hoá đơn, dòng giờ ghi rõ giờ vào – ra × đơn giá; chuyển / gộp bàn giữ đúng giờ; bỏ tiền giờ, huỷ bàn đã chạy phải có Quản lý; đặt trước, nhắc 30 phút, tính đủ khung đặt; QR khách không gọi được món giá giờ; tab "Tính giờ" ở thanh dưới. **Chưa phát hành**; chỉ quán Demo có bàn tính giờ.

## Các đợt (theo thứ tự làm)

| Đợt | Việc | Cho ai | Đụng tiền thật | Trạng thái |
|---|---|---|---|---|
| 1 | Giá theo khung giờ / thứ + làm tròn block, tối thiểu, ân hạn | mọi ngành, nhất là karaoke, sân | Có (máy chủ tính) | App xong (b9f95f1); máy chủ CHƯA ÁP — `ke-hoach-gia-gio-khung-block.md` |
| 2 | Lịch đặt dạng lưới "giờ × bàn / sân", chạm ô trống để đặt | sân, karaoke | Không | Xong (c0750be), chỉ app — `ke-hoach-lich-dat-luoi.md` |
| 3 | Lịch cố định: đặt lặp hàng tuần (ví dụ T3, T5 18–20 giờ cả tháng), kiểm trùng, bỏ một buổi | sân bóng, cầu lông, pickleball | Không | App xong; máy chủ CHƯA ÁP — `ke-hoach-lich-co-dinh.md` |
| 4 | Tiền cọc vào Thu Chi, tự trừ vào hoá đơn lúc thanh toán, hoàn / mất cọc khi huỷ | sân, karaoke đặt trước | Có | Chưa |
| 5 | Báo cáo tính giờ riêng trong module: giờ chơi, tiền giờ, tỉ lệ bàn được dùng theo giờ / ngày, tiền giờ so với đồ uống | chủ quán | Không (chỉ đọc) | Chưa |
| 6 | Ngày lễ trong bảng giá (Tết, 30/4, 2/9…, quán tự thêm ngày) | karaoke, sân | Có | Chưa |
| 7 | Gói giờ và hẹn giờ kết thúc: bán "2 giờ", nhắc khi còn 10 phút / hết giờ | karaoke, sân | Có (gói) | Chưa |
| 8 | Mất mạng: đo xem quán bị chặn thanh toán bàn tính giờ bao nhiêu lần, rồi mới quyết có làm chế độ dự phòng | mọi quán | Có | Chưa — đo trước |
| — | Cân nhắc sau, chỉ làm khi có quán thật đòi: tạm dừng giờ, khách tự đặt qua mạng, màn hình phụ cho khách xem giờ | | | Chưa |

## Vì sao thứ tự này

- **Đợt 1 trước:** chỗ thiếu lớn nhất so với đối thủ; không có thì quán karaoke / sân không dùng được giá thật của họ. Chủ Quán chốt làm xong đợt 1 rồi mới phát hành.
- **Đợt 2, 3 liền nhau:** cùng màn Lịch đặt; lịch cố định cần lưới để thấy trùng.
- **Đợt 4 sau 3:** cọc gắn với lượt đặt; đụng Thu Chi và thanh toán nên làm khi lịch đặt đã ổn.
- **Đợt 5:** chỉ đọc, an toàn, cần có dữ liệu thật mới có ý nghĩa nên để sau khi phát hành.
- **Đợt 6, 7:** mở rộng đợt 1 khi có quán thật cần.
- **Đợt 8:** tốn công và rủi ro tiền nhất; đo trên quán thật trước.

## Nguyên tắc chung mọi đợt

1. Không cài gì thì quán tính y như cũ (test hồi quy).
2. Tiền thật do máy chủ chốt; app tính tạm phải khớp (bộ ca kiểm dùng chung SQL và Dart).
3. Thay đổi máy chủ: thử trên bản sao (`db-fix/chuoi_stage_dryrun.sh`), xin Chủ Quán trước khi áp, có backup và tệp hoàn tác.
4. Thử trên máy ảo + quán Demo; chụp dữ liệu Demo trước / sau; hỏi trước khi bấm Thanh toán / Mở bàn thật.
5. Mỗi đợt xong: sửa bài hướng dẫn Boom (đăng khi phát hành), `.docs/kien-truc-data.md`, `.docs/tinh-nang.md`, ghi nhật ký vào kế hoạch đợt.

## Nhật ký lộ trình

- 28/11: lập lộ trình; đợt 1 có kế hoạch chi tiết và 4 quyết định của Chủ Quán; bắt đầu đợt 1 giai đoạn A (máy chủ).
- 28/11: đợt 1 giai đoạn A (máy chủ) viết xong, bản sao đạt (31/31 + bộ cũ), chờ Chủ Quán cho áp.
- 28/11: đợt 2 (lịch dạng lưới) viết xong, thử máy ảo; chỉ app.
- 28/11: đợt 3 (lịch cố định) máy chủ viết + bản sao đạt (chưa áp), app viết xong, thử máy ảo.
