# Thiết kế: Boom tự lấy số liệu trên máy chủ (hướng 1, bản sửa sau đo thử) — 03/11/2026

## Vì sao

Hỏi Boom thật trên web (quán KAY-Rạch Giá, 03/11) cho thấy câu nào số liệu tới được Boom thì trả lời đúng bài; gần một nửa câu
hỏng vì **app** chọn sai đường trước khi tới Boom:

| Câu thật | App làm gì | Kết quả |
|---|---|---|
| "tháng trước cuối tuần với ngày thường khác nhau nhiều không" | coi là hỏi cách dùng app | chỉ cách bấm "Đổi ngày" |
| "tháng trước … dư ít hơn tháng 9 không" | lấy kỳ theo chữ "tháng 9" | so nhầm tháng 9 với tháng 8 |
| "tháng trước so với tháng 9 món nào giảm nhiều nhất" | trả mẫu tại chỗ (revenue_summary) | chỉ nêu tổng doanh thu |
| "tháng trước buổi chiều quán vắng quá, có cách nào" | gửi tư vấn KHÔNG kèm số | danh sách chung chung |

Việc chọn đường nằm trong ~1.500 dòng Dart (IntentClassifier, `_wantsAdvice`, `_moduleTopicSrc`, `boomHelpWins`…), mỗi lần sửa
phải chờ bản app qua duyệt Apple / Google. Dạy Boom ở máy chủ không chữa được loại lỗi này.

## Đo thử trước khi chọn (03/11)

| Thử | Kết quả |
|---|---|
| Bộ định tuyến gpt-4o-mini (JSON: loại câu, kỳ, mục) trên 30 câu (16 câu hỏi thật + câu khó) | **đúng 15/30**: ghi nhầm năm 2023 ở 9 câu; xếp 8 câu cần số quán ("buổi chiều vắng có cách nào", "GIAM15 có hiệu quả không", "do uong ban it qua") vào "tư vấn chung" → sẽ không lấy số; chậm thêm ~2,4 giây / câu |
| Cỡ khối số nếu gửi đủ bán hàng + 5 mục (3 quán mẫu) | bán hàng ~7.000 ký tự, 5 mục ~4.000 ký tự (~1.500 token) trên nền ~13.000 token / câu → thêm < 0,0003 USD / câu |

→ **Không dùng bộ định tuyến GPT.** Hai việc nó làm đều làm tốt hơn bằng cách khác:
- kỳ → **bộ đọc ngày bằng luật** (0 ms, đúng, test được);
- mục → **không chọn nữa, gửi đủ mọi mục người hỏi được xem**. Lỗi "thiếu số" (loại lỗi lớn nhất hôm nay) biến mất vì không còn bước chọn.

## Luồng mới

App gửi **câu hỏi + lịch sử** lên máy chủ. Máy chủ tự đọc số bằng quyền của chính người hỏi rồi dùng lại toàn bộ phần đã dạy
(formatFacts / formatModules, dòng tính sẵn lần 1–103, kiểm câu trả lời). Sửa về sau chỉ cần áp máy chủ.

```
app ──(mode 'ask': store_id, question, history)──▶ boom-chat
   1. Luật cứng (0 ms): chào hỏi / cảm ơn → trả ngắn; hỏi quán khác → từ chối; "cách / bấm / cài đặt…" rõ ràng → bài hướng dẫn
   2. Đọc kỳ bằng luật (0 ms): kỳ chính + kỳ so; câu không nói kỳ → tháng này (tháng này < 7 ngày → thêm tháng trước làm mốc)
   3. Kiểm quyền vai trò → đọc ĐỦ số được xem, song song, đệm theo (quán, kỳ)              (~0,3–1 giây; lần đệm ~0)
   4. formatFacts + formatModules + dòng tính sẵn → gpt-4o-mini trả lời → kiemTraLoi          (không thêm lần gọi GPT nào)
```

### 1. Đọc kỳ bằng luật

- Chép `IntentClassifier.timeRangeIn` / `boomRangeOf` (Dart) sang TS, tính theo **Asia/Ho_Chi_Minh** (Deno chạy UTC), sửa lỗi đã thấy:
  "tháng trước … ít hơn / so với tháng 9" → kỳ chính tháng 10, **kỳ so** tháng 9.
- Bộ test = 30 câu đo thử + câu trong bộ đề; nhãn kỳ ra đúng dạng app ("Tháng trước (tháng 10)"…) để `soNgay` và dòng tính sẵn chạy.
- Không còn bước "câu này có cần số không": mọi câu không rơi vào luật cứng ở bước 1 đều nhận đủ số (câu "20/11 nên làm gì" cũng
  thấy số bán của quán — có lợi).

### 2. Quyền

- Máy chủ đang kiểm JWT + thành viên quán (`callerId`, `isMember`); RLS chỉ chặn theo quán, **không** theo vai trò → nhân viên thường
  vẫn đọc được bảng tiền qua API. Máy chủ phải chép đúng `resolveBoomPerms` + `boomModuleAccess` (đọc `store_members`, `app_settings`
  `module_config_v2` / `perm_<role>`, `store_roles`, `staff_members.modules`) sang TypeScript, test đối chiếu từng vai trò với bản Dart.
