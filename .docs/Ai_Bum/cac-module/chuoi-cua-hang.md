# 🏬 Module: Báo Cáo Nhiều Cửa Hàng / Chuỗi

**Trạng thái:** ✅ Hoàn thành · DB đã áp production · Web `/pos/` đã deploy (1.0.5+13) · Android/iOS/Windows **chưa phát hành**
**Cập nhật:** 17/10/2026
**Mã module:** `chain` (ô trong lưới Modules, route `/chain`)

---

## Mục Đích
Một Chủ quán có nhiều cửa hàng/chi nhánh cần **một chỗ** để xem cả chuỗi đang chạy thế nào và **so sánh các quán với nhau** (quán nào dẫn đầu, quán nào tụt, quán nào có vấn đề), mà không phải chuyển từng quán rồi mở Báo cáo.

Chuỗi chỉ là **lớp đọc tổng hợp**. Menu, kho, nhân viên, bàn và doanh thu của mỗi cửa hàng **vẫn tách riêng theo `store_id`**. Chưa chung Ví/điểm/khách trong chuỗi (xem "Chưa làm").

## Ai Thấy Module Này
- **Chỉ Chủ quán** (`session.isOwner`). Quản lý và nhân viên **không thấy**, không cấp được qua vai trò (`store_roles.modules`). Server cũng kiểm lại, không tin client.
- Tự **bật một lần** cho mỗi cửa hàng khi Chủ quán sở hữu từ 2 cửa hàng trở lên hoặc đã có chuỗi. Sau đó chủ gỡ/thêm lại trong chế độ **Sửa** như mọi module; đã gỡ thì không tự quay lại.
- Chủ chỉ có 1 cửa hàng: không tự hiện, nhưng thêm tay được từ bộ chọn module.

## Tính Năng Chính
- **Lập chuỗi:** Chủ quán tạo chuỗi, **chủ động** thêm/gỡ từng cửa hàng mình sở hữu (nhiều cửa hàng cùng chủ không tự thành chuỗi). Mỗi thao tác có audit.
- **Chọn kỳ:** Hôm nay / Tuần này / Tháng này, kèm thanh `‹ kỳ ›` xem kỳ cũ.
- **Thẻ tổng:** doanh thu, số đơn, TB/đơn, tiền mặt, chuyển khoản, giảm giá; chip tăng/giảm so với **cùng kỳ trước**.
- **Nhận xét nhanh:** cảnh báo/ghi nhận tự động, mỗi dòng có giải thích số liệu và ngưỡng.
- **Xếp hạng doanh thu:** hạng, màu riêng mỗi quán, tỷ trọng, chip tăng/giảm.
- **So sánh theo chỉ số:** Doanh thu / Số đơn / TB/đơn / Giảm giá, vạch trung bình chuỗi, nhãn Cao nhất/Thấp nhất/Mới mở.
- **Cơ cấu thanh toán:** cột chồng 100% tiền mặt/chuyển khoản/thẻ/ví-khác từng quán.
- **Xu hướng theo ngày:** mỗi quán một đường (không vẽ ngày chưa tới).

## Cách Đọc Chip Tăng/Giảm
- **Xanh/đỏ** chỉ khi thay đổi **vượt mức dao động bình thường** (đã quy đổi theo ngày có bán) **và** con số tổng cũng đáng kể.
- **Xám:** trong dao động bình thường, hoặc hai cách tính ngược chiều (ví dụ quán nghỉ vài ngày: tổng giảm mạnh nhưng mỗi ngày bán thì không đổi).
- **"Ít dữ liệu":** chưa đủ 15 đơn mỗi bên. **"Quán mới":** chưa đủ lịch sử. **"Mới" / "Chưa so sánh":** không có gốc để so.
- **Chạm vào chip** để xem lý do bằng lời.

