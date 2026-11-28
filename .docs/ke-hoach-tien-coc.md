# Kế hoạch đợt 4: Tiền cọc vào Thu Chi, tự trừ khi thanh toán

Đợt 4 của `lo-trinh-tinh-gio.md`, lập 28/11/2026 khi Chủ Quán bảo "Làm tiếp đi rồi commit" (đợt 3 đã commit 0cc4764). **Đụng tiền thật**: sửa hàm thanh toán bàn. Viết, thử trên bản sao, xin Chủ Quán trước khi áp.

## Hiện trạng (đọc máy chủ 28/11, chỉ đọc)
- `ban_dat_truoc.tien_coc`: chỉ ghi nhớ, không vào Thu Chi, không trừ hoá đơn. Production: 0 lượt có cọc.
- `settle_ban_session_v5` (thanh toán bàn): tạo đơn hàng (`orders.total` = tổng sau giảm / phụ thu), `payment_settlements`, và ĐÚNG 1 dòng `finance_records` income = tổng, `fund_type` theo cách trả (tiền mặt / chuyển khoản), `is_auto = true`.
- Thu Chi + giao ca đếm tiền theo `finance_records` (tiền mặt / ngân hàng).

## Vấn đề phải tránh
Nếu cọc vào Thu Chi lúc nhận VÀ thanh toán vẫn ghi thu đủ tổng → Thu Chi tính tiền cọc hai lần. Nếu cọc không vào Thu Chi → tiền mặt trong két lệch sổ lúc giao ca.

## Chủ Quán chốt (28/11)
"Ghi ngay, trừ khi thanh toán, nhưng phải thiết kế cùng với module Khách hàng."

## Hiện trạng module Khách hàng (đọc 28/11)
- `customers.real_balance` (ví tiền thật) và `bonus_balance` (tiền thưởng), `total_topup`; lịch sử ở `balance_transactions` (`topup_real`, `topup_bonus`, `spend_real`, `spend_bonus`).
- `topup_customer_wallet_v1`: nạp ví → cộng `real_balance` (+ thưởng theo gói nạp) → ghi Thu Chi income "Nạp ví: tên khách" đúng quỹ (tiền mặt / ngân hàng) → tiền vào két được ghi NGAY.
- Bán ở quầy (`complete_pos_sale_v1`) trả được bằng ví: trừ ví, phiếu Thu Chi quỹ `wallet` (không cộng tiền mặt két, không đếm hai lần với lúc nạp).
- Thanh toán bàn (`settle_ban_session_v5`) CHƯA trả được bằng ví; có gắn khách để tích điểm (`p_customer_id`).
- Production: 1 khách có số dư ví, 2 lần nạp — module ví gần như chưa ai dùng.

## Cách làm (cọc = tiền trong ví khách)
1. **Lượt đặt gắn khách hàng**: hộp đặt tìm khách theo số điện thoại / tên (khách có sẵn) hoặc tạo khách mới nhanh (tên + SĐT). `ban_dat_truoc.customer_id`.
2. **Nhận cọc = nạp ví khách** (ghi ngay): nạp `real_balance` bằng số cọc, KHÔNG tặng thưởng gói nạp, lịch sử ví ghi "Cọc đặt Sân 1 · 03/12 18:00", Thu Chi ghi phiếu thu "Cọc đặt sân: tên khách" đúng quỹ. Lượt đặt ghi số cọc + phiếu (`coc`, `coc_trang_thai` = `da_thu`).
3. **Thanh toán bàn của lượt đặt đã nhận**: tự gắn khách vào hoá đơn (tích điểm như thường), tự trả phần cọc bằng ví (tối đa số cọc, không quá tổng), phần còn lại tiền mặt / chuyển khoản như thường. Đơn hàng ghi đủ tổng (báo cáo doanh thu đúng). Thu Chi: phần ví ghi quỹ `wallet` (như bán ở quầy), phần còn lại đúng quỹ → không đếm cọc hai lần, két khớp. Cọc chuyển `da_tru`. Màn thu tiền + mã QR: "Đã cọc 200.000 (ví khách) · Khách trả thêm 280.000".
   - Kèm theo: thanh toán bàn trả bằng ví khách nói chung (khách có số dư ví) — module Khách hàng có thêm chỗ dùng ví ở bàn.
