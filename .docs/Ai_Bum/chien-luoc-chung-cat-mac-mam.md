# 🧠 CHIẾN LƯỢC AI BUM LOCAL & CHƯNG CẤT THEO DỮ LIỆU THỰC TẾ

> **Ứng dụng:** Quán Nhỏ POS (`quannho.lpm.vn/pos`)
>
> **Phạm vi đầu tiên:** Quán Cây → 5 quán thử nghiệm → 10 quán thử nghiệm
>
> **Cập nhật:** 06/08/2026
>
> **Trạng thái:** Kế hoạch đã thống nhất, triển khai theo từng giai đoạn và đo bằng dữ liệu thật

---

## 🎯 1. ĐỊNH VỊ CHÍNH THỨC CỦA AI BUM

AI Bum **không phải chatbot order cho khách hàng**. Bum là **thư ký và cố vấn vận hành dành cho chủ quán F&B**, được tích hợp trực tiếp trong Quán Nhỏ POS.

### Bốn trụ cột năng lực

1. **Phân tích POS:** Doanh thu, lợi nhuận, số đơn, món bán chạy/chậm và giờ cao/thấp điểm.
2. **Kho và nhập hàng:** Cảnh báo sắp hết, dự báo lượng cần nhập dựa trên dữ liệu bán thực tế.
3. **Kinh doanh và marketing:** Đề xuất combo, giá bán, chương trình kích cầu và nội dung quảng bá.
4. **Thư ký chủ động:** Bản tin sáng, cảnh báo quan trọng và tổng kết cuối ngày nhưng không spam.

### Nguyên tắc bất biến

- Bum không tự nghĩ ra doanh thu, tồn kho, lương hoặc số liệu vận hành.
- Mọi số liệu phải được tính bằng SQL/RPC từ Supabase; AI chỉ diễn giải và tư vấn.
- Bum chỉ được đọc dữ liệu đúng `store_id`, module và quyền của người đang hỏi.
- Giai đoạn đầu chỉ **đọc và tư vấn**; chưa tự động tạo, sửa hoặc xóa dữ liệu.
- Hành động thay đổi dữ liệu trong tương lai phải được người dùng xác nhận và ghi `AppLogger.logUserAction(...)`.

---

## 🧩 2. KIẾN TRÚC HYBRID: CLASSIFICATION → RPC/RAG → LOCAL AI → CLOUD FALLBACK

```text
Khách hỏi Bum
    ↓
Kiểm tra phiên đăng nhập, store_id và quyền dữ liệu
    ↓
Ẩn dữ liệu cá nhân không cần thiết
    ↓
Intent Classification
    ├── Câu hỏi số liệu       → RPC/SQL Supabase
    ├── Hướng dẫn sử dụng     → RAG tài liệu AI Bum
    ├── Câu hỏi quen thuộc    → FAQ đã kiểm duyệt
    ├── Phân tích nghiệp vụ   → Qwen3-4B Bum local
    └── Không hiểu/câu quá khó → OpenAI API fallback
    ↓
Kiểm tra số liệu, quyền và định dạng câu trả lời
    ↓
Hiển thị trong Quán Nhỏ POS
    ↓
Thu thập đánh giá 👍/👎 và đưa lỗi vào hàng chờ kiểm duyệt
```

### Vai trò của Classification

Classification chỉ xác định **người dùng đang muốn làm gì**, không tự tạo số liệu và không phải kho câu trả lời.

Các intent đầu tiên:

| Domain | Intent tiêu biểu |
|---|---|
| Bán hàng | `revenue_summary`, `sales_comparison`, `top_products`, `slow_products` |
| Kho | `low_stock`, `out_of_stock`, `purchase_forecast` |
| Thu chi | `finance_summary`, `expense_anomaly`, `profit_summary` |
| Nhân sự | `staff_on_shift`, `attendance_summary`, `payroll_help` |
| Vận hành | `pending_tasks`, `shift_progress`, `operations_alert` |
| Hướng dẫn | `app_help`, `module_help`, `permission_help` |
| Tư vấn | `business_advice`, `combo_recommendation`, `marketing_copy` |
| Trí nhớ | `remember_store_fact`, `recall_store_fact` |
| Chung | `smalltalk`, `unknown` |

