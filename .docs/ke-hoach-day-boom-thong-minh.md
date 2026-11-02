# Kế hoạch dạy Boom thông minh hơn khi tư vấn chủ quán (lập 28/10/2026)

Kế hoạch này **thay** `ke-hoach-day-boom-50-lan.md`. Các lần dạy về chọn đường trong kế hoạch cũ được gộp vào Giai đoạn 1.
Kế hoạch được lập sau **một lần kiểm** các phần sau:
- Hàm máy chủ `boom-chat`: lời nhắc tư vấn `ADVICE_PROMPT`, cách ghép tin nhắn `buildMessages`, mô hình, trí nhớ.
- Số liệu app gửi kèm: `ShopFacts`, `ModuleFacts`.
- Kết quả 16 đợt dạy trước.

---

## 1. Boom đang thông minh tới đâu

| Phần | Hiện có | Điểm yếu |
|---|---|---|
| **Hiểu câu hỏi** (chọn đường) | 16 đợt dạy; câu một lượt đúng khoảng 90%; hội thoại 2 lượt 65–80% | Câu số đầu tiên còn bị đưa nhầm sang hướng dẫn; câu nói tiếp xin phân tích chỉ đúng khoảng 60% |
| **Số gửi cho GPT** | Doanh thu, số đơn, so với kỳ trước, món bán chạy / bán chậm theo nhóm, theo giờ, theo thứ, theo khung giờ, combo tính sẵn; số theo mục (thu chi, kho, chấm công, khách, voucher) là khối riêng | Không có chuỗi theo tháng / tuần, không có cùng kỳ năm trước, chưa tính sẵn tỉ lệ ngành (giá vốn %, lương %, mặt bằng %); số bán và số theo mục **không đi chung** trong một câu; kỳ dài nhất 92 ngày |
| **Cách suy luận** (lời nhắc) | Đã có: trả lời thẳng, 3–5 ý, "Cần xem lại / Việc tuần này", luật khuyến mãi, ngày lễ, mốc giá vốn 25–35%, mặt bằng dưới 15% | Lời nhắc là **một danh sách luật rất dài**, dễ chồng chéo; không có khung suy luận theo loại câu hỏi (chẩn đoán / quyết định / kế hoạch); GPT tự làm phép tính; không hỏi lại khi thiếu dữ kiện |
| **Hiểu quán** | Ngày hôm nay, ngày lễ sắp tới, 4 lượt hỏi đáp gần đây | Không biết loại quán, giá trung bình, giờ mở cửa, mục tiêu của chủ; không nhớ đã khuyên gì và kết quả ra sao |
| **Mô hình** | gpt-4o-mini, độ ngẫu nhiên 0.2, câu tư vấn tối đa 600 token | Chưa thử mô hình mạnh hơn cho câu phân tích khó |
| **Thước đo** | Bộ giả lập chọn đường (GPT giả); công cụ chấm GPT thật cho câu hỏi cách làm | **Chưa từng chấm chất lượng câu tư vấn.** Mọi con số cải thiện trước nay chỉ đo việc chọn đường |

Kết luận: để Boom **thông minh hơn**, ưu tiên theo thứ tự:
1. Có thước đo cho câu tư vấn.
2. Gửi số đủ và tính sẵn.
3. Cho GPT khung suy luận rõ.
4. Cho Boom hiểu riêng từng quán.

Chọn đường đúng vẫn cần, nhưng chỉ là điều kiện nền.

---

## 2. Thước đo "thông minh" (làm trước tiên)

### 2.1 Bộ đề tư vấn chuẩn: 60 tình huống trên 3 quán mẫu

- **Ba quán giả**, mỗi quán một file số liệu cố định, giống dữ liệu thật:
  - A: cà phê mang đi.
  - B: trà sữa có topping.
  - C: quán bún / cơm có đồ uống.
- Mỗi quán có 3 tháng số bán, thu chi, kho, chấm công, khách và voucher, trong đó cài sẵn **vấn đề có đáp án**. Ví dụ:
  - Giá vốn một món 45%.
  - Thứ Ba doanh thu tụt.
  - Một combo đắt hơn mua lẻ.
  - Lương chiếm 38% doanh thu.
  - Topping ế.
  - Khách quay lại giảm.
- **60 câu hỏi** chia 6 loại, mỗi loại 10 câu:

| Loại | Ví dụ |
|---|---|
| Chẩn đoán | "sao tháng này lời ít vậy" |
| Quyết định | "có nên tăng giá bạc xỉu lên 30k không" |
| Kế hoạch | "lên kế hoạch tăng doanh thu tháng 11" |
| So sánh | "tuần này so tuần trước sao" |
| Dự báo | "ước cuối tháng được bao nhiêu" |
| Nói tiếp | 2 lượt: số → "sao vậy", "làm gì cho tăng" |

### 2.2 Thang chấm 8 tiêu chí (0–2 điểm mỗi tiêu chí, tối đa 16)

1. **Trả lời thẳng:** dòng đầu là kết luận hoặc con số.
2. **Đúng số:** mọi con số khớp với khối số liệu; không bịa.
3. **Tìm ra vấn đề cài sẵn:** chỉ ra đúng nguyên nhân hoặc điểm bất thường.
4. **Có lý lẽ:** nối số liệu với kết luận ("vì số đơn giảm 18%, giá trị mỗi đơn giữ nguyên").
5. **Việc làm cụ thể:** 2–3 việc có món / giờ / con số và thời hạn, làm được với quán nhỏ.
6. **Đúng quán:** chỉ nói món, nhóm quán đang có; không khuyên điều trái loại quán.
7. **Thận trọng đúng mức:** nói rõ còn thiếu số gì; không phán thay chủ ở quyết định lớn.
8. **Gọn và dễ đọc:** không sáo, không lặp, đúng cách xưng hô.

### 2.3 Cách chấm

- **Công cụ mới:** `cham_tu_van.ts`, cùng kiểu với `cham_gpt.ts` có sẵn.
  - Trả lời đúng như hàm `boom-chat` đang làm (cùng `buildMessages`, lời nhắc, mô hình).
  - Sau đó gpt-4o chấm theo thang 8 tiêu chí, kèm đáp án vấn đề cài sẵn.
  - Không ghi gì vào database.
- **Khoá OpenAI:** Chủ Quán tự dán khoá khi chạy. Claude không dò, không đọc, không in, không lưu khoá.
- **Chi phí ước tính mỗi lần chấm 60 câu:** khoảng 60 × (3.000 token trả lời bằng gpt-4o-mini + 4.000 token chấm bằng gpt-4o), tức khoảng **0,7–1 USD**.
- **Chủ Quán chấm tay 10 câu** ở lần đầu, để kiểm xem gpt-4o chấm có khớp ý mình không.
- **Mốc điểm:** chấm mốc gốc ngay. Sau mỗi giai đoạn chấm lại cùng bộ đề. Giữa chừng không chấm để tiết kiệm.

---

## 3. Lộ trình: 6 giai đoạn, 50 lần dạy

Mỗi lần dạy = sửa đúng một mục + bài kiểm đơn vị. Cuối mỗi giai đoạn: đo gộp một lần, QC một lần, chấm GPT thật (nếu giai đoạn đổi câu tư vấn), rồi hỏi duyệt áp + commit.
Cột "Áp lên đâu" cho biết việc cần duyệt:
- **app**: web /pos, các bản app sau.
- **máy chủ**: triển khai lại hàm boom-chat.
- **db**: thêm hàm đọc số, migration.

### Giai đoạn 0: Thước đo (lần 1–5)

| # | Việc | Áp lên đâu |
|---|---|---|
| 1 | Viết 3 file số liệu quán mẫu A / B / C có vấn đề cài sẵn | không |
| 2 | Viết 60 câu đề kèm đáp án vấn đề + thang chấm | không |
| 3 | Viết `cham_tu_van.ts` (trả lời + chấm, không ghi database); chạy thử 3 câu bằng GPT giả | không |
| 4 | **Chấm mốc gốc** 60 câu bằng GPT thật (cần duyệt + Chủ Quán dán khoá) | không |
| 5 | Chủ Quán chấm tay 10 câu; chỉnh thang chấm nếu lệch; ghi điểm mốc gốc từng tiêu chí, từng loại câu | không |

Kết quả giai đoạn 0 sẽ chỉ ra tiêu chí yếu nhất. Thứ tự các lần dạy trong Giai đoạn 2–3 có thể đảo theo kết quả này, không cần chẩn đoán thêm.

### Mốc gốc chấm GPT thật (28/10): 10,2/16

| Tiêu chí (0–2) | Điểm | | Loại câu (/16) | Điểm |
|---|---|---|---|---|
| Trả lời thẳng | **0,82** | | Chẩn đoán | 11,7 |
| Đúng số | 1,53 | | Quyết định | 9,7 |
| Tìm vấn đề | 1,52 | | Kế hoạch | 10,6 |
| Lý lẽ | **0,88** | | So sánh | 11,3 |
| Việc làm cụ thể | **0,90** | | Dự báo | **8,9** |
| Đúng quán | 1,88 | | Nói tiếp | **9,1** |
| Thận trọng | 1,38 | | | |
| Gọn | 1,30 | | | |

- **Chấm tay (lần 5):** Chủ Quán đồng ý cả 10/10 điểm gpt-4o chấm → tin được điểm chấm tự động, không cần chấm tay mỗi mốc.
- Vấn đề cài sẵn tìm ra 49/57. Câu mà app thiếu số: 9,8; câu đủ số: 11,1.
- Ba tiêu chí yếu nhất là **trả lời thẳng, lý lẽ, việc làm cụ thể**, đều là lỗi của cách suy luận. Nên **đưa lần 28–31 (khung 4 bước, khung theo loại câu, mẫu trả lời) lên trước**.
- Lỗi điển hình:
  - Câu mở đầu "Dạ Anh/Chị ơi, … có thể do nhiều nguyên nhân" thay vì nói kết luận.
  - Bạc xỉu giá vốn 45% mà Boom khuyên **không** tăng giá.
  - Dự báo tự tính sai, bịa mức dùng gạo mỗi ngày → cần lần 20 (dự báo tính sẵn) và 25 (số ngày còn đủ dùng).
- Câu nói tiếp "chi tiết hơn" thì bịa số → lần 36.

### Ghi chú từ Giai đoạn 0 (28/10, chưa chấm GPT thật)

- Lời nhắc tư vấn dài khoảng 18.000 ký tự (khoảng 6.000 token) mỗi câu → lần 28 rút gọn sẽ giảm cả chi phí.
- **Kỳ "tuần này" chưa hết tuần:** nếu app gửi số 0 cho những ngày chưa tới, máy chủ ghi "quán NGHỈ" cho các ngày đó. Cần kiểm phía app → sửa ở lần 21.
- **Phần trăm so kỳ trước ghi dấu chấm** ("GIẢM 14.2%"), chỗ khác dùng dấu phẩy → sửa ở lần 17.
- **Món giá ≤ 5.000đ** (trà đá 3.000đ) làm quán bún không có dòng "Combo tính sẵn" → xem ở lần 23.

### Giai đoạn 1: Hiểu đúng câu hỏi (lần 6–15). Nền cho mọi thứ sau

| # | Việc | Áp lên đâu |
|---|---|---|
| 6 | Xong đợt 16 (kỳ + con số + từ hỏi; "hết bao nhiêu tiền"; câu nói tiếp sau số theo mục) + hồi quy một lượt | app |
|  | ↳ Hồi quy 28/10: 7 câu tốt lên, 3 câu tụt cần sửa: "lương … bất thường … lỗi gì vậy" (phải đi hướng dẫn: "lỗi gì" là hỏi lỗi), "bao cao hom nay hien chua co giao dich" (thêm "chưa có / không có" vào chữ chặn của luật kỳ + con số), "tháng này nhập kho hết bao nhiêu tiền" (phải đọc số kho, không đọc số bán) | |
| 7 | Câu xem xu hướng không chủ đề ("nhìn số năm nay quán có đi lên không"), dự báo nhập hàng có chữ "nhập" | app |
| 8 | Hỏi so chi nhánh ngắn ("còn chi nhánh 2"), khung giờ / ca ("khung tối thì sao") | app |
| 9 | "sao giảm so với tuần trước", "tốt hay tệ so với quán bình thường" sau số nhanh → tư vấn kèm số | app |
| 10 | Mượn kỳ cho câu nói tiếp ở số theo mục; câu cải thiện ngắn không dấu ("giam kieu gi") | app |
| 11 | "nói lại ngắn gọn / mỗi con số tổng", "số lượng cụ thể bao nhiêu" sau tư vấn → nói tiếp | app |
| 12 | Câu mới tự đủ nghĩa không gửi kèm lượt trước; hỏi giá bán hợp lý là tư vấn chung | app |
| 13 | Câu lạc đề sau lượt số (bóng đá, "MU đá mấy giờ"), so app khác, khen / cảm ơn; lạc đề gõ không dấu | app |
| 14 | Lịch sử gửi GPT dùng **câu gốc** của người dùng | app |
| 15 | Tìm đúng bài hướng dẫn cho 10 việc hay hỏi (sơ đồ bàn, QR, nhật ký sửa giá, máy in, đổi món sau in, thu chi ghi sai, báo cáo lệch thu chi, sửa giá, tìm khách theo số điện thoại, gán quản lý) | app (bộ hướng dẫn) |

### Kết quả Giai đoạn 1 (28/10, chưa áp)

| Bộ | Trước | Sau |
|---|---|---|
| Q — hội thoại, **kín** | 42/80 | **48/80** |
| Q1 — một lượt, **kín**: đúng đường | 47/60 | **50/60** |
| Q1: tìm đúng bài | 23/30 | **24/30** |
| QC giai đoạn 1 (bẫy) | — | 19/30 |
| O / N / M / L / P / QC15 | 67 / 53 / 68 / 76 / 58 / 26 | 71 / 52 / 74 / 79 / 60 / 32 |

- Bộ một lượt cũ: không tụt; câu kho / ca làm vẫn trả số nhanh.
- Câu tụt còn lại:
  - "xem khách này đã chi tổng bao nhiêu chỗ nào" (đi tư vấn thay vì hướng dẫn).
  - "tháng này nhập kho hết bao nhiêu tiền" vẫn đọc số bán.
- 112 bài kiểm qua.
- Script áp chung: `db-fix/boom_ap_dung.sh <nhãn> "<dấu hiệu>"` (lần 46 làm sớm).

### Giai đoạn 2: Đủ số và số đã tính sẵn (lần 16–27)

Nguyên tắc: **app tính, GPT diễn giải**. GPT-4o-mini hay tính sai, nên mọi tỉ lệ, chênh lệch, dự báo đều do app tính sẵn rồi ghi thành chữ.

