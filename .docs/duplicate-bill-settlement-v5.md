# Atomic Settlement V5 — chống trùng bill

Trạng thái ngày 02/09/2026: mã nguồn và migration đã được chuẩn bị, **chưa áp dụng production**. Release Windows mới chỉ được phép phát hành sau khi PostgreSQL runtime gate chạy thành công trên database test cô lập.

## Kết quả rà soát và chạy thật ngày 02/09

- Gate đã chạy trên PostgreSQL 17.11 local, hai database fixture riêng (có/không coupons), sử dụng hàm membership V4 từ migration thật thay vì mock cho phép mọi nhân viên. 7 bài concurrency/auth mỗi nhánh, cùng SQL integration: món hủy, ví/replay, topup lặp, manual discount/audit, POS/Bàn, rollback lỗi finance, giá đổi, reconcile, số bill >=1000. Cleanup database/roles test thành công.
- Sửa lỗi `record IS NOT NULL` với record có cột NULL: kiểm tra primary key để replay/reconcile không bỏ qua giao dịch đã commit.
- Unique finance chỉ dùng `checkout_reference_id` suy ra bởi trigger, không unique toàn bộ customer reference của nạp ví.
- POS giữ nguyên request durable đến acknowledge; nút Đối soát cho phép khôi phục kể cả giỏ trống. Key legacy thiếu payload chỉ tra `reconcile_pos_sale_v1`; thiếu kết quả vẫn fail-closed và cần đối soát, không tự xóa key.
- POS session closure được đưa vào RPC, kiểm tra phiên còn mở và món đã gửi bếp thuộc giỏ; session có món hủy/nguồn QR khác bị chặn để đối soát thay vì thu tiền từ giỏ stale. Không tự bỏ các session ID để vượt guard.
- In bếp sau POS chỉ gửi các line chưa gửi; replay không auto-print. In lại hóa đơn là thao tác riêng có app log.
- Trước rollout còn cần schema/RLS staging giống production, thử Windows/máy in thật, kiểm thử refund/hủy bill đã thanh toán với trigger mới. Không dùng kết quả fixture để suy ra đã deploy hay sửa dữ liệu bill lịch sử.

## Nguồn dữ liệu chuẩn

- Thanh toán bàn: `payment_settlements` là một lần thu tiền; `finance_records.reference_id = payment_settlements.id`.
- POS bán nhanh: `pos_idempotency_operations` giữ operation; `finance_records.reference_id = orders.id`.
- `orders` và `order_items` dùng cho món/order; không được cộng số lần thu tiền của một settlement bằng cách đếm mù mọi order.
- `payment_settlements.cashier_staff_id` là thu ngân commit giao dịch. `orders.waiter_id` là nhân viên phục vụ.

## Luồng bàn

Mọi bàn, gồm bàn thường và QR, gọi `settle_ban_session_v5`. Client không còn được tự ghi order, finance, stock, loyalty hoặc đóng session trong đường checkout thực thi.

Operation key được lưu trong `SharedPreferences`, scope theo store/session/fingerprint. Timeout hoặc lỗi mạng không xóa key. Repository đối soát bằng `reconcile_ban_settlement_v1`; retry cùng intent nhận replay không tạo side effect.

Auto-print dùng task key `<settlement_id>:cashier`. Response `is_replay=true` không tự in.

## Luồng POS bán nhanh

`PosRepository.completeSale` gọi `complete_pos_sale_v1`. RPC tạo order number, order/items, finance, stock/recipe, loyalty và coupon trong một transaction. Key và cart fingerprint được lưu bền vững; replay trả order cũ và không tự in bill.

## Thu ngân và báo cáo

- Thu–Chi giữ `reference_id` và mở chi tiết bằng ID canonical.
- Với settlement bàn, popup gom các canonical order qua `ban_session_orders`.
- Dashboard lấy doanh thu, cash/bank và thu ngân từ auto-income + settlement/order metadata; orders chỉ dùng cho số order, customer và nhân viên phục vụ.

## Gate phát hành

1. Chạy `bash test/backend/run_phase1_docker_gate.sh` trên máy có Docker Desktop.
2. Phải thấy `PHASE 1 RUNTIME GATE: ALL TESTS PASSED`, exit code 0 và cleanup sạch container/volume.
3. Backup và preflight duplicate scan production.
4. Apply migration additive trước, sau đó mới phát hành Windows client.
5. Không chạy reconciliation dữ liệu 060/061 trước khi xác nhận khách thực trả cash hay transfer.
