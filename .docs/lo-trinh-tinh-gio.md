# Lộ trình lớn: module Các hoạt động tính giờ

Lập 28/11/2026 theo lời Chủ Quán "lập nguyên phần kế hoạch lớn đi rồi thực hiện dần", từ phần đối chiếu với Sapo, KiotViet, PosApp, Vietbill, POS365, ALOBO (cùng ngày). Kế hoạch gốc của module (đã làm): `ke-hoach-ban-tinh-gio.md`. Mỗi đợt có kế hoạch chi tiết riêng khi bắt đầu; đợt sau chỉ bắt đầu khi đợt trước đã thử xong.

## Hiện có (tới 28/11)

Tính theo phút, giá riêng từng bàn, làm tròn lên 1.000 đ, máy chủ chốt giờ; sơ đồ tự co giãn (điện thoại / máy tính bảng / máy tính) có đồng hồ, giờ vào, người mở bàn, số món, cảnh báo quá 6 giờ, tổng tiền giờ đang chạy; khối "ĐANG TÍNH GIỜ" trong bàn; một hoá đơn, dòng giờ ghi rõ giờ vào – ra × đơn giá; chuyển / gộp bàn giữ đúng giờ; bỏ tiền giờ, huỷ bàn đã chạy phải có Quản lý; đặt trước, nhắc 30 phút, tính đủ khung đặt; QR khách không gọi được món giá giờ; tab "Tính giờ" ở thanh dưới. **Chưa phát hành**; chỉ quán Demo có bàn tính giờ.

## Các đợt (theo thứ tự làm)