| # | Việc | Áp lên đâu |
|---|---|---|
| 16 | Gửi **số bán + số theo mục chung một câu** khi câu chạm cả hai ("lương có cao so với doanh thu", "chi phí / doanh thu") | app |
| 17 | Tính sẵn **tỉ lệ ngành**: giá vốn % doanh thu, lương %, mặt bằng %, điện nước %. Ghi rõ mốc kinh nghiệm (giá vốn 25–35%, lương 20–30%, mặt bằng dưới 15%) và "cao / vừa / thấp" | app + máy chủ (định dạng) |
| 18 | **Chuỗi theo tháng** (tới 12 tháng) và theo tuần (tới 12 tuần): chỉ tổng doanh thu / số đơn / giá trị đơn, đọc nhẹ | db (hàm đọc) + app |
| 19 | **Cùng kỳ năm trước** (tháng này năm ngoái, tuần này năm ngoái) | app (kỳ) + db |
| 20 | **Dự báo tính sẵn**: cuối tháng / cuối năm theo nhịp hiện tại, kèm cách tính một dòng | app |
| 21 | **Tự phát hiện bất thường tính sẵn**: ngày tụt hoặc tăng mạnh so trung bình cùng thứ, món tụt mạnh so kỳ trước, khoản chi tăng vọt. Gửi dạng "Bất thường: …" | app |
| 22 | **Phân rã thay đổi doanh thu**: do số đơn hay giá trị đơn, do món nào, do khung giờ nào (đã có một phần; làm đủ cho mọi kỳ) | app |
| 23 | Giá vốn từng món → **lãi gộp từng món** và món "bán nhiều mà lãi ít" (khi quán có nhập giá vốn) | app |
| 24 | Theo **thu ngân / nhân viên**: số đơn, doanh thu, huỷ món, giảm giá; không gửi tên khách | app + db |
| 25 | Khách: tỉ lệ quay lại, khách mới / cũ, giá trị trung bình khách quen; kho: **số ngày còn đủ dùng** theo tốc độ bán | app |
| 26 | Bỏ giới hạn 92 ngày cho số tổng (vẫn giữ 92 ngày cho số theo món để nhẹ) | app |
| 27 | Rà **riêng tư**: thêm số mới không gửi tên / số điện thoại khách cho OpenAI; lương chỉ gửi khi người hỏi có quyền; giữ luật "số theo mục không lưu vào sổ hỏi đáp" | app + máy chủ |

### Kết quả Giai đoạn 2 (29/10, chưa áp): chấm GPT thật 10,2 → **10,9/16**

| Tiêu chí (0–2) | Mốc gốc | GĐ 2 | | Loại câu (/16) | Mốc gốc | GĐ 2 |
|---|---|---|---|---|---|---|
| Trả lời thẳng | 0,82 | 0,97 | | Chẩn đoán | 11,7 | 12,0 |
| Đúng số | 1,53 | 1,68 | | Quyết định | 9,7 | 11,0 |
| Tìm vấn đề | 1,52 | 1,58 | | Kế hoạch | 10,6 | 10,4 |
| Lý lẽ | 0,88 | 0,98 | | So sánh | 11,3 | 11,2 |
| Việc làm cụ thể | 0,90 | 0,95 | | Dự báo | 8,9 | **11,1** |
| Đúng quán | 1,88 | 1,92 | | Nói tiếp | 9,1 | 9,6 |
| Thận trọng | 1,38 | 1,53 | | | | |
| Gọn | 1,30 | 1,27 | | | | |

- Đã làm:
  - Máy chủ tính sẵn: thứ trong tuần (sửa lỗi "tuần này"), ngày bán yếu bất thường, dự báo cả tháng, giá vốn so mốc 25–35%, tỉ lệ chi phí trên doanh thu (cộng theo nhóm, chỉ khi kỳ trọn tháng); cấm GPT tự tính "đủ dùng mấy ngày"; QC 9 lỗi đã sửa.
  - App gửi ngày đầu / cuối của kỳ (giờ VN).
- Để lại (cần view database, Chủ Quán duyệt):
  - Lần 18 (chuỗi 12 tháng), lần 19 (cùng kỳ năm trước). Máy chủ đã nhận sẵn hai trường này.
  - Lần 24 (số theo thu ngân).
- Mỗi câu dao động ±2–4 điểm giữa hai lần chấm (GPT trả lời có ngẫu nhiên) → chỉ tin số trung bình.
- Ba tiêu chí còn yếu nhất (trả lời thẳng, lý lẽ, việc làm) là việc của Giai đoạn 3 (lời nhắc).
- "Khách quay lại 11,4%" vẫn bị gọi là "tín hiệu tích cực" → cần mốc cho tỉ lệ khách quay lại.

### Giai đoạn 3: Cách suy luận (lời nhắc) (lần 28–37)

| # | Việc | Áp lên đâu |
|---|---|---|
| 28 | Sắp xếp lại `ADVICE_PROMPT` thành **khung 4 bước** thay cho danh sách luật rời: kết luận → vì sao (số) → 2–3 việc làm (cụ thể, có số đo và thời hạn) → cần xem thêm gì. Gộp luật trùng, bỏ luật mâu thuẫn; giữ nguyên các luật an toàn | máy chủ |
| 29 | **Khung riêng theo loại câu**: chẩn đoán (tìm nguyên nhân từ phân rã), quyết định (lợi / rủi ro / con số hoà vốn), kế hoạch (theo tuần, có mốc đo), so sánh, dự báo. App gửi kèm "loại câu" đã đoán | app + máy chủ |
| 30 | **Hỏi lại một câu** khi thiếu dữ kiện then chốt (vd hỏi tăng giá mà chưa có giá vốn) thay vì khuyên chung chung | máy chủ |
| 31 | Mẫu suy luận: 6 ví dụ hỏi → trả lời mẫu tốt (ngắn) trong lời nhắc, chọn theo loại câu (chỉ gửi 1–2 mẫu đúng loại để tiết kiệm token) | máy chủ |
| 32 | **Con số hoà vốn / tác động** tính sẵn cho câu quyết định (tăng giá 3k thì mất bao nhiêu khách vẫn hoà) | app |
| 33 | Thử **gpt-4o** cho câu phân tích khó (chẩn đoán, kế hoạch); giữ gpt-4o-mini cho câu dễ. So điểm / chi phí trên bộ đề rồi Chủ Quán chọn | máy chủ (biến môi trường) |
| 34 | Độ dài theo loại câu (kế hoạch 900 token, câu nhanh 300) | máy chủ |
| 35 | Tự kiểm sau khi trả lời: con số trong câu trả lời phải có trong khối số; sai → bỏ con số đó (kiểm ở máy chủ, không gọi GPT thêm) | máy chủ |
| 36 | Câu nói tiếp đi sâu: "chi tiết hơn / sao vậy" → đi xuống một tầng phân rã (nhóm → món → giờ), không lặp lại | máy chủ |
| 37 | Chấm GPT thật lần 2 trên bộ đề; sửa 3 tiêu chí điểm thấp nhất | — |

### Kết quả Giai đoạn 3 (29/10, chưa áp): chấm GPT thật 10,9 → **11,2/16** (mốc gốc 10,2)

| Tiêu chí | GĐ 2 | GĐ 3 | | Loại câu | GĐ 2 | GĐ 3 |
|---|---|---|---|---|---|---|
| Trả lời thẳng | 0,97 | 1,05 | | Kế hoạch | 10,4 | **11,7** |
| Lý lẽ | 0,98 | 1,08 | | Nói tiếp | 9,6 | **10,7** |
| Tìm vấn đề | 1,58 | 1,67 (52/57) | | Quyết định | 11,0 | 11,4 |
| Đúng quán | 1,92 | 2,00 | | Dự báo | 11,1 | 11,4 |
| Việc làm cụ thể | 0,95 | 0,93 | | Chẩn đoán | 12,0 | 11,7 |
| Gọn | 1,27 | 1,25 | | So sánh | 11,2 | **10,4** |

- Đã làm:
  - Khung 4 bước (kết luận → Vì sao → Việc tuần này → Cần xem lại).
  - Khung theo loại câu, máy chủ tự nhận loại (đúng 56/60 câu bộ đề).
  - Hỏi lại 1 câu khi thiếu số; câu kế hoạch 900 token.
  - Câu viết bài / app / chào không theo khung.
  - QC 7 điểm đã sửa.
- So sánh giảm vì khung thiếu việc làm → đã thêm "Việc tuần này" vào khung so sánh (chưa chấm lại).
- **Việc làm cụ thể vẫn yếu (0,93):** GPT hay đưa việc chung ("chạy khuyến mãi buổi chiều", "tổ chức sự kiện"). Lần 31 (mẫu trả lời tốt) và thử gpt-4o (lần 33) là bước kế.
- GPT vẫn chèn `**` dù đã dặn, nhưng máy chủ đã tự bỏ ký hiệu này trước khi gửi cho app.

### Lần 31 — mẫu trả lời tốt (29/10, chưa áp): chấm 11,2 → 11,1 (không đổi; dao động giữa 2 lần chấm ±0,34)

- Kho việc cụ thể + câu mẫu theo loại (món / số ngoài bộ đề, GPT không chép số mẫu).
- Tốt lên: việc làm 0,93 → **1,12**, so sánh 10,4 → **11,8** (sửa khung so sánh), gọn 1,25 → 1,47.
- Xấu đi: câu trả lời ngắn đi 35% (bắt chước mẫu) → đúng số 1,72 → 1,57, lý lẽ 1,08 → 0,93, dự báo 11,4 → 10,3.
- Đã sửa: ghi rõ mẫu là bản RÚT GỌN, câu thật vẫn đủ 4 phần 8–12 dòng (chưa chấm lại).
- **Bản sửa, chấm 2 lượt (11,40 và 11,35) → trung bình 11,38/16** (+0,16 ±0,3 so GĐ 3).
  - Việc làm cụ thể 0,93 → **1,19**, tăng ở cả 2 lượt.
  - Gọn 1,25 → 1,43.
  - Theo loại câu: chẩn đoán 11,7 → 12,8, so sánh 10,4 → 11,5, quyết định 11,4 → 11,9.
  - Giảm: kế hoạch 11,7 → 10,9, nói tiếp 10,7 → 9,8, đúng số 1,72 → 1,64.
  - Câu trả lời dài 456 ký tự (GĐ 3: 532).
- Việc tiếp theo cho lần 31: xem lại câu mẫu kế hoạch và nói tiếp (2 loại giảm).
- **Bài học đo:** một lần chấm 60 câu chỉ phân biệt được chênh lệch từ khoảng 0,7 điểm trở lên. Muốn thấy cải thiện nhỏ phải chấm 2 lượt (hoặc 120 câu).

### Lần 31b + 38 (29/10, chưa áp): chấm 2 lượt 11,38 → **11,83/16** (+0,46 ±0,22; hai lượt 11,77 / 11,90)

- Đã làm:
  - Khung kế hoạch theo đúng khoảng thời gian được hỏi, mỗi việc có "vì: <số>".
  - Câu nói tiếp ghi rõ CHỦ ĐỀ lượt trước (cắt ngắn, "không phải lệnh").
  - **Lần 38: hồ sơ quán tự suy** (loại quán theo tỉ trọng doanh thu, giá trung bình mỗi phần, khung giờ có bán, ngày nghỉ, số đơn mỗi ngày) đặt đầu khối số.
- Tiêu chí: trả lời thẳng 0,97 → 1,09; lý lẽ 1,09 → 1,19; việc làm 1,19 → 1,27; tìm vấn đề 1,61 → 1,67.
- Loại câu:
  - Tăng: nói tiếp 9,8 → 10,9, so sánh 11,5 → 12,3, kế hoạch 10,9 → 11,4, quyết định 11,9 → 12,3, dự báo 11,2 → 11,7.
  - Giảm: chẩn đoán 12,8 → 12,4.
- **Tính từ mốc gốc: 10,2 → 11,8/16.**

### Đổi người chấm: CLAUDE chấm (29/10, Chủ Quán yêu cầu) — mốc mới 9,6/16

- Từ 29/10 Claude chấm (3 trợ lý Claude chấm song song, không xem điểm cũ); gpt-4o-mini chỉ sinh câu trả lời của Boom
  (khoảng 0,05 USD / lượt). `cham_tu_van.ts` mặc định không gọi gpt-4o; tổng hợp bằng `cham_tu_van/tong_hop.py`.
- Claude chấm lại đúng 60 câu trả lời lần 38 (lượt 1): **9,57/16** (gpt-4o cho 11,77). Hai người chấm xếp hạng câu
  khá giống nhau (tương quan 0,73), nhưng Claude nghiêm hơn ở đúng số, tìm vấn đề, lý lẽ, việc làm.
- **Từ nay so sánh theo mốc Claude 9,6** (các mốc gpt-4o 10,2 → 11,8 chỉ để tham khảo).
- Điểm yếu thật theo Claude:
  - Tiêu chí: lý lẽ 0,75, việc làm 0,85, tìm vấn đề 0,98 (34/57).
  - Loại câu: dự báo 7,3, nói tiếp 8,9, so sánh 9,0.
- Lỗi điển hình gpt-4o bỏ qua:
  - Lấy dự báo tháng 10 làm dự báo tháng 11; coi doanh thu 3 ngày là ước cả tuần.
  - Bịa số khi khối không có (số từng món tháng trước, phần thịt / rau / bún trong chi nguyên liệu, tỉ lệ khách quay lại).
  - Cộng / chia sai khi tự tính (thu − chi kỳ trước, % một khoản).
  - Khuyên chạy tiếp mã giảm giá đang ăn 9% tiền hàng.
- Việc kế tiếp (ưu tiên):
  1. Dự báo tuần / tháng sau tính sẵn và cấm dùng dự báo tháng này cho tháng khác.
  2. Luật "không có số → nói không có, không ước" mạnh hơn.
  3. Tính sẵn thêm (thu − chi kỳ trước, % từng mã giảm giá).

### Lần 39 (29/10, Claude chấm, chưa áp): số tính sẵn + cấm số giả + **ĐIỂM CẦN CHÚ Ý tính sẵn** → 9,6 → **10,2/16** (1 lượt)

- Bản A (số tính sẵn: dự báo đúng kỳ, tuần chưa trọn, thu − chi kỳ trước, % từng mã; cấm số giả):
  - 9,61 (2 lượt), không đổi so mốc 9,57.
  - Dự báo 7,3 → 9,0.
- Bản B (A + câu mẫu không số): 8,79 → **bỏ**. Mẫu chỗ trống làm câu trả lời chung chung hơn.
  - Phát hiện lúc thử bản B: GPT chép số mẫu (9%, 2.000đ, 1/3) sang quán khác, in nguyên "[Mốc 1]" → máy chủ bỏ dấu ngoặc nhãn; quay lại mẫu bản A.
- **Bản C = A + "ĐIỂM CẦN CHÚ Ý (tính sẵn)"**:
  - Nội dung: máy chủ tự liệt kê combo đắt hơn mua lẻ, giá vốn > 35%, nhóm topping / món thêm < 5%, món chưa bán, khoản chi tăng ≥ 50%, giảm giá > 8%, khách quay lại < 20%, hao hụt kho, hàng hết, ca quên chấm ra.
  - Lượt 1: **10,23/16** (+0,66 ±0,32 so mốc). Tìm vấn đề 0,98 → 1,15, đúng số 1,40 → 1,57.
  - Lượt 2 chưa chạy được: **tài khoản OpenAI của khoá chấm hết tiền** (credit_balance_exhausted).
