# KẾ HOẠCH GIAO ANTIGRAVITY — THIẾT KẾ LẠI GIAO DIỆN TRANG QUẢN TRỊ (/admin)

> Dự án: Quán Nhỏ POS — trang quản trị nền tảng `https://quannho.lpm.vn/admin/`
> Ngày lập: 25/10/2026 · Người yêu cầu: Chủ Quán ("giao diện quá xấu, viết thiết kế bàn giao cho Antigravity")
> Phạm vi: **CHỈ GIAO DIỆN** (HTML/CSS/JS hiển thị). Không đổi máy chủ, quyền, đăng nhập, dữ liệu.
> Trạng thái: giao việc. **Không deploy production, không sửa nginx, không push Git** khi chưa có Chủ Quán duyệt.

---

## 1. Mệnh lệnh thực thi

Thiết kế lại toàn bộ giao diện 4 tab của trang quản trị cho **đẹp, rõ thứ bậc thông tin, dễ đọc trên điện thoại và máy tính**,
giữ nguyên mọi chức năng, dữ liệu và các chốt an toàn ở mục 4. Kết quả là 3–5 file tĩnh trong `admin_web/` (+ font tự host).

Trang hiện tại (ảnh Chủ Quán gửi 25/10): nền xanh đen phẳng, 9 thẻ số cùng cỡ cùng màu không có thứ bậc, biểu đồ cột
trống trải không trục/không lưới/không nhãn, nhãn ngày chồng chữ, khoảng trống lớn, ở một số bề rộng nội dung tràn mép phải
(ô "Tính cả quán thử" bị cắt). Chủ Quán dùng chủ yếu **điện thoại** và Chrome trên máy tính.

## 2. Kiến trúc hiện có (đọc trước khi sửa)

| File | Vai trò |
|---|---|
| `admin_web/index.html` | Khung trang: đăng nhập + 4 tab + bảng chi tiết (drawer) + toast. Có thẻ CSP. |
| `admin_web/app.css` | Toàn bộ kiểu (token màu sáng/tối ở `:root`). |
| `admin_web/app.js` | Logic: đăng nhập, gọi RPC, vẽ từng tab. Hàm `el()` tạo phần tử bằng `textContent`. |
| `admin_web/build.sh` | Đóng gói → `build/admin_web/` + sinh `config.js` (địa chỉ + khoá công khai anon). Thêm file mới (font, ảnh) thì **sửa lệnh `cp` trong build.sh**. |
| `admin_web/dev/mock_server.py` | **Máy chủ giả để xem trước** — dữ liệu mẫu đủ mọi tab, không đụng production. |
| `db-fix/trang_quan_tri_v2_ap_dung.sh` | Script áp (bước 3 = đưa trang lên). **Không chạy** — Claude/Chủ Quán áp sau khi duyệt. |

Xem trước trên máy:

```bash
cd quan_nho && bash admin_web/build.sh && python3 admin_web/dev/mock_server.py build/admin_web 8765
# mở http://localhost:8765/admin/  — tên đăng nhập bất kỳ, mật khẩu "dung" (giá trị giả của máy chủ giả)
```

Luồng dữ liệu: đăng nhập `POST /api/auth/admin-jwt {username, password}` → vé quản trị (4 giờ, lưu `sessionStorage`)
→ mọi số liệu qua `POST /supabase/rest/v1/rpc/<tên hàm>` (header `apikey` = anon, `Authorization: Bearer <vé>`).
Lời dặn Boom qua `POST /supabase/functions/v1/boom-chat {mode:'admin_prompt'}`.

## 3. Hợp đồng dữ liệu (KHÔNG đổi — chỉ đổi cách hiển thị)