| Đợt | Việc | Cho ai | Đụng tiền thật | Trạng thái |
|---|---|---|---|---|
| 1 | Giá theo khung giờ / thứ + làm tròn block, tối thiểu, ân hạn | mọi ngành, nhất là karaoke, sân | Có (máy chủ tính) | App xong (b9f95f1); máy chủ ĐÃ ÁP 28/11 18:14 (mốc 20261128_181424) — `ke-hoach-gia-gio-khung-block.md` |
| 2 | Lịch đặt dạng lưới "giờ × bàn / sân", chạm ô trống để đặt | sân, karaoke | Không | Xong (c0750be), chỉ app — `ke-hoach-lich-dat-luoi.md` |
| 3 | Lịch cố định: đặt lặp hàng tuần (ví dụ T3, T5 18–20 giờ cả tháng), kiểm trùng, bỏ một buổi | sân bóng, cầu lông, pickleball | Không | App xong (0cc4764); máy chủ ĐÃ ÁP 28/11 18:18 (mốc 20261128_181842) — `ke-hoach-lich-co-dinh.md` |
| 4 | Tiền cọc vào Thu Chi, tự trừ vào hoá đơn lúc thanh toán, hoàn / mất cọc khi huỷ — làm chung ví khách (module Khách hàng) | sân, karaoke đặt trước | Có | App xong; máy chủ ĐÃ ÁP 28/11 18:19 (mốc 20261128_181909) — `ke-hoach-tien-coc.md` |
| 5 | Báo cáo tính giờ riêng trong module: giờ chơi, tiền giờ, tỉ lệ bàn được dùng theo giờ / ngày, tiền giờ so với đồ uống | chủ quán | Không (chỉ đọc) | App xong, chỉ đọc, không đổi máy chủ — `ke-hoach-bao-cao-tinh-gio.md` |
| 6 | Ngày lễ trong bảng giá (Tết, 30/4, 2/9…, quán tự thêm ngày) | karaoke, sân | Có | App xong; máy chủ ĐÃ ÁP 28/11 18:15 (mốc 20261128_181507) — `ke-hoach-ngay-le-gia-gio.md` |
| 7 | Gói giờ và hẹn giờ kết thúc: bán "2 giờ", nhắc khi còn 10 phút / hết giờ | karaoke, sân | Có (gói) | App xong; máy chủ ĐÃ ÁP 28/11 18:17 (mốc 20261128_181658) — `ke-hoach-goi-gio.md` |
| 8 | Mất mạng: đo xem quán bị chặn thanh toán bàn tính giờ bao nhiêu lần, rồi mới quyết có làm chế độ dự phòng | mọi quán | Có | Đã đo 30 ngày (28/11): lúc mạng chập chờn 496/497 phiên vẫn thanh toán xong → đề xuất chưa làm dự phòng, đo lại sau phát hành — `ke-hoach-mat-mang.md` |
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
- 28/11: đợt 4 (tiền cọc) lập kế hoạch, Chủ Quán chốt làm chung ví khách + 4 quyết định.
- 28/11: đợt 4 giai đoạn A (máy chủ cọc = ví khách, thanh toán bàn v6) viết xong, bản sao đạt.
- 28/11: đợt 4 giai đoạn B–D (app: hộp đặt khách + cọc, xử lý cọc, thu tiền bàn trừ cọc, hồ sơ khách) viết xong, thử máy ảo; Chủ Quán duyệt thiết kế, bảo commit, chưa áp.
- 28/11: đợt 5 (báo cáo tính giờ, chỉ đọc) viết xong, thử máy ảo.
- 28/11: đợt 6 (ngày lễ) Chủ Quán chốt khung Lễ luôn thắng + quán tự thêm ngày; máy chủ viết, bản sao đạt (chưa áp); app viết xong.
- 28/11: đợt 7 (gói giờ) Chủ Quán chốt giá gói riêng + lố tính thêm, về sớm đủ gói, gói theo bàn có Cả khu; máy chủ viết, bản sao đạt (chưa áp); app viết xong.
- 28/11: đợt 8 đo mất mạng 30 ngày trên quán thật (`tool/do_mat_mang.sh`, chỉ đọc): 496/497 phiên thanh toán lúc mạng chập chờn vẫn xong; đề xuất chưa làm chế độ dự phòng, chờ Chủ Quán quyết.
- 28/11 18:14–18:19: Chủ Quán bảo "Áp cả 5 đợt ngay". Áp máy chủ theo thứ tự 1 → 6 → 7 → 3 → 4, mỗi đợt chạy thử trên máy chủ thật (tự huỷ) rồi sao lưu → áp → test, tất cả PASS; bộ tính giờ v1, đặt trước v1, tên dòng chạy lại PASS. Trước khi áp đã so `settle_ban_session_v5` và `qn_tinh_gio_ghi_dong_v1` trên máy chủ trùng bản đã chép (md5). App vẫn chưa phát hành; chỉ quán Demo có bàn tính giờ.
- 28/11 18:25–18:50: thử thật trên Demo (máy ảo, bản release): gói giờ + thanh toán 50.000 đúng; ngày lễ + khung Lễ 90.000 (app và máy chủ khớp); cọc 50.000 → thanh toán 83.000, trừ ví 50.000, khách trả thêm 33.000, Thu Chi không đếm hai lần; lịch cố định lỗi safeupdate → sửa nóng `20261128_dat_truoc_lap_where_true.sql` (ĐÃ ÁP 18:44, mốc 20261128_184429) rồi đặt 4 buổi + huỷ chuỗi đúng. Gỡ hết cài đặt thử. Còn lỗi app: đặt ở màn Lịch đặt xong quay về, màn tính giờ không thấy lượt mới cho tới khi mở lại app (mở bàn không hỏi nhận khách đặt).
- 28/11 19:00: sửa lỗi app "đặt ở Lịch đặt xong, màn tính giờ không thấy lượt mới": Mở bàn hỏi thẳng máy chủ lượt đặt sắp tới của bàn (`DatTruocRepository.luotKeTiepCuaBan`, mất mạng thì dùng danh sách trong máy); rời màn Lịch đặt thì đọc lại lượt đặt gần đây. Thử máy ảo + Demo: thẻ A 2 hiện lượt mới ngay, Mở bàn hỏi nhận khách; lượt thử đã huỷ.
- 28/11 19:00–19:35: QC sâu. So 6.000 ca ngẫu nhiên app ↔ máy chủ (khung, ngày lễ, gói, làm tròn, giá lẻ): lệch 0. Rà mã độc lập tìm 6 lỗi đáng kể; đã sửa: (1) bill / phiếu tạm tính in và QR đòi cả phần cọc → in "Đã cọc", "CÒN PHẢI TRẢ", QR lấy số còn phải trả; (2) màn Thu tiền xoá khách trước khi tra, mạng chập thì hiện đủ tổng mà máy chủ vẫn trừ ví → giữ khách / ví của cọc; (5) đối soát lại không trả vi_da_tru → đọc từ payment_settlements; máy chủ `20261128_tinh_gio_qc_sua.sql` (ĐÃ ÁP 19:10, mốc 20261128_191050, Chủ Quán cho): (4) gộp / huỷ bàn có cọc → cọc kẹt, nay xử lý được trong Lịch đặt, (6) đổi gói sau khi chốt → chốt lại dòng tiền giờ, (3) khách lượt đặt đã xoá không chặn thanh toán. Thử thật Demo thêm: Bán hàng, cọc quán giữ / để ví / hoàn, gộp bàn có cọc rồi gỡ cọc, chuyển bàn có gói (đoạn cũ 50.000, bàn mới phần gói còn giá 0, tổng 51.000), báo cáo 7 ngày khớp máy chủ. Lưới Lịch đặt: lượt đã huỷ / không đến (cọc xong) không còn chiếm ô.
- 28/11 19:33: Chủ Quán chốt "Tự mang cọc sang" khi gộp bàn. `20261128_gop_ban_mang_coc.sql` (ĐÃ ÁP, mốc 20261128_193254): gộp thì lượt đặt đã nhận (còn cọc) gắn sang phiên đích; bàn đích có cọc của khách khác thì không mang, app báo xử lý trong Lịch đặt. Test M1–M3; thử Demo: gộp A 2 (cọc 20.000) vào A 1, thanh toán A 1 trừ 2.000 (hoá đơn 2.000), phần dư ở lại ví.