- Còn yếu:
  - Lý lẽ 0,7.
  - Câu "có nên" nghiêng về NÊN ở quyết định lớn (cắt người, đóng ca, đổi mối, chạy tiếp mã giảm giá).
  - Khuôn "thử 2 tuần" lặp máy móc.
  - Câu nói tiếp còn lạc chủ đề.

### Lần 40 (31/10, Claude chấm 2 lượt, đã áp): 10,23 → **10,30/16** (không đổi về tổng)

- Đã làm:
  - Quyết định LỚN (cắt người, đóng ca, đổi mối, chạy / tắt khuyến mãi) không phán thay chủ: nêu số ủng hộ / phản đối + điều kiện.
  - "Vì sao" phải có ≥ 1 phép so có số, cấm đoán nguyên nhân không có trong khối.
  - Việc làm chỉ trong giờ / ngày quán có bán; "thử 2 tuần" chỉ cho đổi giá / combo.
  - Câu nói tiếp mở bằng đúng chủ đề.
- Kết quả:
  - Tăng: quyết định 10,2 → **11,4**, thận trọng 1,10 → 1,27, trả lời thẳng 1,37 → 1,52, kế hoạch 9,0 → 9,6, nói tiếp 10,4 → 10,9.
  - Giảm: so sánh 10,9 → 10,0, dự báo 10,0 → 9,2, việc làm 0,95 → 0,86.
- Sau lần chấm, câu mẫu kế hoạch được bỏ số: trỏ tới DÒNG số liệu thay vì "9%", "1/3" vì GPT vẫn chép (chưa chấm lại).
- **Trần của cách sửa lời nhắc:** 4 lần gần nhất đều quanh 10,2–10,3.
- Lỗi lặp lại mọi bản (giới hạn của gpt-4o-mini):
  - Bịa số khi khối không có (số từng món tháng trước, chia nhỏ khoản nguyên liệu, % tăng tháng sau).
  - Khuyên ngược điểm cần chú ý (đẩy món giá vốn 45–48%).
- Bước kế đề xuất:
  - (a) Máy chủ tự kiểm số trong câu trả lời, số không có trong khối → hỏi lại GPT 1 lần.
  - (b) App gửi thêm số từng món kỳ trước.
  - (c) Thử gpt-4o cho câu khó (cần duyệt chi phí).

### Lần 41 (31/10, Claude chấm 2 lượt, đã áp): 10,30 → **10,51/16**

- Đã làm (bước kế (a) của lần 40): máy chủ tự kiểm số.
  - `soLa(answer, soLieuGoc(...))` trong logic.ts dò tiền / % / số lượng ở kết luận, "Vì sao", "Cần xem lại".
  - Bỏ qua phần "Việc tuần này" (đề xuất) và "(ví dụ …)".
  - Cho qua: số có trong khối (sai số theo cách viết, tiền tròn tối đa 4%); cộng / trừ tiền trong cùng vế câu hoặc vế kề; cộng / trừ số lượng chỉ trong cùng vế; tỉ lệ % giữa 2 số cùng vế; tiền trong câu trả lời × số phần trong khối; mốc 25 / 30 / 35 / 50%.
  - Có số lạ → index.ts hỏi lại GPT 1 lần (còn ≥ 4 giây, hẹn giờ ≤ 8 giây), nhật ký ghi `+kiem_so`. cham_tu_van.ts làm y hệt.
  - Lỗi đã gặp: mẫu `đ\b` không khớp khi "đ" ở cuối (đ không phải chữ ASCII) → số tiền "25.000.000đ" không được kiểm; ghép số cả dòng dài (danh sách khoản chi 1 dòng) → gần như số nào cũng "tính ra được" → tách theo vế câu.
- Kết quả: hỏi lại 4–7 / 60 câu. Đúng số 1,49 → 1,57, thận trọng 1,27 → 1,43; D50 (dự báo chi tháng sau) 6–7 → 12–13.
- Còn yếu:
  - Bịa số trùng số khác có trong khối thì lọt (D59 "rau 15 triệu, bún 10 triệu").
  - Bản viết lại đôi khi kém hơn (D60 lượt 2: bắt đúng phép nhân sai nhưng 15 → 9).
  - Lý lẽ 0,76, việc làm 0,84; khuyên ngược điểm cần chú ý.
  - Sau lần chấm: siết cộng số lượng cùng vế + cho phép tiền × số phần → bắt thêm D32 "740 / 710 phần" (chưa chấm lại).
- Bước kế: (b) app gửi số từng món kỳ trước; (c) thử gpt-4o cho câu khó (cần duyệt).

### Lần 42 (31/10, Claude chấm 2 lượt, đã áp): 10,51 → **10,82/16**

- Đã làm:
  - Câu mẫu kế hoạch nói lý do bằng lời thường (bỏ "vì dòng ĐIỂM CẦN CHÚ Ý…", "khối KHÁCH HÀNG…" mà GPT chép, có khi bịa khối không có).
  - `kiemTraLoi` gộp 3 lỗi vào 1 lần hỏi lại: số lạ (lần 41), `khuyenNguoc` (giảm giá / tặng / đẩy mạnh món giá vốn cao hơn mốc trong cùng vế câu; bỏ qua "giảm giá vốn"), lộ tên dòng nội bộ.
- Kết quả: lý lẽ 0,76 → 0,84, việc làm 0,84 → 0,93, đúng quán 1,61 → 1,71; kế hoạch 9,2 → 10,5, quyết định 12,0 → 12,4; lộ chữ nội bộ 7 câu → 0. Hỏi lại 8–10 / 60 câu.
- Còn yếu:
  - Câu bị hỏi lại điểm lẫn lộn (D08 +3, D23 +4; D50, D58 −4): bản viết lại không luôn tốt hơn → lợi chính đến từ sửa câu mẫu.
  - Lọt "tăng cường quảng bá Bạc xỉu (vì giá vốn cao hơn mốc)" (D21, D22): GPT hiểu điểm cần chú ý là món cần đẩy.
- Bước kế (lần 43): ghi thẳng ở dòng điểm cần chú ý "→ lời mỏng: không đẩy / không giảm giá, xem tăng giá hoặc giảm định lượng" (sửa từ dữ liệu gốc thay vì bắt lỗi rồi hỏi lại).

### Lần 43 (31/10, thử rồi BỎ, không áp): 80 câu bị ảnh hưởng 10,51 → 10,30

- Thử: dòng điểm cần chú ý của món giá vốn cao ghi "→ LỜI MỎNG: không đẩy / quảng bá / giảm giá / tặng món này; hướng đúng là tăng giá nhẹ hoặc giảm định lượng"; bộ dò khuyên ngược thêm "quảng bá / mời thêm / giới thiệu".
- Hỏng: GPT hiểu "không … món này" thành đừng đụng món → câu "có nên tăng giá Trà dâu tây / Cơm sườn" thành KHÔNG NÊN (16 → 7–11). Bài học: câu cấm phủ cả món làm đảo quyết định; nếu thử lại phải viết theo hướng NÊN ("NÊN tăng giá nhẹ / giảm định lượng; tránh giảm giá, tặng").
- Cách chấm tiết kiệm lần đầu: chỉ chấm câu bị ảnh hưởng, khối số liệu ghi 1 lần, 2 trợ lý → khoảng 0,27 triệu token (so 0,5 triệu).

### Lần 43b (31/10, Claude chấm 2 lượt, đã áp 01/11): 78 câu bị ảnh hưởng 10,62 → **11,13/16**; ước cả đề 10,82 → **11,15**

- Đã làm: dòng điểm cần chú ý của món giá vốn cao viết theo hướng NÊN: "món lời mỏng: hướng đúng là TĂNG GIÁ nhẹ hoặc giảm định lượng (giảm giá / tặng / quảng bá thêm chỉ làm mỏng lời hơn)"; bộ dò khuyên ngược bắt thêm "quảng bá / mời thêm / giới thiệu".
- Kết quả: cả 8 tiêu chí tăng (thẳng 1,42 → 1,54; lý lẽ 0,86 → 0,92; việc làm 0,88 → 0,95; gọn 1,59 → 1,72). Câu "có nên tăng giá" (D12, D16, D19) giữ 16/16; D42 +5, D58 +4.
- Còn yếu: D35 gọi giá bán là giá vốn; D32 bịa số món tháng trước; D59 chia nhỏ khoản nguyên liệu; khuyên tặng topping ở quán không bán topping (lần 44 thử sửa, bỏ).

### Lần 44 (01/11, thử rồi BỎ, không áp): 57 câu bị ảnh hưởng 10,65 → 10,18

- Thử: hồ sơ quán thêm "quán không bán topping: ưu đãi kèm hợp quán là nâng size, x2 điểm tích, combo theo giá tính sẵn"; bước tự kiểm hỏi lại khi khuyên topping ở quán đó.
- Được: hết khuyên tặng topping ở quán không bán (D33, D51).
- Hỏng: GPT chép "nâng size / x2 điểm" vào mọi câu, kể cả món chính quán bún cơm và combo không có → đúng quán 1,60 → 1,32, thận trọng 1,46 → 1,33. Bài học: dòng hồ sơ không gợi ý việc cụ thể; nếu thử lại chỉ ghi "không bán topping".

### Lần 45 / 45b (01/11, Claude chấm 2 lượt, đã áp 45b): nói rõ số còn thiếu thay vì bịa số chi tiết

- Gốc lỗi: bước tự kiểm bắt được số bịa, nhưng khi hỏi lại GPT bịa số khác (D32 "Bạc xỉu tháng trước 710 phần" → 715; D59 "rau 15 triệu, bún 10 triệu") vì khối số liệu không nói số đó không có.
- Lần 45: khối bán hàng luôn ghi "CHƯA có số từng món kỳ trước"; khối thu chi ghi "Chi chỉ có TỔNG từng khoản, CHƯA có số riêng từng mặt hàng". 86 câu bị ảnh hưởng 11,28 → 11,12: D32 / D59 hết bịa nhưng việc làm 0,95 → 0,79 (dòng "chưa có" ở mọi câu làm GPT dè dặt).
- Lần 45b (áp): dòng số món kỳ trước chỉ ghi khi câu hỏi có "món" và "trước"; dòng thu chi giữ. 8 câu có dòng mới 9,94 → **11,12** (D32 5–6 → 13; D59 6 → 10–11); 22 câu bị hỏi lại (mã không đổi) 10,41 → 9,64 là dao động.
- Còn yếu: D59 nói thiếu số rồi bảo xem app, không nêu chi nguyên liệu +28% và đối chiếu phiếu nhập; D42 lấy dự báo tháng này cho tháng sau; D18 lấy số 1 giờ làm cả ca; so tỉ lệ trên tổng chi với mốc trên doanh thu (D09).

### Lần 46 (01/11, Claude chấm 2 lượt, đã áp): hỏi tháng khác thì không đưa số dự báo tháng này

- Gốc lỗi: dòng "Dự báo cả tháng" dù dặn "KHÔNG dùng cho tháng khác" vẫn bị GPT chép làm dự báo tháng 11 (D42).
- Đã làm: câu hỏi có "tháng sau / tới / tiếp / kế" hoặc "tháng N" khác tháng đang xem → bỏ con số dự báo, chỉ ghi "CHƯA có dự báo cho tháng đó; mốc là tháng này đã có …, còn … ngày".
- Kết quả: 3 câu có dòng mới (D21, D42, D45) 8,83 → **10,33** (D42 5 / 9 → 11 / 11); 19 câu bị hỏi lại (mã không đổi) 9,37 → 9,00 là dao động. Chấm 1 trợ lý khoảng 0,13 triệu token.
- Bài học chung lần 45b–46: bỏ con số dễ chép nhầm khỏi khối số liệu hiệu quả hơn lời dặn "không dùng"; chỉ thêm dòng khi câu hỏi đúng loại.
- Còn yếu: D45 chưa dùng điểm riêng của quán (đông tối, cuối tuần); lấy số 1 giờ làm cả ca (D18, D57); bỏ sót khung 14–16h vắng; D13 nói "số nghiêng về mở" khi không có số; D50 tự đặt dự báo chi nguyên liệu.

### Lần 47 (01/11, thử rồi BỎ, không áp): 78 câu bị ảnh hưởng 11,08 → 10,68

- Thử: thêm dòng "Doanh thu theo ca (cộng sẵn từ số theo giờ)" theo khung sáng 5–11h / trưa 11–14h / chiều 14–17h / tối từ 17h vào mọi khối có số theo giờ (35/60 câu).
- Được: D18, D57 dùng đúng số ca tối 18.748.000đ (14,1%), không lấy số 1 giờ nữa; nhưng điểm hai câu gần như không đổi (khung "tối từ 17h" lệch ca tối thật 16–20h của quán, D18 vẫn tự mâu thuẫn "không nên đóng" rồi "thử không mở").
- Hỏng: cả 8 tiêu chí tụt nhẹ (lý lẽ 0,96 → 0,87, việc làm 0,95 → 0,88). Lần thứ hai thấy dòng thêm vào mọi khối làm điểm chung tụt (lần 45 cũng vậy).
- Nếu thử lại: chỉ thêm khi câu hỏi / lượt trước nói về ca / giờ / buổi, và chia ca theo giờ mở bán thật của quán (vd 16–20h), không theo khung cố định.

### Lần 47b (01/11, thử rồi BỎ): 5 câu có dòng mới 10,2 → 10,0

- Thử: dòng doanh thu theo ca chỉ khi câu hỏi / lượt trước nói về ca / giờ / buổi; ca theo giờ quán có bán thật (vd Sáng 6h–11h, Trưa 11h–14h, Tối 16h–20h). Chỉ 5 câu có dòng này.
- Được: số ca đúng (D18, D57 nói ca tối 16h–20h 21.873.000đ = 16,5%).
- Không lên điểm: chỗ mất điểm của các câu này là lý lẽ và việc làm (D18 lý lẽ nghiêng về đóng mà kết luận không đóng, không tính chi phí ca tối; D57 giải thích vòng tròn "vì quán vắng"), không phải số. Bài học: đúng số chưa đủ, cần sửa cách suy luận.
- Nhận thấy: người chấm nhiều lần chê Boom chèn "tăng giá Bạc xỉu / Cơm sườn" vào câu không hỏi về giá (D01, D21, D38, D48, D57, D58) → nhiều khả năng do dòng điểm cần chú ý của lần 43b ("hướng đúng là TĂNG GIÁ") có trong mọi khối. Ứng viên cho lần 48.

### Lần 48 (01/11, thử rồi BỎ): 25 câu bỏ hướng 10,84 → 9,96

