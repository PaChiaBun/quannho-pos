---
module: finance
ten: Thu Chi
phien_ban: 1.0.5+20
cap_nhat: 2026-10-23
nguon:
  - lib/screens/finance_screen.dart
  - lib/modules/finance/screens/add_transaction_sheet.dart
  - lib/modules/finance/repository/finance_repository.dart, providers/finance_providers.dart
  - lib/core/services/store_auth_service.dart (danh mục mặc định)
  - lib/core/widgets/order_detail_dialog.dart
  - Nơi tự ghi thu/chi: supabase/migrations/20261008_fix09_quy_doi_don_vi_cong_thuc.sql (bán quầy, thanh toán bàn), lib/modules/kho/repository/kho_repository.dart, lib/modules/kho_chuyen_nghiep/repository/kho_chuyen_nghiep_repository.dart, lib/modules/loyalty/repository/loyalty_repository.dart, lib/modules/tinhluong/repository/tinhluong_repository.dart
---

# Thu Chi

> Sổ tiền của quán: mọi khoản thu (bán hàng, nạp ví, thu khác) và chi (nhập hàng, lương, điện nước…), tách **Tiền mặt** và **Tiền gửi**, tính lợi nhuận và xuất sổ quỹ cho kế toán.

## Ai dùng được
- Người có module **Thu Chi** trong vai trò. Module bật sẵn cho quán mới, nhưng **mặc định chỉ Chủ quán và Quản lý** có Thu Chi; các vai trò có sẵn của quán mới (Thu ngân, Nhân viên, Bếp) **không có**. Chủ quán thêm module cho vai trò bất kỳ ở **Nhân viên → Vai trò** (mẫu gợi ý "Thu ngân" khi tạo vai trò mới có sẵn Thu Chi).
- Ai vào được module đều xem được toàn bộ thu chi và ghi thu/chi (công tắc "Xem toàn bộ thu chi" trong Hành động nhạy cảm hiện **chưa có tác dụng**). **Xoá** khoản ghi tay: chỉ Chủ quán/Quản lý.

## Màn hình gồm những gì
- **Đầu trang**: "Thu Chi", **"LỢI NHUẬN"** (thu − chi), **"Biên lợi nhuận"** (%), ô **"Tổng thu"** và **"Tổng chi"** kèm % tăng/giảm so với kỳ trước.
- Hai nút **"+ Ghi thu"** và **"− Ghi chi"**.
- Dòng **"Đang xem: <kỳ> (<ngày>)"** và nút **"Đổi ngày"**.
- **"Giao dịch"**: lọc **"Tất cả" / "↓ Thu" / "↑ Chi"**; lọc quỹ **"Tất cả" / "Tiền mặt" / "Tiền gửi"**; nút **xuất CSV** (gợi ý "Xuất tệp CSV cho kế toán").
- Danh sách giao dịch nhóm theo ngày ("Hôm nay", "Hôm qua", "T2, 20/10"…). Khoản **tự động** có nhãn **"Auto"**.

## Khoản thu/chi tự động (không cần ghi tay)
| Khi nào | Ghi | Mô tả trên sổ |
|---|---|---|
| Thanh toán ở **Bán hàng** | Thu | "Bán hàng #QN-…" |
| Thanh toán ở **Quản lý Bàn** | Thu | "Thanh toán bàn …" |
| Thu tiền đơn **QR mang đi** | Thu | "Bán hàng mang đi #QR-… (#Qxx)" |
| **Nạp ví** khách hàng | Thu | "Nạp ví: …" — vào quỹ **Tiền mặt** hoặc **Tiền gửi** theo cách thu thu ngân chọn lúc nạp (Tiền mặt / Chuyển khoản) |
| **Nhập hàng** ở Kho hàng | Chi | "Nhập hàng: …" / "Nhập hàng <số phiếu> — <NCC>" |
| **Nhập nhanh** nguyên liệu ở Kho Chuyên Nghiệp | Chi | "Nhập nhanh: …" |
| **Huỷ phiếu nhập** ở Kho hàng | Thu (hoàn) | "Huỷ nhập hàng <số phiếu> — <lý do>" |

