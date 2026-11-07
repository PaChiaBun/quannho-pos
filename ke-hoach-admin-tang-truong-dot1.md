# Kế hoạch: /admin theo dõi tăng trưởng — Đợt 1

Ngày lập: 05/11/2026. Trạng thái: **ĐÃ ÁP production 05/11 06:11 VN (TS 20261105_061053).** Chưa đối chiếu số trên màn hình sau đăng nhập.

## 1. Mục tiêu

Sau đợt này, mở `/admin` trả lời được 3 câu trong 1 phút:

1. Công ty đang thu được bao nhiêu tiền mỗi tháng, từ bao nhiêu quán?
2. Quán mới tạo có bán thật và có ở lại không, lứa sau có tốt hơn lứa trước không?
3. Quán nào đang dùng thật, một khách (chủ quán) có bao nhiêu quán?

Chỉ dùng dữ liệu đã có. **Không phát hành app, không đổi web /pos, không đổi bảng, không ghi dữ liệu.**

## 2. Việc Chủ Quán làm trước (không cần viết mã)

| # | Việc | Vì sao |
|---|---|---|
| T1 | Vào Tổng quan, mở "Gợi ý đánh dấu quán thử", xem và đánh dấu | 26/10 có 33 gợi ý, 0 quán được đánh dấu; số lẫn quán thử thì mọi tỷ lệ bên dưới đều sai |
| T2 | Chạy tệp đo chỉ đọc mà Claude đưa (bước 0 ở mục 6) rồi gửi lại kết quả | Claude không được đọc production; cần số thật để chốt ngưỡng "dùng thật" |

## 3. Quyết định cần chốt

| # | Câu hỏi | Mặc định nếu không chốt khác |
|---|---|---|
| Q1 | Ngưỡng "dùng thật" | **Từ 20 đơn trong 7 ngày.** Đo 05/11: không quán nào ở mức 20–49 đơn, nên mọi ngưỡng từ 20 đến 50 đều ra cùng 4 quán; 2 quán ở mức 10–19 đơn trung bình chưa tới 2 đơn/ngày |
| Q2 | Có đổi nghĩa "Tích cực" không | **Không.** Chủ Quán đã chốt 25/10 (có đơn trong 7 ngày); chỉ thêm "dùng thật" bên cạnh |
| Q3 | Tab Quán có hiện doanh thu không | **Không.** Giữ chốt 25/10, xem doanh số trong hồ sơ quán |

Việc riêng, không chặn đợt này: **khi nào tắt nút tự gia hạn miễn phí** (khoảng 25/11 có 169 quán hết hạn). Đợt 1 sẽ hiện số liệu để quyết.

## 4. Thay đổi

### 4.1 Hàm mới `admin_growth_v1(p_include_test boolean)`

Migration `supabase/migrations/20261105_admin_tang_truong_v1.sql` (+ `_ROLLBACK.sql`). Hàm chỉ đọc (`STABLE SECURITY DEFINER`), kiểm `qn_admin_caller()`, chỉ cấp cho `qn_admin`. Trả về 3 khối:

**a) `money` — tiền của công ty**

| Trường | Cách tính |
|---|---|
| `mrr_vnd` (doanh thu định kỳ quy theo tháng) | **Chỉ từ đơn thu phí.** Tổng theo từng quán Pro còn hạn, không khoá, phần đã trả chưa hết: đơn gần nhất ÷ số tháng của đơn |
| `paying_stores` | Số quán được tính vào `mrr_vnd` |
| `manual_paid_stores` | Pro còn hạn có tiền ghi tay qua "Đổi gói": form không có số tháng nên không đoán, không vào MRR |
| `comp_stores` | Pro còn hạn không có tiền (tặng, số tiền 0), hoặc đơn đã hết phần trả và đang chạy bằng phần tặng |
| `lifetime_stores` | Pro không thời hạn: có tiền cũng không chia được theo tháng, nên không tính vào `mrr_vnd` |
| `cash_30d_vnd` | Tổng `admin_store_actions.amount_vnd` 30 ngày, cùng cách tính với "thu 30 ngày" ở tab Gói |
| `first_paid_30d` / `renewed_30d` | Số quán trả lần đầu / trả tiếp trong 30 ngày; ghi thêm tiền mà không kéo dài hạn không tính là trả tiếp |
| `pro_lapsed` | Quán từng trả tiền đã hết hạn; không tính quán chỉ được tặng và quán khoá |
| `trial_ending_30d` | Quán free hết hạn trong 30 ngày tới (thấy được mốc 25/11) |
| `self_extend_30d` | Số lần tự gia hạn miễn phí trong 30 ngày |

