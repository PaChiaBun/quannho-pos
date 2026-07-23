# 🧠 STRATEGY: CHƯNG CẤT AI BUM & HẠ TẦNG LOCAL SERVER "MAC MÂM" (I MÂM)
> **Ứng dụng:** Quán Nhỏ POS (`quannho.lpm.vn/pos`)  
> **Tác giả:** CEO Nguyễn Hữu Long & Đội ngũ Kỹ thuật AI  
> **Ngày phê duyệt:** 23/07/2026  

---

## 🎯 1. ĐỊNH VỊ CHÍNH THỨC CỦA AI BUM
AI Bum **KHÔNG PHẢI** là chatbot order cho khách hàng.  
AI Bum là **THƯ KÝ & CỐ VẤN CHIẾN LƯỢC ẢO** dành riêng cho **CHỦ QUÁN F&B** trên `quannho.lpm.vn/pos`.

### 4 Trụ cột Năng lực:
1. **Phân tích Báo cáo POS (BI Analytics):** Doanh thu, Lợi nhuận, Món bán chạy/ế, Chi phí COGS.
2. **Quản lý Kho & Nhập hàng:** Cảnh báo hụt bia/thịt bò, dự báo nhập hàng ngày lễ/cuối tuần.
3. **Cố vấn Kinh doanh & Marketing:** Đề xuất combo kích cầu giờ thấp điểm, chiến lược giá.
4. **Thư ký Chủ động (Proactive Briefing & Voice AI):**
   - Bản tin Sáng chào Chủ quán và tóm tắt việc cần làm trong ngày.
   - **Tương lai (v2.0):** Trò chuyện giọng nói 2 chiều (Voice AI) tự nhiên như gọi điện cho thư ký thật.

---

## 🛠️ 2. CHIẾN LƯỢC DỮ LIỆU HYBRID 70/30 (TỐI ƯU CHI PHÍ)

Tập dữ liệu chưng cất (Knowledge Distillation Dataset) được cấu trúc theo tỷ lệ 70/30:

| Thành phần Dữ liệu | Tỷ lệ | Nguồn thu thập | Chi phí | Mục tiêu Đào tạo |
| :--- | :--- | :--- | :--- | :--- |
| **Dữ liệu Ngôn ngữ Nền tảng** | **70%** (~20k - 30k câu) | HuggingFace mã nguồn mở (*PhoGPT, Vi-Alpaca, Vi-QA*) | **0 VNĐ** | Đảm bảo AI Bum nói tiếng Việt trôi chảy, tự nhiên, đúng ngữ pháp. |
| **Dữ liệu F&B Chuyên sâu Độc quyền** | **30%** (~10k - 15k câu) | Chưng cất tự động từ DeepSeek-R1 / GPT-4o API bằng Script Python | **~200k - 300k VNĐ** | Chuyên sâu F&B Việt Nam: Phân tích POS, quản lý kho, công nợ, nhắc nhở chủ quán. |

---

## 🖥️ 3. PHÂN BỔ HẠ TẦNG PHẦN CỨNG ("MAC MÂM" - I MÂM)

| Thiết bị | Cấu hình | Vai trò trong Dự án | Chi phí |
| :--- | :--- | :--- | :--- |
| **MacBook Pro 14" (2023)** | Chip **M3 Pro**, **RAM 18GB**, SSD 512GB | **Máy Chưng Cất & Fine-Tune (Training Lab)**<br>- Sinh 30% dữ liệu F&B độc quyền.<br>- Fine-tune mô hình AI Bum 7B bằng Apple MLX QLoRA ban đêm (2-3 tiếng). | **0 VNĐ** *(Tận dụng laptop có sẵn)* |
| **iMac 24-inch (2021)** | Chip **M1**, **RAM 8GB**, SSD 256GB | **Máy Thử nghiệm (Demo Server)**<br>- Nạp bản AI Bum Mini (3B thông số, 4-bit, ~2.1GB RAM) để test kết nối API với web POS. | **0 VNĐ** *(Tận dụng iMac có sẵn)* |
| **Mac Mâm (I Mâm)** | Chip **M1 Pro / M1 Max**, **RAM 32GB/64GB** | **AI Local Server 24/7 Thương mại hóa**<br>- Cắm nguồn 24/7 tại Lab, phục vụ hàng ngàn Chủ quán cùng lúc mà không bị tràn RAM.<br>- Giải phóng hoàn toàn Laptop M3 Pro. | **~8 - 11 triệu VNĐ** *(Trích tiền lời bán POS thu mua)* |

---

## 🗺️ 4. LỘ TRÌNH THỰC THI 3 GIAI ĐOẠN

### Giai đoạn 1: Chuẩn bị Dữ liệu & Chưng cất (Tuần 1) — *Chi phí ~200k - 300k*
1. Tải 70% dữ liệu tiếng Việt mã nguồn mở miễn phí trên HuggingFace về MBP M3 Pro.
2. Chạy Script Python gọi API DeepSeek-R1/GPT-4o sinh 30% dữ liệu F&B độc quyền.
3. Đóng gói thành tập dữ liệu `AI_Bum_Dataset_v1.jsonl` (30.000 câu).

### Giai đoạn 2: Fine-tune & Thử nghiệm trên iMac M1 (Tuần 2 - Tuần 3) — *Chi phí 0đ*
1. Chạy lệnh fine-tune QLoRA bằng Apple MLX trên **MacBook Pro M3 Pro (18GB RAM)** trong 2-3 tiếng ban đêm.
2. Quantize 4-bit thành `AI_Bum_7B_Q4.gguf` và `AI_Bum_3B_Q4.gguf`.
3. Nạp bản 3B lên **iMac M1 8GB** (dùng Ollama / MLX-LM) chạy thử nghiệm API kết nối với `quannho.lpm.vn/pos`.

### Giai đoạn 3: Thương mại hóa & Vận hành Mac Mâm 24/7 (Tuần 4) — *Chi phí ~8-11 triệu*
1. Mua 01 Mac Mâm M1 Pro/Max (RAM 32GB/64GB) cắm nguồn 24/7 làm AI Server chính thức.
2. Chuyển bản AI Bum 7B/14B thông minh nhất lên Mac Mâm, giải phóng hoàn toàn laptop M3 Pro và iMac M1.
3. Cấu hình cơ chế **Cloud Fallback** (mất điện Local -> Tự động chuyển Cloud API) đảm bảo dịch vụ thông suốt 100%.

---

## 🎙️ 5. MỞ RỘNG TƯƠNG LAI: VOICE AI BUM (v2.0)

Giao tiếp giọng nói 2 chiều siêu tự nhiên:
- **Nghe (STT):** Dùng mô hình **Whisper** (nghe tiếng Việt cực chuẩn kể cả môi trường quán nhậu đang ồn ào).
- **Bộ não (LLM):** **AI Bum 7B** đã chưng cất.
- **Nói (TTS):** Dùng mô hình **VieTTS / Kokoro-TTS** (giọng đọc tiếng Việt truyền cảm như người thật).
- **Tốc độ:** Chip Neural Engine của Mac Mâm xử lý phản hồi giọng nói dưới **0.8 giây**.
