# Kế hoạch triển khai Boom

Mục tiêu: có bộ hướng dẫn theo từng module (người đọc và Boom cùng dùng), luôn khớp với app, rồi dựng gói module theo loại hình quán (bắt đầu: trà sữa mang đi).

## Nguyên tắc
- **Code là nguồn chính** cho tên nút, tên màn hình, thứ tự thao tác, điều kiện theo vai trò/nền tảng. Migration/RPC cho quy tắc phía máy chủ và mã lỗi. Nhật ký chỉ dùng cho lịch sử và lỗi thường gặp, không dùng cho các bước thao tác.
- Chỗ không kiểm chứng được từ code ghi `[cần xác nhận]`. Không bịa tên nút.
- Không đưa mật khẩu, khoá, IP riêng vào tài liệu.
- **BẮT BUỘC khi nạp vào Boom:** cắt bỏ **front-matter** (khối `---` đầu tệp) và toàn bộ mục **"Ghi chú cho Chủ Quán (không đưa cho khách)"** (từ tiêu đề đó tới hết tệp) trước khi đưa vào RAG / kho kiến thức. Hai phần này chứa tên bảng, RPC, đường dẫn file, số liệu production và lỗ hổng chưa vá — **không bao giờ** được hiện cho khách. Không nạp `viec-can-sua.md`, `ke-hoach-trien-khai-boom.md`, `TEMPLATE.md`, `MUC-LUC.md`. Bộ câu kiểm tra phải có câu hỏi dò xem Boom có lộ nội dung Ghi chú không.
- Tài liệu nằm ở `.docs/Huong_dan/`, tách khỏi `.docs/Ai_Boom/cac-module/` (dành cho lập trình viên).

## Khuôn mỗi bài
1. Dành cho ai (vai trò, nền tảng)
2. Làm gì / khi nào dùng
3. Các bước (theo đúng tên nút)
4. Quyền và giới hạn
5. Lỗi thường gặp và cách xử lý
6. Nguồn: file/màn hình/RPC và phiên bản app áp dụng

Đầu mỗi tệp module có front-matter: `module`, `nguon` (danh sách file), `phien_ban`, `cap_nhat`.

## Giai đoạn 0 — Nền (nhỏ)
- Tạo `.docs/Huong_dan/` + `TEMPLATE.md` + `MUC-LUC.md`.
- Chốt khuôn bằng **1 bài mẫu**: Bán hàng. Chủ Quán duyệt khuôn trước khi nhân ra.

## Giai đoạn 1 — Viết tài liệu từng module
Mỗi module: đọc `cac-module/<x>.md` + màn hình Dart + RPC liên quan → viết 5–10 bài ngắn → tự rà tên nút với code.

| Đợt | Module |
|---|---|
| 1 | Bán hàng, In Hoá Đơn (mới), QR Gọi Món (mới) |
| 2 | Thu Chi, Kho hàng, Kho Chuyên Nghiệp (mới) |
| 3 | Quản lý Bàn, Bếp, Khách hàng |
| 4 | Nhân viên + vai trò/phân quyền, Chấm công, Lương |
| 5 | Báo cáo, Báo cáo chuỗi, Vận Hành, Nhật Ký Log |

Cuối mỗi đợt: Chủ Quán (hoặc nhân viên KAY) đọc lại các luồng quan trọng; sửa theo góp ý.

## Giai đoạn 2 — Giữ tài liệu khớp app
> **ĐÃ LÀM 23/10:** test `test/docs/huong_dan_dong_bo_test.dart` + `tool/dong_dau_huong_dan.dart` + bước F trong `qn.md`.
- Thêm bước vào `qn.md`: sau mỗi thay đổi màn hình/quy tắc, dùng CodeGraph tìm bài hướng dẫn trỏ tới file đó và cập nhật.
- Bài kiểm tra tự động: nếu file nguồn của bài đã đổi mà bài chưa đổi → cảnh báo.
- Cập nhật `MUC-LUC.md` và nhật ký khi thêm/sửa bài.