- Thử: chỉ ghi "→ món lời mỏng: hướng đúng là TĂNG GIÁ nhẹ…" khi câu hỏi nói giá / lời / vốn / món / combo / menu; câu khác chỉ ghi giá vốn N% (mốc 25–35%).
- Được: câu không hỏi giá mà chèn "tăng giá" giảm từ 7–8 xuống 3 / 25.
- Hỏng: lý lẽ 0,88 → 0,58, việc làm 0,84 → 0,72, đúng quán 1,46 → 1,30. Bỏ hướng thì GPT tự suy sai ("món giá vốn thấp hơn mốc", "lãi tốt nhất" cho món không có giá vốn, mời thêm Bạc xỉu vì giá vốn cao). Bài học: dòng hướng đúng của lần 43b đang giữ lý lẽ đứng vững; việc chèn tăng giá là cái giá nhỏ hơn.
- Nhận định sau 4 lần thử liền không lên (44, 47, 47b, 48): sửa khối số liệu đã gần hết tác dụng; chỗ mất điểm lớn còn lại là lý lẽ và việc làm của gpt-4o-mini (giải thích vòng tròn, việc làm lạc đề, chép khuôn kế hoạch 4 tuần). Hướng tiếp: thử mô hình mạnh hơn cho câu tư vấn có số liệu (cần Chủ Quán duyệt chi phí), hoặc chấm đủ 120 câu để lấy mốc mới trước khi dạy tiếp.

### Thử gpt-4o (01/11, Chủ Quán duyệt ~3,3 USD): đủ 60 câu × 2 lượt, chấm KÍN cạnh gpt-4o-mini (bản lần 46)

- Cách chấm: mỗi câu đặt 2 câu trả lời A / B xáo thứ tự, 4 trợ lý không biết câu nào của mô hình nào (kết quả `gpt4o_vs_mini_l46_claude_20261101.json`).
- Kết quả: gpt-4o-mini **11,46** → gpt-4o **12,26/16** (+0,80); 4o hơn 64 câu, kém 37, bằng 19. Mọi loại câu đều tăng (kế hoạch 10,70 → 11,75, quyết định 12,20 → 13,05, nói tiếp 11,95 → 12,95).
- Theo tiêu chí: tìm vấn đề 1,20 → 1,57, lý lẽ 0,81 → 1,13, việc làm 1,02 → 1,32, thận trọng 1,47 → 1,65; riêng **gọn 1,80 → 1,21** (4o viết dài hơn).
- Chi phí đo được: khoảng 0,027 USD (≈ 700đ) mỗi câu tư vấn có số liệu với gpt-4o, so với khoảng 0,0017 USD (≈ 40đ) với gpt-4o-mini (≈ 16 lần).
- Lỗi chung cả hai mô hình (sửa bằng dạy được): coi mã giảm giá dùng nhiều là hiệu quả (D37), tính ngược tác động tắt mã (D46), kết luận trà sữa lời hơn khi chưa có giá vốn (D35), đẩy món chưa bán thay vì ẩn / bỏ.

### Lần 49 / 49b (01/11, Claude chấm kín, đã áp 49b): mã giảm giá — tiền bớt là chi phí, tắt mã thì quán thu thêm

- Gốc lỗi: khối khuyến mãi ghi "GIAM15 610 lần, giảm 9.348.000đ" → GPT đọc như doanh thu mã mang về: "GIAM15 hiệu quả hơn" (D37), "tắt GIAM15 doanh thu giảm 9,3 triệu" (D46).
- Lần 49 (bỏ): chỉ dặn thêm "tiền giảm là chi phí, không phải doanh thu" → GPT vẫn trả lời y cũ.
- Lần 49b (áp): đổi chữ thành "quán bớt cho khách …" kèm trung bình mỗi lần; tính sẵn "mã bớt nhiều nhất = mã TỐN nhất, chưa chắc hiệu quả nhất" và "tắt mã: khách vẫn mua thì quán THU THÊM tối đa …; doanh thu chỉ giảm ở phần khách bỏ đi → tắt thử 1–2 tuần rồi so số đơn".
- Kết quả: chấm kín 3 câu × 2 lượt cạnh bản lần 46: 8,17 → **12,5/16** (D46 5 / 6 → 13 / 13; D15 11 → 14 / 15; D37 8 → 12 / 8).
- Còn yếu: D37 lượt 2 vẫn "GIAM15 hiệu quả hơn vì bớt nhiều"; chưa gợi ý thu hẹp mã (giảm mức bớt, chỉ giờ vắng, để hết hạn 30/11).
- Bài học (khớp lần 45b–46): sửa cách VIẾT số để GPT không đọc ngược hiệu quả hơn lời dặn; tính sẵn hướng đúng của phép tính.

### Lần 50 (01/11, Claude chấm kín, đã áp): món chưa bán → ẩn / bớt nhập; nhóm nào lời hơn → chưa so được khi thiếu giá vốn

- Gốc lỗi: dòng "món chưa bán phần nào" trong Điểm cần chú ý không ghi hướng, còn lời nhắc dặn "đưa món chưa bán lên đầu menu" → GPT khuyên giảm giá / quảng bá món không ai gọi (lặp ở nhiều câu chấm l46, l48). D35 "trà sữa với trà trái cây nhóm nào lời hơn": GPT kết luận theo doanh thu dù trà sữa chưa có giá vốn.
- Sửa: alert món chưa bán ghi "→ hướng đúng là ẨN khỏi menu / bớt nhập nguyên liệu riêng (món mới thêm thì chờ thêm 2 tuần); KHÔNG giảm giá / quảng bá"; 2 chỗ lời nhắc đổi theo (món bán chậm mới đưa lên đầu menu). Câu hỏi có "lời / lãi" và có ≥ 2 nhóm: thêm dòng "Tính sẵn lời theo nhóm" (nhóm nào có giá vốn mấy món, % từng món) → chưa so được nhóm nào lời hơn.
- Kết quả: chấm kín 68 cặp (34 câu khối đổi × 2 lượt) cạnh bản lần 49b: 10,41 → **11,28/16** (mới hơn 36, kém 18, bằng 14); đúng quán 1,21 → 1,56; D35 5 → 16; D56 10–11 → 15; D10, D32 +3–4. Chẩn đoán 11,10 → 10,40 (10 cặp, lỗi riêng lẻ: bịa thứ, gọi món lời khi không có giá vốn).
- Còn yếu: vẫn nhắc món chưa bán ở câu không liên quan (dự báo D47); tự ghép combo đắt hơn mua lẻ (D02, D08); D22 "tuần sau" trả kế hoạch 4 tuần.
- Bài học (khớp 43b, 49b): ghi hướng đúng ngay trong dòng cảnh báo hiệu quả hơn lời dặn chung.

### Lần 51 / 51b / 51c (01/11, Claude chấm kín, đã áp 51): hỏi "tuần sau" chia theo ngày; câu dự báo bỏ món chưa bán

- Gốc lỗi: câu mẫu kế hoạch là mẫu tháng (Tuần 1 / 2 / 3–4) → D22 "tuần sau nên làm gì" trả kế hoạch 4 tuần dù khung đã dặn chia theo đúng khoảng thời gian. Câu dự báo (D47) chèn "ẩn món chưa bán".
- Lần 51 (áp): câu kế hoạch có "tuần sau / tuần tới" dùng `MAU_KE_HOACH_TUAN` (Thứ 2–3 / Thứ 4 / Thứ 5–CN); câu loại dự báo bỏ món chưa bán khỏi khối (dùng chung cờ của kỳ 1 ngày).
- Kết quả: chấm kín 12 cặp (D22 + 5 câu dự báo có khối × 2 lượt) cạnh bản lần 50: 9,42 → **10,33/16**; D22 8 / 6 → 12 / 12; dự báo 9,9 → 10,0 (hết nhắc món chưa bán nhưng vẫn chèn tăng giá / quảng bá lạc đề).
- Lần 51b (bỏ): mẫu tuần khác (quán mì, tối vắng, cuối tuần đông) → GPT chép "cuối tuần đông hơn" cho quán văn phòng. Lần 51c (bỏ): mẫu chỉ có chỗ trống <…> → câu chung chung, mất điểm yếu chính.
- Còn yếu: D22 chép 2 ý của mẫu ("mỗi đơn chỉ 1 món", "x2 điểm"); câu dự báo gán % của số so cùng kỳ cho cả tháng / tuần, không nói ngày còn lại yếu / mạnh.
- Bài học: GPT chép nội dung câu mẫu → mẫu cần sát loại câu nhưng ý trong mẫu không được trái dữ liệu phổ biến; mẫu rỗng thì mất cụ thể.

### Lần 52 (01/11, Claude chấm kín, đã áp): câu dự báo — ngày còn lại theo thứ, % kỳ trước chỉ của phần đã có, bỏ điểm cần chú ý

- Gốc lỗi: câu dự báo gán −14,2% (so cùng kỳ 28 ngày) cho cả tháng, không nói 3 ngày còn lại gồm Thứ 7 yếu (D41); chép Điểm cần chú ý thành việc lạc đề (tăng giá trà dâu, quảng bá topping — D47).
- Sửa: dòng "Dự báo cả tháng" ghi từng ngày còn lại kèm trung bình / ngày của thứ đó và "% so kỳ trước chỉ là của N ngày đã có, KHÔNG phải % cả tháng" (khi có số kỳ trước); câu loại dự báo không nhận ĐIỂM CẦN CHÚ Ý; khung dự báo dặn việc làm chỉ nhắm ngày / giờ còn lại.
- Kết quả: chấm kín 20 cặp (10 câu dự báo × 2 lượt) cạnh bản đang chạy: 10,0 → **11,1/16** (mới hơn 9, kém 6, bằng 5); D41 10 / 7 → 15 / 13; D46_2 8 → 13; D50_2 7 → 11; lý lẽ 0,65 → 1,00, việc làm 0,65 → 1,05. Tụt: D49_2 15 → 12, D48 9 → 7 / 8.
- Còn yếu: D47 vẫn gán +4,2% của 3 ngày cho cả tuần (dòng ước tuần chưa có trung bình theo thứ); D48 tự đặt ~3 triệu cả ngày; D45 chung chung (chưa nói 24–25/12 rơi thứ mấy); D44 tự đặt lượng nhập.
- Bài học (khớp 49b, 50): bỏ khỏi khối thứ GPT hay chép lạc đề hiệu quả hơn dặn "không chèn".

### Lần 53 (01/11, Claude chấm kín, đã áp): ước cả tuần / cả ngày — % kỳ trước chỉ của phần đã có, không tự đặt số cả ngày

- Gốc lỗi: D47 "tuần này chắc được bao nhiêu" gán +4,2% (3 ngày so cùng kỳ) cho cả tuần; D48 "chắc cả ngày được bao nhiêu" tự đặt ~3 triệu dù khối chỉ có số tới 14h; hồ sơ quán kỳ hôm nay ghi "có bán 6h–14h" như giờ đóng cửa.
- Sửa (chỉ câu dự báo): dòng ước tuần ghi ngày chưa có số + "% so kỳ trước chỉ là của N ngày đã có, KHÔNG phải % cả tuần"; kỳ hôm nay + dự báo: dòng "KHÔNG tự đặt con số cả ngày", nêu số tới giờ + % so cùng giờ, hỏi quán còn bán tới mấy giờ; hồ sơ kỳ hôm nay ghi "(hôm nay tới giờ này, CHƯA phải giờ đóng cửa)".
- Bản đầu thêm phần ước tuần cho MỌI câu kỳ tuần → 8 cặp câu khác tụt nhẹ (13 → 10 … 10 → 9) → giới hạn cho câu dự báo; so khối 60 câu với bản đang chạy: chỉ D47, D48 đổi.
- Kết quả: chấm kín D47, D48 × 2 lượt: 7,5 → **11,25/16** (D48 7 / 5 → 10 / 11; D47 9 / 9 → 10 / 14).
- Còn yếu: D48 chỉ nói "chưa ước được", không nêu mốc ca tối 16–20h (khối hôm nay chưa có số đó — cần app gửi số ca tối cùng thứ tuần trước); D47 lượt 1 vẫn gán +4,2%.
- Bài học: dòng mới chỉ thêm cho đúng loại câu (khớp 45b); kiểm khối các câu khác không đổi trước khi chấm.

### Lần 54 (01/11, Claude chấm kín, đã áp): tự kiểm combo đắt hơn mua lẻ, topping ở quán không bán topping

- Gốc lỗi: GPT tự ghép combo ngoài "Combo tính sẵn" với giá cao hơn tổng giá lẻ (D02 Trà tắc + Bánh mì thịt 45.000đ khi lẻ 43.000đ; D08 Cơm sườn + Trà đá 45.000đ); gợi ý tặng topping ở quán cà phê / quán bún (D22, D33, D51). Mỗi lỗi ~3/120 câu.
- Sửa: `comboDat` (câu có "combo" + đúng 2 tên món có giá trong khối, bỏ tên nằm trong tên dài hơn; giá nhỏ nhất trong câu > tổng lẻ → lỗi) và lỗi topping (câu có "topping", khối có "Các nhóm quán đang bán" mà không có chữ topping) thêm vào `kiemTraLoi` → hỏi lại 1 lần. Thử trên 240 câu cũ: bắt 6, không bắt nhầm.
- Kết quả: sinh lại D02, D08, D22, D33, D51 × 3 lượt; chấm kín 7 câu bị bắt (trước / sau hỏi lại): 7,71 → **10,43/16**, 7/7 tốt hơn; dùng số 0,29 → 1,86.
- Còn yếu: D02 sau hỏi lại dùng combo sáng (Cà phê sữa đá + Bánh mì thịt) cho khung chiều thay vì món bán chạy chiều.
- Bài học: lỗi hiếm nhưng rõ ràng → bắt bằng tự kiểm (chỉ tốn khi sai) thay vì thêm dòng vào mọi khối.

### Mốc lần 54 (01/11, Claude chấm 60 câu lượt 1): khoảng 11,2/16

- Hai gói 11,9 / 10,53. Yếu nhất: việc làm 0,93, lý lẽ 1,13, tìm vấn đề 1,2. Nhóm lỗi: việc chung chung 34/60, bỏ sót vấn đề 15, lạc đề 6, trái hồ sơ 4 (giờ nghỉ, ngày nghỉ), bịa "mỗi đơn chỉ 1 món" (chép mẫu) 2.

### Lần 55 (01/11, bỏ): tự kiểm việc chung chung + đổi "mỗi đơn chỉ 1 món" trong mẫu kế hoạch

- Tự kiểm bắt "theo dõi doanh thu", "tăng cường quảng bá"… (12/60 câu bị hỏi lại); mẫu kế hoạch đổi thành "đồ uống chỉ 0,3 phần / đơn".
- Chấm kín 21 câu cạnh mốc 54: 10,76 → 10,67. Câu bị hỏi lại 10,83 → 11,00 (việc làm 0,83 → 1,08) — lợi nhỏ, tốn thêm 1 lần gọi GPT cho 1/5 câu; câu kế hoạch 10,67 → 10,22 → bỏ cả hai.
- Bài học: bỏ cụm chung chung không làm việc làm cụ thể hơn bao nhiêu; GPT thay bằng việc khác cũng chung.

### Lần 56 (01/11, Claude chấm kín, đã áp): quán nghỉ giữa ngày → nhãn khung giờ theo giờ có bán