"Khoản tiền" gồm 2 loại, đều nằm trong `admin_store_actions`:
- `payment`: số tháng lấy từ đơn `paid` của cùng quán có `paid_at` = thời điểm thao tác. Hai giá trị bằng nhau tuyệt đối vì `qn_billing_apply_order` ghi cả hai trong một giao dịch (`now()`), đã có test qua đúng hàm thật.
- `set_plan` có `amount_vnd > 0`: **không đoán**. Bản đầu suy số tháng từ ngày hết hạn; QC 2 vòng cho thấy mọi cách suy đều sai tới 3–12 lần khi nhập ngày gần, giữ nguyên ngày, hoặc sửa ngày sau, nên bỏ. Khoản này vẫn vào `cash_30d_vnd`. Muốn tính vào MRR: thêm ô số tháng vào form Đổi gói (đổi hàm ghi, phải hỏi Chủ Quán).
- Quán chỉ được tính là đang trả phí khi phần đã trả chưa hết. Trả đơn rồi được tặng thêm: còn tính tới hết phần đã trả, sau đó là quán tặng.

Số tiền lấy số thực nhận (`paid_amount_vnd`), không lấy giá niêm yết.

**b) `cohorts` — theo lứa quán, 12 tháng gần nhất (giờ Việt Nam)**

Mỗi tháng tạo quán có:
- `created`: số quán tạo.
- `has_menu`: hiện có ít nhất 1 món (bảng món không cho biết ngày thêm món đầu tiên).
- `first_order_7d`: có đơn hoàn thành trong 7 ngày đầu.
- `real_use_30d`: đạt từ 20 đơn trong 30 ngày đầu.
- `retained_60d`: có đơn trong ngày thứ 31–60. Tính trên số quán đã đủ 60 ngày tuổi, kèm `mature_60d`. **Lứa chưa đủ tuổi trả `null` và hiện "chưa đủ ngày"**, không hiện 0%.

**c) `usage` — người dùng thật**
- `real_use_7d`: số quán đạt ngưỡng dùng thật (hằng số trong hàm, đổi bằng migration, không làm trang cấu hình).
- `customers`: số chủ quán khác nhau, ghép `stores.owner_user_id` với thành viên `is_owner` (5 quán thiếu dòng `is_owner`, 6 chủ không có dòng thành viên).
- `multi_store_customers`: chủ có từ 2 quán.

Tất cả loại quán thử trừ khi bật công tắc "Tính cả quán thử".

### 4.2 Hàm mới `admin_store_list_v2`

Chép thân `admin_store_list_v1`, thêm:
- `p_sort`, `p_dir` với danh sách cột cho phép (`orders_7d`, `orders_30d`, `last_order_at`, `created_at`, `menu_items`, `name`), giá trị lạ trả `BAD_SORT`. **Sửa lỗi hiện tại:** sắp xếp chỉ trong 30 quán đang tải.
- Mỗi dòng thêm `owner_user_id`, `owner_store_count`.
- Ô tìm kiếm tìm cả tên chủ.

Giữ nguyên `v1` để trang cũ chạy được khi hoàn tác.

### 4.3 Trang `admin_web/` (`index.html`, `app.js`, `app.css`)