4. **Huỷ / khách không đến**: hỏi một trong ba — "Để cọc trong ví khách" (dùng lần sau, không đổi Thu Chi), "Quán giữ cọc" (trừ ví, ghi lịch sử ví "Mất cọc", Thu Chi không đổi vì đã thu), "Hoàn cọc" (trừ ví + phiếu chi "Hoàn cọc" đúng quỹ; chỉ Chủ quán / Quản lý).
5. **Lịch cố định**: một lần cọc cho cả lịch; nằm trong ví, trừ theo quyết định ở dưới.
6. Hồ sơ khách (module Khách hàng) hiện các lượt đặt sân và cọc của khách.

## Chạm tới
- Máy chủ: `ban_dat_truoc.customer_id`, cột cọc; hàm nhận cọc (gọi lại phần lõi của nạp ví, không bonus) / xử lý cọc khi huỷ; `ban_dat_truoc_luu_v1`, `ban_dat_truoc_lap_v1` nhận `customer_id`; thanh toán bàn trả bằng ví (v6, giữ v5 cho máy cũ hoặc chặn). Test hồi quy: phiên không khách, không cọc → y hệt cũ (đơn, settlement, Thu Chi, kho, điểm); bán ở quầy bằng ví không đổi.
- App: hộp đặt (tìm / tạo khách, cọc + hình thức), hộp lượt đặt (xem cọc, xử lý cọc khi huỷ), màn thu tiền bàn (dòng cọc / ví, số khách trả, QR), hồ sơ khách (lượt đặt, cọc).
- Tài liệu: tinh-gio.md, khach-hang.md, thu-chi.md, kien-truc-data.md.

## Rủi ro
- Hàm thanh toán là hàm tiền quan trọng nhất (841 dòng). Sửa tối thiểu, test hồi quy cả bộ thanh toán hiện có trên bản sao, có tệp hoàn tác nguyên văn.
- Máy cũ (app chưa cập nhật) thanh toán bàn có cọc: máy chủ vẫn trừ đúng ở Thu Chi; màn thu tiền máy cũ hiện tổng chưa trừ cọc → nhân viên thu thừa. Cần phát hành app cùng lúc áp, hoặc máy chủ chặn máy cũ thanh toán bàn có cọc.

## Chủ Quán đã chốt (28/11)
1. Cọc ghi Thu Chi NGAY lúc nhận, trừ khi thanh toán, làm chung với module Khách hàng (cọc = tiền trong ví khách).
2. Huỷ / không đến: hỏi mỗi lần, ba cách (để trong ví / quán giữ cọc / hoàn cọc — hoàn chỉ Quản lý); không đến thì chọn sẵn "Quán giữ cọc".
3. Lịch cố định: một lần cọc, trừ vào buổi đầu tiên khách đến.
4. Máy chưa cập nhật app thanh toán bàn có cọc: máy chủ chặn, báo cập nhật app.

## Các giai đoạn
- A. Máy chủ: cột + hàm cọc + thanh toán bàn trả bằng ví (v6) + chặn máy cũ; test hồi quy toàn bộ thanh toán bàn và bán ở quầy; thử bản sao; xin áp.
- B. App: hộp đặt (khách + cọc), hộp lượt đặt (cọc, huỷ), màn thu tiền bàn (ví / cọc), hồ sơ khách.
- C. Tài liệu. D. Thử máy ảo + Demo (hỏi trước khi bấm Thanh toán thật).

## Nhật ký

