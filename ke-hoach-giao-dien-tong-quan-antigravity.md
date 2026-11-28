# GIAO ANTIGRAVITY — THIẾT KẾ LẠI TAB "TỔNG QUAN" TRANG QUẢN TRỊ (/admin/#overview)

> Dự án: Quán Nhỏ POS — `https://quannho.lpm.vn/admin/#overview`
> Ngày giao: 26/10/2026 · Người yêu cầu: Chủ Quán
> Lời Chủ Quán: giao diện phải **thật đẹp, tinh tế, như các app báo cáo chuyên nghiệp trên thế giới**, và **không được có biểu tượng (icon) trông như do AI vẽ**.
> Phạm vi: **CHỈ GIAO DIỆN tab Tổng quan** (HTML / CSS / JS hiển thị). Không đổi máy chủ, database, quyền, đăng nhập, dữ liệu.
> **Không deploy, không sửa nginx, không commit / push** khi Chủ Quán chưa duyệt.

---

## 1. Việc cần làm

Thiết kế lại tab Tổng quan để Chủ Quán **mở ra trong 5 giây biết ngay**: hôm nay phải làm gì, hệ thống đang bán ra sao, quán nào đang bỏ dùng.
Giữ nguyên **mọi chức năng và dữ liệu đang có**, chỉ thay cách trình bày.

Làm theo 2 bước:
1. **Bản mẫu để duyệt:** sửa trực tiếp trên máy chủ giả, chụp ảnh 3 cỡ màn hình (1440×900, 768×1024, 375×812), cả nền sáng và nền tối.
   Gửi ảnh + một đoạn giải thích ngắn về hướng thiết kế. **Dừng lại chờ Chủ Quán duyệt.**
2. **Hoàn thiện** theo góp ý, chạy đủ tiêu chí nghiệm thu ở mục 8.

## 2. Hiện trạng — vì sao chưa đẹp

Trang hiện tại (nền xanh than, nhấn cam) đủ chức năng nhưng trông "rập khuôn":
- **Hộp lồng hộp:** mọi khối đều là thẻ có viền nằm trong một thẻ có viền khác → rối mắt, không có chỗ thở.
- **Không có thứ bậc:** 7 ô "Việc cần làm", 3 thẻ lớn, 6 ô phụ, 4 ô doanh số đều na ná nhau; mắt không biết nhìn đâu trước.
- **Thẻ lớn có viền màu trên đầu + nhãn hình viên thuốc khắp nơi** — đúng kiểu giao diện "do AI sinh ra".
- **Trang quá dài, một cột:** danh sách "Quán đang bỏ dùng" chiếm cả màn hình; biểu đồ tăng trưởng bị đẩy xuống cuối.
- Biểu đồ nhỏ, chưa có đường dóng khi rê chuột, chưa có đường so sánh kỳ trước.
- Số không đi kèm xu hướng (chỉ có chữ "▼18% so với kỳ trước"), thiếu biểu đồ mini.

## 3. Phong cách mong muốn

**Tham khảo** (chỉ học tinh thần, không sao chép giao diện hay logo):
Stripe Dashboard, Linear, Vercel Analytics, Plausible Analytics, Shopify Admin, Mixpanel.

Điểm chung của các trang này, phải đạt được:
- **Tiết chế:** một màu nhấn duy nhất (cam Quán Nhỏ `#F07A45`) dùng ít và đúng chỗ; phần còn lại là thang màu trung tính (xám ấm / xanh than).
  Xanh lá / đỏ **chỉ** dùng cho tăng / giảm.
- **Chữ làm chủ đạo:** thứ bậc tạo bằng cỡ chữ, độ đậm và khoảng trắng, **không phải** bằng viền, bóng đổ, nền màu.
  Số lớn rõ ràng (`font-variant-numeric: tabular-nums`), nhãn nhỏ màu xám, đơn vị nhỏ hơn số.
- **Ít khung:** chia khu bằng khoảng trắng và đường kẻ mảnh 1px; chỉ những khối thật sự độc lập mới là thẻ. Không thẻ nào nằm trong thẻ khác.
- **Lưới 8px**, góc bo nhỏ (8–10px), bóng đổ gần như không có (nền tối: không bóng).
- **Biểu đồ sạch:** lưới ngang rất mờ, không viền khung, nhãn trục thưa, một màu, rê chuột / chạm có đường dóng + hộp số.
- Phông: **Plus Jakarta Sans** đã tự host trong `admin_web/fonts/` (dùng 400 / 500 / 600 / 700, không thêm file mới).

### 3.1 Luật về biểu tượng (icon) — BẮT BUỘC