- Gốc lỗi: nhãn khung cố định "Chiều (14–17h)" → quán C nghỉ 14–16h bị đề xuất giảm giá khung 14–17h (D28), khuyên "đóng ca từ 20h" (D18).
- Sửa: quán có giờ nghỉ giữa ngày (khoảng trống trong giờ có bán) → nhãn ghi giờ thật có bán + "quán nghỉ a–bh" (vd "Chiều (16–17h, quán nghỉ 14–16h)", "Tối (17–20h)"); quán khác giữ nhãn cũ. Chỉ khối 10 câu quán C đổi.
- Kết quả: chấm kín 10 câu × 2 lượt cạnh mốc 54: 9,6 → **10,3/16**; đúng quán 1,50 → 1,80; thận trọng 1,20 → 1,45; D18 2 / 4 → 11 / 8; D28 5 → 8. Nói tiếp (D57, D58) 10,5 → 9,0: ghi ca tối 17–20h thay vì 16–20h.
- Áp: `db-fix/boom_l56_ap_dung.sh` (TS 20261101_220542) — lần chạy đầu bị chặn ở bước triển khai, chạy lại sau khi Chủ Quán duyệt.

### Lần 57 (01/11, bỏ): hồ sơ quán tính sẵn từng ca (quán nghỉ giữa ngày)

- Sửa thử: hồ sơ quán C ghi "có bán 2 ca: ca sáng 6h–14h (110.927.000đ = 83,5%…), ca tối 16h–20h (21.873.000đ = 16,5%…)".
- Đúng mục tiêu: D18, D57 dùng đúng 21,9 triệu / 16–20h, hết "17–20h".
- Chấm kín 10 câu quán C × 2 lượt cạnh bản lần 56: 9,75 → 9,3 (dùng số 1,50 → 1,70 nhưng thận trọng 0,95 → 0,70, đúng quán 1,75 → 1,45): số ca tối nhỏ (16,5%) đặt ngay trong hồ sơ làm GPT nghiêng hẳn về "đóng ca tối", khuyên ẩn món đang bán → bỏ.
- Bài học: số đặt ở HỒ SƠ QUÁN (đầu khối) được GPT coi là kết luận; % nhỏ dễ thành "nên bỏ". Số ca nên chỉ đưa khi câu hỏi về ca (theo loại câu, như 45b).

### Tìm nguyên nhân (02/11): vì sao việc làm chung chung, lý lẽ yếu

- Lời nhắc câu tư vấn ~21.500 ký tự, 37 luật; câu phân tích có số liệu chỉ cần ~1/3. Giả thuyết "mini loãng chú ý" → lần 58 thử.
- Khối số liệu chỉ có kỳ trước dạng TỔNG (doanh thu, số đơn) → hỏi "sao giảm" thì không có số giảm ở giờ / thứ / món nào → GPT đoán, việc làm chung chung.
- Giới hạn suy luận của gpt-4o-mini (gpt-4o +0,8 cùng khối): đọc ngược tăng / giảm, so tổng tháng với trung bình ngày, gán % 3 ngày cho cả tuần.

### Lần 58 (02/11, bỏ): lời nhắc gọn cho câu phân tích có số liệu

- Bỏ luật không liên quan (phạm vi, từ chối, lao động, Excel, Tết, viết bài, khối không có…): lời nhắc 21.400 → 10.800 ký tự, token vào −29%.
- Chấm kín 55 câu: 12,40 → 12,22 (ngang) → độ dài lời nhắc KHÔNG phải nguyên nhân; bỏ (chỉ lợi chi phí).

### Lần 59 (02/11, Claude chấm kín, đã áp máy chủ; app 1.0.6 build 23 đã phát hành): số kỳ trước chia nhỏ

- App (`boom_read_only_data_service.dart`, `boom_chat_provider.dart`): kỳ trước đọc thêm `created_at` → `prev_by_hour`, `prev_by_weekday`; đọc món kỳ trước song song → `groups[].prev_revenue`, `moves` (≤ 6 món đổi doanh thu nhiều nhất), `prev_from` / `prev_to`.
- Máy chủ: `changeLine` — dòng "SO … — GIẢM / TĂNG Ở ĐÂU (tính sẵn)": 3 giờ đổi nhiều nhất theo chiều tổng, thứ giảm / tăng nhiều nhất (trung bình / ngày), từng nhóm, món đổi nhiều nhất. Chỉ câu chẩn đoán / so sánh / hỏi giảm, tụt, vì sao (đưa mọi câu: kế hoạch 11,83 → 10,17). Có `moves` thì bỏ câu "CHƯA có số từng món". App cũ không gửi → như trước.
- Bộ đề: dựng số kỳ trước cho quán A / B / C khớp vấn đề (A mất khách sáng 6–8h; B topping −30%; C tuần món thêm −52%, tháng Thứ 4 −40%); cập nhật ý chính D01, D05, D08, D32, D33, D38.
- Kết quả: chấm kín 14 câu nhận dòng (1 lượt): 11,43 → **11,71/16**; lý lẽ 0,79 → 1,14; tìm vấn đề 1,07 → 1,21; D01 10 → 15, D32 8 → 12. Còn yếu: đọc nhầm số kỳ trước (dùng số 1,79 → 1,64, D38), việc làm vẫn chung.
- Áp: `db-fix/boom_l59_ap_dung.sh` (TS 20261102_013340). Cần bản app mới để quán thật gửi số kỳ trước.

### Lần 60 (02/11, Claude chấm kín, đã áp): dòng tăng / giảm ghi theo chiều "kỳ trước → nay"

- Gốc lỗi: dạng "12h 2.319.000đ (kỳ trước 3.437.000đ, −1.118.000đ)" → GPT lấy số nay trừ tiếp phần chênh ("2.319.000đ xuống 1.201.000đ", D38); "giảm nhiều nhất Thứ 2" bị đọc thành "Thứ 2 thấp nhất" (D21).
- Sửa (`changeLine`): giờ / thứ / nhóm / món đều ghi "kỳ trước X → nay Y (chênh, %)"; dòng theo thứ ghi "đây là mức ĐỔI so kỳ trước, không phải thứ bán cao / thấp nhất", nhãn "giảm / tăng mạnh nhất".
- Kết quả: chấm kín 35 câu (1 lượt) cạnh bản lần 59: 11,57 → **11,66/16**; dùng số 1,63 → 1,77; việc làm 0,97 → 1,09; D21 6 → 11; chẩn đoán (5 câu) 12,0 → 11,0, kế hoạch (6 câu) 9,17 → 10,83. Còn yếu: bỏ sót nhóm giảm mạnh (Món thêm −52%), việc làm chung.
- Áp: `db-fix/boom_l60_ap_dung.sh` (TS 20261102_151258). Không cần bản app mới.

### Lần 61 (02/11, bỏ): nêu thẳng nhóm giảm mạnh nhất theo % kèm tiền / đơn

- Sửa thử (`changeLine`): sau dòng theo nhóm thêm "→ nhóm giảm mạnh nhất theo %: Món thêm −52,3%, tính trên mỗi đơn kỳ trước 3.481đ → nay 1.862đ" (cả khi tổng tăng, vd Topping −30,1% ở D05). Chỉ 9 câu có ≥ 2 nhóm và có nhóm giảm.
- Chấm kín 9 câu × 2 lượt cạnh bản lần 60: 12,17 → 11,83; lý lẽ 0,89 → 0,67; tìm vấn đề 1,39 → 1,33. Người chấm: cả hai bản vẫn bỏ sót Topping −30,1% (D05), Món thêm −52,3% (D38) → bỏ.
- Bài học: thêm một câu "điểm chính" vào cuối dòng dài không làm GPT nhắc tới; nhóm nhỏ (3–4% doanh thu) bị coi là không đáng kể. Muốn GPT dùng thì phải nằm trong kết luận "Phân tích tính sẵn" (đầu khối) — nhưng lần 57 cho thấy số đặt ở đầu khối dễ thành kết luận cứng → cần thử có kiểm soát.

### Lần 62 (02/11, Claude chấm kín, đã áp): mỗi đơn nhỏ đi → câu "Phân tích tính sẵn" nêu nhóm giảm mạnh nhất

- Sửa (`formatFacts`): câu chẩn đoán / so sánh / hỏi vì sao giảm, giá trị mỗi đơn giảm, có ≥ 2 nhóm → nối vào "Phân tích tính sẵn": "Giá trị mỗi đơn giảm đi cùng nhóm Topping giảm mạnh nhất (kỳ trước 9.086.000đ → nay 6.354.000đ, -30,1%) → mỗi đơn có ít Topping hơn; nêu nhóm này khi giải thích." Câu kế hoạch không có. 6/35 câu đề nhận dòng.
- Kết quả: chấm kín 6 câu × 2 lượt cạnh bản lần 60: 12,83 → **13,42/16**; tìm vấn đề 1,33 → 1,67; lý lẽ 1,17 → 1,50; D38 13 → 15 (2 lượt), D05 13 → 15 / 14. Còn yếu: việc làm chép "điểm cần chú ý" (tăng giá món) vào câu vì sao giảm; D54 vẫn khuyên tặng topping.
- Bài học (so lần 61): cùng một số, đặt ở câu KẾT LUẬN đầu khối thì GPT dùng, đặt cuối dòng dài thì bỏ qua.
- Áp: `db-fix/boom_l62_ap_dung.sh` (TS 20261102_155136). Không cần bản app mới.

### Lần 63 (02/11, bỏ): câu vì sao đổi → "điểm cần chú ý" ghi là chuyện riêng, việc chính nhắm chỗ đổi

- Sửa thử: khi có dòng "GIẢM / TĂNG Ở ĐÂU", đầu dòng điểm cần chú ý đổi thành "chuyện RIÊNG có từ trước, KHÔNG phải lý do doanh thu đổi … việc làm chính phải nhắm đúng giờ / nhóm / món đang đổi". 14/35 câu đổi.
- Chấm kín 14 câu × 2 lượt cạnh bản lần 62: 11,25 → 11,11; việc làm 0,75 → 0,64 (mục tiêu tụt); lý lẽ 0,96 → 0,86. GPT bớt chép "tăng giá Bạc xỉu" nhưng thay bằng việc chung / tặng kèm, không tự nghĩ ra việc nhắm đúng giờ / nhóm đang giảm → bỏ.
- Bài học: bảo GPT "đừng dùng X" không làm nó nghĩ ra việc đúng; muốn việc làm cụ thể phải tính sẵn VIỆC (giờ / nhóm / con số) như các lần 49–53, không chỉ nói hướng.
- Lỗi khác thấy khi chấm: D10 cả 4 bản nói "Nước chanh chưa bán" (thực bán 80 phần; chưa bán là Nước cam, Sữa đậu nành); D02 gán số riêng 14h, 15h cho cả khung 14–17h; D39 bỏ sót giá vốn Cơm sườn 48%.

### Lần 64 (02/11, Claude chấm kín, đã áp): tự kiểm món có bán bị gọi là "chưa bán"

- Gốc lỗi: D10 cả 4 bản (l60, l62, l63 × 2) nói "Nước chanh … chưa bán phần nào" — khối ghi "Bán ít nhất nhóm (có bán): Nước chanh (80 phần…). Chưa bán phần nào trong kỳ: 2 món: Nước cam, Sữa đậu nành"; GPT đọc lẫn hai vế liền nhau, có bản còn khuyên ẩn món đang bán.
- Sửa: `chuaBanSai` trong `kiemTraLoi` — vế câu (tách . ; , xuống dòng) có "chưa bán / chưa ai gọi / không bán được" và tên món mà khối ghi "(N phần" với N > 0 → hỏi lại 1 lần.
- Đo trên 214 câu trả lời cũ: bắt 4, cả 4 đúng lỗi (đều D10), không bắt nhầm. D10 × 4 lượt: bản cũ sai 4/4, bản mới đúng 4/4. Chấm kín 4 cặp: 8,25 → **10,5/16**; dùng số 0 → 1,75; lý lẽ 0,5 → 1,0.
- Áp: `db-fix/boom_l64_ap_dung.sh` (TS 20261102_160149). Không cần bản app mới.

### Lần 65 / 65b (02/11, Claude chấm kín, đã áp 65b): câu vì sao giảm → tính sẵn VIỆC nên nhắm + mốc đo

- Sửa (`formatFacts`, nối vào "Phân tích tính sẵn", chỉ câu vì sao / so sánh khi doanh thu giảm): mất khách (số đơn là chính) → "Việc nên nhắm (tính sẵn): kéo khách lại đúng 7h và 8h (giờ mất nhiều nhất) bằng ưu đãi khách quen / món chủ lực của chính khung đó; mốc đo: doanh thu 7h + 8h nay X, kỳ trước Y"; đơn nhỏ đi → "mời thêm Món thêm trong mỗi đơn …; mốc đo: nay 0,19 phần Món thêm / đơn". 65b: câu hỏi đã nói buổi / giờ (sáng, trưa, chiều, tối, giờ…) thì không đưa việc theo giờ.
- Kết quả: chấm kín 5 câu × 2 lượt cạnh bản lần 64: 11,7 → 12,2; D02 ("buổi chiều vắng") bị kéo sang 7–8h 9 → 6, 8 → 6 → thêm 65b (D02 về như cũ); 8 bài còn lại 12,5 → **13,75**, việc làm 0,75 → 1,0, lý lẽ 0,9 → 1,2. Chưa chấm lại bản 65b.
- Bài học (so lần 63): tính sẵn chính VIỆC (giờ / nhóm + mốc đo) thì việc làm cụ thể hơn; chỉ nói "đừng làm X" thì không. Còn yếu: GPT chép nguyên "ưu đãi khách quen / món chủ lực", chưa nêu món / mức ưu đãi.
- Áp: `db-fix/boom_l65_ap_dung.sh` (TS 20261102_161310). Không cần bản app mới.

### Lần 66 (02/11, bỏ): việc nên nhắm ghi tên 2 món chủ lực của khung giờ mất khách

- Sửa thử: thay "món chủ lực của chính khung đó" bằng tên 2 món bán chạy nhất của khung chứa giờ mất nhiều nhất (quán A: "Cà phê sữa đá, Bánh mì thịt"). Chỉ 3 câu đổi (D01, D32, D33).
- Chấm kín 3 câu × 2 lượt cạnh bản 65b: 13,33 → 13,33; việc làm 1,0 → 1,0. Người chấm: việc vẫn thiếu MỨC ưu đãi; có bản đẩy combo cà phê + bánh mì đang đắt hơn mua lẻ (rủi ro đã lường) → bỏ.
- Bài học: việc làm còn thiếu mức ưu đãi / con số chứ không thiếu tên món; lần sau thử ghi sẵn mức (vd giảm 3.000đ / ly cho khách quen 7–8h, thử 2 tuần) — chú ý không đè lên món giá vốn cao / combo đắt.

### Lần 67 (02/11, Claude chấm kín, đã áp): việc nên nhắm có sẵn mức làm thử và mục tiêu số

