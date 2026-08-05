# 🐘 KẾ HOẠCH GIAO VIỆC CHO ANTIGRAVITY — AI BUM PILOT QUÁN CÂY

> **Ngày lập:** 06/08/2026
>
> **Mục tiêu:** Xây AI Bum read-only chạy thử tại Quán Cây, sau đó mới mở rộng 5–10 quán
>
> **Chiến lược nguồn:** `.docs/Ai_Bum/chien-luoc-chung-cat-mac-mam.md`
>
> **Nguyên tắc thực thi:** Làm từng phase, báo cáo và chờ duyệt trước khi sang phase tiếp theo

---

## 1. BỐI CẢNH ANTIGRAVITY PHẢI ĐỌC TRƯỚC KHI LÀM

Đọc đầy đủ theo đúng thứ tự:

1. `.agents/workflows/qn.md`
2. `.docs/tong-quan.md`
3. `.docs/kien-truc.md`
4. `.docs/kien-truc-data.md`
5. `.docs/tinh-nang.md`
6. `.docs/lam-viec.md`
7. `nhat_ky.md` — ưu tiên mục mới nhất
8. Toàn bộ `.docs/Ai_Bum/`

Sau khi đọc, Antigravity phải báo cáo ngắn:

- Hiểu Bum là ai và phục vụ ai.
- Trạng thái hiện tại của UI Bum.
- Nguồn sự thật dữ liệu và cơ chế phân quyền.
- Các rủi ro hoặc điểm chưa rõ cần xác nhận.

Không viết code trước khi hoàn thành báo cáo này.

---

## 2. HIỆN TRẠNG ĐÃ XÁC NHẬN

- Nút Bum hiện gọi `_BumComingSoonSheet` trong `lib/main.dart`; chưa có màn chat thật.
- Chưa có implementation `features/ai_assistant/` trong `lib/`.
- Session hiện nằm tại `lib/core/providers/session_provider.dart`.
- Quyền hành động nằm tại `lib/core/providers/permission_provider.dart` và phải fail-closed.
- Audit logging dùng `lib/core/utils/app_logger.dart`.
- Supabase là nguồn dữ liệu business chính.
- Worktree hiện có nhiều thay đổi QR Order và Bill Printer chưa commit.

### Cảnh báo phạm vi

Antigravity không được sửa, format hoặc refactor các phần QR Order, Bill Printer, Bàn, POS hoặc Settings nếu việc đó không trực tiếp cần cho điểm vào Bum. Không được xóa hoặc ghi đè thay đổi đang có của người khác.

Không commit, push, deploy production hoặc chạy migration production nếu chưa được chủ dự án yêu cầu rõ ràng.

---

## 3. KIẾN TRÚC MỤC TIÊU V1

```text
Flutter Bum Chat
    ↓
AI Gateway có xác thực
    ↓
Classification
    ├── SQL/RPC read-only: số liệu thật
    ├── FAQ/RAG: hướng dẫn Quán Nhỏ
    ├── Qwen3-4B local: diễn giải và phân tích
    └── OpenAI fallback: chỉ câu mới/khó
    ↓
Response Validator
    ↓
Flutter hiển thị câu trả lời + nguồn + nút 👍/👎
```

### Quy tắc kỹ thuật

- Model không truy cập Supabase trực tiếp.
- Model không được nhận service-role key, anon key không cần thiết, PIN hoặc token đăng nhập.
- Mọi truy vấn business phải đi qua tool/RPC được allow-list.
- Mọi RPC phải kiểm tra `store_id` và quyền phía server; không chỉ tin header do Flutter gửi.
- Số liệu do SQL/RPC tính; model chỉ diễn giải.
- V1 chỉ read-only, không tạo/sửa/xóa business data.
- Khi confidence thấp, hỏi lại hoặc fallback; không đoán.
- Cloud fallback chỉ nhận dữ liệu tối thiểu đã loại PII.

---

## 4. PHÂN PHASE GIAO VIỆC

## PHASE 0 — AUDIT & THIẾT KẾ CHI TIẾT

### Mục tiêu

Chốt đường xác thực an toàn và thiết kế kỹ thuật trước khi viết tính năng.

### Việc cần làm

1. Trace toàn bộ luồng đăng nhập từ `UserAuthService` đến `sessionProvider` và Supabase headers.
2. Chứng minh bằng mã nguồn/RLS rằng client có hoặc không thể giả `x-user-id` và `x-store-id`.
3. Đề xuất cơ chế AI Gateway xác minh phiên đăng nhập; không được tin giá trị store/user từ body request.
4. Liệt kê chính xác bảng và cột cần cho 10 câu hỏi pilot Quán Cây.
5. Đề xuất API contract cho:
   - `POST /v1/bum/chat`
   - `POST /v1/bum/feedback`
   - `GET /health`