- Bán bằng **tiền mặt** → quỹ Tiền mặt; **chuyển khoản / thẻ** → quỹ Tiền gửi; bán quầy trả bằng **ví** → quỹ riêng "ví" — **không** tính vào sổ Thu Chi (tiền đã ghi thu lúc nạp ví); xem đơn trả bằng ví ở Báo cáo → Hóa đơn.
- **Huỷ món** ở Quản lý Bàn **không** ghi khoản nào vào Thu Chi — chỉ trừ kho nguyên liệu (hao hụt) khi bếp đang làm hoặc đã xong.
- Khoản tự động **không xoá tay được**. Chạm vào để xem: khoản bán hàng mở **chi tiết đơn** (món, phương thức, người bán); khoản khác hiện "Tự động từ: … Không thể xóa thủ công."

## Các việc thường làm

### 1. Ghi một khoản chi (vd tiền điện) hoặc thu khác
1. Bấm **"− Ghi chi"** (hoặc **"+ Ghi thu"**). Có thể đổi loại ngay trong bảng.
2. Nhập **"Số tiền"**.
3. Chọn **"Quỹ giao dịch"**: **"Tiền mặt"** hoặc **"Tiền gửi (NH)"** — chọn đúng nơi tiền thực sự ra/vào.
4. Chọn **"Danh mục"**. Danh mục có sẵn khi tạo quán:
   - Thu: Doanh thu bán hàng, Thu khác.
   - Chi: Nhập hàng, Điện - Nước, Thuê mặt bằng, Lương nhân viên, Marketing, Chi khác.
5. **"Ghi chú (tuỳ chọn)"** — ghi rõ nội dung (vd "Tiền điện tháng 10").
6. Bấm **"Ghi chi • <số tiền>đ"** để lưu.

> Không ghi tay khoản nhập hàng hay bán hàng đã có ở module khác — sẽ bị **tính hai lần**. **Lương thì phải ghi tay** (danh mục "Lương nhân viên"): trả lương ở module Lương hiện **chưa** tự ghi chi.

### 2. Xem theo khoảng thời gian
1. Bấm **"Đổi ngày"** → **"Chọn thời gian báo cáo"**: Hôm nay, Hôm qua, 7 ngày qua, Tuần này, Tháng này, Tháng trước, hoặc **"📅 Chọn ngày tùy chỉnh..."**.
2. Lợi nhuận, tổng thu/chi và danh sách đổi theo kỳ đã chọn.

### 3. Xem riêng tiền mặt hoặc tiền gửi
- Chọn **"Tiền mặt"** để đối chiếu với tiền trong két; **"Tiền gửi"** để đối chiếu với tài khoản ngân hàng.

### 4. Xoá khoản ghi nhầm
1. **Vuốt** khoản đó từ phải sang trái, hoặc **giữ lâu** vào nó.
2. Hỏi **"Xoá giao dịch?"** → nhập **"Lý do xoá *"** (ít nhất 3 ký tự) → **"Xoá"** → "Đã xoá giao dịch".
3. Chỉ **Chủ quán hoặc Quản lý** xoá được, và chỉ khoản **ghi tay**. Khoản biến mất khỏi Thu Chi, nhưng máy chủ lưu lại nguyên khoản đó cùng người xoá, lý do, giờ xoá để đối chiếu sau này.

### 5. Xuất sổ chi tiết quỹ cho kế toán
1. Chọn kỳ, rồi chọn quỹ **"Tiền mặt"**, **"Tiền gửi"** hoặc **"Tất cả"** (= Tiền mặt + Tiền gửi).
2. Bấm nút xuất CSV → chia sẻ/lưu tệp `So_Chi_Tiet_Quy_….csv` (trên web: trình duyệt tải tệp về).
3. Tệp có: số tồn đầu kỳ, từng dòng với ngày chứng từ, số phiếu thu (PT-…) / phiếu chi (PC-…), **quỹ**, diễn giải, số tiền thu, chi và **số tiền còn lại** sau mỗi dòng; cuối tệp có **cộng phát sinh** và **tồn cuối kỳ**. Mở bằng Excel hiển thị đúng tiếng Việt.
4. Tệp luôn gồm **cả thu lẫn chi** của kỳ, dù đang lọc "↓ Thu" hay "↑ Chi".

> Sổ quỹ chỉ tính tiền thật của quán: **không gồm bán bằng ví khách** (tiền đã ghi thu lúc nạp ví).