### 28/11 — Giai đoạn A (máy chủ): viết xong, bản sao đạt, CHƯA ÁP, CHƯA commit
- `supabase/migrations/20261128_tien_coc_vi_khach.sql` (+ `_ROLLBACK`: v5 nguyên văn production 28/11). Cần đợt 3 áp trước (preflight kiểm `chuoi_id`).
- Cột `ban_dat_truoc.customer_id`, `coc_trang_thai`, `coc_quy`, `coc_finance_id`, `coc_settlement_id`, `coc_khoa`; `payment_settlements.vi_da_tru`.
- Hàm: `ban_dat_truoc_gan_khach_v1` (cả lịch cố định; đã có cọc thì không đổi khách), `ban_dat_truoc_nhan_coc_v1` (ví thật + lịch sử "Cọc đặt Sân 1 · dd/mm hh:mm", phiếu thu "Cọc đặt sân: …" đúng quỹ, chống trùng theo mã, một cọc mỗi lượt / lịch), `ban_dat_truoc_xu_ly_coc_v1` (trong_vi / quan_giu / hoan — hoan cần Quản lý, phiếu chi; chỉ khi không còn buổi chờ khách), `qn_coc_cua_phien_v1`, `settle_ban_session_v6`.
- **Thiết kế v6 ít rủi ro:** không chép 841 dòng của v5; v6 gọi NGUYÊN v5 (đơn hàng, kho, điểm, phiếu thu như cũ) với khách của lượt đặt, rồi trừ ví (`spend_real`, gắn đơn), giảm phiếu thu lúc thanh toán đúng phần ví (về 0 thì xoá), thêm phiếu quỹ `wallet` (Thu Chi không tính quỹ ví — `kCashBookAllFundsFilter`), ghi `vi_da_tru`, cọc `da_tru`. Gửi lại cùng mã: v5 trả kết quả cũ, v6 đọc `vi_da_tru`, không trừ ví lần hai. v5 thêm một đoạn đầu hàm: phiên có cọc mà không đi qua v6 (`qn.settle_v6`) → `COC_CAN_CAP_NHAT_APP`.
- Test `supabase/tests/tien_coc_vi_khach_test.sql` 20 điểm: hồi quy v6 = v5 khi không cọc; nhận cọc (cần khách, ví +, không thưởng, Thu Chi ngay, gửi lại, một lần, không đổi khách); v5 máy cũ bị chặn; khách khác bị chặn; v6 trừ cọc (đơn đủ, phiếu thu 280k, ví 200k quỹ wallet, Thu Chi tiền mặt tổng 480k không đếm hai lần); gửi lại; huỷ (còn chờ khách thì chưa, phục vụ không hoàn, quán giữ, hoàn có phiếu chi); lịch cố định trừ ở buổi đầu; trả thêm bằng ví.
- Bản sao (đợt 3 + 4): 20/20; tính giờ 50, đặt trước 40, lịch cố định 18, giao ca 15, chặn đóng phiên 15, nạp ví an toàn, kho topping PASS. `settlement_v5_production_schema_test` ("duplicate or missing side effect") và `settle_v5_concurrency_test` (thiếu `store_code`) lỗi GIỐNG HỆT khi đã gỡ đợt 4 → lỗi cũ của bộ test, chưa sửa. Hoàn tác chạy được. Bản sao đã xoá.
- Script `db-fix/tien_coc_vi_khach_ap_dung.sh` (chưa chạy).
- Còn: giai đoạn B (app: hộp đặt chọn / tạo khách + nhận cọc, hộp lượt đặt cọc / huỷ 3 cách, màn thu tiền bàn gọi v6 + dòng cọc / ví + QR theo số còn lại, hồ sơ khách), C (tài liệu), D (thử).