- `admin_whoami_v1()` → `{ok, user_id, name}`
- `admin_store_overview_v1({p_include_test})` → `{ok, total, test_stores, new_today, new_7d, new_30d, active_7d, active_30d, sleeping, never_sold, new_by_day:[{day, n}]×60, active_by_week:[{week_start, n}]×12}`
- `admin_store_list_v1({p_filter: all|active|sleeping|never|new7|test, p_search, p_include_test, p_limit≤200, p_offset})` → `{ok, total, rows:[{id, name, store_code, plan, status, trial_ends_at, last_active_at, created_at, owner_name, is_test, orders_7d, orders_30d, last_order_at, devices, device_last_seen, staff_owner, staff_manager, staff_other, menu_items}]}` — **không có doanh thu (cố ý, Chủ Quán chốt)**.
- `admin_set_test_store_v1({p_store, p_is_test})` → `{ok}`
- `admin_boom_stats_v1({p_days})` → `{ok, turns, gpt_turns, stores, up, down, unanswered, blocked, errors, cost_usd, reviewed:{dung, chua_dung, sai, teach}, by_tool:{…}}`
- `admin_boom_turns_v1({p_store, p_from, p_to, p_filter: all|unreviewed|down|refused|unanswered|error|wrong|teach, p_search, p_limit, p_offset})` → `{ok, total, rows:[{id, created_at, store_id, source: gpt|app, tool, question, answer_preview(≤400), answer_len, store_name, user_name, log_status, rating, model, verdict, needs_teaching}]}`
- `admin_boom_turn_v1({p_id})` → `{ok, turn:{…, answer, store_name, user_name}, log:{status, model, rating, rating_reason, input_tokens, output_tokens, cost_usd, latency_ms}|null, chunks:[{id, title, module}], review:{verdict, note, needs_teaching}|null}`
- `admin_boom_review_v1({p_id, p_verdict: dung|chua_dung|sai|null, p_note, p_needs_teaching})` → `{ok}`
- `admin_boom_knowledge_v1()` → `{ok, packs:[{version, chunk_count, note, created_at}], chunks:[{id, module, title, uses, ups, downs}], cache:[{id, kind, questions[], answer, status, hits, ups, downs, note, updated_at}], changelog:[{applied_at, version, title, detail, checks}]}`
- `admin_boom_chunk_v1({p_id})` → `{ok, chunk:{id, title, module_name, text}}`
- boom-chat `admin_prompt` → `{model, enabled, cache_on, logic_version, advice_prompt, guide_prompt, refusal:{…}}`
- Lỗi: `{ok:false, error:'FORBIDDEN'}` → về màn đăng nhập; HTTP 401 → hết phiên.

## 4. Chốt an toàn BẮT BUỘC giữ (vi phạm = không duyệt)

1. **Chỉ `textContent` / `createTextNode`** cho mọi chữ lấy từ dữ liệu (câu hỏi của khách, câu trả lời Boom, tên quán…).
   Cấm `innerHTML`, `insertAdjacentHTML`, `outerHTML`, `document.write`, template chèn HTML, thư viện render HTML từ chuỗi.
   Máy chủ giả có câu hỏi chứa `<img src=x onerror=alert(1)>` — phải hiện nguyên như chữ.
2. **Không tải gì từ ngoài:** không CDN, không Google Fonts, không thư viện biểu đồ từ mạng. CSP hiện tại:
   `default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'self'; form-action 'none'; base-uri 'none'`
   (thẻ meta trong `index.html` **và** header nginx). Cấm script/style nội tuyến, cấm thuộc tính `style="…"`, `onclick="…"`.
   - Muốn dùng phông **Plus Jakarta Sans** (phông của app): tự host file từ `test/fonts/PlusJakartaSans-*.ttf`
     (giấy phép OFL kèm `test/fonts/OFL-PlusJakartaSans.txt`, chép cả giấy phép) vào `admin_web/fonts/` (nên đổi sang
     `.woff2`), thêm `font-src 'self'` vào CSP meta, sửa `build.sh` chép thư mục fonts. **Header nginx cũng phải thêm
     `font-src 'self'`** (khối `location ^~ /admin/` trong `/etc/nginx/sites-available/lpm.vn`) — ghi rõ trong báo cáo
     để Claude sửa khi áp (Chủ Quán duyệt); không tự sửa nginx.
   - Biểu đồ: SVG tự vẽ (như hiện tại) hoặc thư viện nhỏ **chép vào repo** (tự host, có giấy phép) — ưu tiên SVG tự vẽ.