## Câu Hỏi Thường Gặp
- *"Sao quán X giảm 42% mà chip màu xám?"* → Quán nghỉ vài ngày trong kỳ; bình quân mỗi ngày bán gần như không đổi. Nhận xét nhanh sẽ liệt kê đúng những ngày không có đơn.
- *"Sao hôm nay không thấy so sánh?"* → Ngày được so với **cùng thứ tuần trước** (cuối tuần bán nhiều hơn ngày thường ~40%), cùng khoảng giờ đã trôi qua. Đầu ngày chưa có đơn là bình thường, hệ thống không báo động.
- *"Mở thêm quán mới có làm tổng chuỗi tăng ảo không?"* → Không. Chip tổng chỉ tính các quán so sánh được và nói rõ quán nào chưa được tính.
- *"Muốn xem chi tiết nhân viên/kho của một quán?"* → Chuyển sang quán đó rồi mở Báo cáo. Báo cáo chuỗi **không có KPI cá nhân nhân viên xuyên chuỗi**.

---

# 🧱 Cấu Trúc Kỹ Thuật (cho người phát triển)

## Luồng dữ liệu
```
Trang chủ ─ ô "chain" (chỉ isOwner) ─▶ ChainReportScreen
   │                                         │
   │ ChainModuleOffer (tự bật 1 lần)         ├─ ChainRepository ──▶ RPC (Supabase, SECURITY DEFINER)
   ▼                                         │     list_my_chains_v1 · get_chain_report_v1 ×2 (kỳ này + kỳ so sánh)
ModuleRepository.activate('chain')           │
                                             ├─ chain_compare.dart   (kỳ, hàng so sánh, xu hướng ngày — logic thuần)
                                             └─ chain_insights.dart  (đánh giá ý nghĩa, nhận xét — logic thuần)
```
Kỳ so sánh và kỳ hiện tại được tải **song song**; lỗi riêng kỳ so sánh chỉ ẩn chip tăng/giảm, không làm hỏng báo cáo.

## Bản đồ file
| Tầng | File | Vai trò |
|---|---|---|
| Màn hình | `lib/screens/chain_report_screen.dart` | Toàn bộ UI báo cáo; dùng đúng token màu của `report_screen.dart` |
| Màn hình | `lib/screens/chain_manage_sheet.dart` | Bottom sheet tạo chuỗi, thêm/gỡ cửa hàng |
| Màn hình | `lib/screens/chain_module_offer.dart` | Widget không hiển thị: tự bật module 1 lần (cờ `chain_module_offered_<storeId>`) |
| Dữ liệu | `lib/core/repositories/chain_repository.dart` | Gọi RPC, model `StoreMetrics/ChainReport/MyChains`, `ChainException` (mã lỗi → câu tiếng Việt), `rpcOverride` cho test |
| Logic | `lib/core/utils/chain_compare.dart` | `windowFor` (kỳ + kỳ so sánh), `buildRows`, `sortedBy`, `chainAverage`, `buildDailyTrend` |
| Logic | `lib/core/utils/chain_insights.dart` | `InsightConfig` (mọi ngưỡng), `assessChange`, `analyzeStores`, `analyzeChainTotals`, `buildInsights` |
| Nối vào app | `lib/core/repositories/module_repository.dart` | `_kAllModules` có `chain` (mặc định tắt, position 15) |
| Nối vào app | `lib/shared/widgets/module_tile.dart` | Ô `chain` (lime, `titleLines: 2` chỉ cho ô này) |
| Nối vào app | `lib/screens/dashboard_screen.dart` | Lọc cứng chỉ `isOwner`, route `/chain`, gắn `ChainModuleOffer` |
| Nối vào app | `lib/screens/report_screen.dart` | Biểu tượng cửa hàng ở header Báo cáo (lối phụ) |

**Cố ý KHÔNG** thêm `chain` vào `permMap` (dashboard) hay `kAllModules`/`kDefaultPerms` (`staff_service.dart`) hay danh sách module của `role_manager_screen.dart` → không cấp được cho vai trò nào.