### 28/11 — Giai đoạn B–D (app): Chủ Quán duyệt thiết kế ("Duyệt, làm vào app"), viết xong, CHƯA commit, máy chủ CHƯA ÁP
- Thiết kế trên bảng Design (5 bảng: dòng tiền, hộp đặt, thu tiền, huỷ, hồ sơ khách).
- `dat_truoc.dart`: `DatTruoc.customerId / cocTrangThai / cocQuy / coCocCho`; `ganKhach`, `nhanCoc` (mã chống trùng mỗi hộp), `xuLyCoc`, `docCocCuaPhien` (chép `qn_coc_cua_phien_v1`), `docCuaKhach`; `tienTraBangVi` (chép v6).
- Hộp đặt: ô "Chọn khách hàng" (`_ChonKhachSheet`: tìm tên / SĐT, "Khách mới"), ô "Tiền cọc" + Tiền mặt / Chuyển khoản; lưu = `luu_v1` (tiền cọc 0) → `gan_khach` → `nhan_coc`; cọc mà chưa chọn khách thì tìm theo SĐT, chưa có thì tạo. Lỗi sau khi lưu: hộp giữ, bấm lại chỉ làm phần cọc. Lịch cố định: cọc gắn buổi đầu còn chờ. Lượt đã có cọc: ô cọc chỉ xem, không đổi khách.
- Huỷ / không đến lượt lẻ có cọc → `XuLyCocSheet` (không đến chọn sẵn "Quán giữ cọc", huỷ chọn sẵn "Để trong ví", Hoàn khoá với không phải Chủ / Quản lý); huỷ chuỗi hết buổi chờ thì hỏi; lượt huỷ còn cọc có nút "Xử lý tiền cọc".
- Thu tiền bàn: đọc cọc trước khi mở (lỗi thì dừng, tránh thu đủ tổng); có cọc thì khoá khách = khách đặt; khối "Tổng hoá đơn / Đã cọc (ví …) / KHÁCH TRẢ THÊM"; QR + tiền khách đưa theo số còn lại; công tắc "Trả bằng ví khách"; màn thành công ghi "Đã trừ ví khách …". `settleBanSession` gọi v6, thiếu v6 (PGRST202) thì gọi v5 (trừ khi chọn trả ví).
- Hồ sơ khách (loyalty_screen): ô "Ví", mục "Đặt sân · N lượt" (`LuotDatCuaKhach`), "Lịch sử ví".
- Tài liệu: tinh-gio.md (3 mục mới + 6 dòng lỗi), khach-hang.md, thu-chi.md, kien-truc-data.md.
- Test: `tien_coc_test.dart` 5; ảnh mẫu `xu_ly_coc_360.png`, `dat_coc_360.png`, `dat_lap_360.png` dựng lại (hộp có thêm ô khách). test/modules/tinh_gio 74/74; settlement client, qr_order v4, chặn đóng phiên PASS.
- Máy ảo + Demo: hộp đặt có ô khách, tìm khách, gõ cọc hiện Tiền mặt / Chuyển khoản + "Đặt · nhận cọc 200.000 đ"; KHÔNG bấm Đặt. Dữ liệu Demo (thêm đếm lượt đặt, khách, Thu Chi) trước / sau giống hệt.
- Chưa: bill in chưa ghi dòng trừ cọc; chưa thử thanh toán thật có cọc (cần áp máy chủ đợt 3 + 4, rồi hỏi Chủ Quán trước khi bấm Thanh toán trên Demo).

### 28/11 18:19 — ĐÃ ÁP production

Chủ Quán: "Áp cả 5 đợt ngay". `DRYRUN=1 bash db-fix/tien_coc_vi_khach_ap_dung.sh` trên máy chủ thật PASS (tự huỷ), rồi `bash db-fix/tien_coc_vi_khach_ap_dung.sh`: sao lưu, áp, test PASS. Mốc hoàn tác `quannho_before_*_20261128_181909.dump` (trong /root/quannho-backups); hoàn tác: `ROLLBACK=1 bash db-fix/tien_coc_vi_khach_ap_dung.sh`.
