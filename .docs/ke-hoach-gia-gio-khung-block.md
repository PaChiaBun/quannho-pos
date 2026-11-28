# Kế hoạch: giá theo khung giờ và làm tròn theo block (module Các hoạt động tính giờ)

Lập 28/11/2026 theo lời Chủ Quán "Lập kế hoạch", sau phần đối chiếu đối thủ (Sapo, KiotViet, PosApp quảng bá giá theo khung giờ / ngày và làm tròn block; mình mới tính theo phút, một giá mỗi bàn). Kế hoạch gốc của module: `ke-hoach-ban-tinh-gio.md`.

## 1. Mục tiêu

1. **Giá theo khung giờ và theo thứ:** ví dụ bi da 50.000 đ/giờ trước 17:00, 70.000 đ/giờ từ 17:00; karaoke cuối tuần đắt hơn ngày thường; sân bóng giờ tối đắt hơn.
2. **Làm tròn theo block và chơi tối thiểu:** ví dụ làm tròn lên mỗi 15 / 30 phút, tối thiểu 1 giờ; có thể cho "ân hạn" vài phút (quá block 3 phút chưa tính sang block mới).
3. Quán không cài gì thêm thì **tính y như bây giờ** (theo phút, một giá, làm tròn lên 1.000 đ). Đây là điều kiện bắt buộc, có test so sánh.

Không làm trong đợt này: ngày lễ (để sau, xem mục 7), tạm dừng giờ, bán gói giờ, báo cáo theo bàn, lịch cố định cho sân.

## 2. Hiện trạng (đọc mã và máy chủ 28/11, chỉ đọc)

- Giá một giờ = `products.sell_price` của "món giá giờ" gắn ở `ban_dining_tables.gia_gio_product_id`. Mỗi mức giá là một món ("Giờ chơi 60.000 đ/giờ", danh mục "Tiền giờ"); nhiều bàn dùng chung một món.
- Tiền thật do máy chủ chốt: `qn_tinh_gio_ghi_dong_v1` (số phút = làm tròn lên, tối thiểu 1; tiền = ceil(phút × giá / 60 / 1000) × 1000; khách đặt trước thì tính tới hết khung đặt). Ghi đúng một dòng `ban_session_items` có `gio_tu`, tên "Giờ chơi · Bàn 3 · 14:05 – 15:35 · 1 giờ 30 phút × 60.000 đ/giờ" (migration 20261127).
- App tính tạm (thẻ bàn, khối ĐANG TÍNH GIỜ, ô tóm tắt, TỔNG TẠM TÍNH) bằng `tinhGioTamTinhBan` / `tinhGioThanhTien` trong `lib/modules/tinh_gio/tinh_gio.dart`, phải ra đúng số máy chủ.
- Chuyển / gộp bàn: đoạn ở bàn cũ chốt riêng (`ban_chuyen_ban_tinh_gio_v1` gọi ghi dòng với `p_du_khung = false`).
- Production: **chỉ quán Demo** có bàn tính giờ (6 bàn). Đổi cách tính lúc này không đụng quán thật.

## 3. Cách tính mới (đề xuất)

**Bảng giá gắn theo từng bàn** (Chủ Quán chốt 28/11). Giá gốc vẫn là món giá giờ như nay; khung giá và cách làm tròn lưu riêng cho mỗi bàn. Để quán nhiều bàn khỏi đặt từng bàn, hộp Đặt giá giờ giữ nút "Chỉ bàn này / Cả khu": chọn "Cả khu" thì chép cùng cài đặt cho mọi bàn của khu.

Mỗi bàn có:
- **Giá gốc**: `sell_price` của món giá giờ như cũ.
- **Các khung giá** (0 hoặc nhiều): thứ áp dụng (T2…CN), từ giờ – đến giờ (giờ Việt Nam, cho phép qua đêm, ví dụ 22:00 – 02:00), giá một giờ. Khung trùng nhau thì khung đứng trên thắng (Chủ quán kéo thứ tự).
- **Làm tròn**: block (1, 5, 10, 15, 30, 60 phút; mặc định 1 = theo phút), tối thiểu (phút, mặc định 0), ân hạn (phút, mặc định 0, nhỏ hơn block).

Các bước tính cho một lượt chơi từ `vao` tới `ra`:
1. `phut_choi` = làm tròn lên số phút thực (như nay, tối thiểu 1).
2. `phut_tinh` = áp làm tròn: nếu `phut_choi` vượt bội số block gần nhất không quá ân hạn thì giữ bội số đó, còn lại làm tròn lên bội số block; rồi lấy tối đa với `toi_thieu`. Khách đặt trước: lấy tối đa với độ dài khung đặt (như nay).
3. Chia khoảng [`vao`, `vao` + `phut_tinh`) theo ranh giới khung giá; mỗi phút lấy giá của khung chứa nó (không thuộc khung nào thì giá gốc).
4. Tiền = ceil(Σ phút × giá / 60 / 1000) × 1000 (làm tròn 1 lần ở cuối, như nay).