**Tổng quan**
- Khối mới **"Tiền của công ty"** ngay dưới "Việc cần làm hôm nay". Khi chưa có quán trả phí, hiện đúng `0 đ` kèm câu "Chưa có quán trả phí" và số quán sắp hết hạn, không để trống.
- Đổi chữ **"Doanh thu" → "Doanh số qua POS"** ở: `index.html:157,169`, `app.js:745,750,790,823,825`. Không đổi `app.js:2871,2899` (mô tả năng lực của Boom, nghĩa khác).
- Thẻ "Quán đang dùng tích cực": thêm dòng nhỏ "trong đó X dùng thật". Thẻ tổng: thêm "X khách (chủ quán)".
- Khối mới **"Giữ chân theo lứa quán"** ngay dưới phễu: bảng 12 tháng, điện thoại chuyển thành thẻ.
- "Việc cần làm hôm nay": thêm ô "Quán nghi là quán thử", bấm mở khối gợi ý.
- "Cách tính các chỉ số": thêm định nghĩa các chỉ số mới.
- Lỗi tải khối mới không làm hỏng các khối khác (có Thử lại, như `loadOverviewExtra`). Thêm id khối mới vào danh sách xoá khi Thoát (`app.js:225`).

**Tab Quán**
- Gọi `admin_store_list_v2`; đổi sắp xếp thì gọi lại máy chủ và về trang 1. Bỏ `sortedStores`.
- Tên chủ hiện "· 3 quán" khi có từ 2 quán; bấm vào lọc đúng các quán của chủ đó.

**Giữ chốt an toàn:** chữ từ dữ liệu chỉ qua `textContent`, không tải ngoài, vé chỉ ở `sessionStorage`, Thoát xoá sạch.

### 4.4 Không làm trong đợt này

- **Lọc theo gói ở tab Quán** (đã nói ở bản đánh giá): tab Gói đã có đủ bộ lọc này, thêm là trùng.
- Sửa "thu 30 ngày" ở khu Thu phí (hàm `admin_billing_overview_v1` tính cả quán thử, tab Gói thì không): ghi nhận, sửa khi có đơn thật.
- Biểu đồ xu hướng MRR: cần lưu số theo thời gian, chưa có tiền thì chưa cần.
- Nhịp app, phiên bản, nguồn khách, Telegram, SePay: Đợt 2 và 3.

## 5. Kiểm thử

**SQL** — `supabase/tests/admin_tang_truong_v1_test.sql` (theo mẫu `tong_quan_nang_cap_test.sql`, kết thúc ROLLBACK, so số trước / sau khi thêm dữ liệu thử):

| Nhóm | Ca phải đúng |
|---|---|
| Quyền | Khoá công khai, vé quán, vé quản trị thu hồi: bị chặn; vé quản trị: được |
| MRR | 499.000 đ / 6 tháng → 83.167 đ/tháng (làm tròn); Pro hết hạn, quán khoá: không tính |
| MRR | Tặng (tiền 0 hoặc NULL) vào `comp_stores`; Pro không thời hạn vào `lifetime_stores`, không tính MRR |
| MRR | Trả 2 lần chỉ tính lần gần nhất; trả thiếu tính số thực nhận; phụ thu tay không đổi MRR; tiền ghi tay vào `manual_paid_stores` |
| Phân loại | Lần đầu vs trả tiếp; `cash_30d_vnd` khớp `revenue_vnd_30d` của `admin_plan_overview_v1` |
| Lứa quán | Quán 40 ngày tuổi không tính vào `retained_60d`; lứa chưa đủ tuổi trả `null`; đơn huỷ không tính |
| Lứa quán | Ranh giới tháng theo giờ Việt Nam (tạo 23:30 UTC ngày cuối tháng thuộc tháng sau) |
| Chủ quán | Chủ 2 quán đếm 1 khách; quán thiếu dòng `is_owner` vẫn đếm; quán thử bị loại, bật công tắc thì có |
| Danh sách v2 | Quán đơn ít nhất lên đầu khi sắp tăng dần **trên toàn bộ**, không chỉ trang 1; `BAD_SORT`; phân trang không trùng / sót |
| Không đổi gì | Hàm không ghi dữ liệu; hàm `v1` giữ nguyên |