- Sửa (nối vào "Việc nên nhắm" của lần 65b): mất khách → "Mức làm thử: thẻ tích ly mua 8 tặng 1 hoặc bớt 2.000đ / đơn cho đơn trong 7h, 8h, chạy 2 tuần; giữ nếu doanh thu các giờ đó lên lại ≥ 1.475.000đ / ngày (nửa đường về mức cũ)" (ngưỡng tính theo NGÀY vì số giờ là của cả kỳ; thiếu ngày kỳ thì bỏ ngưỡng); đơn nhỏ đi → "mục tiêu sau 2 tuần 0,25 phần / đơn (+30%), không giảm giá Món thêm".
- Kết quả: chấm kín 4 câu × 2 lượt cạnh bản 65b: 12,88 → **13,75/16**; việc làm 0,88 → **1,62**; 7/8 bài khá hơn (D01 14 / 13 → 16 / 16, D38 15 → 16 cả 2 lượt). D32 lượt 1 13 → 10: khuyên tăng giá Cà phê sữa đá đang mất khách (lỗi có sẵn).
- Bài học (so lần 66): thứ GPT thiếu là MỨC và MỤC TIÊU bằng số, không phải tên món; ghi sẵn thì GPT chép đúng vào việc làm.
- Còn lại: khuyên tăng giá món đang mất khách (D32); lấy số phần một khung giờ làm số cả kỳ (D32 lượt 2: 620 phần sáng); câu so tuần không nói mới có 3 ngày (D33).
- Áp: `db-fix/boom_l67_ap_dung.sh` (TS 20261102_163311). Không cần bản app mới.

### Lần 68 (02/11, bỏ): tự kiểm khuyên tăng giá món đang mất khách

- Sửa thử: `tangGiaMatKhach` trong `kiemTraLoi` — vế câu có "tăng / nâng giá" + tên món mà dòng "món đổi nhiều nhất" ghi kỳ trước A phần → nay B phần (B < A), bỏ qua món có ghi giá vốn cao → hỏi lại. Đo 250 câu cũ: bắt 3, đều đúng (D32).
- D32 × 4 lượt: bản cũ sai 1/4; bản mới hết tăng giá nhưng chuyển sang GIẢM GIÁ 2.000đ / tặng kèm. Chấm kín 4 cặp: 10,0 → 9,5; việc làm 0,50 → 0,25 → bỏ.
- Bài học (giống lần 63): hỏi lại kiểu "đừng tăng giá" làm GPT lật sang giảm giá. Lời hỏi lại phải đưa VIỆC ĐÚNG có sẵn (vd chép "Việc nên nhắm" của khối), không chỉ cấm. D32 ("món nào giảm nhiều nhất") vẫn yếu: chỉ nêu 1 món, không nhắm 7–8h.

### Lần 69 (02/11, bỏ, không chấm): hỏi lại kèm "Việc nên nhắm" khi tăng giá món mất khách

- Sửa thử: như lần 68 nhưng chỉ bắt khi khối có "Việc nên nhắm (tính sẵn)" và lời hỏi lại đưa đúng việc đó ("cũng KHÔNG đổi sang giảm giá / tặng").
- D32 × 4 lượt: cả 4 khuyên "giảm giá 2.000đ Cà phê sữa đá" cả ngày (bản lần 67: 0/4 giảm giá, 1/4 tăng giá) → rõ kém, bỏ không cần chấm.
- Gốc thật của D32 ("món nào giảm nhiều nhất"): câu hỏi về MÓN nhưng việc tính sẵn là về GIỜ → GPT không dùng, tự nghĩ việc cho món (tăng / giảm giá). Hướng sau: câu hỏi món giảm → tính sẵn việc cho chính món giảm nhiều nhất (giờ món đó bán chạy, mời kèm, không đổi giá).

### Lần 70 (02/11, Claude chấm kín, đã áp): hỏi món giảm → tính sẵn việc cho chính món giảm nhiều nhất

- Sửa (`formatFacts`, thay việc theo giờ khi câu hỏi có "món"): "Việc nên nhắm cho món giảm nhiều nhất (tính sẵn): Cà phê sữa đá kỳ trước 1374 → nay 1150 phần — GIỮ GIÁ (tăng giá làm mất thêm khách, giảm giá làm mỏng lời); nhân viên mời Cà phê sữa đá kèm món đang bán chạy ở khung sáng (khung món này bán chạy), đưa lên đầu menu 2 tuần; mốc đo: nay ~288 phần / tuần, mục tiêu ~316 phần / tuần (nửa đường về mức cũ)". Món giảm nhiều nhất theo doanh thu trong `moves`; khung lấy từ `by_band`.
- Kết quả: chấm kín D32 4 cặp cạnh bản lần 67: 11,75 → **13,5/16**; việc làm 0,50 → 1,25; trả lời thẳng 1,25 → 2,0; tìm vấn đề 1,75 → 1,25 (không nhắc khung 6–8h, Bạc xỉu, Bánh mì thịt). Chỉ D32 trong đề nhận dòng.
- Bài học (so lần 68–69): việc tính sẵn phải KHỚP chủ đề câu hỏi (món ↔ món, giờ ↔ giờ) thì GPT mới dùng.
- Áp: `db-fix/boom_l70_ap_dung.sh` (TS 20261102_164150). Không cần bản app mới.

### Lần 71 (02/11, bỏ): kỳ chưa trọn — ghi "so 3 ngày với 3 ngày, tuần mới có 3/7 ngày" ngay trên dòng so kỳ trước

- Sửa thử: câu vì sao / so sánh, kỳ "Tuần này" / "Tháng này" so "Cùng kỳ" → nối "(so N ngày với N ngày cùng kỳ — tuần này mới có N/7 ngày, chưa phải cả tuần: nói rõ điều này khi so)" vào dòng kỳ trước. 13 câu đổi.
- Chấm kín 13 câu × 2 lượt cạnh bản lần 70: 10,77 → 10,35; thận trọng 0,85 → 0,73 (mục tiêu tụt); nói tiếp 9,75 → 7,75. Người chấm: cả 4 bài so tuần, cả 6 bài so tháng (D01, D05) hai bản đều KHÔNG nói kỳ chưa trọn → bỏ.
- Bài học: lời dặn "nói rõ khi so" đặt trong dòng số không được GPT chép (khác số / việc tính sẵn). Hướng còn lại: đưa vào bước tự kiểm (câu so kỳ chưa trọn mà câu trả lời không có "mới có / chưa trọn / N ngày" → hỏi lại), hoặc chấp nhận.

### Lần 72 (02/11, Claude chấm kín, đã áp): tự kiểm câu so tuần chưa trọn không nói số ngày

- Sửa: `tuanChuaTron` trong `kiemTraLoi` — khối có "Kỳ: Tuần này (a–b/…)" (1–5 ngày) + "Cùng kỳ tuần trước", câu trả lời nhắc "tuần trước" mà không có "mới có / chưa trọn / N/7 / N ngày đầu…" → hỏi lại: thêm ngay câu đầu "tuần này mới có N/7 ngày, so với N ngày cùng kỳ tuần trước".
- Đo 275 câu cũ: bắt 22 (D33 × 10, D38 × 10, D22, D47). D33, D38 × 2 lượt bản mới đều mở đầu "tuần này mới có 3/7 ngày…". Chấm kín 4 cặp cạnh bản lần 70: 13,0 → **14,0/16**; thận trọng 1,0 → 2,0; tiêu chí khác giữ nguyên.
- Bài học (so lần 71): lời dặn trong dòng số không được chép; tự kiểm + hỏi lại thì được (như lần 64).
- Áp: `db-fix/boom_l72_ap_dung.sh` (TS 20261102_165757). Không cần bản app mới.

### Lần 73 (02/11, Claude chấm kín, đã áp): tự kiểm gán số một giờ cho cả khung giờ

- Sửa: `soGioChoKhung` trong `kiemTraLoi` — vế câu có khung "a–b h" / "từ a h đến b h" (≥ 2 giờ) và số tiền đúng bằng doanh thu riêng 1 giờ trong khung (đọc dòng "Doanh thu theo giờ trong kỳ"), không có tổng khung → hỏi lại kèm "1.956.000đ là riêng 14h …; cả khung 14h–17h là 6.723.000đ". Khung a–b tính giờ a … b−1. Tách vế câu không cắt ở dấu chấm giữa hai chữ số (số tiền).
- Đo 275 câu cũ: bắt 9 (đều D02, đều đúng). D02 × 4 lượt: bản cũ sai 4/4, bản mới ghi đúng tổng 4/4. Chấm kín 4 cặp cạnh bản lần 72: 7,75 → **8,5/16**; dùng số 1,0 → 2,0; tìm vấn đề 1,0 → 2,0; đúng quán 1,0 → 0,5, việc làm 0,5 → 0,25 (combo cà phê + bánh mì sáng cho buổi chiều — lỗi có sẵn, 5/8 câu cả hai bản).
- Còn lại cho lần sau: D02 đẩy món buổi sáng cho buổi chiều dù đã có dòng "Món bán chạy theo khung giờ".
- Áp: `db-fix/boom_l73_ap_dung.sh` (TS 20261102_170408). Không cần bản app mới.

### Lần 74 (02/11, Claude chấm kín, đã áp): hỏi một buổi vắng → tính sẵn việc dùng đúng món của buổi đó

- Gốc lỗi: lời nhắc dặn "combo giờ vắng dùng đúng Combo tính sẵn", mà "Combo tính sẵn" ghép món chạy nhất CẢ NGÀY (quán A: Cà phê sữa đá + Bánh mì thịt = món sáng) → D02 ("buổi chiều vắng") đẩy combo sáng cho 14–17h (5/8 câu l72–73).
- Sửa (`formatFacts`, sau dòng "Món bán chạy theo khung giờ"): câu hỏi nhắc 1 buổi + vắng / ít khách / chậm / ế / cách nào / làm sao / kéo khách → "Việc nên nhắm cho buổi chiều (tính sẵn): khung 14–17h trung bình 240.000đ / ngày (7% doanh thu ngày); món bán chạy ĐÚNG khung này: Trà tắc, Cà phê sữa đá → ưu đãi chỉ trong 14–17h (vd mua 2 ly bớt 5.000đ, hoặc thẻ tích ly giờ này), chạy 2 tuần; mốc đo: giữ nếu ≥ 288.000đ / ngày (+20%). KHÔNG dùng món / combo bán chạy buổi sáng (Bánh mì thịt)". Bỏ món giá vốn > 35% (Bạc xỉu). "Có nên bỏ combo sáng" không nhận dòng; "toi" không dấu không tính là tối.
- Kết quả: chấm kín D02 4 cặp cạnh bản lần 73: 8,25 → **10,0/16**; đúng quán 0,25 → 2,0; việc làm 0,25 → 1,0. Còn yếu: chỉ 1 việc, không chép mốc giữ, câu đầu nói vòng.
- Áp: `db-fix/boom_l74_ap_dung.sh` (TS 20261102_170841). Không cần bản app mới.

### Mốc lần 74 (02/11, Claude chấm kín A/B đủ 60 câu cạnh bản lần 59): 11,4 → 11,8/16

- Cách đo: sinh 60 câu × 1 lượt bằng bản lần 74 (máy chủ hiện tại) và bản lần 59 (`de42ee6`), 4 người chấm kín song song.
- Tổng 11,4 → **11,8**; khá hơn 26, kém 17, bằng 17. So sánh 10,6 → **12,8**; kế hoạch 11,2 → 11,8; quyết định 12,3 → 12,6; dự báo 11,1 → 11,2; chẩn đoán 12,0 → 11,8; nói tiếp 11,2 → 10,6.
- Tiêu chí: việc làm 0,90 → 0,98; đúng quán 1,75 → 1,83; tìm vấn đề 1,22 → 1,28; lý lẽ 0,90 → 0,95 — vẫn là 2 tiêu chí thấp nhất.
- Lỗi lặp lại (4 người chấm): việc làm chung / chỉ 1 việc / thiếu mốc; bỏ sót vấn đề thứ hai có sẵn trong khối; "Vì sao" đoán mò; bịa "mỗi đơn chỉ 1 món" (D22, D27); hiểu "tiền giảm của mã" là hiệu quả (D37, D46); D57 ca tối 17–20h.

### Lần 75 (02/11, đã áp làm lưới an toàn, không chấm điểm): tự kiểm số phần món bị gọi là số đơn

- Sửa: `phanThanhDon` trong `kiemTraLoi` — "N đơn" trong câu trả lời mà khối không có "N đơn" nhưng có N là số phần ("N phần" hoặc "Tên N" của dòng "Món bán chạy theo khung giờ") → hỏi lại.
- Đo 395 câu cũ: bắt 2 (D57 "ca tối 210 đơn, ca trưa 520 đơn"; D18 "210 đơn"), đều đúng, không bắt nhầm. D57 × 4 lượt mỗi bản: cả hai không mắc → không chấm được; Chủ Quán duyệt áp vì chỉ chạy khi sai thật.
- Còn lại (câu nói tiếp D57): câu trước ghi ca tối 16–20h nhưng 2/4 lượt viết "17h đến 20h" (nhãn khung "Tối (17–20h)").
- Áp: `db-fix/boom_l75_ap_dung.sh` (TS 20261102_172212).

### Lần 76 (02/11, đã áp): câu nói tiếp "làm gì cho tăng" kế thừa ngữ cảnh giảm

- Lỗi: D51, D58 — lượt trước Boom vừa nói doanh thu giảm, Chủ Quán hỏi tiếp "vậy làm gì cho tăng" → câu mới không phải loại chẩn đoán nên khối không có "Việc nên nhắm (tính sẵn)"; GPT chép "điểm cần chú ý" (tăng giá Bạc xỉu, giấu món) hoặc tặng nước / trứng.
- Sửa: `formatFacts(f, now, question, truoc)`; `hoiVi` cũng bật khi lượt trước (`luotTruoc`: history + memory cuối) có "giảm / tụt" và câu mới hỏi làm gì / tăng / cách / sao để. `buildMessages`, `soLieuGoc`, `cham_tu_van.ts` truyền lượt trước.
- Chấm kín D51, D58 × 4 lượt cạnh lần 75: 10,4 → 12,6/16; việc làm 1,0 → 1,75; tìm vấn đề 0,6 → 1,1; 5 cặp khá hơn, 1 bằng, 2 kém 1 điểm (`cham_tu_van/ket_qua/l76_claude_20261102.json`).
- Còn lại: vẫn có lượt chép tăng giá Bạc xỉu / Cơm sườn từ điểm cần chú ý; D58 có lượt tặng nước chanh / trứng; D51 bỏ sót khung chiều vắng.
- Áp: `db-fix/boom_l76_ap_dung.sh` (TS 20261102_191549).

### Lần 77 (02/11, bỏ): bỏ gợi ý TĂNG GIÁ ở điểm cần chú ý khi quán mất khách

- Sửa thử: số đơn giảm + có việc kéo khách lại → lọc bỏ cảnh báo giá vốn "TĂNG GIÁ" (D51 chép thành việc ở l76).
- Chấm kín D01, D33, D51 × 4: 12,4 → 12,5/16, 10/12 cặp bằng; tăng giá 2/12 → 0/12 nhưng việc làm 1,17 → 1,00, tìm vấn đề 0,83 → 0,75 (mất điểm Bạc xỉu lời mỏng). Bỏ (`ket_qua/l77_claude_20261102.json`).