6. Đề xuất cấu trúc thư mục Flutter và gateway; chưa tạo code.
7. Đề xuất dependency tối thiểu, giải thích lý do từng dependency.
8. Lập threat model: giả store, prompt injection, PII leak, service key leak, replay, spam và chi phí cloud.

### Đầu ra bắt buộc

- Báo cáo audit bằng Markdown.
- Sơ đồ sequence request/response.
- API schema mẫu.
- Danh sách migration dự kiến.
- Danh sách quyết định cần chủ dự án duyệt.

### Điểm dừng

Dừng và chờ duyệt. Không sang Phase 1 nếu xác thực server-side chưa được chốt.

---

## PHASE 1 — UI CHAT BUM VỚI MOCK DATA

### Mục tiêu

Thay bottom sheet “Coming Soon” bằng giao diện chat thật nhưng chưa gọi AI/backend.

### Phạm vi file dự kiến

```text
lib/features/ai_assistant/
  models/
    bum_message.dart
  providers/
    bum_chat_provider.dart
  screens/
    bum_chat_sheet.dart
  widgets/
    bum_message_bubble.dart
    bum_suggestion_chips.dart
    bum_typing_indicator.dart
```

Chỉnh tối thiểu `lib/main.dart` để `_showBumSheet()` mở `BumChatSheet`.

### Yêu cầu UI

- Mobile `< 600px` và Tablet/PC `>= 600px` theo quy chuẩn hiện tại.
- Font Outfit, Navy `#1C2151`, Cam `#FF6B35`, nền Kem `#FFF8F0`.
- Có trạng thái empty, loading, streaming giả lập, error và retry.
- Suggestion chip ban đầu:
  - Hôm nay bán được bao nhiêu?
  - Món nào bán chạy nhất?
  - Kho có gì sắp hết?
  - Hôm nay ai đang làm?
- Nút gửi đủ lớn cho cảm ứng.
- Không log toàn bộ nội dung chat vào `AppLogger`.

### Test/nghiệm thu

- Widget test mở/đóng sheet, gửi câu, loading, retry.
- `flutter analyze` không có error mới.
- `git diff --check` sạch.
- Không đụng logic QR/Printer/POS ngoài điểm mở sheet.

### Điểm dừng

Chụp màn hình Mobile và Desktop/Tablet, báo danh sách file thay đổi rồi chờ duyệt.

---

## PHASE 2 — DATABASE & READ-ONLY TOOLS

### Mục tiêu

Tạo lớp dữ liệu an toàn cho 10 câu hỏi pilot, chưa kết nối model.

### Tool/RPC pilot

1. `get_today_sales_summary`
2. `compare_sales_periods`
3. `get_top_products`
4. `get_slow_products`
5. `get_low_stock_items`
6. `get_stock_forecast_inputs`
7. `get_finance_summary`
8. `get_staff_on_shift`
9. `get_pending_operations_tasks`
10. `get_store_context_for_bum`

Tên RPC cuối cùng có thể thay đổi sau audit, nhưng mỗi RPC phải:

- Chỉ trả trường cần thiết.
- Cô lập theo cửa hàng phía database/server.
- Kiểm tra quyền Owner/Manager/Staff.
- Không nhận `store_id` tùy ý mà không xác minh membership.
- Không trả SĐT, PIN, ảnh selfie, GPS hoặc token.
- Có giới hạn thời gian/khoảng ngày để chống truy vấn quá lớn.
- Có test SQL cho đúng quán, sai quán và user không đủ quyền.

### Bảng AI tối thiểu dự kiến

- `bum_conversations`
- `bum_messages`
- `bum_feedback`
- `bum_memories`

Chỉ tạo bảng thật sau khi schema và RLS được duyệt. Không lưu chain-of-thought. Nội dung chat phải có retention policy và cơ chế xóa.

### Điểm dừng

Giao migration, rollback và test script. Không chạy production.

---

## PHASE 3 — CLASSIFICATION V1

### Mục tiêu

Phân loại câu hỏi bằng rules + semantic matching, chưa cần train classifier riêng.

### Intent ban đầu

```text
revenue_summary
sales_comparison
top_products
slow_products
low_stock
purchase_forecast
finance_summary
staff_on_shift
attendance_summary
payroll_help
pending_tasks
app_help
business_advice
remember_store_fact
recall_store_fact
smalltalk
unknown
```

### Output schema

```json
{
  "domain": "sales",
  "intent": "revenue_summary",
  "confidence": 0.98,
  "entities": {
    "time_range": "today"
  },
  "requires_live_data": true,
  "tool": "get_today_sales_summary",
  "needs_clarification": false
}
```

### Quy tắc route ban đầu