**Bản sao cục bộ** (Postgres trên máy, không dùng bản sao trên cụm production): bản cũ thiếu hàm → test FAIL; áp → PASS; áp lại → PASS; hoàn tác → hết hàm mới và md5 `v1` không đổi. **Đo tốc độ (đã đo, 200 quán + 50.000 đơn, `app_logs` trống):** `admin_growth_v1` 17 ms, `admin_store_list_v2` 11 ms; `orders` đã có chỉ mục `(store_id, status, created_at)`, không thêm chỉ mục.

**Trang** (`admin_web/dev/mock_server.py` thêm 2 hàm mới): 320 / 375 / 768 / 1440 px × sáng / tối, không tràn ngang, 0 lỗi console, chỉ gọi localhost; sắp xếp ở trang 2 vẫn đúng toàn bộ; khối mới lỗi + Thử lại; `0 đ` và "chưa đủ ngày" hiện đúng; tên chứa HTML hiện như chữ; Thoát xoá sạch.

**QC độc lập:** 1 tác tử chỉ đọc rà công thức tiền và quyền trước khi áp.

## 6. Thứ tự làm

| Bước | Việc | Ai làm |
|---|---|---|
| 0 | Viết tệp đo chỉ đọc; chạy và gửi kết quả; chốt Q1 | Claude viết, Chủ Quán chạy |
| 1 | Viết test SQL trước, rồi migration + rollback; kiểm trên bản sao cục bộ | Claude |
| 2 | Sửa trang + máy chủ giả; kiểm 4 kích thước | Claude |
| 3 | QC độc lập, sửa lỗi | Claude |
| 4 | Script `db-fix/admin_tang_truong_ap_dung.sh` theo mẫu `tong_quan_nang_cap_ap_dung.sh` | Claude |
| 5 | Duyệt và áp: build → sao lưu DB → migration → test tự ROLLBACK → sao lưu trang → đưa trang → kiểm mã băm và quyền | **Chủ Quán duyệt** |
| 6 | Đăng nhập xem số thật, đối chiếu với kết quả bước 0 | Chủ Quán |
| 7 | Cập nhật tài liệu (mục 7), nhật ký, CodeGraph + Graphify | Claude |

**Hoàn tác:** `ROLLBACK=1 bash db-fix/admin_tang_truong_ap_dung.sh <TS>`: trả trang cũ rồi xoá 2 hàm. Không có dữ liệu nào phải khôi phục.

## 7. Tài liệu phải cập nhật

- `.agents/workflows/qn.md`, mục "Trang quản trị nền tảng": 2 hàm mới, định nghĩa MRR và "dùng thật".
- `.docs/kien-truc-data.md`, `.docs/tinh-nang.md`: hiện chưa nhắc gì tới trang quản trị, thêm mục ngắn.
- `nhat_ky.md`. Không cần đụng `.docs/Huong_dan/` và bộ Boom vì không đổi app.

## 8. Rủi ro

| Rủi ro | Cách giữ |
|---|---|
| Công thức tiền sai làm quyết định sai | Test từng ca, QC riêng, mỗi chỉ số có định nghĩa ngay trên trang |
| Nối khoản `payment` với đơn thu phí | Đã giải quyết: cùng `now()` trong một giao dịch, không phải sửa hàm thu phí. Ghi chú ở `qn.md`: đừng tách hai lệnh ghi đó |
| Thư mục `quan_nho` có việc dở của phiên khác | Chỉ commit đúng các tệp của đợt này; `admin_web/` hiện sạch |
| Số đầu tiên gây thất vọng (MRR gần 0) | Đúng thực tế, không phải lỗi; đó là số cần thấy trước mốc 25/11 |