### Lần 78 (02/11, đã áp): quán mất khách → việc thứ hai hạ giá combo đắt hơn mua lẻ

- Lỗi (chấm l77): câu "làm gì cho tăng" chỉ 1 việc (thẻ tích ly 7–8h), bỏ sót combo cà phê sữa + bánh mì đắt hơn lẻ 2.000đ; có lượt khuyên "tạo combo" đã có.
- Sửa: nhánh mất khách của "Việc nên nhắm" thêm "Việc thứ hai (tính sẵn): hạ giá combo từ P xuống ≤ giá lẻ; mốc đo: N phần combo trong kỳ" khi có combo `price > retail`.
- Chấm kín D01, D33, D51 × 4 cạnh lần 76: 12,9 → 13,7/16; D51 10,5 → 12,75 (4/4 khá hơn); việc làm 1,00 → 1,42; tìm vấn đề 1,33 → 1,67; gọn 1,92 → 1,58 (`ket_qua/l78_claude_20261102.json`).

### Lần 79 (02/11, bỏ): việc thêm cho giờ chiều vắng ở câu "làm gì cho tăng"

- Sửa thử: 3 giờ vắng nhất đều 13–17h → "Việc thêm cho giờ vắng (tính sẵn)": tổng cả kỳ, % doanh thu, món chiều chạy, giờ vàng 2 tuần.
- Chấm kín D51 × 8 cạnh lần 78: 11,6 → 10,6/16 (1 hơn, 5 kém); câu dài hơn, bịa "giá vốn hợp lý" cho món không có giá vốn nhiều hơn. Bỏ — việc thứ ba làm loãng (giống l71: thêm dòng làm câu kém).

### Lần 80 (02/11, đã áp cùng 78): mốc doanh thu / ngày chỉ chia cho ngày có mở bán

- Lỗi (người chấm l79 nêu): mốc "giữ nếu ≥ X / ngày" chia cho mọi ngày trong kỳ; quán A nghỉ Chủ nhật → mốc thấp hơn thật ~14%.
- Sửa: `ngayMoBan(f)` bỏ thứ có `by_weekday` = 0; dùng cho mốc kéo khách (l67) và mốc một buổi (l74). Số phần / tuần của món (l70) vẫn theo tuần lịch.
- D01 1.475.000đ → 1.721.000đ / ngày; D02 288.000đ → 336.000đ / ngày. Sửa số, không chấm A/B.
- Áp 78 + 80: `db-fix/boom_l80_ap_dung.sh` (TS 20261102_193303). Lần áp đầu tự trả bản cũ vì hàm khởi động chậm hơn 8 giây → script hỏi lại tối đa 4 lần.

### Lần 81 (02/11, bỏ): tự kiểm khen món có lời / giá vốn hợp lý khi không có giá vốn

- Sửa thử: `loiKhongVon` trong `kiemTraLoi` (bắt 46/3.416 câu cũ, đều đúng) + đổi lời hỏi lại khuyên ngược ("đẩy món lời tốt hơn thay thế" — chính cụm này làm GPT gán "lời tốt" cho món không có giá vốn).
- Chấm kín D21, D22, D28, D51, D58 × 4: 11,0 → 10,55/16 (6 hơn, 9 kém); câu kế hoạch D21, D22 kém rõ. Hỏi lại một lần sửa không hết. Bỏ (`ket_qua/l81_claude_20261102.json`).

### Lần 82 (02/11, đã áp): ví dụ mẫu câu kế hoạch bỏ "(vì mỗi đơn chỉ có 1 món)", "Thứ 5–CN"

- Lỗi: 90/3.476 câu cũ (D22, D21, D28…) chép nguyên "(vì mỗi đơn chỉ có 1 món)" từ `MAU_KE_HOACH_TUAN` / `MAU_LOAI.ke_hoach` dù quán ~1,2–2 phần / đơn; mẫu "Thứ 5–CN" làm GPT xếp việc vào Chủ nhật quán nghỉ.
- Sửa: "(để tăng giá trị mỗi đơn)", "Thứ 5–6"; test giữ mẫu không có lại.
- Chấm kín 10 câu kế hoạch × 3 cạnh lần 80: 10,8 → 10,77/16 (ngang); "mỗi đơn 1 món" 4/30 → 0/30. Giữ như sửa lỗi (`ket_qua/l82_claude_20261102.json`).

### Lần 83 (02/11, đã áp): việc tính sẵn cho đúng thứ được hỏi

- Lỗi: D28 "kế hoạch cho ngày thứ 4 để bớt ế", D08 "thứ 4 sao bán ế" — việc chung cả tuần, tặng kèm Cơm sườn (giá vốn 48%).
- Sửa: câu hỏi nhắc một thứ < 85% ngày thường (trung vị) + từ kế hoạch / làm gì / ế / vắng… → "Việc nên nhắm cho Thứ X (tính sẵn)": mức / ngày, % ngày thường, nhập nguyên liệu + xếp người theo mức đó, ưu đãi chỉ ngày đó, không dùng món giá vốn cao, mốc nửa đường sau 4 tuần. Tính cả thứ của hôm nay (bộ đề: hôm nay là Thứ 4).
- Chấm kín D08, D28 × 6 cạnh lần 82: 7,6 → 12,75/16, 12/12 khá hơn; tìm vấn đề 0,75 → 2,0; việc làm 0,5 → 1,83 (`ket_qua/l83_claude_20261102.json`).

### Lần 84 (02/11, đã áp): thứ yếu so kỳ trước — "mới tụt", hỏi lý do

- Lỗi (chấm l83): GPT nói "Thứ 4 thường vắng" dù kỳ trước 4.785.750đ / ngày; không hỏi lý do.
- Sửa: dòng việc cho thứ yếu thêm "Kỳ trước Thứ X trung bình … → MỚI tụt kỳ này (−%), không phải vốn vắng; … hỏi chủ quán Thứ X vừa qua có gì khác" khi kỳ trước cao hơn > 15%.
- Chấm kín D08, D28 × 6 cạnh lần 83: 10,4 → 12,5/16 (10 hơn, 1 kém); thận trọng 0,83 → 1,67 (`ket_qua/l84_claude_20261102.json`).

### Lần 85 (02/11, đã áp): việc tính sẵn cho nhóm món được hỏi bán thêm

- Lỗi: D27 "muốn bán thêm nước uống", D24 "tăng bán topping" — quảng bá chung, không nêu nhóm chỉ ~7% / 4% doanh thu, có lượt đẩy món cả kỳ chưa bán.
- Sửa: câu bán thêm / tăng / kế hoạch nhắc tên nhóm (hoặc nước / uống) không phải nhóm lớn nhất → "Việc nên nhắm cho nhóm X (tính sẵn)": % doanh thu, phần / đơn, món nên mời (giá ≥ trung vị nhóm, bán nhiều nhất, không giá vốn cao) kèm món chủ lực, phần ghép −5%, không đẩy món chưa bán, mốc +30% phần / đơn.
- Chấm kín D24, D27 × 6 cạnh lần 84: 8,1 → 11,2/16 (10 hơn, 0 kém); lý lẽ 0,5 → 1,5 (`ket_qua/l85_claude_20261102.json`).

### Lần 86 (02/11, bỏ): lịch nhập tính sẵn cho câu nhập hàng

- Sửa thử: `formatModules(m, now, question)` — hỏi "nhập" + có hao hụt → "Lịch nhập tính sẵn: (1) nhập ngay hàng dưới tối thiểu; (2) hàng hao hụt đặt theo ngày; mốc hao hụt giảm nửa".
- Chấm kín D29, D44 × 6: 10,5 → 10,33/16 (3 hơn, 6 kém); gọn 1,67 → 0,92 (lặp số). Bỏ.
- Áp 82–85: `db-fix/boom_l85_ap_dung.sh` (TS 20261102_213043).

### Lần 87 (02/11, đã áp): câu quyết định không kèm số liệu → "Chưa có số để quyết"

- Lỗi: D13 "quán gần văn phòng, chủ nhật có nên mở bán" 4–5/16 — khung quyết định LỚN bắt dòng đầu "Số đang nghiêng về …" nên GPT nói số nghiêng khi không có số, đòi số Chủ nhật quán chưa từng mở.
- Bản đầu (thêm nhánh vào khung chung): 30 câu quyết định 11,8 → 13,1 nhưng D11 "bỏ combo sáng" 12,3 → 10 (né kết luận dù có số).
- Sửa: `QUYET_KHONG_SO` chỉ nối vào khung khi câu quyết định KHÔNG có facts lẫn modules. Câu có số giữ nguyên lời nhắc.
- Chấm kín D13 × 3 cạnh lần 85: 4 → 15/16 (`ket_qua/l87_claude_20261102.json` 30 câu bản đầu, `l87d_…` bản cuối).

### Lần 88 (02/11, đã áp): hỏi có nên đóng một buổi; "ca toi" không dấu

- Lỗi: D18 "ca toi co nen dong luon ko, ban it qua" — "toi" không dấu bị loại (sợ là "tôi") nên không có việc tính sẵn cho buổi; GPT bịa "số đơn đang giảm", lấy 12h làm doanh thu tối.
- Sửa: "ca toi" / "buoi toi" là buổi tối; khung tối cắt theo giờ bán cuối (17–20h, không 17–24h); hỏi đóng / nghỉ → "Quyết định đóng buổi (tính sẵn)": mức / ngày, %, món chạy, CHƯA đóng ngay, so tiền người + gas + điện / ngày, thử rút giờ vắng nhất. Ví dụ ưu đãi theo loại quán (ly / phần).
- Chấm kín D18 × 6 cạnh lần 85: 3,7 → 12,5/16 (`ket_qua/l88_claude_20261102.json`).

### Lần 89 (02/11, đã áp): hỏi đổi mối vì hao hụt

- Lỗi: D20 "bún tươi hao hụt nhiều, có nên đổi mối" — "số nghiêng về đổi mối" khi khối chỉ có số hao hụt.
- Sửa: `formatModules(m, now, question)`; câu đổi mối / nhà cung cấp + có hao hụt → "Quyết định đổi mối (tính sẵn)": chưa đủ số để đổi, hao hụt hàng tươi thường do nhập dư → đặt theo ngày 2 tuần rồi mới so mối. `buildMessages`, `soLieuGoc`, `cham_tu_van.ts` truyền câu hỏi.
- Chấm kín D20 × 6 cạnh lần 85: 7,7 → 12,8/16 (`ket_qua/l89_claude_20261102.json`).

### Lần 90 (02/11, đã áp): hỏi dự báo chi tháng sau

- Lỗi: D50 "tháng sau tiền chi nguyên liệu chắc tăng bao nhiêu" — GPT tự đặt 68–70 triệu từ 2 kỳ.
- Sửa: câu tháng sau / dự báo + chi / nhập / nguyên liệu → "Dự báo chi tháng sau (tính sẵn)": khoản đó chỉ có 2 kỳ, không tự đặt số; mốc "giá nhập giữ thì như tháng này"; việc đối chiếu hoá đơn nhập theo tuần.
- Chấm kín D50 × 6 cạnh lần 85: 7,3 → 13,0/16 (`ket_qua/l90_claude_20261102.json`).

### Lần 91 (02/11, bỏ): ghi thứ cho ngày lễ, thêm lễ được hỏi ngoài 45 ngày

- Sửa thử: `todayBlock(now, question)` ghi "(Thứ Năm)" sau mỗi ngày lễ; câu nhắc noel / tết / tháng N lấy thêm lễ trong 120 ngày.
- Chấm kín D45 × 6: 9,0 → 9,5/16 — GPT vẫn không nêu thứ của 24–25/12, câu vẫn chung chung; đổi dòng HÔM NAY của mọi câu → bỏ.
- Áp 87–90: `db-fix/boom_l90_ap_dung.sh` (TS 20261102_222401).

### Lần 92 (02/11, đã áp): so hai món được hỏi

- Lỗi: D39 "cơm sườn với bún bò món nào lời hơn" — GPT không nêu giá vốn cơm sườn 48%, không nói chưa so được vì thiếu giá vốn bún bò, khuyên chủ tự nếm.
- Sửa: câu nhắc đúng 2 món (khớp 2 chữ đầu tên) + "với / hay / so / nào" → "So 2 món (tính sẵn)": số phần, món bán nhiều hơn; đủ giá vốn thì lãi gộp / phần, thiếu thì "CHƯA so được món nào lời hơn — xin nhập giá vốn"; "ngon hơn" app không đo.
- Chấm kín D39 × 6: 5,5 → 9,7/16 (`ket_qua/l92_claude_20261102.json`).

### Lần 93 (02/11, đã áp): thu − chi đổi do thu hay do chi

- Lỗi: D03 "thu chi sao dư ít hơn tháng trước" — GPT tự trừ sai (16.343.000đ), bỏ sót tiền điện tăng mạnh theo %.
- Sửa: câu thu / chi / dư / lời + so / sao / giảm / tăng (không phải tháng sau, "nếu") → "Phân tích tính sẵn: thu − chi đổi ±X = thu …, chi … → nguyên nhân chính là THU / CHI; khoản tăng mạnh nhất theo %".
- Chấm kín D03, D09, D34, D40: 10,83 → 11,0/16; lỗi trừ sai 16,3 triệu 3 → 0 (`ket_qua/l93_claude_20261102.json`).

### Lần 94 (02/11, bỏ): doanh thu theo ca khi hỏi một ca

- Sửa thử: D57 nhận ca được hỏi (lấy ca nhắc sớm nhất). Chấm kín 7,5 → 8,5/16, GPT vẫn lấy ca trưa → bỏ.

### Lần 95 (02/11, đã áp): nhóm món — "bán ít", "gọi thêm", tên nhóm từ lượt trước

- Lỗi: D10 "do uong ban it qua phai ko" (không dấu, "bán ít") và D54 "lam sao de khach goi them" (nhóm topping ở lượt trước) không nhận dòng việc cho nhóm (lần 85).
- Sửa: thêm "bán ít / gọi thêm"; câu không nhắc nhóm thì lấy tên nhóm trong 12 chữ đầu lượt trước.
- Chấm kín D10, D54 × 6: 9,3 → 13,75/16; D54 6,8 → 14,8 (`ket_qua/l95_claude_20261102.json`).

### Lần 96 (03/11, đã áp): kho, hao hụt, nhập hàng tính sẵn

- Lỗi: D44 bịa "nhập 5 kg trân châu đủ dùng tháng 11"; D04 tự phán hao hụt "khá cao so với bình thường"; quên hao hụt nấu dư và hàng sắp hết.
- Sửa: câu kho / hao hụt / nhập / sắp hết / tồn (chữ "kho" đứng riêng, không bắt "khoản") → "Kho tính sẵn": tổng hao hụt, số bỏ đi mỗi ngày, việc theo loại hàng (nấu dư → mẻ nhỏ theo giờ đông; hàng tươi → đặt theo ngày); hàng cần nhập xếp theo còn / tối thiểu, số ít nhất để lên mức tối thiểu; hỏi nhập bao nhiêu tháng sau → nêu cách tính, không đặt số. Chỉ hỏi hao hụt thì không nhắc hàng cần nhập. Hàm `soNgay(period)`.
- Chấm kín D04, D44, D53 × 4: 8,8 → 11,6/16; đúng số 1,33 → 2,0 (`ket_qua/l96_claude_20261103.json`). Kiểm D29 (lịch nhập gas, gạo) × 4: 11,75 → 10,75, chênh ở "gọn", trong dao động (`l97_claude_20261103.json`).