## Lỗi thường gặp
| Thấy gì | Vì sao | Làm gì |
|---|---|---|
| "Bạn không có quyền Thu Chi nên không ghi được phiếu thu/chi…" | Vai trò không có module Thu Chi (máy chủ kiểm) | Nhờ Chủ quán/Quản lý ghi, hoặc Chủ quán giao module Thu Chi cho vai trò |
| Không xoá được một khoản | Khoản tự động ("Auto") | Khoản tự động không xoá được. Đơn đã thanh toán hiện **không huỷ / hoàn tiền được trong app**; nhập hàng sai thì **Huỷ phiếu nhập** ở Kho hàng (hệ thống ghi khoản thu hoàn). Trường hợp khác báo Chủ quán |
| Không vào được Thu Chi (Thu ngân, Phục vụ…) | Vai trò mặc định không có module Thu Chi | Nhờ Chủ quán bật module Thu Chi cho vai trò |
| "Chỉ Chủ quán hoặc Quản lý được xoá giao dịch thu chi" | Nhân viên không phải Chủ quán/Quản lý | Nhờ Chủ quán/Quản lý xoá |
| "Nhập lý do xoá (ít nhất 3 ký tự)" | Để trống lý do | Ghi rõ vì sao xoá |
| "Chưa rõ đã xoá hay chưa (lỗi mạng)…" | Mất mạng giữa chừng | Tải lại danh sách; nếu khoản còn thì xoá lại (không xoá nhầm) |
| Lợi nhuận thấp hơn thực tế | Nhập hàng bị ghi tay thêm một lần (đã có khoản tự động "Nhập hàng"), hoặc ở các tháng trước sổ còn khoản "Giá vốn NL" do app tự ghi khi huỷ món / sản xuất | Kiểm tra và xoá khoản nhập hàng ghi tay bị trùng. Khoản "Giá vốn NL" ghi trùng: báo Chủ quán kiểm tra — khoản gỡ khỏi sổ vẫn được lưu lại, khôi phục được |
| "Không có dữ liệu để xuất file!" | Kỳ đang chọn không có giao dịch | Đổi kỳ |
| "Xuất file thất bại. Hãy chụp lại báo chủ app." | Lỗi tạo/chia sẻ tệp | Thử lại; chụp màn hình gửi chủ app |
| "Lưu giao dịch thất bại. Hãy chụp lại báo chủ app." | Mất mạng hoặc lỗi máy chủ | Kiểm tra mạng rồi ghi lại |
| Không thấy khoản bán bằng ví trong Thu Chi | Đúng thiết kế: bán bằng ví không phải tiền vào quán | Xem ở Báo cáo → Hóa đơn |

## Liên quan module khác
- **Bán hàng, Quản lý Bàn, QR Gọi Món**: tự ghi thu khi thanh toán.
- **Khách hàng**: nạp ví ghi thu vào quỹ Tiền mặt / Tiền gửi theo cách thu đã chọn; bán bằng ví ghi vào quỹ ví.
- **Kho hàng / Kho Chuyên Nghiệp**: nhập hàng, nhập nhanh ghi chi; huỷ phiếu nhập ghi thu hoàn; huỷ món có công thức ở Bàn chỉ trừ kho hao hụt, không ghi Thu Chi.
- **Lương**: trả lương **chưa** tự ghi chi (xem bài Lương); ghi tay.
- **Báo cáo**: tab "Tài chính" và thẻ Chi phí / Lợi nhuận lấy từ Thu Chi; tab "Hóa đơn" liệt kê bill từ các khoản thu tự động.

## Ghi chú cho Chủ Quán (không đưa cho khách)

### Khác biệt với bản app cũ (cho Chủ Quán)
- App cũ: huỷ món bếp đang làm / đã xong (món có công thức) tự ghi khoản chi "Giá vốn NL: <món> × N phần" (cả khi sản xuất). Các khoản "Giá vốn NL" ghi trùng trước đây đã được gỡ khỏi sổ ngày 23/10/2026 (vẫn lưu lại, khôi phục được). Máy còn chạy app cũ có thể vẫn ghi "Giá vốn NL" — cập nhật app. Trước bản 22/10/2026, huỷ món mới gửi (bếp chưa làm) cũng có thể bị ghi.
- Trước bản 22/10/2026: bấm Xoá khoản ghi tay trên app cũ không còn tác dụng — cập nhật app để xoá; nạp ví luôn ghi vào quỹ Tiền mặt; máy chủ chưa kiểm module Thu Chi khi ghi phiếu.
- App cũ ghi nhãn lọc "↑ Thu / ↓ Chi" (ngược mũi tên).
- App cũ (trước 23/10/2026): lọc "Tất cả" cộng cả bán bằng ví nên tổng thu cao bất thường; xuất sổ quỹ sai khi chọn "Tất cả" và có thể sai số tồn với quán nhiều giao dịch; chỉ cộng 1.000 phiếu mỗi lần xem nên tổng thu/chi cả tháng của quán > 1.000 phiếu/tháng thấp hơn thực tế (tạm thời xem theo tuần/ngày) — cập nhật app.