3. **Vé đăng nhập** chỉ ở `sessionStorage`; bấm Thoát / hết phiên phải xoá vé VÀ xoá mọi nội dung đã tải khỏi DOM
   (hàm `logout()` hiện tại làm việc này — giữ hành vi).
4. Không lưu dữ liệu quán / hội thoại vào `localStorage`, IndexedDB, cookie. `localStorage` chỉ được dùng cho tuỳ chọn
   hiển thị (sáng/tối, tab gần nhất).
5. Không thêm tính năng ghi dữ liệu mới, không gọi RPC khác danh sách mục 3.
6. Trang `noindex`, `no-referrer` giữ nguyên.

## 5. Định hướng thiết kế

**Nhận diện:** cùng họ với app Quán Nhỏ — cam chủ đạo `#F07A45`, xanh than `#1E2A4A`/`#12152A`, phông Plus Jakarta Sans,
góc bo 12–16px, đổ bóng mềm. Có **cả giao diện sáng và tối** (theo `prefers-color-scheme`, có nút chuyển, nhớ bằng localStorage).
Chữ số dùng `font-variant-numeric: tabular-nums`. Định dạng số Việt Nam (`1.234`), ngày `dd/mm`, giờ `HH:mm`.

**Bố cục:**
- **Máy tính (≥ 1024px):** thanh bên trái (logo "Quán Nhỏ · Quản trị", 4 mục có biểu tượng SVG tự vẽ, tên người đăng nhập +
  Thoát ở đáy); nội dung rộng tối đa ~1280px.
- **Máy tính bảng (600–1023px):** thanh trên gọn, tab cuộn ngang.
- **Điện thoại (< 600px):** thanh điều hướng dưới đáy 4 mục (như app), nội dung một cột, bảng chuyển thành thẻ. Không tràn ngang
  ở 320–430px. Vùng chạm ≥ 44px.

**Tab Tổng quan:**
- Hàng **KPI chính** (thẻ lớn, có màu nhấn): *Đang dùng tích cực* (`active_7d`, kèm tỷ lệ trên tổng quán thật), *Quán mới 7 ngày*,
  *Tổng quán*. Hàng **phụ** nhỏ hơn: mới hôm nay, mới 30 ngày, có đơn 30 ngày, ngủ, chưa bán, quán thử đã loại.
- **Phễu kích hoạt:** Tạo quán (total) → Đã từng bán (total − never_sold) → Còn bán 30 ngày (active_30d) → Tích cực 7 ngày
  (active_7d), có % chuyển đổi từng bước. Đây là chỉ số Chủ Quán cần nhất (130/180 quán chưa bán đơn nào).
- Biểu đồ "Quán mới theo ngày (60 ngày)" và "Quán có đơn theo tuần (12 tuần)": có trục, vạch lưới nhẹ, nhãn ngày thưa
  (mỗi 7–10 ngày), tooltip khi chạm/rê (ngày + số), cột nổi bật cho hôm nay / tuần này, trạng thái rỗng đẹp.
- Công tắc "Tính cả quán thử" dạng switch, không bị cắt.

**Tab Quán:**
- Máy tính: **bảng** có tiêu đề dính, sắp xếp theo cột (đơn 7 ngày, ngày tạo, đơn gần nhất, món menu), cột trạng thái dạng
  nhãn màu (Tích cực xanh / Ngủ vàng / Chưa bán xám / Quán thử đỏ nhạt). Điện thoại: thẻ gọn 2 cột số.
- Thanh lọc (chip) + ô tìm + phân trang (hoặc "Xem thêm"). Hành động mỗi quán: "Xem Boom của quán", "Đánh dấu quán thử"
  (hỏi xác nhận). Bấm tên quán mở bảng chi tiết (dùng lại dữ liệu dòng, không gọi thêm).

**Tab Boom: Hội thoại:**
- Hàng số liệu nhỏ (lượt hỏi, quán dùng, 👍/👎, chưa trả lời được, từ chối, chi phí, đã chấm).
- Danh sách lượt dạng **bong bóng chat thu gọn** (câu hỏi đậm, trả lời 2 dòng mờ), nhãn: loại câu trả lời, nguồn
  (*Qua máy chủ* / *App tự trả*), 👎, điểm của Chủ Quán, "Cần dạy lại".
