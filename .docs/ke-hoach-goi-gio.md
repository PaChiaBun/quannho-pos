# Kế hoạch: gói giờ và nhắc hết giờ (đợt 7 lộ trình tính giờ)

Lập 28/11/2026 khi Chủ Quán bảo "làm tiếp đi" (đợt 6 đã commit ec81b38). Lộ trình: `lo-trinh-tinh-gio.md`. **Đụng tiền thật**. Viết, thử bản sao, xin Chủ Quán trước khi áp; **áp sau đợt 6** (migration tự kiểm).

## Chủ Quán đã chốt (28/11)

1. **Giá gói riêng, lố tính thêm**: quán đặt sẵn gói, ví dụ "2 giờ = 100.000". Chơi 2 giờ 20 phút → 100.000 + 20 phút theo giá giờ thường (có khung giá, ngày lễ, làm tròn).
2. **Về sớm tính đủ gói**: mua gói 2 giờ, chơi 1 giờ 30 vẫn trả đủ giá gói.
3. **Gói cài theo từng bàn**, có "Cả khu" (như khung giá).

## Cách làm

Máy chủ (`20261128_goi_gio.sql`):
- Bảng `ban_goi_gio` (bàn, `so_phut` 15–720, `gia`, `thu_tu`), tối đa 6 gói mỗi bàn, không trùng số phút. Ghi qua `ban_goi_gio_luu_v1(quán, mảng bàn, gói jsonb)` — Chủ quán / Quản lý.
- Cột `ban_sessions.goi_phut`, `goi_gia`: gói của **đoạn đang tính**, chép giá lúc chọn (sau đổi bảng gói không ảnh hưởng khách đang chơi). App không sửa thẳng được (trigger giữ nguyên giá trị cũ khi ghi từ app).
- `ban_chon_goi_gio_v1(quán, phiên, mã gói | null)`: chọn gói lần đầu cần quyền thu tiền (như chốt giờ); **đổi hoặc bỏ** gói đã chọn cần Chủ quán / Quản lý.
- `qn_tinh_gio_tinh_tien_v3(bàn, giá gốc, vào, phút chơi, gói phút, gói giá)`: làm tròn như cũ ra `S`; có gói thì `S = max(S, gói phút)` (tính đủ gói); tiền = giá gói + ceil(Σ giá từng phút từ phút thứ `gói phút` tới `S` / 60 / 1000) × 1000 (phần lố theo khung giá + ngày lễ). Không gói = đúng như v2. `qn_tinh_gio_tinh_tien_v2` thành vỏ gọi v3 không gói.
- `qn_tinh_gio_ghi_dong_v1`: đọc gói của phiên, tên dòng:
  - trong gói: "Giờ chơi · P2 · 18:00 – 20:00 · chơi 1 giờ 30 phút · gói 2 giờ 100.000 đ"
  - lố: "… · chơi 2 giờ 17 phút · gói 2 giờ 100.000 đ + 30 phút × 60.000 đ/giờ"
- **Chuyển bàn khi đang có gói**: đoạn bàn cũ chốt với gói (đủ giá gói); bàn mới nhận **phần gói còn lại** (số phút còn, giá 0). Hết phần còn thì bàn mới tính như thường. **Gộp bàn**: đoạn bàn nguồn chốt với gói như cũ, gói không sang bàn đích.

App:
- Phép tính `tinhGioTien` thêm gói, chép đúng v3; `tinhGioTamTinhBan` đọc gói của phiên. Bộ ca kiểm chung SQL ↔ Dart.
- Hộp **Đặt giá giờ**: phần "Gói giờ" trong "Giá theo giờ & làm tròn" (thêm / sửa / xoá gói: số giờ + giá), lưu cùng nút Lưu, theo "Chỉ bàn này / Cả khu".
- Khối **ĐANG TÍNH GIỜ**: nút "Chọn gói" (bàn có gói) → hộp chọn gói; có gói thì ghi "Gói 2 giờ · còn 25 phút" / "Hết gói, lố 8 phút". Thẻ bàn ghi "còn 25'" / "lố 8'".
- **Nhắc**: khi còn 10 phút và khi hết gói, máy đang mở app hiện hộp nhắc (như nhắc khách đặt trước) với nút "Đã báo khách". Nhắc theo từng máy (không ghi máy chủ).

## Bộ ca kiểm (SQL ↔ Dart)

Giá gốc 60.000, gói 120 phút = 100.000, ngày thường (30/11/2026 Thứ Hai).