- Mục không có quyền / module đang tắt → không đọc, ghi "người hỏi chưa xem được X (mục tắt / chưa có quyền)" vào khối số.
- Đọc số bằng **JWT người hỏi + anon key** (không dùng service key) → RLS vẫn là hàng rào cuối.

### 3. Đọc số — nhanh

- Mọi mục đọc **song song**; đệm theo (quán, kỳ) trong bộ nhớ hàm: kỳ đang chạy 10 phút, kỳ đã qua ("tháng trước") 6 giờ → hỏi tiếp
  cùng kỳ gần như tức thì. Mục lỗi / quá 3 giây → bỏ mục đó, ghi "chưa đọc được X", vẫn trả lời.

| Mục | Cách đọc trên máy chủ |
|---|---|
| bán hàng (facts) | **RPC mới `boom_sales_facts_v1(p_store, p_from, p_to, p_prev_from, p_prev_to)`** `SECURITY INVOKER`: tổng hợp trong Postgres theo giờ VN — doanh thu, đơn, by_hour, by_weekday, nhóm, top / slow, moves, by_band, kỳ trước. Thay việc app tải toàn bộ `order_items` (tới 100k dòng). Trả đúng dạng `parseFacts` đang nhận. |
| thu chi, kho, nhân sự, khách, khuyến mãi | Chép truy vấn PostgREST trong `boom_module_data_service.dart` sang TS (đã là PostgREST sẵn). Trả đúng dạng `parseModules`. |
| chuỗi | Giữ đường cũ ở giai đoạn này. |

Bẫy đã biết: `user_accounts`, `pos_coupon_redemptions` có thể bị RLS chặn → kiểm policy trước; RPC cần chỉ mục `orders(store_id, created_at)`.

### 4. App / web

- Cờ `boom_server_route` (bật cho web trước). Bật → app chỉ còn tự xử lý: câu chào, nút gợi ý bài hướng dẫn; mọi câu khác đi `mode 'ask'`.
  Máy chủ lỗi / hết giờ → app chạy đường cũ (không mất câu trả lời).
- Thời gian chờ `ask` 30 giây.

## Các bước làm (mỗi bước dừng hỏi Chủ Quán trước khi áp)

0. **Đã đo 03/11 — "gửi đủ mục" không làm Boom kém đi.** Chấm kín 60 câu bộ đề (1 lượt / bản, 3 người chấm Claude):
   - Chung: mục liên quan 12,50 → đủ mục 12,45 /16 (19 câu hơn, 21 kém, 20 bằng — trong mức dao động).
   - Câu app hiện **không gửi số** (5 câu: D13, D23, D30, D55, D60): 9,2 → **11,6** — đúng loại lỗi thấy khi hỏi thật.
   - Câu chỉ hỏi bán hàng (35): 12,80 → 12,66. Câu chỉ hỏi mục (thu chi, kho…, 20): 12,80 → 12,30 — đôi khi lẫn số
     (D15 gán 9% tổng giảm cho riêng GIAM15). Theo dõi; nếu hỏi thật thấy lẫn → câu hỏi rõ một mục thì gửi bán hàng dạng rút gọn.
   - Token vào +20% (~2.100 token / câu). Kết quả: `cham_tu_van/ket_qua/b10_du_muc_claude_20261103.json`.
1. **Máy chủ — đọc kỳ bằng luật + quyền + đọc 5 mục + đệm** — **đã áp 03/11** (cùng 1.2, `db-fix/boom_ask_ap_dung.sh`, TS 20261103_032245):
   `ky.ts` (30 câu thật đúng hết), `lay_so.ts` (quyền 10 vai trò + 5 mục, đọc bằng vé người hỏi), `hoi.ts` (đệm), `index.ts` mode `'ask'`.
   Script áp kiểm `index.ts` trên máy chủ = bản commit chặng 1 (lần sau đổi mốc 168db4d → commit này).
2. **DB — `boom_sales_raw_v1`** (migration `20261103_boom_sales_raw_v1.sql` + ROLLBACK) — **đã áp 03/11**. Hàm trả số thô
   (doanh thu, đơn, theo giờ / thứ / món / khung giờ); `ban_hang.ts` dựng gói facts y như app. Đối chiếu quán KAY-Rạch Giá tháng 10:
   487.883.810đ / 3.366 đơn, tháng 9 436.064.400đ, cơm sườn miếng 849 phần — khớp app; ~1 giây lần đầu, ~0,1 giây sau.
3. **Web — bật cờ, build, đưa lên `quannho.lpm.vn/pos`**. Hỏi thật lại các câu 03/11 trên Chrome; so với kết quả cũ.
4. Ổn 1–2 tuần trên web → bật cho app (bản app sau), rồi mới xoá dần phần chọn đường trong Dart.

## Rủi ro

- Lộ số cho nhân viên không có quyền nếu chép sai luật quyền → test từng vai trò; RLS vẫn chặn khác quán.
- Gửi đủ mục có thể làm GPT lan man sang mục không hỏi → bước 0 đo trước; khối đã có "ĐIỂM CẦN CHÚ Ý — nêu điểm liên quan câu hỏi".
- Đọc kỳ bằng luật vẫn có câu lạ không hiểu → mặc định tháng này + ghi câu vào log để bổ sung luật (sửa ở máy chủ).
- Không thêm lần gọi GPT nào; máy không còn tải tới 100k dòng → nhanh hơn đường cũ, nhất là trên điện thoại yếu.