Classification đồng thời trích xuất `time_range`, tên món, tên nhân viên, chỉ số cần xem, quyền người hỏi, nhu cầu dữ liệu realtime và công cụ cần gọi.

### Cách triển khai Classification ban đầu

1. **Rules:** Từ khóa, mốc thời gian, tên module và các mẫu câu phổ biến.
2. **Semantic matching:** So ý nghĩa câu mới với các intent mẫu; không yêu cầu câu chữ giống hệt.
3. **Qwen3-4B:** Phân loại các câu còn mơ hồ.
4. **OpenAI fallback:** Chỉ dùng khi hệ thống local vẫn không hiểu hoặc cần suy luận phức tạp.

Ngưỡng confidence ban đầu để thử nghiệm:

- `>= 0.85`: gọi thẳng RPC/RAG/FAQ phù hợp.
- `0.65–0.84`: semantic search, Qwen local hoặc hỏi lại để làm rõ.
- `< 0.65`: chuyển fallback có kiểm soát; không được tự đoán.

Các ngưỡng này phải được điều chỉnh sau khi có log thật tại Quán Cây.

---

## 🧠 3. MÔ HÌNH AI VÀ PHÂN CHIA TRÁCH NHIỆM

### Model chính: Qwen3-4B-Instruct 4-bit

Qwen3-4B là nền tảng đầu tiên của Bum vì có kích thước phù hợp, hỗ trợ tiếng Việt, tool calling, structured output, có thể chạy local và có thể fine-tune bằng LoRA/QLoRA.

```text
Qwen3-4B nguyên bản
    + Tính cách Bum
    + Dataset nghiệp vụ F&B/Quán Nhỏ đã kiểm duyệt
    + Tool calling và Classification
    + RAG tài liệu mới nhất
    = AI Bum Local v1
```

Chỉ thử Qwen 8B sau khi bản 4B đã vượt bộ kiểm thử nhưng chưa đạt chất lượng tư vấn mong muốn.

### OpenAI API: fallback, không phải bộ nhớ của Bum

OpenAI API chỉ được dùng cho câu mới, khó hoặc cần suy luận mạnh hơn model local. Trước khi gửi request:

- Chỉ gửi dữ liệu tối thiểu cần cho câu hỏi.
- Loại bỏ SĐT, ảnh, GPS, token, PIN và thông tin cá nhân không liên quan.
- Không gửi toàn bộ database hoặc toàn bộ lịch sử quán.
- API key chỉ nằm trên AI Gateway; không nhúng trong Flutter.
- Tắt chia sẻ dữ liệu huấn luyện và cấu hình lưu trữ phù hợp với chính sách hiện hành.

Không dùng hàng loạt output của OpenAI để chưng cất model local cạnh tranh. Dataset Qwen chỉ nhận câu trả lời do con người viết, sửa hoặc xác nhận có đủ quyền sử dụng.

### Ba cách Bum “học”

1. **Memory:** Nhớ thông tin riêng của từng quán ngay sau khi chủ quán xác nhận.
2. **RAG/FAQ:** Học kiến thức mới sau khi tài liệu hoặc câu trả lời chuẩn được duyệt; không cần train lại.
3. **QLoRA định kỳ:** Cập nhật kỹ năng, giọng điệu và tool calling sau khi tích lũy đủ mẫu chất lượng.

Bum không được tự huấn luyện trực tiếp từ mọi cuộc trò chuyện vì có nguy cơ học câu trả lời sai, dữ liệu độc hại hoặc thông tin riêng của một quán.

---

## 🖥️ 4. HẠ TẦNG PHẦN CỨNG HIỆN CÓ

| Thiết bị | Cấu hình hiện có | Vai trò |
|---|---|---|
| MacBook Pro 14" 2023 | M3 Pro, RAM 18 GB | Chuẩn bị dataset, QLoRA bằng MLX, đánh giá checkpoint, quantize và thử nghiệm model |
| Server local | Dual Xeon, RAM 136 GB, RTX 2060 | AI Gateway 24/7, Classification, RAG, RPC, lưu log, hàng đợi và inference Qwen local |