Chủ Quán không muốn icon "trông như AI". Cụ thể **CẤM**:
- Emoji trong giao diện (🔥 📈 💰 🚀 ✨ ⚠️ ✅ …), kể cả trong tiêu đề, nút, nhãn. Ngoại lệ duy nhất đang có: 👍/👎 ở tab Boom — không đụng.
- Biểu tượng tia sáng ✨, đũa phép, não, robot, ngôi sao lấp lánh, hình cầu phát sáng.
- Ô vuông bo tròn có nền màu gradient chứa icon đặt trên mọi thẻ số.
- Gradient tím–xanh, hiệu ứng kính mờ (glassmorphism), viền / bóng phát sáng (glow), viền màu trên đầu thẻ.
- Icon nhiều nét, nhiều màu, kiểu 3D hoặc minh hoạ.

**Được dùng:**
- Bộ icon nét mảnh đồng nhất: lưới 24px, nét 1.5px, đầu nét bo tròn, chỉ một màu (`currentColor`), hiển thị cỡ 16–20px.
  Có thể chép icon từ **Lucide** (giấy phép ISC) vào thẳng mã SVG trong repo, kèm ghi chú giấy phép. Cấm tải từ mạng.
- Icon **chỉ** dùng ở: thanh điều hướng, nút hành động (Gọi, Hồ sơ, Làm mới, Xem thêm), và dấu chỉ trạng thái nhỏ.
  **Thẻ số liệu không cần icon** — con số và nhãn là đủ (đúng như Stripe, Linear).
- Mũi tên tăng / giảm dùng ký hiệu đơn giản (▲ ▼ hoặc SVG mũi tên 12px), không emoji.

## 4. Bố cục đề xuất cho tab Tổng quan

Thứ tự từ trên xuống (máy tính ≥ 1024px dùng lưới 12 cột, tối đa ~1280px):

1. **Đầu trang:** tiêu đề "Tổng quan", dòng phụ "Cập nhật lúc HH:mm"; bên phải: công tắc "Tính cả quán thử" + nút Làm mới (icon).
2. **Việc cần làm hôm nay** — dải gọn một hàng (kiểu hộp thư việc):
   mỗi việc = số + nhãn ngắn, bấm mở đúng danh sách (giữ hành vi hiện có: `goPlans(...)`, hỗ trợ, đơn thu phí).
   Việc bằng 0 thì làm mờ hoặc gom lại thành "Không còn việc nào khác"; việc > 0 mới nổi bật.
   Điện thoại: cuộn ngang hoặc danh sách 2 cột.
3. **Hàng KPI chính — 4 ô**, mỗi ô: nhãn → số lớn → so với kỳ trước (▲/▼ % màu xanh / đỏ) → **biểu đồ mini (sparkline)** 30 ngày:
   - Doanh thu 7 ngày · Đơn 7 ngày · Quán đang dùng tích cực (kèm % trên tổng quán thật) · Quán mới 7 ngày.
   - Các số phụ (mới hôm nay, mới 30 ngày, có đơn 30 ngày, ngủ, chưa bán, quán thử đã loại, doanh thu 30 ngày, quán có bán 7 ngày)
     xếp thành **một dải chữ nhỏ** bên dưới hoặc nằm trong khối liên quan — không làm thành 10 ô to bằng nhau.
4. **Khối chính, 2 cột (8 + 4):**
   - Trái: **Doanh thu theo ngày (30 ngày)**, biểu đồ lớn. Có nút chuyển "Doanh thu / Số đơn".
     Rê chuột hiện đường dóng + hộp số (ngày, doanh thu, số đơn). Giữ cơ chế cắt trục khi có ngày đột biến (`capOutlier`), nhưng trình bày tinh tế hơn.
   - Phải: **5 quán bán nhiều nhất**: hạng · tên · doanh thu, kèm thanh ngang mảnh thể hiện tỷ lệ; bấm tên mở hồ sơ quán.
5. **Phễu kích hoạt quán:** 4 bước nằm ngang (Tạo quán → Đã từng bán → Còn bán 30 ngày → Tích cực 7 ngày),
   mỗi bước: số, % chuyển đổi từ bước trước, thanh tỷ lệ. Đây là chỉ số Chủ Quán quan tâm nhất (đa số quán chưa bán đơn nào).
   Điện thoại: dọc.
6. **Quán đang bỏ dùng:**
   - Máy tính: **bảng** (Tên quán · Chủ + SĐT · Đơn cuối · Đơn / doanh thu 30 ngày · nút Gọi / Hồ sơ), nhãn "đang khoá" nhỏ.
   - Điện thoại: thẻ gọn.
   - Hiện 5–8 dòng đầu + "Xem tất cả (N)". Không để danh sách chiếm cả trang.