## Database (Supabase)
| Đối tượng | Ghi chú |
|---|---|
| `store_chains` | Chuỗi; `owner_user_id`; tối đa 20 chuỗi/chủ |
| `store_chain_stores` | Cửa hàng ↔ chuỗi, `joined_at/left_at`; unique một phần: mỗi cửa hàng tối đa **1 chuỗi đang hoạt động**; tối đa 50 cửa hàng/chuỗi; giữ lịch sử |
| `store_chain_audit_logs` | Audit tạo chuỗi/thêm/gỡ |
| `qn_is_store_owner(store)` | Chủ (không tính Quản lý) |
| RPC | `create_store_chain_v1`, `add_store_to_chain_v1`, `remove_store_from_chain_v1`, `list_my_chains_v1`, `get_chain_report_v1` |

- Chỉ `authenticated` gọi được RPC (`anon` bị chặn); bảng chỉ SELECT theo chủ chuỗi qua RLS; **ghi chỉ qua RPC** có audit + khóa tư vấn (advisory lock).
- `get_chain_report_v1(p_chain, p_from, p_to, p_tz)`: kỳ ≤ 367 ngày; chỉ gồm cửa hàng còn trong chuỗi **và** người gọi vẫn là chủ (còn lại ở `excluded_stores`). Trả theo từng cửa hàng + tổng + doanh thu theo ngày: `orders`, `revenue`, `gross_revenue` (= doanh thu + giảm giá), `avg_order_value`, tiền mặt/chuyển khoản/thẻ/`wallet_revenue`, `discount`, `void_count`, `void_amount`, `first_order_at`.
- Chỉ đơn `completed`, số tiền `COALESCE(total_amount, total)`. **Không** trả tên người hủy/lý do hủy/KPI nhân viên.
- Migration: `supabase/migrations/20261017_chuoi_cua_hang_v1.sql` và `20261018_chuoi_bao_cao_them_truong_v1.sql` (đều có `_ROLLBACK.sql`). Chỉ **thêm** khóa JSON ở bản 1.1 → client cũ chạy bình thường; client mới coi trường vắng (`null`) là **"không rõ"**, tuyệt đối không coi là 0.

## Quy tắc nhận xét (`InsightConfig`)
Nguyên tắc: **chỉ nói điều dữ liệu đủ chứng minh; thà im lặng hơn báo động giả.**

| Quy tắc | Điều kiện | Ghi chú |
|---|---|---|
| Tăng/giảm có ý nghĩa | bình quân **ngày có bán** vượt ngưỡng dao động `max(sàn, N1·√((1/ngày_này+1/ngày_trước)/2))`, mỗi bên ≥ 15 đơn, tổng thô cùng chiều và ≥ nửa ngưỡng | N1: số đơn 26%, doanh thu 34%; sàn 5%/6%. Kèm nguyên nhân (số đơn hay giá trị mỗi đơn) |
| Quán im lặng | kỳ này 0 đơn, cùng kỳ trước ≥ 5 đơn | Đầu ngày chưa bán không báo |
| Ngày không có đơn | kỳ ≥ 2 ngày đã qua, kỳ so sánh bán ≥ 80% ngày | Liệt kê ngày cụ thể |
| Hủy món/bàn | `void_amount/revenue` ≥ 5% và ≥ 1,8× các quán khác (hoặc ≥ 2× kỳ trước nếu chỉ 1 quán), ≥ 30 đơn | |
| Giảm giá | `discount/gross_revenue` ≥ 4% và ≥ 2× các quán khác, ≥ 30 đơn | |
| TB/đơn | ≥ 115% hoặc ≤ 80% trung bình chuỗi, quán ≥ 15 đơn | |
| Quán mới | `first_order_at` sau đầu kỳ so sánh | Gộp 1 dòng; không tính vào tổng chuỗi |
| Dẫn đầu / tập trung | ≥ 2 quán có đơn; ≥ 70% doanh thu ở 1 quán (từ 3 quán) | |

Tối đa 6 nhận xét, cảnh báo xếp trước. **Thẻ tổng chuỗi** tính kiểu "cùng cửa hàng" (loại quán mới, quy đổi theo ngày bán từng quán).