Không cài khung, block 1, tối thiểu 0 → bước 2 giữ nguyên số phút, bước 3 một giá → **trùng công thức hiện tại**.

**Tên dòng trên hoá đơn** (một dòng như nay):
- Một giá: giữ y như bây giờ.
- Nhiều giá: "Giờ chơi · Bàn 3 · 16:30 – 19:00 · 2 giờ 30 phút (30 phút × 50.000 + 2 giờ × 70.000 đ/giờ)".
- Có làm tròn block / tối thiểu: thêm "(tính 2 giờ)" khi số phút tính khác số phút chơi, để khách hiểu vì sao.

## 4. Các giai đoạn

### Giai đoạn A — Máy chủ (một migration + tệp hoàn tác + test, chạy thử trên bản sao trước khi xin áp)

1. Bảng `ban_gia_gio_cau_hinh` (một dòng mỗi bàn: `table_id` khoá chính, `store_id`, `block_phut`, `toi_thieu_phut`, `an_han_phut`, `updated_at`, `updated_by`) và `ban_gia_gio_khung` (`id`, `store_id`, `table_id`, `thu` smallint[] 1–7, `tu` time, `den` time, `gia` numeric, `thu_tu`). RLS: thành viên quán đọc; ghi chỉ qua hàm. Xoá bàn thì xoá theo.
2. Hàm thuần `qn_tinh_gio_tinh_tien_v2(p_table, p_gia_goc, p_vao, p_phut_choi, p_khung_dat_phut)` → `so_phut_tinh`, `thanh_tien`, `chi_tiet` (jsonb các đoạn giá). Một chỗ tính duy nhất.
3. `qn_tinh_gio_ghi_dong_v1` gọi hàm trên thay cho hai dòng công thức hiện tại; tên dòng theo mục 3. Chữ ký giữ nguyên (app cũ không đổi gì).
4. `ban_gia_gio_luu_v1(p_store, p_tables, p_cau_hinh, p_khung)`: một hoặc nhiều bàn (nút "Cả khu"), ghi trong một giao dịch; chỉ Chủ quán / Quản lý; kiểm giờ hợp lệ, giá ≥ 0, tối đa 12 khung, block thuộc danh sách.
5. Test SQL: mỗi ca ở mục 5 + **so sánh hồi quy**: không cài gì thì `v2` ra đúng từng đồng như công thức cũ với 2.000 khoảng ngẫu nhiên (trong một giao dịch, tự ROLLBACK).

### Giai đoạn B — App

1. Chép phép tính sang Dart (`tinh_gio.dart`) đúng từng bước mục 3; `tinhGioTamTinhBan` nhận cấu hình bảng giá.
2. Provider đọc bảng giá của quán (đọc một lần khi mở màn, như tên nhân viên).
3. Hộp **Đặt giá giờ**: dưới giá gốc thêm "Giá theo khung giờ" (thêm / sửa / xoá khung: chọn thứ, từ – đến, giá) và "Làm tròn" (block, tối thiểu, ân hạn), có câu ví dụ sống: "Chơi 47 phút → tính 1 giờ = 60.000 đ".
4. Thẻ bàn, khối ĐANG TÍNH GIỜ: đơn giá ghi theo khung **đang chạy** ("70.000 đ/giờ · khung tối"), báo trước khi sắp sang khung khác ("17:00 lên 70.000 đ/giờ").
5. Test Dart chạy **cùng bộ ca** với test SQL (mục 5) để hai bên luôn khớp.

### Giai đoạn C — Tài liệu
Bài `tinh-gio.md` (cách đặt khung, làm tròn, đọc dòng hoá đơn), `.docs/kien-truc-data.md`, `.docs/tinh-nang.md`. Chưa đăng Boom cho tới khi phát hành.

### Giai đoạn D — Thử và phát hành
Máy ảo + quán Demo: cài khung, chơi vắt qua ranh giới, chuyển bàn giữa hai khung, đặt trước, thanh toán (hỏi Chủ Quán trước khi bấm Thanh toán ở Demo). Chụp dữ liệu Demo trước / sau. Đi chung bản phát hành app.

## 5. Bộ ca kiểm (dùng chung SQL và Dart)