- Bảng chi tiết (drawer bên phải trên máy tính, toàn màn hình trên điện thoại): hội thoại dạng chat (câu hỏi phải, Boom trái),
  thông số (token, chi phí, thời gian), bài hướng dẫn đã dùng, khu **chấm điểm** 3 nút lớn Đúng / Chưa đúng / Sai + ghi chú
  + "Cần dạy lại" + Lưu. **Phím tắt** khi mở chi tiết: `1/2/3` chọn điểm, `J/K` lượt sau/trước, `S` lưu, `Esc` đóng.

**Tab Boom: Đã dạy:**
- Nhật ký dạy Boom dạng **dòng thời gian** (ngày, phiên bản, tiêu đề, chi tiết, kết quả kiểm tra).
- Bộ hướng dẫn: thẻ tóm tắt bản đang dùng + danh sách module có **thanh mức dùng** (số lần dùng, 👍/👎), mở rộng xem từng đoạn,
  bấm đoạn mở nội dung.
- Bộ nhớ câu trả lời đã duyệt (trạng thái rỗng thân thiện khi trống), bảng năng lực đọc số, nút xem lời dặn đang chạy
  (khối chữ đơn cách, cuộn, nút sao chép).

**Trạng thái chung:** khung xương (skeleton) khi tải, thông báo lỗi có nút "Thử lại", trạng thái rỗng có minh hoạ nhẹ,
toast lưu thành công. Màn đăng nhập: thẻ giữa màn hình, logo, ô "Tên đăng nhập" + "Mật khẩu" (nút hiện/ẩn mật khẩu), báo lỗi
"Tên đăng nhập hoặc mật khẩu không đúng", trạng thái đang đăng nhập.

**Khả năng tiếp cận:** tương phản ≥ 4.5:1, focus rõ, `aria-label` cho nút biểu tượng, bảng có `<th scope>`, drawer có
`role="dialog"` + khoá cuộn nền + trả focus khi đóng.

## 6. Tiêu chí nghiệm thu

1. Chạy máy chủ giả, kiểm 4 tab ở **375×812, 768×1024, 1440×900**, sáng và tối: không tràn ngang, không chữ bị cắt, không lỗi console.
2. Câu hỏi chứa HTML hiện như chữ; grep `admin_web/` không có `innerHTML|insertAdjacentHTML|outerHTML|document.write`.
3. Không có request ra ngoài domain (tab Network chỉ `localhost`). CSP meta còn nguyên (chỉ thêm `font-src 'self'` nếu tự host phông).
4. Đăng nhập sai → báo lỗi; Thoát → về đăng nhập, DOM không còn hội thoại/tên quán.
5. Mọi chức năng cũ còn: lọc, tìm, phân trang, đánh dấu quán thử, xem Boom của quán, chấm điểm + ghi chú + cần dạy lại,
   xem đoạn hướng dẫn, xem lời dặn.
6. `node --check admin_web/app.js` sạch. Kích thước JS + CSS (chưa nén) ≤ ~150 KB, font ≤ 4 file.
7. Ảnh chụp trước/sau 3 kích thước đính kèm báo cáo.

## 7. Quy tắc làm việc

- Chỉ sửa trong `admin_web/` (và `build.sh` nếu thêm font). **Không** sửa `lib/`, `supabase/`, `services/`, `db-fix/`.
- **Không chạy `dart format`** trên thư mục (repo định dạng tay; nhiều test đọc nguyên văn mã nguồn).
- Không deploy, không sửa nginx, không đụng production, không commit/push khi Chủ Quán chưa bảo.
- Không đưa secret, mật khẩu, khoá vào file hay báo cáo (`config.js` do `build.sh` sinh — không chép tay khoá vào repo).
- Xong việc: ghi một mục ngắn vào `nhat_ky.md` (đã làm gì, file nào, ảnh chụp, việc còn chờ: thêm `font-src` vào nginx + áp).
- Báo cáo bằng tiếng Việt, giải thích thuật ngữ kỹ thuật.