| # | Cài đặt | Chơi | Kỳ vọng |
|---|---|---|---|
| G1 | gói 120 = 100.000 | 90' | 100.000, tính 120' |
| G2 | như G1 | 120' | 100.000 |
| G3 | như G1 | 137' | 100.000 + 17' × 60.000 = 117.000 |
| G4 | gói + block 30 | 137' | 100.000 + 30' = 130.000 |
| G5 | gói + block 30 ân hạn 5 | 123' | 100.000 |
| G6 | gói + khung 17–23 = 80.000, vào 16:00 | 150' | 100.000 + 30' × 80.000 = 140.000 |
| G7 | gói phút 50, giá 0 (phần còn sau chuyển bàn) | 30' | 0 |
| G8 | như G7 | 70' | 20' × 60.000 = 20.000 |
| G9 | gói + tối thiểu 180 | 90' | tối thiểu thắng: 180' = 100.000 + 60' = 160.000 |
| G10 | không gói | 2.000 lượt ngẫu nhiên | khớp v2 |
| G11 | ghi dòng có gói | | tên dòng đúng mẫu, một dòng |
| G12 | chọn gói (phục vụ có quyền thu tiền) → đổi gói (phục vụ bị chặn, chủ quán được) → bỏ gói | | |
| G13 | chuyển bàn khi chơi 40' gói 120 | | dòng bàn cũ 100.000; phiên mới gói 80 phút giá 0 |
| G14 | lưu gói: phục vụ bị chặn; 7 gói bị chặn; trùng số phút bị chặn; cả khu | | |

## Nhật ký

### 28/11 — Máy chủ: viết xong, bản sao đạt, CHƯA ÁP

- `supabase/migrations/20261128_goi_gio.sql` (+ `_ROLLBACK`): như mục "Cách làm". v3 chép nguyên v2 đợt 6, thêm gói; ghi_dong chép bản đợt 1, chỉ thêm gói + tên dòng gói; chuyển bàn chép bản production 28/11 (đọc chỉ đọc), thêm phần gói còn lại. Hoàn tác: ba hàm về nguyên văn, bỏ v3, hàm gói, trigger, hai cột, bảng.
- Test `supabase/tests/goi_gio_test.sql` 25 điểm (G1–G15).
- Bản sao (`chuoi_stage_dryrun.sh`, TAG=goi_gio, áp đợt 1 + 6 + 7): gói giờ 25/25; khung giá, ngày lễ, tính giờ v1, đặt trước v1, tên dòng 5/5 TẤT CẢ PASS; hoàn tác rồi ngày lễ, khung giá, tính giờ, đặt trước vẫn PASS, bảng + cột gói mất. Bản sao đã xoá.
- Kịch bản áp `db-fix/goi_gio_ap_dung.sh`. Chưa chạy, chờ Chủ Quán.

### 28/11 — App: viết xong

- `gia_gio.dart`: `GoiGio`, `thoiLuongChu`, `GiaGioCaiDat.goi` (+ `goiTrung`), `tinhGioTien(goiPhut, goiGia)` chép v3. `BanSessionModel.goiPhut/goiGia`; `tinhGioTamTinhBan` nhận gói (4 chỗ gọi trong ban_screen; màn bàn đọc gói từ phiên đọc lại để chọn / bỏ gói hiện ngay).
- `giaGioCaiDatProvider` đọc `ban_goi_gio` riêng (máy chủ chưa có bảng gói vẫn đọc được khung giá).
- Hộp Đặt giá giờ: phần "Gói giờ" (thêm / sửa / xoá, tối đa 6), lưu bằng `BanRepository.luuGoiGio` sau khung giá, trước giá một giờ; không đổi thì không gọi.
- `goi_gio_ui.dart`: `GoiGioSheet`, `ChonGoiSheet` (`BanRepository.chonGoiGio`), `GoiGioDongBan` trong khối ĐANG TÍNH GIỜ, `TinhGioNhacGoi` (gắn trong `TinhGioNhacDatSan`; chỉ theo dõi phiên khi quán có gói). Thẻ bàn: nhãn "gói còn 25'" / "hết gói, lố 8'".
- Test `test/modules/tinh_gio/goi_gio_test.dart` (bộ ca chung + hồi quy 2.000 lượt). Ảnh mẫu `goi_gio_them.png`, `goi_gio_chon.png`, `goi_gio_dong_ban.png`; `gia_gio_co_khung.png` dựng lại. test/modules/tinh_gio 99/99.
- Hướng dẫn `tinh-gio.md`: mục "Bán gói giờ", 4 dòng lỗi; xuất lại `huong_dan.json`.
- Máy ảo + Demo (bản release): hộp Đặt giá giờ A 1 có phần "Gói giờ", thêm gói 2 giờ 100.000 → "1 gói giờ"; bấm Lưu → "Máy chủ chưa có gói giờ. Báo chủ app cập nhật máy chủ." (máy chủ chưa áp), giá một giờ không đổi. Dữ liệu Demo trước / sau giống hệt. Chưa thử: chọn gói cho bàn đang chơi, nhắc 10 phút / hết gói, chuyển bàn có gói, thanh toán (chờ áp máy chủ; hỏi trước khi bấm Thanh toán trên Demo).
