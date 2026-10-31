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