### RTX 2060

Cần chạy `nvidia-smi` để xác nhận card là bản 6 GB hay 12 GB VRAM.

- **6 GB:** Ưu tiên Qwen3-4B Q4; Qwen 8B cần giảm context hoặc offload một phần sang CPU.
- **12 GB:** Qwen3-4B chạy thoải mái hơn; có thể thử inference 8B và QLoRA 4B bằng CUDA.

RAM 136 GB đủ cho model, cache, RAG và CPU offload. Tốc độ thực tế phụ thuộc chính xác model CPU, VRAM, context và số người hỏi đồng thời; phải benchmark trước khi cam kết tải.

### Chưa mua thêm phần cứng

Không mua Mac mới hoặc GPU NVIDIA chuyên nghiệp trong giai đoạn Quán Cây và pilot 5–10 quán. Chỉ đầu tư sau khi:

- AI Bum đã chạy ổn định và được người dùng đánh giá tốt.
- Có dữ liệu tải thực tế chứng minh server hiện tại không đáp ứng.
- Doanh thu thuê bao đủ tài trợ cho hạ tầng mới.

---

## 📚 5. CHIẾN LƯỢC DATASET

Không dùng tỷ lệ 70% dữ liệu tiếng Việt chung và 30% F&B như kế hoạch cũ. Model nền đã có năng lực ngôn ngữ; dataset Bum cần tập trung vào nghiệp vụ, tool calling, quyền dữ liệu và cách tư vấn.

### Dataset Bum v1: 4.000–8.000 mẫu chất lượng

| Nhóm dữ liệu | Tỷ lệ mục tiêu |
|---|---:|
| Hỏi đáp thao tác các module Quán Nhỏ | 30% |
| Classification, tool/RPC và structured output | 25% |
| Phân tích F&B từ dữ liệu quán giả lập | 20% |
| Phân quyền, riêng tư, từ chối và chống đoán số liệu | 10% |
| Tình huống thiếu/mâu thuẫn dữ liệu | 10% |
| Tính cách và cách xưng hô của Bum | 5% |

### Gold set độc lập

Tạo 500–800 tình huống kiểm thử không xuất hiện trong train:

- Số liệu doanh thu, kho và tài chính.
- Quyền Owner/Manager/Staff.
- Tool calling và JSON schema.
- Câu hỏi tiếng Việt đời thường, viết tắt và sai chính tả.
- Prompt injection và yêu cầu lấy dữ liệu quán khác.
- Tình huống phải nói “chưa đủ dữ liệu”.

### Dữ liệu không được đưa vào training

- SĐT, tên thật, ảnh selfie, GPS, PIN, token và API key.
- Dữ liệu lương/doanh thu thật chưa được ẩn danh và cấp quyền.
- Output AI chưa qua kiểm duyệt.
- Câu hỏi/câu trả lời của quán A có thể làm lộ dữ liệu cho quán B.

---

## 🔁 6. VÒNG LẶP HỌC TỪ NGƯỜI DÙNG

```text
Khách hỏi
    ↓
Bum trả lời bằng RPC/RAG/Qwen/OpenAI fallback
    ↓
Khách đánh giá 👍 hoặc 👎
    ↓
Lưu intent, route, nguồn trả lời và lỗi (đã ẩn dữ liệu nhạy cảm)
    ↓
Chủ quán/đội Bum kiểm duyệt
    ├── Sự thật riêng của quán → Memory theo store_id
    ├── Kiến thức dùng chung   → RAG/FAQ
    ├── Sai Classification     → Thêm intent example
    ├── Thiếu dữ liệu/tool     → Bổ sung RPC
    └── Kỹ năng lặp lại        → Dataset QLoRA kỳ tiếp theo
```

Không tự động đưa mọi câu trả lời vào dataset. Mẫu training chỉ được chấp nhận khi đã có câu trả lời chuẩn do con người xác nhận.

---

## 🗺️ 7. LỘ TRÌNH TRIỂN KHAI

### Giai đoạn 1 — Quán Cây: Bum read-only