## Giai đoạn 3 — Gói module theo loại hình quán
> **ĐÃ LÀM 23/10 (trà sữa mang đi):** [goi-tra-sua-mang-di.md](goi-tra-sua-mang-di.md) — 6 đề xuất chờ duyệt. Phần "Hợp với loại hình nào" để trong tài liệu gói (không chèn vào từng bài để Boom khỏi đọc nhầm).
- Mỗi module thêm phần "Hợp với loại hình nào".
- Dựng gói gợi ý, thử trước với **trà sữa mang đi**: cần / có thể cần / không cần, và các khoảng trống (chọn đường–đá–topping, định mức pha chế, tem ly, đơn app giao hàng).
- Mỗi khoảng trống thành một đề xuất riêng để Chủ Quán quyết định làm hay không.

## Giai đoạn 4 — Nối vào Boom (viết lại 23/10/2026 sau khi đối chiếu code)

**Hiện trạng đã kiểm (23/10):** Boom trong app (`boom_chat_provider.dart`) KHÔNG gọi mô hình AI nào — đoán ý bằng từ khoá
(`intent_classifier.dart`) và chỉ trả 6 loại câu hỏi số liệu (doanh thu, so sánh, bán chạy, bán chậm, sắp hết hàng, ai đang
trong ca). Câu hỏi "cách làm" (ý `app_help`) chỉ được đáp "Tớ chưa hiểu rõ lắm…". `rag_engine.dart` có sẵn nhưng không được
gọi ở đâu, chấm điểm bằng đếm từ trùng, không hiểu chữ không dấu. `openai_fallback_service.dart` là giả lập. Máy chủ AI riêng
(BunServer, Qwen2.5-3B 4-bit) giới hạn **512 token** cho cả câu hỏi + tài liệu + trả lời — không chứa nổi một bài hướng dẫn;
dịch vụ trả lời của nó cũng chưa dùng kho tài liệu. Bản kế hoạch 22/10 viết "nạp vào RAG" khi chưa kiểm những điều này.

### Bước 4.1 — Tra cứu hướng dẫn ngay trong app (không cần mô hình AI)
> **ĐÃ LÀM 23/10 (app chưa phát hành; bảng `boom_help_packs` ĐÃ ÁP production 23/10 18:03, chưa đăng bản nào — app dùng bản đóng gói).** Số liệu bộ câu hỏi: xem nhat_ky.md 23/10.
1. **Xuất bài cho Boom** (`tool/xuat_huong_dan_boom.dart`): cắt front-matter + mục "Ghi chú cho Chủ Quán" (thiếu dấu mốc →
   dừng); bỏ ghi chú phiên bản app ("app cũ…", "app bản mới, sau …") vì Boom chạy trong app mới; chặn nếu còn lọt tên kỹ thuật
   (tên bảng/hàm dạng `snake_case`, đường dẫn `.dart`/`.sql`, "migration", "RPC", "production"); chia thành đoạn theo từng việc
   (mục `###`), phần "Ai dùng được", và từng dòng bảng "Lỗi thường gặp". Kết quả: `assets/boom_help/huong_dan.json`.
2. **Bộ tìm kiếm mới**: bỏ dấu, từ đồng nghĩa (bill/hoá đơn, huỷ/xoá…), chấm điểm BM25 theo tiêu đề + nội dung.
3. **Boom trả lời**: câu không phải câu hỏi số liệu → tìm trong hướng dẫn; đủ chắc → trả nguyên đoạn đã duyệt kèm nguồn
   ("Theo hướng dẫn …"); không chắc → nói không chắc, gợi ý 2–3 chủ đề gần nhất. Không tự tạo tên nút.
4. **Bộ câu hỏi kiểm tra** (gõ có dấu / không dấu / viết tắt) — một phần do người khác viết, không nhìn bộ tìm kiếm.
   Ngưỡng bật: đúng ở 3 kết quả đầu ≥ 85%.
5. **Cập nhật bài không cần phát hành app**: bảng `boom_help_packs` trên máy chủ (mọi người đọc, chỉ quản trị ghi); app dùng
   bản đóng gói, có bản mới hơn trên máy chủ thì dùng bản đó. Áp bảng lên production cần Chủ Quán duyệt.