- Confidence `>= 0.85`: gọi RPC/RAG/FAQ tương ứng.
- `0.65–0.84`: semantic search/Qwen hoặc hỏi lại.
- `< 0.65`: `unknown`, không tự đoán.

Các ngưỡng là config để điều chỉnh sau log thật.

### Test/nghiệm thu

- Tối thiểu 20 cách diễn đạt cho mỗi intent quan trọng.
- Có câu tiếng Việt đời thường, viết tắt và sai chính tả.
- Không dùng test set làm rules mẫu trực tiếp.
- Báo confusion matrix, accuracy theo intent và tỷ lệ `unknown`.
- Mục tiêu đầu: macro-F1 `>= 0.90` trên tập pilot đã duyệt.

---

## PHASE 4 — RAG/FAQ QUÁN NHỎ

### Mục tiêu

Cho Bum tra đúng tài liệu `.docs/Ai_Bum/` và các hướng dẫn module hiện hành.

### Yêu cầu

- Chunk theo heading/module, không cắt cơ học giữa một quy trình.
- Mỗi chunk có `source_path`, `heading`, `updated_at`, `module` và checksum.
- Re-index khi checksum thay đổi.
- Câu trả lời hướng dẫn phải kèm nguồn tài liệu nội bộ.
- Không đưa secret hoặc thông tin kết nối nhạy cảm trong tài liệu vào index.
- Khi không tìm thấy nguồn đủ tin cậy, trả `not_found`; không bịa.

### Điểm dừng

Demo ít nhất 30 câu hỏi hướng dẫn từ nhiều module và báo precision@k.

---

## PHASE 5 — QWEN3-4B LOCAL TRÊN SERVER

### Mục tiêu

Chạy baseline Qwen3-4B 4-bit bằng RTX 2060 và expose endpoint chỉ trong mạng nội bộ của AI Gateway.

### Việc cần làm

1. Chạy `nvidia-smi`, xác nhận VRAM, driver và CUDA.
2. Benchmark model nguyên bản trước khi fine-tune.
3. Thử context 4K, 8K và 16K; không mặc định context cực lớn.
4. Đo:
   - thời gian load model;
   - VRAM/RAM;
   - time-to-first-token;
   - token/giây;
   - tải 1/2/4 request đồng thời;
   - lỗi OOM và thời gian phục hồi.
5. Gateway chỉ gửi context đã lọc và kết quả tool; model không tự gọi database.
6. Response validator phải kiểm tra JSON/tool schema và ngăn model tự thêm số liệu không có trong tool result.

### Điểm dừng

Giao báo cáo benchmark. Chỉ chốt engine/model/context sau khi có số đo thật.

---

## PHASE 6 — OPENAI FALLBACK

### Mục tiêu

Chỉ chuyển câu mới/khó lên OpenAI khi local route không giải quyết được.

### Yêu cầu

- API key chỉ lưu trong secret/env của gateway.
- Không commit `.env` hoặc log API key.
- PII redaction trước khi gửi.
- Prompt composer dùng cấu trúc cố định: role, intent, dữ liệu được phép, nguồn RAG, câu hỏi, output schema.
- Có timeout, retry giới hạn, circuit breaker, rate limit và ngân sách theo quán.
- Ghi usage token/chi phí nhưng không ghi secret hoặc chain-of-thought.
- Không dùng output OpenAI tự động làm dataset Qwen.
- Khi cloud lỗi, Bum báo rõ và vẫn giữ được các chức năng RPC/RAG local.

### Test/nghiệm thu

- Unit test PII redaction.
- Test API timeout, 429, 5xx và mất mạng.
- Test prompt injection yêu cầu lấy dữ liệu quán khác.
- Test ngân sách và rate limit.

---

## PHASE 7 — FEEDBACK, MEMORY & LEARNING QUEUE

### Mục tiêu

Tạo vòng lặp giúp Bum tốt lên nhưng không tự học bừa.

### Luồng

```text
Khách đánh giá 👍/👎
    ↓
Lưu route, intent, nguồn và lỗi đã ẩn PII
    ↓
Hàng chờ kiểm duyệt
    ├── Memory riêng của quán
    ├── FAQ/RAG dùng chung
    ├── Intent example mới
    ├── Tool/RPC còn thiếu
    └── Dataset QLoRA do con người duyệt
```

### Quy tắc

- Memory bắt buộc có `store_id`, category, source và trạng thái xác nhận.
- Không cho Staff tạo memory cấp toàn quán nếu không có quyền.
- Cho Owner xem, sửa và xóa memory của quán.
- Không tự đưa câu trả lời cloud/local vào training.
- Có retention và xóa hội thoại theo yêu cầu.

---

## PHASE 8 — DATASET & QLORA BUM V1

### Mục tiêu

Fine-tune Qwen3-4B sau khi kiến trúc data/tool đã ổn định.