| # | Cài đặt | Chơi | Kỳ vọng |
|---|---|---|---|
| 1 | không gì | 14:05–15:35 (90') | như cũ: 90' × 60.000 = 90.000 |
| 2 | không gì | 44'10" | 45' = 45.000 (như cũ) |
| 3 | khung T2–CN 17:00–24:00 = 80.000 | 16:30–17:30 | 30' × 60.000 + 30' × 80.000 = 70.000 |
| 4 | khung 22:00–02:00 = 90.000 | 23:00–01:00 qua đêm | 120' × 90.000 = 180.000 |
| 5 | khung chỉ T7, CN | T6 23:30 – T7 00:30 | 30' giá gốc + 30' giá cuối tuần |
| 6 | block 30 | 47' | 60' |
| 7 | block 30, ân hạn 5 | 33' | 30' |
| 8 | block 30, ân hạn 5 | 36' | 60' |
| 9 | tối thiểu 60 | 20' | 60' |
| 10 | đặt trước 2 giờ + block 30 | về sau 50' | 120' (khung đặt thắng) |
| 11 | khung + block | 16:50 chơi 25', block 30 | 30' tính từ 16:50: 10' giá gốc + 20' giá khung |
| 12 | chuyển bàn lúc 17:10, hai bàn khác khung | bàn cũ 16:40–17:10 | đoạn bàn cũ tính theo khung của bàn cũ, đoạn mới theo bàn mới |
| 13 | giá gốc 0, khung 0 | bất kỳ | 0 đ, không lỗi |
| 14 | hai khung chồng nhau | 18:00 | khung đứng trên thắng |

## 6. Rủi ro và cách giữ an toàn

- **Đổi cách tính tiền thật:** mặc định không cài gì = công thức cũ, có test hồi quy 2.000 khoảng; áp máy chủ phải xin Chủ Quán, có backup và tệp hoàn tác.
- **App cũ (đến build 38) không biết khung giá:** số tạm tính trên thẻ có thể lệch khi quán đã cài khung, nhưng tiền thật vẫn do máy chủ chốt đúng và màn thu tiền đã hiện số máy chủ. Quán đang dùng cần cập nhật app trước khi cài khung; hộp đặt giá chỉ có ở bản mới.
- **Giờ máy sai múi giờ:** khung giá tính theo giờ Việt Nam ở máy chủ; app tính tạm theo giờ máy (đã như vậy ở mọi chỗ).
- **Phức tạp cho người dùng:** mặc định ẩn trong "Cài thêm"; câu ví dụ sống ngay dưới để Chủ quán thấy kết quả trước khi lưu.

## 7. Chủ Quán đã chốt (28/11)

1. Bảng giá gắn **theo từng bàn** (không theo mức giá). Hộp đặt giá có "Cả khu" để chép cho cả khu.
2. Chơi vắt qua hai khung: **tách theo từng phút**.
3. Hoá đơn: **một dòng có ghi chi tiết**.
4. **Làm đợt này trước**, phát hành một thể (không phát hành build 39 trước).

Chưa hỏi, làm theo đề xuất: có ô ân hạn (mặc định 0); ngày lễ để đợt sau.

## 8. Nhật ký thực hiện

### 28/11 — Giai đoạn A (máy chủ): viết xong, thử trên bản sao đạt, CHƯA ÁP

- `supabase/migrations/20261128_gia_gio_khung_block.sql`: hai bảng (`ban_gia_gio_cau_hinh`, `ban_gia_gio_khung`, RLS chỉ đọc đúng quán), `qn_tinh_gio_tinh_tien_v2`, `qn_tinh_gio_thoi_luong_v1`, `qn_tinh_gio_tien_chu_v1`, `qn_tinh_gio_ghi_dong_v1` (lấy nguyên bản production 28/11, chỉ thay phần tính tiền + tên dòng; trả thêm `so_phut_choi`, `doan`), `ban_gia_gio_luu_v1`. `_ROLLBACK`: ghi_dong nguyên bản production 28/11, bỏ hàm và bảng mới.
- Tên dòng: một giá như cũ; nhiều giá "… · 47 phút (27 phút × 60.000 + 20 phút × 90.000 đ/giờ)"; làm tròn "… · chơi 47 phút, tính 1 giờ × 60.000 đ/giờ".
- Phút thuộc khung theo giờ VN của thời điểm BẮT ĐẦU phút đó (có giây: vào 16:59:30 thì phút đầu giá gốc). Ân hạn chỉ áp khi đã đủ ít nhất một block (chơi 4 phút, block 30, ân hạn 5 → 30, không thành 0).
- Test `supabase/tests/gia_gio_khung_block_test.sql` 31 điểm: 14 ca mục 5 (+ biến thể), hồi quy 2.000 lượt ngẫu nhiên khớp công thức cũ từng đồng, lưu (phục vụ bị từ chối, cả khu, ân hạn ≥ block, block lạ, thứ 8, bàn quán khác, mặc định = xoá, bàn đang chạy), tên dòng (làm tròn, hai giá, vẫn một dòng).
- Bản sao (`chuoi_stage_dryrun.sh`, TAG=gia_khung): test mới 31/31; `ban_tinh_gio_v1_test`, `ban_dat_truoc_v1_test`, `tinh_gio_ten_dong_test` TẤT CẢ PASS; chạy tệp hoàn tác rồi bộ tính giờ cũ vẫn PASS, bảng mới mất. Bản sao đã xoá. Hai lần test hỏng là lỗi của chính test (biến `GIA` trùng tên cột; phiên "47 phút" cộng giây thành 48), đã sửa.
- Kịch bản áp `db-fix/gia_gio_khung_block_ap_dung.sh` (backup → áp → test). Chưa chạy, chờ Chủ Quán.

### 28/11 — Giai đoạn B (app): viết xong, thử máy ảo, CHƯA commit (máy chủ chưa áp)

Chủ Quán: "Làm tiếp đi chưa áp".
- `lib/modules/tinh_gio/gia_gio.dart`: `KhungGia`, `GiaGioCaiDat`, `tinhGioLamTron`, `tinhGioGiaLuc`, `tinhGioKhungLuc`, `tinhGioDoiGiaKe`, `tinhGioTien` — chép đúng `qn_tinh_gio_tinh_tien_v2`; tiền tính bằng số nguyên phần trăm đồng (không lệch số thực). `tinhGioThanhTien` cũng chuyển sang số nguyên. `tinhGioTamTinhBan` nhận `caiDat`, thêm `soPhutTinh`.
- `giaGioCaiDatProvider` (tinh_gio_widgets.dart) đọc hai bảng đúng quán, thứ tự `thu_tu, id` như máy chủ; máy chủ chưa có bảng / lỗi mạng → rỗng (tính như cũ). Nối vào thẻ bàn (tab Bàn và màn tính giờ), ô tóm tắt, khối ĐANG TÍNH GIỜ, TỔNG TẠM TÍNH.
- Hộp Đặt giá giờ: phần "Giá theo giờ & làm tròn" (`gia_gio_ui.dart`: danh sách khung, thêm / sửa / xoá / đưa lên; chip block, ân hạn, tối thiểu), hộp `KhungGiaSheet` (ngày, nút nhanh, Từ – Đến bằng đồng hồ 24 giờ, Cả ngày, giá). Ví dụ sống 25 phút / 47 phút / 1 giờ 40 theo cài đặt đang sửa. Lưu: khung + làm tròn TRƯỚC (`BanRepository.luuGiaGioCaiDat` → `ban_gia_gio_luu_v1`), lỗi thì không đổi giá một giờ; không đổi gì thì không gọi (máy chủ cũ vẫn đặt giá được). Dòng báo lỗi chuyển lên ngay trên nút Lưu.
- Khối ĐANG TÍNH GIỜ: "80.000 đ/giờ (khung 17:00 – 23:00) • làm tròn 30 phút…", dòng "Từ 17:00: 80.000 đ/giờ" khi sắp đổi giá trong 2 giờ. Thẻ bàn trống ghi giá đang áp "(theo khung)".
- Test: `test/modules/tinh_gio/gia_gio_khung_test.dart` (bộ ca như SQL + hồi quy 2.000 lượt + tạm tính bàn); ảnh mẫu mới `gia_gio_co_khung.png`, hai ảnh hộp cũ dựng lại (giờ ví dụ cố định 16:30). test/modules/tinh_gio 54/54.
- Máy ảo + Demo: mở hộp, thêm khung T2–T6 17:00–23:00 80.000, chọn mỗi 30 phút, ân hạn 5: tóm tắt và ví dụ đúng; bấm Lưu → "Máy chủ chưa có khung giá giờ…" hiện trên nút Lưu, giá A 1 không đổi. Dữ liệu Demo trước / sau giống hệt. Chưa thử: lưu thật (chờ áp máy chủ), khối đang chạy giờ với khung, máy tính bảng.
- Hướng dẫn `tinh-gio.md`: hai mục mới "Giá theo khung giờ", "Làm tròn theo block, chơi tối thiểu", một dòng lỗi; sửa câu ví dụ dưới ô giá.

### 28/11 18:14 — ĐÃ ÁP production

Chủ Quán: "Áp cả 5 đợt ngay". `DRYRUN=1 bash db-fix/gia_gio_khung_block_ap_dung.sh` trên máy chủ thật PASS (tự huỷ), rồi `bash db-fix/gia_gio_khung_block_ap_dung.sh`: sao lưu, áp, test PASS. Mốc hoàn tác `quannho_before_*_20261128_181424.dump` (trong /root/quannho-backups); hoàn tác: `ROLLBACK=1 bash db-fix/gia_gio_khung_block_ap_dung.sh`.
