# Checklist áp migration hóa đơn điện tử v1

Migration: `supabase/migrations/20261016_einvoice_foundation_v1.sql`. Rollback: `..._ROLLBACK.sql`.
Quy tắc: áp lên **bản sao** trước. Chỉ áp production khi Chủ quán duyệt bằng lời trong chat. Không áp lúc quán đang đông khách.

## 1. Kiểm tra trước khi áp (chạy trên bản sao, chỉ đọc)

```sql
-- a) Hàm và bảng mà migration dựa vào phải tồn tại (kỳ vọng: 4 dòng true)
SELECT to_regprocedure('public.current_store_id()') IS NOT NULL AS has_current_store_id,
       to_regprocedure('public.qn_caller_id()')     IS NOT NULL AS has_qn_caller_id,
       to_regclass('public.stores')                 IS NOT NULL AS has_stores,
       to_regclass('public.store_members')          IS NOT NULL AS has_store_members;

-- b) store_members có đủ cột migration dùng (kỳ vọng: user_id, store_id, role, is_owner)
SELECT column_name FROM information_schema.columns
 WHERE table_schema='public' AND table_name='store_members'
   AND column_name IN ('user_id','store_id','role','is_owner') ORDER BY 1;

-- c) Chưa có bảng trùng tên (kỳ vọng: 0 dòng)
SELECT table_name FROM information_schema.tables
 WHERE table_schema='public' AND table_name LIKE 'einvoice\_%';
```
Nếu (a) hoặc (b) thiếu thì **dừng**, không áp. Báo lại để sửa migration.

## 2. Áp trên bản sao

1. Sao lưu hoặc dùng bản sao đã tách khỏi production.
2. Chạy file migration. Migration tự kiểm quyền cuối (anon không đọc được, authenticated không ghi trực tiếp) và hoàn tác nếu sai.
3. Kỳ vọng: không lỗi, có 3 bảng `einvoice_*` và 2 hàm.

## 3. Kiểm tra sau khi áp (bản sao)

Dùng một quán thử và hai tài khoản (Chủ quán, Quản lý) với JWT thật của app:
- Quản lý gọi `set_einvoice_enabled_v1(true)` → `OWNER_ONLY`.
- Chủ quán gọi → `success`, `changed: true`. Gọi lần hai → `changed: false`.
- `einvoice_audit_logs` của quán có đúng số dòng thay đổi.
- Quán A không đọc được dữ liệu `einvoice_*` của quán B.
- Từ app, `INSERT/UPDATE` trực tiếp vào `einvoice_documents` và `einvoice_store_config` bị từ chối.
- Chèn vài dòng `einvoice_documents` bằng service_role và so `einvoice_report_v1` với tổng tay.

## 4. Kiểm tra trên thiết bị (build có code mới)

- Cài đặt: chỉ Chủ quán thấy mục "Hóa đơn điện tử"; Quản lý và Thu ngân không thấy.
- Chưa đặt PIN duyệt nhanh → báo cần đặt PIN. Sai PIN → từ chối. Đúng PIN → bật/tắt được, thông báo đúng.
- Tắt rồi bật: bill thanh toán xong vẫn ghi đủ vào báo cáo Doanh thu ở cả hai trạng thái.
- Báo cáo → tab "Hóa đơn": đổi Hôm nay/Tuần/Tháng, kéo làm mới, hiển thị 0 khi chưa có hóa đơn. Trước khi áp migration, tab hiện thông báo lỗi tải, không treo.
- Màn hình hẹp (điện thoại) và rộng (tablet/PC) đều không tràn.

## 5. Áp production (sau khi Chủ quán duyệt)

1. Áp ngoài giờ cao điểm. Giữ sẵn file ROLLBACK.
2. Chạy lại mục 1 và 3 trên production.
3. Chạy `codegraph sync .` và `graphify update .` nếu có sửa thêm code.
4. Báo cáo kết quả, ghi `nhat_ky.md`.

## 6. Hoàn tác

Chạy `20261016_einvoice_foundation_v1_ROLLBACK.sql`. Lệnh này **xóa** dữ liệu hóa đơn và nhật ký công tắc đã lưu. Sao lưu trước nếu đã có dữ liệu thật. App cũ vẫn chạy, tab "Hóa đơn" chỉ báo lỗi tải.

## 7. Chưa làm (phạm vi tiếp theo)

Đưa bill vào hàng đợi khi bật công tắc (đụng settlement v5, cần thiết kế riêng), worker phát hành meInvoice, cấu hình tài khoản meInvoice theo quán, thuế suất/nhóm thuế. Phụ thuộc câu trả lời của MISA (xem `tich-hop-misa.md` mục 5).
