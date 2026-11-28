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