## Cách so kỳ (`windowFor`)
- Ngày → **cùng thứ tuần trước**; tuần/tháng → kỳ liền trước.
- Kỳ **đang diễn ra** so với **phần đã trôi** của kỳ so sánh (không so nửa kỳ với cả kỳ).

## Số đo thật làm căn cứ (đọc production 17/10/2026, chỉ truy vấn tổng hợp)
- Hệ thống mới có **1 quán bán thật** (~115 đơn/ngày) → ngưỡng chưa hiệu chuẩn được bằng nhiều quán; đặt thành hằng có giải trình, nên xem lại khi có thêm quán.
- Cuối tuần bán nhiều hơn ngày thường ~40%; so một ngày với cùng thứ lệch doanh thu P80 = 34% (so với hôm qua: 53%).
- `orders.status` chỉ có `completed`/`open`; hủy nằm ở `void_audit_logs`; giảm giá ở `orders.discount` (`discount_amount` luôn rỗng).
- Tuần chỉ bán 4/7 ngày có thể hiện "−46%" dù mỗi ngày bán gần như không đổi → bắt buộc quy đổi theo ngày bán.

## Bẫy đã gặp (đừng lặp lại)
1. Test bằng dữ liệu giả không bắt được mọi lỗi: chạy engine trên **JSON thật của RPC** làm lộ 3 lỗi (tổng chuỗi bị quán mới thổi phồng; nhiều dòng "quán mới" gần trùng; chip xanh mà số hiển thị âm/rất nhỏ).
2. Không so "hôm nay" với "hôm qua" (nhịp theo thứ rất mạnh).
3. Màu của quán tránh lục/xanh dương/vàng vì dành cho tiền mặt/chuyển khoản/thẻ.
4. Quán mới không được gắn "Thấp nhất".
5. Chạy web ở `localhost` không đăng nhập được vào máy chủ thật (CORS ở `/api/auth/pos-jwt`); dùng bản xem thử dữ liệu giả/JSON thật bên dưới.

## Kiểm thử & công cụ
- **Flutter (104 test, 4 file):** `test/core/chain_insights_test.dart`, `test/core/chain_compare_test.dart`, `test/screens/chain_report_screen_test.dart`, `test/screens/chain_module_offer_test.dart`.
- **SQL (57 kiểm tra):** `supabase/tests/chuoi_cua_hang_v1_test.sql` (38) + `chuoi_bao_cao_truong_moi_test.sql` (19); chạy thử trên bản sao bằng `db-fix/chuoi_stage_dryrun.sh` / `chuoi11_stage_dryrun.sh`; áp production bằng `db-fix/chuoi_ap_dung.sh` / `chuoi11_ap_dung.sh` (sao lưu → áp → test → tự ROLLBACK).
- **Xem thử giao diện:** `scratch/chain_report_preview.dart` (dữ liệu giả) và `scratch/chain_demo_real_preview.dart` (JSON thật từ bản sao). Dữ liệu ảo có đánh dấu để xóa sạch: `db-fix/demo_chuoi_seed.sql`, `demo_chuoi_cleanup.sql`, `demo_chuoi_stage.sh`.

## Chưa làm / nợ
- Chung Ví/điểm/khách trong chuỗi; hồ sơ nhân viên đa cửa hàng.
- Phát hành Android/iOS/Windows (các máy đã cài vẫn chạy bản cũ, chưa có module).
- Hiệu chuẩn lại ngưỡng khi có nhiều quán bán thật.
- Vài lỗi dữ liệu cũ phát hiện khi đo: 3 cặp `order_number` trùng (bill trùng trước settlement v5).

## Liên quan
- Báo cáo từng quán: [`bao-cao.md`](bao-cao.md) · Thu chi: [`thu-chi.md`](thu-chi.md)
- Kiến trúc dữ liệu: `.docs/kien-truc-data.md` (mục "Chuỗi cửa hàng") · Tính năng: `.docs/tinh-nang.md`
- Nhật ký chi tiết: `nhat_ky.md` (các mục 17/10/2026)