7. **Tăng trưởng, 2 cột:** "Quán mới theo ngày (60 ngày)" và "Quán có đơn theo tuần (12 tuần)", cột tuần đang chạy vẽ nhạt
   (đã có logic "Tuần này (mới N ngày)").
8. **Gợi ý đánh dấu quán thử:** đặt cuối trang, **thu gọn mặc định** ("Có N quán nghi là quán thử — Xem lại"),
   mở ra mới thấy danh sách có ô chọn + nút "Đánh dấu quán đã chọn" (giữ hộp hỏi xác nhận).
9. Chú thích định nghĩa (tích cực, ngủ, bỏ dùng…): chuyển thành **dấu (i) nhỏ cạnh tiêu đề**, rê / chạm mới hiện, thay cho đoạn chữ dài cuối trang.

**Máy tính bảng (600–1023px):** KPI 2×2, khối chính xếp dọc.
**Điện thoại (< 600px):** một cột, KPI 2×2 gọn, vùng chạm ≥ 44px, không tràn ngang ở 320–430px.
**Trạng thái:** khung xương (skeleton) khi tải; lỗi từng khối hiện riêng kèm nút "Thử lại" (khối khác vẫn chạy — giữ hành vi hiện có);
khối rỗng có câu nhẹ nhàng, không minh hoạ màu mè.

## 5. Hệ thống thiết kế (token)

Định nghĩa trong `:root` của `admin_web/app.css`, có cả **sáng và tối** (giữ nút chuyển sáng / tối hiện có):
- Màu: nền trang, nền khối, đường kẻ, chữ chính / phụ / mờ, nhấn cam, tăng (xanh), giảm (đỏ), cảnh báo (vàng hổ phách).
  Độ tương phản chữ ≥ 4.5:1 ở cả hai nền.
- Thang chữ: 12 / 13 / 14 / 16 / 20 / 28 / 36px; số KPI 28–36px đậm 600.
- Khoảng cách: 4 / 8 / 12 / 16 / 24 / 32 / 48px.
- Định dạng số kiểu Việt Nam: `1.234`, tiền rút gọn `126tr`, `7,7 tỷ` (đã có `fmtMoneyShort`), ngày `dd/mm`.

Token mới phải không làm hỏng các tab khác (Quán, Gói, Hỗ trợ, Boom) — nếu đổi token dùng chung thì kiểm lại cả các tab đó.

## 6. Kiến trúc hiện có (đọc trước khi sửa)

| File | Vai trò |
|---|---|
| `admin_web/index.html` | Khung trang. Tab Tổng quan là `<section id="tab-overview">` (các khối `ov-todo`, `ov-hero`, `ov-secondary`, `ov-sales`, `ov-rev-chart`, `ov-top`, `ov-funnel`, `ov-drop`, `ov-new-chart`, `ov-week-chart`, `ov-suggest-card`). Có thẻ CSP. |
| `admin_web/app.css` | Toàn bộ kiểu, token màu sáng / tối ở `:root`. |
| `admin_web/app.js` | Logic. Tổng quan: `loaders.overview`, `loadOverviewExtra` (có `ovExtraGen` chống kết quả về muộn đè kết quả mới), `renderChart` (SVG tự vẽ), `salesKpi`, `todoKpi`, `goPlans`, `deltaText`, `fmtMoneyShort`. Hàm `el()` / `svgEl()` tạo phần tử an toàn. |
| `admin_web/build.sh` | Đóng gói → `build/admin_web/` (+ sinh `config.js`). |
| `admin_web/dev/mock_server.py` | **Máy chủ giả** có dữ liệu mẫu (gồm ngày doanh thu đột biến, tên quán chứa HTML, quán bị khoá, 14 quán bỏ dùng). |

Xem trước trên máy (không đụng production):
```bash
cd quan_nho && bash admin_web/build.sh && python3 admin_web/dev/mock_server.py build/admin_web 8765
# mở http://localhost:8765/admin/#overview — tên đăng nhập bất kỳ, mật khẩu "dung" (giá trị giả của máy chủ giả)
```

### Dữ liệu tab Tổng quan (KHÔNG đổi, chỉ đổi cách hiển thị)
- `admin_store_overview_v1({p_include_test})` → `{total, test_stores, new_today, new_7d, new_30d, active_7d, active_30d, sleeping, never_sold, new_by_day:[{day,n}]×60, active_by_week:[{week_start,n}]×12}`
- `admin_overview_extra_v1({p_include_test})` →
  - `sales`: `orders_7d, revenue_7d, orders_prev7, revenue_prev7, orders_30d, revenue_30d, orders_prev30, revenue_prev30, stores_selling_7d, by_day:[{day,n,revenue}]×30, top:[{id,name,code,orders,revenue,orders_7d}]×≤5`
  - `dropping`: `{total, rows:[{id,name,code,owner_name,owner_phone,last_order_at,orders_30d,revenue_30d,locked}]×≤50}`
  - `todo`: `trial_ending, trial_expired, pro_ending, pro_expired, follow_ups_due, support_open, support_in_progress, billing_pending`
  - `test_suggest`: `[{id,name,code,created_at,reason: name_test|name_junk, orders_total}]×≤100`