6. Ghi nhận lần Boom không tìm được (chỉ đếm, không lưu câu chữ của người dùng — quy tắc không gửi văn bản tự do).

### Bước 4.2 — GPT-4o mini (API OpenAI) trả lời dựa trên bài hướng dẫn — Chủ Quán chốt 23/10/2026
> **ĐÃ LÀM + ĐÃ TRIỂN KHAI production 24/10 00:36 (CHƯA có khoá → Boom vẫn trả nguyên văn; app mới chưa phát hành):** hàm `supabase/functions/boom-chat`, migration `20261023_boom_ai_v1.sql`, app `BoomAiService`; triển khai `db-fix/boom_ai_ap_dung.sh`, đặt khoá `db-fix/dat_khoa_openai.sh`. QC độc lập 3 vòng — xem nhat_ky.md 24/10.
> App chỉ gửi MÃ đoạn + phiên bản bản hướng dẫn; máy chủ lấy nội dung từ bản đã đăng (`boom_help_packs`).
> **LUẬT CỦA BOOM (Chủ Quán yêu cầu 24/10, ĐÃ ÁP production 24/10 01:40; người dùng thấy khi có khoá + app mới):** Boom chỉ hỗ trợ dùng app, bán hàng / thu hút
> và giữ khách / khuyến mãi, đọc báo cáo — thu chi — lãi lỗ của CHÍNH quán, vận hành quán. Không bàn chính trị, tôn giáo,
> không lập trình, không nêu số liệu quán khác / đối thủ / "trung bình thị trường"; ví dụ có số phải ghi "(ví dụ giả định)".
> Ba lớp: (1) luật trong câu dặn GPT (lớp chính, `logic.ts` RULES); (2) bộ lọc hẹp trên máy chủ ở chế độ tư vấn — chỉ chặn
> câu THUẦN ngoài phạm vi (câu có nhắc quán / khách / nhân viên… để GPT xử lý), trả câu từ chối, không tốn tiền, ghi sổ
> `blocked`; câu GPT trả về có mã lập trình → thay bằng câu từ chối; (3) app tự chặn câu hỏi số liệu quán khác
> (`boomAsksOtherStore`) để không trả nhầm số của quán mình. Chế độ mới `advice`: không có bài hướng dẫn liên quan → GPT
> tư vấn kinh doanh (ghi "Gợi ý của Boom (AI)", có 👍/👎). Che số riêng nhưng GIỮ số tiền chủ quán đưa ra.
> Migration `20261024_boom_ai_v2_luat.sql` (+ ROLLBACK), triển khai `db-fix/boom_luat_ap_dung.sh`. QC độc lập 4 vòng — nhat_ky.md 24/10.
> **HUỶ hướng Ollama / Unsloth (Qwen2.5-3B trên BunServer) cho khung chat Boom** (Chủ Quán quyết 23/10): mô hình nhỏ,
> ngữ cảnh 512 token, không đọc nổi một bài hướng dẫn. Hai dịch vụ đó trên BunServer vẫn chạy cho trang quản trị /
> lớp học — tắt hay giữ là quyết định riêng (hỏi Chủ Quán trước khi đụng máy chủ AI).

**Kiến trúc (khoá API không bao giờ rời máy chủ):**
`App Boom → hàm máy chủ boom-chat (Supabase Edge Functions trên VPS) → OpenAI`.
1. **Khoá OpenAI** chỉ nằm trong file bí mật trên VPS (quyền 600, chỉ root đọc), nạp vào dịch vụ hàm dưới dạng biến
   môi trường. Không có trong app, mã nguồn, tài liệu, nhật ký. Khoá nên tạo riêng cho dự án, đặt hạn mức chi tiêu
   tháng ở trang OpenAI; lộ thì thu hồi và thay trong một lệnh.
2. **Hàm boom-chat** kiểm vé đăng nhập (JWT) + người hỏi thuộc quán; giới hạn lượt / người / giờ và chi phí / quán /
   ngày + trần chi phí cả hệ thống / tháng; che số điện thoại, email, dãy số dài trước khi gửi; chỉ gửi câu hỏi +
   tối đa 3 đoạn hướng dẫn đã duyệt (KHÔNG gửi doanh thu, tên khách, dữ liệu quán). Mô hình đặt bằng cài đặt máy chủ
   (mặc định `gpt-4o-mini`) — đổi không cần phát hành app.