### Trình tự

1. Tạo gold set 500–800 mẫu độc lập.
2. Tạo dataset v1 4.000–8.000 mẫu đã kiểm duyệt.
3. Pilot QLoRA 500–1.000 mẫu trên Mac M3 Pro 18 GB.
4. Đo RAM, tốc độ, loss và chất lượng; không hứa thời gian trước benchmark.
5. Chỉ train toàn bộ khi pilot tốt hơn baseline.
6. So sánh:
   - Qwen nguyên bản;
   - Qwen + Classification/RAG/tools;
   - Qwen fine-tune;
   - Cloud fallback.
7. Version model, adapter, dataset, config và eval report.
8. Có rollback về model cũ.

### Không được làm

- Không dùng dữ liệu thật chưa ẩn danh.
- Không dùng output OpenAI hàng loạt làm nhãn cho model local.
- Không train bằng test/gold set.
- Không deploy model chỉ vì loss giảm; phải vượt eval nghiệp vụ và bảo mật.

---

## PHASE 9 — SHADOW TEST QUÁN CÂY

### Mục tiêu

Chạy Bum bằng dữ liệu thật nhưng giới hạn Owner và read-only.

### Cách rollout

1. Feature flag chỉ bật cho Quán Cây và tài khoản Owner được chỉ định.
2. Tuần đầu shadow mode: lưu câu trả lời để đánh giá, chưa chủ động gửi cảnh báo.
3. Sau khi đạt chất lượng mới bật chat trực tiếp.
4. Theo dõi hằng ngày:
   - intent và confidence;
   - route local/RPC/RAG/cloud;
   - latency;
   - token/chi phí;
   - 👍/👎;
   - lỗi dữ liệu/quyền;
   - tỷ lệ hallucination.
5. Chạy ổn định 30 ngày trước khi mời quán thứ hai.

### Tiêu chí đạt

- 0 trường hợp lộ chéo `store_id`.
- 0 trường hợp Staff xem dữ liệu vượt quyền.
- Tool/JSON hợp lệ `>= 99%`.
- Số liệu RPC chính xác `>= 99%`.
- Câu trả lời bám nguồn `>= 95%`.
- Chủ quán đánh giá trung bình `>= 4/5`.
- Các câu tài chính/lương không được bịa số liệu.

---

## 5. THỨ TỰ ƯU TIÊN

```text
P0: Xác thực, store isolation, read-only RPC
P1: UI chat, Classification, RAG/FAQ
P2: Qwen local và benchmark RTX 2060
P3: OpenAI fallback có kiểm soát
P4: Feedback, memory, dataset
P5: QLoRA và mở rộng 5–10 quán
```

Không đảo thứ tự để fine-tune trước khi tool/RPC, bảo mật và gold set hoàn chỉnh.

---

## 6. QUY CHUẨN BÁO CÁO SAU MỖI PHASE

Antigravity phải báo:

1. Đã làm gì.
2. File nào đã thay đổi.
3. Migration nào đã tạo/chạy và chạy ở môi trường nào.
4. Test nào đã chạy, kết quả cụ thể.
5. Screenshot/benchmark nếu phase yêu cầu.
6. Rủi ro còn lại.
7. Đề xuất phase tiếp theo.

Sau đó dừng chờ chủ dự án duyệt.

---

## 7. PROMPT KHỞI ĐỘNG GỬI CHO ANTIGRAVITY

```text
Bạn đang làm dự án Quán Nhỏ POS tại:
/Users/banhbao/Quan Nho/quan_nho

Hãy đọc và tuân thủ tuyệt đối:
1. .agents/workflows/qn.md
2. toàn bộ context được workflow yêu cầu
3. toàn bộ .docs/Ai_Bum/
4. .docs/Ai_Bum/ke-hoach-giao-viec-antigravity.md

Nhiệm vụ hiện tại chỉ là PHASE 0 — AUDIT & THIẾT KẾ CHI TIẾT.
Không viết code, không chạy migration, không deploy, không commit/push.

Đặc biệt:
- Worktree đang có thay đổi QR Order, Bill Printer và các phần khác của người dùng.
- Không sửa, format, xóa hoặc ghi đè các thay đổi đó.
- AI Bum v1 là read-only, chạy thử tại Quán Cây.
- Qwen3-4B local là model chính; OpenAI chỉ fallback.
- Classification + RPC/RAG phải xử lý câu quen thuộc trước khi gọi model/cloud.
- Không được tin store_id/user_id do client tự gửi nếu chưa xác minh phía server.

Hãy hoàn thành đúng đầu ra của Phase 0, nêu bằng chứng theo file/line,
đưa ra các lựa chọn kỹ thuật và dừng chờ duyệt trước Phase 1.
```