### Lần 97 (03/11, đã áp): hỏi cắt bớt người

- Lỗi: D17 "ca nhiều quá, có nên cắt bớt 1 người" — GPT tự đặt ngưỡng "trên 30 / dưới 20 ca", nói "không ai làm quá nhiều" dù Ngọc ~58 giờ / tuần.
- Sửa: câu cắt / bớt / giảm / cho nghỉ + người / nhân viên / ca → "Quyết định cắt người (tính sẵn)": kết luận CHƯA nên cắt ngay khi bớt 1 người làm người còn lại quá 48 giờ / tuần; giờ / người / tuần, ca lệch nhiều nhất – ít nhất, giờ dồn khi bớt 1 người; việc: chia lại ca, sửa ca quên chấm ra, rút 1 người ở giờ vắng 2 tuần.
- Bản đầu: 6/6 câu mở "nghiêng về cắt" (9,6 → 11,6 gồm D29). Ghi rõ kết luận trong dòng → chấm kín D17 × 6: 7,3 → 14,2/16, 6/6 khá hơn (`ket_qua/l97b_claude_20261103.json`).
- Áp 92–97: `db-fix/boom_l97_ap_dung.sh` (TS 20261103_003836).

### Lần 98 (03/11, đã áp): kế hoạch cho một dịp

- Bỏ thử trước đó: D59 "khoản chi nguyên liệu chi tiết hơn" (nối phiếu nhập theo nhà cung cấp) — app chỉ gửi phần thu chi cho câu này, dòng không tới Boom; D48 "cả ngày được bao nhiêu" — khối hôm nay không có giờ mở ca tối. Cả hai cần sửa app, chưa làm.
- Lỗi: D30 "sắp tới 20/11 quán bún có nên làm gì" — GPT rải "Tuần 1–3" (cả sau ngày lễ), nhắm khách giáo viên dù quán gần chợ, giảm giá toàn menu, mời ăn miễn phí.
- Sửa: câu kế hoạch nhắc ngày / dịp (dd/mm, tết, noel, trung thu…), không phải tuần / tháng sau → thêm `KE_HOACH_DIP`: chỉ tới ngày đó (trước 3–7 ngày, đúng ngày, 1–2 ngày sau đo); dịp không hợp khách chính → làm nhẹ, có điều kiện, không tặng món chính, không quảng cáo tốn tiền.
- Chấm kín D30 × 6: 4,8 → 11,3/16, 6/6 khá hơn (`ket_qua/l98_claude_20261103.json`). Còn lỗi: nói sai thứ của 20/11 (Thứ Sáu).

### Lần 99 (03/11, đã áp): so cuối tuần – ngày thường

- Lỗi: D36 "cuối tuần với ngày thường khác nhau nhiều không" — GPT gọi tổng tháng là trung bình ngày, so tổng Chủ nhật với Thứ 2, đoán do số đơn, khuyên ưu đãi cuối tuần (đã đông nhất).
- Sửa: câu nhắc cuối tuần / ngày thường → "So cuối tuần – ngày thường (tính sẵn)": trung bình / ngày Thứ 2–6 và Thứ 7–CN (chỉ thứ có ≥ 2 ngày), gấp mấy lần; không nói do số đơn; việc: thêm người / nguyên liệu cuối tuần, ưu đãi ngày yếu nhất với mốc đo.
- Chấm kín D36 × 6: 8,2 → 13,3/16, 6/6 khá hơn (`ket_qua/l99_claude_20261103.json`).

### Lần 100 (03/11, đã áp): khách quay lại

- Lỗi: D06 "khách quay lại nhiều ko" — GPT so 210 khách quay lại (cộng dồn) với 240 khách mới (trong kỳ); việc chung chung; D25 đề xuất làm thẻ tích điểm dù quán đã có.
- Sửa: câu quay lại / khách quen / giữ khách → "Giữ khách (tính sẵn)": tỉ lệ cộng dồn, không so với khách mới; quán đã có tích điểm hay chưa (không khẳng định lý do); việc theo đó; mốc đo tỉ lệ +3 điểm sau 2 tháng.
- Chấm kín D06, D25 × 5: 9,0 → 13,8/16, 10/10 khá hơn (`ket_qua/l100_claude_20261103.json`). Còn lỗi: gọi cả 1.320 khách có điểm là "lâu chưa ghé".
- Áp 98–100: `db-fix/boom_l100_ap_dung.sh` (TS 20261103_010342).

### Lần 101 (03/11, đã áp): sửa 4 lỗi khi hỏi Boom thật (quán KAY-Rạch Giá, web)

- Hỏi thật 5 câu trên Chrome sau khi áp 98–100. Câu 20/11 đã theo khung 3 mốc (lần 98). Lỗi lộ ra:
  1. Kho: tồn −1 phần, tối thiểu 1000 → "nhập ít nhất 1001 phần" (dòng lần 96 trừ số âm).
  2. "Tháng này cuối tuần với ngày thường" ngày 03/11: kỳ mới 3 ngày, dòng lần 99 không bật (đúng) nhưng GPT so 1 Chủ nhật với 1 Thứ 2, khuyên khuyến mãi Thứ 2.
  3. "Khách quay lại": app không gửi số khách cho quán này (chưa rõ do chưa bật mục Khách hàng / quyền hay chưa lưu khách — không đọc được database thật).
  4. "Tháng trước thu chi sao": chi 0đ (chưa ghi phiếu chi) không được nhắc; dòng lần 93 nằm trong điều kiện "có khoản chi" nên mất → GPT nói ngược chiều ("tháng 9 thu tăng 76%").
- Sửa: tồn âm ghi "tồn ÂM (số kho sai — kiểm lại)", số cần nhập tính từ 0; câu cuối tuần / ngày thường mà mỗi thứ < 2 ngày → "CHƯA đủ số để so", không so 1 ngày với 1 ngày; dòng lần 93 dời ra ngoài, ghi rõ kỳ nào so kỳ nào và "THU GIẢM / CHI TĂNG" (không nói ngược chiều); chi 0đ → "quán CHƯA ghi phiếu chi, thu − chi không phải tiền dư"; quán có mục khách mà 0 khách → "chưa lưu khách, chưa đo được".
- Chấm kín lại 4 câu thu chi lần 93 (D03, D09, D34, D40) × 3: 10,8 → 11,8/16 (`ket_qua/l101_claude_20261103.json`). Còn: việc làm câu thu chi chung chung; D40 "có lời hơn ko" chưa trả lời thẳng "không".
- Áp: `db-fix/boom_l101_ap_dung.sh` (TS 20261103_012720).

### Lần 102 (03/11, đã áp): đếm số ngày theo nhãn kỳ app thật

- Hỏi thật lần 2 (7 câu, quán KAY-Rạch Giá): doanh thu giảm / thu chi / so 2 món đúng bài; "có nên cắt bớt 1 người" KHÔNG có dòng lần 97 → Boom nói "số đang nghiêng", "không có ai đi trễ" (đều đã cấm).
- Nguyên nhân: `soNgay` (lần 96) chỉ đọc nhãn bộ đề "(1–28/10/2026)"; app thật gửi "Tháng trước (tháng 10)", "Tháng này (1/11–3/11)", "Tháng 9 (1/9/2026–30/9/2026)", "Tuần trước (27/10–2/11)" → 0 ngày → dòng "Quyết định cắt người" (lần 97) và "~x / ngày" hao hụt (lần 96) chưa từng chạy trên app thật.
- Sửa: `soNgay` đọc khoảng "d/m–d/m", "d/m/y–d/m/y", "d–d/m/y" và "tháng N" (số ngày của tháng). Test theo đúng 4 kiểu nhãn app.
- Lỗi phía app (chưa sửa, cần bản app sau): "tháng trước cuối tuần với ngày thường khác nhau nhiều không" bị hiểu là hỏi cách dùng app; "tháng trước … dư ít hơn tháng 9 không" lấy nhầm kỳ tháng 9 so tháng 8. Quán Rạch Giá tắt mục Khách hàng → câu khách quay lại báo đúng.
- Bài học: kiểm dòng tính sẵn bằng nhãn kỳ / dữ liệu đúng như app thật gửi, không chỉ bằng bộ đề mẫu.
- Áp: `db-fix/boom_l102_ap_dung.sh` (TS 20261103_014819).

### Lần 103 (03/11, đã áp): hao hụt món chưa có giá vốn không phải 0đ

- Hỏi thật (quán KAY-Rạch Giá) sau lần 102: "Quyết định cắt người" đã hiện (19 người, ~22 giờ / người / tuần, bớt 1 người còn ~23 giờ). Câu "tháng trước kho hao hụt nhiều không": các món hao hụt (cơm sườn cọng 49 phần…) ghi giá trị 0đ vì chưa nhập giá vốn → Boom kết luận "không hao hụt nhiều về giá trị"; dòng "Kho tính sẵn" (lần 96) bỏ qua vì chỉ lấy món có giá trị > 0.
- Sửa: dòng hao hụt ghi "(chưa có giá vốn → chưa tính được tiền, KHÔNG phải 0đ)"; "Kho tính sẵn" dùng mọi phiếu hao hụt có số lượng (tính ~x / ngày), có món chưa giá vốn thì nhắc tiền thật cao hơn, không nói "không mất tiền".
- Hỏi thật thêm: "món ế, có nên bỏ" và "món nào lời nhất" đúng bài. 4 lỗi phía app (chưa sửa): câu cuối tuần / ngày thường bị hiểu là hỏi cách dùng app; câu có "tháng trước" và "tháng 9" lấy nhầm kỳ; "món nào giảm nhiều nhất" app tự trả mẫu tổng doanh thu; "buổi chiều vắng, có cách nào" app không gửi số liệu.
- Áp: `db-fix/boom_l103_ap_dung.sh` (TS 20261103_023718).

### Giai đoạn 4: Hiểu riêng từng quán (lần 38–44)

| # | Việc | Áp lên đâu |
|---|---|---|
| 38 | **Hồ sơ quán tự suy**: loại quán (từ nhóm món), giá trung bình, giờ mở thật (từ giờ có bán), ngày nghỉ, số món, có giao hàng / QR không. Gửi 2–3 dòng đầu mỗi câu tư vấn | app |
| 39 | **Chủ quán tự khai một lần** (Boom hỏi khi phù hợp): mục tiêu (tăng khách / tăng lãi / giảm việc), khu vực (văn phòng / trường / dân cư), tiền mặt bằng | app + db |
| 40 | **Nhớ lời khuyên đã đưa**: lưu tóm tắt "đã đề xuất gì, ngày nào" (không lưu số) | máy chủ + db |
| 41 | **Theo dõi kết quả**: lần sau Boom so số trước / sau ("tuần trước đề xuất combo sáng: combo bán 34 phần, doanh thu sáng +12%") | app + máy chủ |
| 42 | Mùa vụ của quán: thứ / tháng mạnh yếu riêng của quán (từ chuỗi tháng), không chỉ ngày lễ chung | app |
| 43 | Cách xưng hô, độ dài, mức chi tiết theo người hỏi (chủ / quản lý / nhân viên) | máy chủ |
| 44 | Chấm GPT thật lần 3 (thêm 10 câu đòi hỏi hiểu quán) | — |

### Giai đoạn 5: Chủ động (lần 45–48). Tính năng mới, mỗi mục hỏi duyệt riêng

| # | Việc | Áp lên đâu |
|---|---|---|
| 45 | **Tóm tắt tuần**: sáng thứ Hai Boom gửi 5 dòng (doanh thu tuần, bất thường, 1 việc nên làm) khi chủ quán mở app | app + máy chủ |
| 46 | **Cảnh báo sớm**: hàng sắp hết theo tốc độ bán, ngày tụt mạnh, chi phí vượt mức thường | app |
| 47 | **Gợi ý câu hỏi tiếp theo** theo ngữ cảnh (nút sau câu tư vấn: "Món nào kéo giảm?", "Lên kế hoạch tuần sau") | app |
| 48 | Nút "Đã làm theo" cho việc Boom đề xuất, để lần 41 theo dõi | app + db |

### Giai đoạn 6: Học từ người dùng thật (lần 49–50, rồi lặp mãi)

| # | Việc | Áp lên đâu |
|---|---|---|
| 49 | Mỗi tuần một lần "duyệt Boom": câu bị 👎, câu chưa trả lời được, câu hỏi thật mới. Gom thành bài kiểm và câu đề mới; Chủ Quán duyệt mới áp (quy trình đã có) | tuỳ |
| 50 | Tổng kết: chấm lại toàn bộ đề, so mốc gốc từng tiêu chí; lập kế hoạch vòng sau | — |

---

## 4. Việc cần Chủ Quán duyệt

| Việc | Khi nào |
|---|---|
| Chấm bằng GPT thật (tốn khoảng 1 USD mỗi lần; Chủ Quán tự dán khoá) | Lần 4, 37, 44, 50 và khi so mô hình (33) |
| Triển khai lại hàm boom-chat (đổi lời nhắc / định dạng số) | Cuối Giai đoạn 2, 3, 4 |
| Thêm hàm đọc số / migration trên database | Lần 18, 19, 24, 39, 40, 48 |
| Đưa web /pos | Cuối mỗi giai đoạn |
| Tính năng mới (Giai đoạn 5) | Từng mục |
| Đổi mô hình sang gpt-4o (tăng chi phí) | Lần 33 |

## 5. Cách làm để nhanh và ít token

- Không chẩn đoán lại sau mỗi lần dạy. Kế hoạch đã ghi việc và câu mẫu.
- Đo gộp **một lệnh** cuối mỗi giai đoạn. Chấm GPT thật chỉ ở các mốc đã ghi.
- Mỗi giai đoạn có QC độc lập **một lần** và bộ kín mới viết trước khi sửa.
- Thứ tự trong giai đoạn có thể đổi theo điểm chấm mốc gốc, nhưng không thêm vòng chẩn đoán.

## 6. Rủi ro

- **Lời nhắc dài hơn → tốn token hơn mỗi câu.** Bù bằng cách chỉ gửi phần khung / mẫu đúng loại câu.
- **Thêm số → tăng dữ liệu gửi OpenAI.** Lần 27 rà riêng tư trước khi áp.
- **gpt-4o đắt hơn gpt-4o-mini nhiều lần.** Chỉ dùng cho câu khó, và Chủ Quán quyết sau khi xem điểm và chi phí.
- **Hồ sơ / trí nhớ dài hạn** (38–41) cần bảng mới trên database. Làm theo quy trình migration, hỏi trước khi áp.