1. **[ĐÃ SỬA trong app 23/10 — chưa phát hành] Xuất CSV** (`lib/modules/finance/fund_ledger_csv.dart`, test `test/modules/finance/fund_ledger_csv_test.dart` 10 PASS). Lỗi cũ: (a) "Tất cả" ghi tiêu đề "TIỀN GỬI NGÂN HÀNG", tồn đầu kỳ = 0; (b) tồn đầu kỳ chỉ cộng tối đa 1.000 phiếu (giới hạn máy chủ) → quán nhiều giao dịch sai số dư; (c) xuất theo bộ lọc Thu/Chi đang chọn → cột "còn lại" sai; (d) web không xuất được (dùng tệp tạm của máy); (e) dấu phẩy trong diễn giải bị xoá thay vì bọc đúng chuẩn. Nay: tải đủ phiếu theo trang (`fetchAllRecords`), "Tất cả" = Tiền mặt + Tiền gửi có cột Quỹ, bỏ ví khách và phiếu không thuộc quỹ, có cộng phát sinh và tồn cuối kỳ, web tải tệp về. Thêm: ô bắt đầu bằng `=` `+` `-` `@` được thêm dấu `'` ở đầu để Excel không chạy thành công thức; chia sẻ trên iPad chạy được (đã đặt vị trí bảng chia sẻ). Cột Quỹ có ở mọi sổ, không riêng "Tất cả".
2. **[ĐÃ SỬA 23/10 — chưa phát hành] Tính hai lần doanh thu khi khách trả bằng ví** (#8): nạp ví ghi thu (tiền mặt/tiền gửi), bán bằng ví ghi thu lần nữa (quỹ "wallet", do `complete_pos_sale_v1`). Nay "Tất cả" (danh sách, tổng, so kỳ trước, và "Kết quả kinh doanh" ở Báo cáo) bỏ quỹ ví (`kCashBookAllFundsFilter`), giữ phiếu chưa có quỹ — đúng hướng "Thu Chi là sổ tiền", khớp sổ quỹ CSV. Dữ liệu thật 23/10: quán thật chưa có phiếu quỹ ví nào (34 đơn trả ví đều ở 2 quán Demo, không có phiếu Thu Chi). **Lưu ý:** vì vậy dòng "Tiền hàng" ở Báo cáo là **tiền vào** (gồm nạp ví, thu tay), không phải doanh số; thẻ "Doanh thu" (theo đơn, có đơn ví) − "Chi phí" có thể ≠ "Lợi nhuận" (theo sổ tiền) — lệch này có từ trước.
2b. **[ĐÃ SỬA 23/10 — chưa phát hành] Tổng Thu Chi thiếu với quán đông:** danh sách và tổng (kể cả so kỳ trước, "Kết quả kinh doanh") chỉ tải 1.000 phiếu (giới hạn máy chủ). KAY-Rạch Giá 09/2026 có 3.161 phiếu, thu thật **436.064.400đ** — app cũ chỉ cộng ~1/3 (1.000 phiếu mới nhất ≈ 142 triệu). Nay tải đủ theo trang (`fetchAllPages`).
3. **Thanh toán bàn không có lựa chọn ví** (chỉ Tiền mặt / Chuyển khoản / Thẻ, đã kiểm `ban_screen.dart` 22/10); `settle_ban_session_v5` cũng chỉ phân biệt bank/cash. Khách có ví muốn trả ở bàn thì chưa làm được — khác Bán hàng quầy.
4. **[ĐÃ SỬA trong app 23/10 — chưa phát hành] "Giá vốn NL"**: `deductIngredients` (`kho_chuyen_nghiep_repository.dart`) từng ghi khoản chi "Giá vốn NL" mỗi lần trừ nguyên liệu (huỷ món ở Bàn, lệnh sản xuất kiểu cũ, luồng bán POS cũ) — trừ lợi nhuận lần hai vì tiền nguyên liệu đã ghi chi lúc nhập hàng. Nay chỉ trừ kho + ghi `stock_movements`, không ghi Thu Chi. **Dữ liệu cũ: ĐÃ GẠCH BỎ trên production 23/10 08:52** (Chủ Quán duyệt) 64 phiếu, 5.486.170đ (Kay T5 quỹ tiền mặt 58 phiếu 4.951.907đ; Bò Đen 1, CHUCHA 3, Xôi Dính 2 không quỹ) — chép nguyên vào `finance_record_deletions` (lý do `DON_DU_LIEU_2026_10_23`), khôi phục được bằng `ROLLBACK=1 bash db-fix/don_thu_chi_cu_ap_dung.sh`. **Đính chính sau kiểm toán:** chỉ 58 phiếu của Kay là tính trùng thật; 6 phiếu của 3 quán nhỏ là chi phí nguyên liệu tồn đầu chưa từng ghi chi — **ĐÃ KHÔI PHỤC trên production 23/10 09:14** (Chủ Quán duyệt, `db-fix/don_thu_chi_cu_v1_khoi_phuc_3_quan.sql`). Hiện chỉ còn 58 phiếu của Kay gạch bỏ.
5. **[ĐÃ SỬA 22/10 — máy chủ ĐÃ áp lúc 21:59; app mới chưa phát hành]** Lỗi cũ: xoá khoản ghi tay là xoá hẳn, ai vào được module cũng xoá được, không lịch sử; app còn sửa/xoá thẳng được mọi dòng thu chi (kể cả dòng tự động) qua API. Sửa: RPC `delete_manual_finance_record_v1` (chỉ Chủ quán/Quản lý, bắt buộc lý do, lưu vết vào `finance_record_deletions`) + trigger `guard_finance_records_v1` chặn app UPDATE/DELETE thẳng. Chưa có màn xem "lịch sử xoá" — tạm đọc trên máy chủ.
6. Quyền `finance.view_all` có trong danh sách quyền nhưng **chưa được dùng** ở màn Thu Chi: nhân viên có module là thấy mọi khoản.
7. **[ĐÃ SỬA trong app 23/10 — chưa phát hành]** Mũi tên thống nhất "↓ Thu / ↑ Chi" (bảng ghi, bộ lọc, danh sách).
8. Có nút **"+ Ghi thu" / "− Ghi chi"**, nhưng **không có màn thêm/sửa danh mục** (nhóm phân loại như "Điện nước", "Lương nhân viên"…); quán chỉ chọn được 8 danh mục mặc định khi ghi.
9. Vai trò mặc định: quán mới được tạo sẵn Thu ngân `["pos","ban","report"]`, Nhân viên `["ban"]`, Bếp `["kitchen","ban"]` (`store_auth_service.dart` `seedDefaults`; các dòng này thắng `kDefaultPerms`) → không vai trò có sẵn nào có `finance`. Lưu ý mẫu "Thu ngân" ở `role_manager_screen.dart` lại có `finance` — hai nguồn mặc định lệch nhau. Mã đơn QR mang đi có tiền tố `QR-` (`generate_daily_order_number_v1(…, 'QR')`).
10. Lịch sử xoá nằm ở bảng `finance_record_deletions` (chỉ đọc được trên máy chủ).
11. Nạp ví (`topup_customer_wallet_v1`, `20261022_nap_vi_an_toan_v1.sql`) ghi `fund_type` = `cash` / `bank` theo lựa chọn của thu ngân. App ≤ 1.0.5+20 vẫn nạp kiểu cũ.
12. Không có chức năng huỷ/hoàn đơn đã thanh toán (`PosRepository.cancelOrder` không được gọi) — khoản "Bán hàng #…" ghi nhầm hiện không có đường sửa trong app.
13. **[ĐÃ SỬA trong app 23/10 — chưa phát hành]** Ghi thu/chi khi đang xem quỹ "Tất cả" từng lưu quỹ `'all'` (không thuộc quỹ nào, không vào sổ Tiền mặt/Tiền gửi) — nay mặc định Tiền mặt. **Dữ liệu cũ: ĐÃ XỬ LÝ trên production 23/10 08:55** (Chủ Quán duyệt) — gạch bỏ 2 phiếu thử quán "bán hàng" (lưu ở `finance_record_deletions`, mã `DON_DU_LIEU_2026_10_23B`), phiếu 100.000đ "Quán Bánh Kem" chuyển Tiền mặt. Khôi phục: `ROLLBACK=1 bash db-fix/don_thu_chi_cu_v2_ap_dung.sh`.