3. **Câu dặn mô hình:** chỉ trả lời dựa trên đoạn hướng dẫn được đưa; không có trong đoạn → nói không chắc, gợi ý mục
   gần nhất / hỏi Chủ quán; không tự đặt tên nút; xưng "tớ / cậu", ngắn gọn.
4. **App:** câu hỏi số liệu vẫn trả bằng dữ liệu tại chỗ (không gửi ra ngoài). Câu "cách làm" có đoạn hướng dẫn liên
   quan → gọi boom-chat; lỗi / hết hạn mức / chưa có khoá → trả nguyên văn đoạn hướng dẫn như Bước 4.1 (không bao giờ
   im lặng). Câu không có đoạn nào liên quan → KHÔNG gọi GPT (tránh bịa, tiết kiệm).
5. Bật / tắt và hạn mức đặt trên máy chủ. Áp lên production: hỏi Chủ Quán.

### Bước 4.3 — Boom thông minh dần (học có người duyệt, không tự học bừa)
> **BỘ NHỚ CÂU ĐÃ DUYỆT (Chủ Quán chốt 24/10: Claude phân tích + đề xuất, Chủ Quán đồng ý mới áp) — ĐÃ ÁP production
> 24/10 02:42 (bộ nhớ trống — chờ người dùng hỏi thật rồi duyệt lần đầu).** Câu hỏi trùng câu đã duyệt → trả câu đã duyệt, không gọi GPT (0 đồng, chạy cả khi chưa có khoá). Quy trình
> + tiêu chí duyệt: `boom-quy-trinh-duyet.md`. Migration `20261024_boom_ai_v3_bo_nho.sql`, triển khai
> `db-fix/boom_bo_nho_ap_dung.sh`, lấy hàng chờ `db-fix/boom_duyet_lay.sh`, áp đề xuất `db-fix/boom_duyet_ap.sh`.
GPT-4o mini không tự nhớ giữa các lần hỏi; "thông minh dần" = kho kiến thức và cách tìm tốt dần lên từ câu hỏi thật:
1. **Sổ hỏi đáp** (`boom_qa_log`): mỗi câu hỏi (đã che thông tin riêng) + đoạn hướng dẫn dùng + câu trả lời + chi phí +
   👍/👎 của người hỏi. Chủ quán / quản lý chỉ xem sổ của quán mình.
2. **Hàng chờ cải thiện:** câu Boom không tìm thấy hướng dẫn, câu bị 👎 → gom lại theo chủ đề để duyệt hằng tuần.
3. **Bài "Hỏi đáp thường gặp"** (`.docs/Huong_dan/hoi-dap.md`): câu hỏi thật + câu trả lời ĐÃ DUYỆT → đi qua đúng
   đường xuất / kiểm / bộ câu hỏi / đăng (`dang_huong_dan_boom.sh`) → Boom biết ngay, không cần phát hành app.
4. **Từ đồng nghĩa + bộ câu hỏi kiểm tra lớn dần** từ cách nhân viên gõ thật → lần sau tìm đúng hơn; mọi thay đổi
   phải qua bộ kiểm tra (không tụt chất lượng).
5. **Câu 👍 nhiều** → thành mẫu trả lời đã duyệt (gợi ý cho mô hình); **câu 👎** → sửa bài hướng dẫn gốc nếu bài sai.
6. Không cho mô hình tự ghi vào kho kiến thức (tránh "học" điều sai hoặc bị cố tình dạy sai). Tinh chỉnh mô hình
   (fine-tune) chỉ cân nhắc khi đã có vài trăm cặp hỏi đáp đã duyệt.

## Tiêu chí hoàn tất mỗi đợt
- Mọi tên nút/màn hình trong bài tìm thấy trong code.
- Mỗi bài có nguồn và phiên bản.
- Chủ Quán đã đọc các luồng thu tiền, in, QR, hủy món.