- Dựng Qwen3-4B Q4 baseline trên server.
- Tạo Classification và 15–20 intent đầu tiên.
- Tạo RPC chỉ đọc cho doanh thu, top món, kho, nhân viên và vận hành.
- Kết nối RAG với tài liệu AI Bum.
- OpenAI chỉ fallback khi `unknown` hoặc câu phân tích khó.
- Thu thập log, confidence, route, latency và đánh giá của chủ quán.

### Giai đoạn 2 — Fine-tune Bum v1

- Chuẩn bị dataset đã kiểm duyệt trên MacBook M3 Pro.
- Pilot QLoRA với 500–1.000 mẫu trước để đo RAM và thời gian.
- Chỉ chạy toàn bộ dataset khi pilot ổn định.
- So sánh model gốc, model có RAG và model fine-tune trên cùng gold set.
- Quantize và deploy có version/rollback.

### Giai đoạn 3 — Pilot 5 quán

- Tách memory, log và dữ liệu tuyệt đối theo `store_id`.
- Theo dõi tỷ lệ fallback, chi phí API, lỗi phân quyền và chất lượng từng quán.
- Chưa cho AI tự thay đổi dữ liệu.
- Cập nhật Classification/RAG hàng tuần; QLoRA theo đợt khi đủ dữ liệu sạch.

### Giai đoạn 4 — Pilot 10 quán và thu phí thử nghiệm

- Load test theo tải thật thay vì tổng số tài khoản.
- Thêm queue, timeout, cache, rate limit và circuit breaker cho cloud fallback.
- Tính chi phí AI theo quán và giới hạn sử dụng hợp lý.
- Chỉ lập kế hoạch mua GPU mới khi có số liệu bottleneck và doanh thu thực tế.

---

## ✅ 8. TIÊU CHÍ THÀNH CÔNG

- Không có trường hợp lộ dữ liệu chéo `store_id`.
- Không vi phạm quyền Owner/Manager/Staff.
- Tool call/JSON hợp lệ `>= 99%`.
- Số liệu từ SQL/RPC chính xác `>= 99%`.
- Câu trả lời bám nguồn dữ liệu/tài liệu `>= 95%`.
- Tỷ lệ bịa số liệu `<= 2%` và tiến tới 0% ở các câu tài chính/lương.
- Biết hỏi lại hoặc nói thiếu dữ liệu khi confidence thấp.
- Chủ quán đánh giá trung bình `>= 4/5`.
- Chạy ổn định tại Quán Cây ít nhất 30 ngày trước khi mở rộng.
- Đo được tỷ lệ câu xử lý local và tỷ lệ phải gọi cloud; mục tiêu tăng local theo thời gian.

---

## 📌 9. QUYẾT ĐỊNH KIẾN TRÚC ĐÃ CHỐT

1. Qwen3-4B Q4 là model local đầu tiên của AI Bum.
2. Classification là thành phần bắt buộc nhưng bắt đầu nhẹ bằng rules + semantic matching.
3. Supabase RPC cung cấp số liệu; RAG cung cấp kiến thức; model không tự đoán.
4. OpenAI API chỉ là fallback có kiểm soát, không phải nguồn tự động chưng cất model local.
5. MacBook M3 Pro dùng cho dataset/fine-tune; server RTX 2060 dùng để phục vụ Bum 24/7.
6. Quán Cây là nơi kiểm thử đầu tiên; chỉ mở lên 5 rồi 10 quán sau khi đạt tiêu chí.
7. Chưa đầu tư GPU chuyên nghiệp cho đến khi sản phẩm tạo doanh thu và benchmark chứng minh cần nâng cấp.

---

## 📝 10. NHẬT KÝ QUYẾT ĐỊNH

| Ngày | Quyết định |
|---|---|
| 23/07/2026 | Khởi tạo chiến lược AI Bum local và hạ tầng thử nghiệm. |
| 06/08/2026 | Chuyển sang Qwen3-4B local; bổ sung RTX 2060, Classification, RAG/RPC, OpenAI fallback và lộ trình Quán Cây → 5 → 10 quán. |