- `admin_set_test_store_v1({p_store, p_is_test})` → `{ok}` (nút đánh dấu quán thử).
- Sparkline cho KPI: dùng `sales.by_day` (doanh thu / đơn) và `new_by_day`; **không** gọi thêm hàm mới.
  "Quán tích cực" chỉ có số theo tuần (`active_by_week`) — dùng làm sparkline 12 tuần.

## 7. Chốt an toàn BẮT BUỘC (vi phạm = không duyệt)

1. Chữ lấy từ dữ liệu (tên quán, tên chủ…) **chỉ** gắn bằng `textContent` / `el()`. Cấm `innerHTML`, `insertAdjacentHTML`,
   `outerHTML`, `document.write`. Máy chủ giả có quán tên `<img src=x onerror=alert(7)>` — phải hiện nguyên như chữ.
2. **Không tải gì từ ngoài:** không CDN, không Google Fonts, không thư viện biểu đồ từ mạng. Biểu đồ vẽ bằng SVG tự viết.
   Giữ nguyên CSP; cấm script / style nội tuyến, cấm thuộc tính `style="…"`, `onclick="…"`.
   Đặt kích thước động bằng thuộc tính SVG hoặc `element.style.x = …` trong JS (CSP hiện tại cho phép cách này).
3. Nút "Gọi" chỉ dùng `tel:` với số đã lọc (giữ code hiện có).
4. Vé đăng nhập chỉ ở `sessionStorage`; Thoát phải xoá hết nội dung đã tải (giữ `logout()`).
   `localStorage` chỉ cho tuỳ chọn hiển thị (sáng / tối, khối thu gọn).
5. Không gọi hàm máy chủ nào khác ngoài danh sách mục 6. Không thêm tính năng ghi dữ liệu.
6. Hiệu ứng chuyển động ngắn (≤ 200ms) và tắt khi `prefers-reduced-motion`.

## 8. Tiêu chí nghiệm thu

1. Ảnh chụp **trước / sau** ở 1440×900, 768×1024, 375×812 — nền sáng và tối. Không tràn ngang, không chữ bị cắt, không chồng chữ.
2. **Kiểm icon:** grep `admin_web/` không có emoji mới (ngoài 👍/👎 sẵn có ở tab Boom); mọi icon là SVG nét 1.5px một màu.
3. Mọi chức năng cũ còn chạy: bấm ô việc cần làm mở đúng danh sách; công tắc quán thử tải lại số; Làm mới; Gọi; Hồ sơ;
   Xem thêm; đánh dấu quán thử (có hỏi xác nhận, nút khoá khi đang gửi); biểu đồ đột biến không làm bẹp cột khác.
4. Rê chuột / chạm biểu đồ hiện đúng số; dùng bàn phím (Tab) đi được qua các ô bấm, có viền focus rõ.
5. Tab khác (Quán, Gói, Hỗ trợ, Boom) không bị vỡ giao diện.
6. Console không lỗi; tab Network chỉ gọi `localhost`; `node --check admin_web/app.js` sạch;
   grep không có `innerHTML|insertAdjacentHTML|outerHTML|document.write`.
7. Kích thước `app.js` + `app.css` (chưa nén) tăng không quá ~40 KB.

## 9. Quy tắc làm việc

- Chỉ sửa trong `admin_web/` (và `admin_web/dev/mock_server.py` nếu cần thêm dữ liệu mẫu). **Không** sửa `lib/`, `supabase/`, `services/`, `db-fix/`.
- **Không chạy `dart format`** (repo định dạng tay, nhiều test đọc nguyên văn mã).
- Không deploy, không sửa nginx, không đụng production, không commit / push khi Chủ Quán chưa bảo.
- Không đưa mật khẩu, khoá bí mật vào file hay báo cáo (`config.js` do `build.sh` sinh).
- Xong việc: ghi một mục ngắn vào `nhat_ky.md` (đã làm gì, file nào, ảnh chụp, việc còn chờ áp).
- Báo cáo bằng **tiếng Việt**, giải thích thuật ngữ kỹ thuật. Claude sẽ QC độc lập rồi mới hỏi Chủ Quán duyệt áp.
