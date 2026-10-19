# 🐘 Module: AI Bum (Trợ Lý AI)

**Trạng thái:** ✅ Hoàn thành  
**Cập nhật:** 09/09/2026 (Cập nhật chuẩn Lego Modules theo qn.md; chuẩn hoá thông tin nền tảng: AI Bum dùng Qwen2.5 làm base model qua framework Unsloth; tích hợp 26 chuyên đề F&B; chốt cơ chế phân quyền Manager theo fail-closed)

---

## 1. Mục Đích
Quản lý trợ lý AI Bum, cấu hình bật/tắt module AI theo vai trò nhân viên trong hệ thống Lego Modules, phân quyền 9 hành động nhạy cảm, và trang bị cho AI Bum năng lực cố vấn vận hành nhà hàng - quán ăn toàn diện. AI Bum sử dụng base model Qwen2.5, được nạp và tối ưu huấn luyện/suy luận bằng framework **Unsloth**, kết hợp kho tri thức 26 chuyên đề F&B bách khoa toàn thư quốc tế và tuân thủ nghiêm ngặt hệ thống pháp lý Việt Nam.

---

## 2. Tính Năng Chính
- Công tắc bật/tắt module AI Bum (`ai_bum`) theo vai trò trong **Quản lý Vai trò** (`role_manager_screen.dart`), lưu trữ trực tiếp tại danh sách Lego Modules (`store_roles.modules` — Single Source of Truth).
- Hiển thị danh mục module AI Bum và 9 hành động nhạy cảm trong **Phân Quyền Nhân Viên** (`nhan_vien_screen.dart`).
- **Single Source of Truth**: Phân quyền nhân viên cấu hình trực tiếp qua Lego Modules; không tạo hay phụ thuộc vào bảng phụ `app_settings` (`action_perms_*`).
- **Pre-Query Security Guard**: Kiểm tra quyền truy cập của người dùng ngay trước khi thực thi các truy vấn dữ liệu kinh doanh.
- **Read-Only Guarantee**: AI Bum chỉ thực hiện đọc dữ liệu (`BumReadOnlyDataService`), không được tạo/sửa/xóa/duyệt dữ liệu, không tự ý can thiệp CSDL POS hay trừ kho.
- **Fail-Closed Auto-Seed**: Khi module `ai_bum` được bật từ OFF $\rightarrow$ ON, tự động cấp 3 quyền an toàn cá nhân (`help`, `my_shift`, `my_payroll`).
- **Missing-Data Guard (Cảnh báo thiếu dữ liệu $\ge 25\%$)**: Nhận diện dữ liệu thiếu trước khi kết luận nguyên nhân hoặc đề xuất giải pháp nghiệp vụ.
- **Cross-Store Isolation Guard**: Cô lập ranh giới đa chi nhánh (`store_id`), tuyệt đối không làm lộ dữ liệu của chi nhánh khác cho nhân sự không có quyền.
- **Khung tối ưu huấn luyện và suy luận Unsloth**: Dùng Qwen2.5 làm base model, tăng tốc huấn luyện và tiết kiệm VRAM theo công bố tham khảo của Unsloth (~70% VRAM, 2–5x tốc độ trong điều kiện tối ưu; chưa benchmark nghiệm thu trên RTX 2060 BunServer).
- **Encyclopedic F&B Advisory Engine**: Tích hợp tri thức 26 Chuyên đề nghiệp vụ, 108 nguồn thẩm quyền và 17 Cây ma trận quyết định phản xạ thực chiến qua kiến trúc RAG & SFT.

---

## 3. 🔑 9 Hành Động Nhạy Cảm (`ai_bum.*`)

| Action Permission | Tên Hành Động | Mức Độ | Mô Tả & Kiểm Soát |
|---|---|---|---|
| `ai_bum.help` | Trợ giúp & Hướng dẫn | An toàn (Auto-seed) | Hỏi đáp về tính năng, thao tác sử dụng app. |
| `ai_bum.my_shift` | Ca làm cá nhân | An toàn (Auto-seed) | Hỏi lịch làm việc, ca làm của chính mình. |
| `ai_bum.my_payroll` | Lương cá nhân | An toàn (Auto-seed) | Hỏi thông tin bảng lương, thu nhập cá nhân. |
| `ai_bum.team_shift` | Ca làm toàn quán | Nhạy cảm | Hỏi lịch làm việc của đồng nghiệp / toàn quán. |
| `ai_bum.sales` | Doanh thu & Bán hàng | Nhạy cảm | Hỏi báo cáo doanh thu, số đơn, mặt hàng bán chạy. |
| `ai_bum.inventory` | Kho hàng | Nhạy cảm | Hỏi tồn kho, nguyên liệu sắp hết, báo cáo kho. |
| `ai_bum.finance` | Thu chi & Tài chính | Nhạy cảm | Hỏi báo cáo dòng tiền, các khoản thu/chi. |
| `ai_bum.operations` | Nhiệm vụ Vận hành | Nhạy cảm | Hỏi tiến độ hoàn thành nhiệm vụ vận hành toàn quán. |
| `ai_bum.all_payroll` | Lương toàn bộ nhân viên | Rất nhạy cảm | Hỏi chi tiết bảng lương, thu nhập của nhân viên khác. |

---

## 4. Quy Tắc Kiểm Soát Vai Trò (Role Control Rules)

Quy tắc phân quyền tuân thủ nghiêm ngặt chuẩn **Lego Modules** (`qn.md`):

1. **Lego Modules (`store_roles.modules`) là nguồn sự thật duy nhất (Single Source of Truth)**:
   - **Không tạo hay phụ thuộc bảng phụ `app_settings`**: Phân quyền nhân viên được cấu hình trực tiếp bằng việc bật/tắt các Lego Modules trong vai trò (`store_roles.modules`). Client và Server tuyệt đối không bắt buộc phải có bản ghi cấu hình `app_settings` (`action_perms_*`) thì mới cho phép thao tác.
   - **Cơ chế suy diễn quyền tự động (`deriveActionPermsFromModules`)**: Các quyền tương ứng tự động được cấp theo module mà vai trò sở hữu (ví dụ: `pos`, `ban`, `kho`, `finance`, `report`, `tinhluong`).

2. **Owner (Chủ quán) — Toàn quyền cố định & Manager (Quản lý) — Quy chuẩn phân quyền**:
   - **Owner (Chủ quán)**: Xác nhận qua `store_members` (`is_owner = true`) hoặc `stores.owner_user_id`: **Có toàn quyền tất cả action permissions** trong hệ thống và toàn bộ 9 quyền AI Bum (chứng minh qua `permission_provider.dart` L18-19 và `permission_guard_test.dart` Test 1).
   - **Manager (Quản lý)**:
     - *Bằng chứng code & test thực tế*: `staff_service.dart` định nghĩa `kAllActions` chỉ gồm 16 quyền vận hành POS thông thường (`pos.*`, `ban.*`, `kho.*`, `finance.*`, `report.*`, `tinhluong.*`, `printer.*`), không hề chứa `ai_bum.*`. Trong `permission_guard_test.dart` (Test 0b & Test 2), `isServerConfirmedAiOwner({'role': 'manager', 'is_owner': false})` trả về `false`.
     - *Quy tắc áp dụng*: Vai trò Manager có toàn bộ 16 quyền vận hành POS thông thường (`kAllActions`), nhưng **không mặc nhiên được cấp các quyền AI Bum nhạy cảm** (`ai_bum.sales`, `ai_bum.inventory`, `ai_bum.finance`, `ai_bum.operations`, `ai_bum.team_shift`, `ai_bum.all_payroll`). Khi bật module `ai_bum`, Manager chỉ mặc định nhận 3 quyền an toàn cá nhân (`help`, `my_shift`, `my_payroll`). Mọi quyền nhạy cảm khác tuân thủ nguyên tắc fail-closed, cần Chủ Quán chủ động cấp qua Lego Modules (`store_roles.modules`) hoặc giao diện phân quyền.

3. **Cashier (Thu ngân)**:
   - Vai trò `cashier` hoặc tên vai trò có chứa `"thu ngân"`, `"quầy"`: Mặc nhiên có quyền thanh toán `pos.checkout`, xem lịch sử `pos.view_history`, giảm giá `pos.apply_discount`.
   - Khi có quyền module `ai_bum`, hỗ trợ hỏi đáp dữ liệu bán hàng (`ai_bum.sales`).

4. **Staff (Nhân viên thông thường)**:
   - Phân quyền kiểm soát qua việc bật/tắt module `ai_bum` trong vai trò (`store_roles.modules`).
   - Khi bật module (`OFF` $\rightarrow$ `ON`), tự động nhận 3 quyền an toàn cá nhân (`help`, `my_shift`, `my_payroll`).
   - Các quyền nhạy cảm khác (`sales`, `finance`, `inventory`, `team_shift`, `operations`, `all_payroll`) do Chủ quán chủ động cấp hoặc suy ra từ Lego Modules liên quan mà vai trò sở hữu.
   - **Fail-closed**: Nếu module `ai_bum` bị tắt hoặc vai trò không có quyền tương ứng với intent dữ liệu, AI Bum từ chối trả lời và tuyệt đối không thực thi truy vấn cơ sở dữ liệu.

---

## 5. 📚 Khung Năng Lực Tri Thức F&B Bách Khoa Toàn Thư (26 Chuyên Đề Nghiệp Vụ)

AI Bum được trang bị nền tảng tri thức chuyên sâu từ **108 nguồn thẩm quyền độc lập** (quốc tế & Việt Nam) biên soạn thành 26 chuyên đề nghiệp vụ nội bộ tại thư mục `ai-bum-implementation/learning/materials/knowledge_modules/`:

| Nhóm / Module | Tên Chuyên Đề Tri Thức | Trọng Tâm Nghiệp Vụ Thực Chiến | Nguồn Thẩm Quyền Tiêu Biểu |
|---|---|---|---|
| **Module 01** | Vận hành hằng ngày & Quản trị lượt bàn | Checklist mở/đóng ca, Float quỹ lẻ, Bảng 86, Điều phối Expo, Phàn nàn L.A.S.T, Lượt quay vòng bàn | VTOS, NRA Restaurant Operations (`SRC-OPS-001..006`) |
| **Module 02** | Bếp, Định mức AP/EP & Tồn kho FEFO | Yield %, Butcher test, Min-Max, FEFO, Đối soát lệch kho, Lưu mẫu thức ăn 24h QĐ 1246 | CIA ProChef, QĐ 1246/QĐ-BYT (`SRC-KIT-001..006`) |
| **Module 03** | Tài chính F&B, Prime Cost & Menu Matrix | Prime Cost $\le 65\%$, Food Cost $28-35\%$, BER điểm hòa vốn, Ma trận Kasavana Stars/Dogs | Jagels, Cornell CHR, Kasavana (`SRC-FIN-001..006`) |
| **Module 04** | Nhân sự, Lập lịch SPLH & Lương BLLĐ | SPLH doanh số giờ công, OJT 4 bước, Lương thêm giờ 150/200/300%, Ca đêm $+30\%$, Đêm lễ $390\%$ | Bộ luật Lao động 2019 (`SRC-HR-001..006`) |
| **Module 05** | Hệ thống nâng cao, HACCP & Sous-vide | 4 Điểm tới hạn CCPs, Vùng nguy hiểm $5-60^\circ\text{C}$, Làm lạnh nhanh 2 giai đoạn, Kỵ khí *C. botulinum* | HACCP Codex, FDA Food Code ROP (`SRC-ADV-001..005`) |
| **Module 06** | Tối ưu chuỗi F&B, Bếp Commissary | RevPASH, Nhiệt động học bao bì giao đi, Bếp trung tâm lô mẻ, Kiểm toán gian lận POS thu ngân | Kimes RevPASH, Avero POS Audit (`SRC-ADV-006..012`) |
| **Module 07** | Quản trị khủng hoảng & Pháp chế F&B | PCCC Chảo dầu Class K cấm tạt nước, Ngộ độc thực phẩm QĐ 39/2006, Hóa đơn điện tử, NĐ 100 say xỉn | NFPA 96, QĐ 39/BYT, NĐ 100/2019 (`SRC-ADV-013..018`) |
| **Module 08** | Đồ uống đặc sản, Dị ứng & Bẫy bọ IPM | SCA Coffee Dialing-in EY $18-22\%$, Giao thức Màu Tím dị ứng Big 9 (thớt tím), Bẫy keo UV IPM | SCA Standards, FDA Big 9 (`SRC-ADV-019..022`) |
| **Module 09** | Môi trường, Bẫy mỡ FOG & Khách say | Quy tắc $25\%$ bẫy mỡ NĐ 45/2022, Dầu ăn thải UCO tái chế Biodiesel, Kỹ thuật de-escalation 2m góc $45^\circ$ | NĐ 45/2022, NĐ 144/2021 (`SRC-ADV-023..025`) |
| **Module 10** | Chuyển đổi số F&B & Webhook BOM | Trừ kho tự động BOM thời gian thực qua Webhook POS-KDS, Thuật toán Grab/Shopee, Biểu giá điện EVN | TT 78/2021, EVN Power Tariff (`SRC-ADV-026..030`) |
| **Module 11** | Buffet nướng lẩu & Yến tiệc BEO | Food Cost per Cover ($32-38\%$ giá vé), Lẩu băng chuyền $0.1\text{ m/s}$ hủy đĩa sau $90\text{p}$, Lệnh tiệc BEO | BEO International, Buffet Ops (`SRC-ADV-031..034`) |
| **Module 12** | Nhượng quyền, Kiosk & Lên men | Phí nhượng quyền Royalty $3-5\%$, Kiosk 3 chạm (3-tap rule), Đồ uống lên men Kombucha/Cold brew pH $2.5-3.5$ | Luật Thương mại, NĐ 35/2006 (`SRC-ADV-035..038`) |
| **Module 13** | ATVSLĐ, Tủ thuốc cứu thương & BHXH | Luật ATVSLĐ 2015, Tủ thuốc TT 19/2016, Sơ cứu bỏng nước mát $15-20\text{p}$ cấm mỡ trăn, Đóng BHXH $32\%$ | Luật ATVSLĐ, TT 19/2016/BYT (`SRC-ADV-039..042`) |
| **Module 14** | Rượu vang, Sommelier & Hầm rượu | Quy trình 5 bước phục vụ vang CMS, Decanting nến tách cặn, Hầm rượu $12-14^\circ\text{C}$ RH $70\%$, Phí Corkage | Court of Master Sommeliers (`SRC-ADV-043..044`) |
| **Module 15** | Bánh mì, Sô-cô-la & Thanh lý bánh cũ | Baker's %, Nhiệt độ nước nhào bột DDT, Tôi nhiệt sô-cô-la Form V $31-32^\circ\text{C}$, Giảm giá sau 20h tái chế | AIB International, École Valrhona (`SRC-ADV-045..047`) |
| **Module 16** | Thu mua F&B & Chống gian lận nhận hàng | Vendor Scorecard 4 tiêu chí, Bắt bài gian lận mạ băng $>15\%$, tiêm thạch tôm, cân bì sọt rỗng, Net 30 | MIT Procurement, NAFIQPM (`SRC-ADV-048..050`) |
| **Module 17** | Rửa chén bồn 3 ngăn & Nước đá sạch | Bồn 3 ngăn $43^\circ\text{C}/77^\circ\text{C}$ Clo $50-100\text{ ppm}$, Úp ráo cấm khăn lau, Đá sạch $0\text{ CFU}$ QCVN 01-1 | FDA Food Code, QCVN 01-1:2018 (`SRC-ADV-051..054`) |
| **Module 18** | Bò Dry-Aged & Muối đỏ Charcuterie | Buồng ủ $1-3^\circ\text{C}$ RH $80-85\%$ hao hụt kép $25-35\%$, Muối đỏ #1 liều $2.5\text{g/kg}$ ($156\text{ ppm}$), Thủy phân Collagen | Texas A&M, USDA-FSIS (`SRC-ADV-055..057`) |
| **Module 19** | Bar đêm, Cân rượu dở & Âm học | Cân chai rượu dở g/ml dung sai $\le 30\text{ml}$, Jigger bắt buộc, Nhạc $120-128\text{ BPM}$, Giới hạn ồn QCVN 26:2010 | Cornell CHR, QCVN 26:2010 (`SRC-ADV-058..059`) |
| **Module 20** | Bếp mở, Khẩu lệnh Brigade & Ikejime | Khẩu lệnh Behind/Hot pan/Corner/Heard, Hạ cá nhân đạo 4 bước Ikejime phá tủy, Gastrophysics đĩa sứ | Escoffier, Tokyo Marine Univ (`SRC-ADV-060..062`) |
| **Module 21** | Ẩm thực bền vững, Chay, Halal, Kosher | Nông sản $<50\text{km}$, Chay kiêng Ngũ Vị Tân (hành tỏi hẹ), Halal cấm 100% cồn, Kosher cách ly thịt sữa $3-6\text{h}$ | HCA Halal, OU Kosher (`SRC-ADV-063..066`) |
| **Module 22** | Bia thủ công, Taproom & Thủy lực rót | Thủy lực cân bằng $P = \Delta P_{\text{line}} + \Delta P_{\text{gravity}}$, Kho bia $2.2-3.3^\circ\text{C}$, Ly sạch beer-clean, Sục rửa kiềm $14\text{ ngày}$ | Brewers Association, QCVN 6-3 (`SRC-ADV-067..069`) |
| **Module 23** | Hải sản quầy Raw Bar & Histamine | Thẻ nhuyễn thể hàu lưu 90 ngày, Khay đục lỗ thoát nước đá, Histamine cá ngừ bền nhiệt $\le 100-200\text{ ppm}$, Găng lưới thép | FDA Seafood Guide, QCVN 8-2 (`SRC-ADV-070..072`) |
| **Module 24** | Bếp trên mây Cloud Kitchen & Đơn KDS | Phụ tải điện $15-20\text{ kVA}$, Hút mùi lọc ESP $95\%$, KDS gộp đơn theo trạm $\le 3\text{p}$, Tem niêm phong túi | Cloud Kitchen Engineering (`SRC-ADV-073..075`) |
| **Module 25** | An ninh mạng POS, PCI-DSS & NĐ 13/2023 | PCI-DSS cấm lưu CVV/PIN/Track data, Báo cáo rò rỉ dữ liệu cho A05 trong $72\text{ giờ}$ (phạt tới 5% DT), VLAN cô lập, Offline POS | PCI-DSS v4.0, NĐ 13/2023/NĐ-CP (`SRC-ADV-076..078`) |
| **Module 26** | Khoa học cảm quan & Thử tam giác R&D | Thử tam giác mù kép ISO 4120 ($p=1/3$, $\alpha=0.05$), Cộng hưởng Umami $8\times$ giảm $30\%$ muối, Hoạt độ nước $a_w \le 0.85$ sốt chai | ISO 4120:2021, Umami Science (`SRC-ADV-079..084`) |

---

## 6. ⚡ Trọn Bộ 17 Cây Ma Trận Quyết Định Phản Xạ Thực Chiến (Decision Trees)

AI Bum được nạp sẵn 17 Cây ma trận phản xạ thao tác để hướng dẫn nhân viên xử lý tình huống chính xác trong vòng 30 giây:
1. **Ma trận 01:** Xử lý khiếu nại món ăn & dịch vụ theo chuẩn L.A.S.T (Đổi món mới $\le 7$ phút, nặng miễn phí món và tặng voucher 20%).
2. **Ma trận 02:** Điều phối bàn giờ cao điểm & Quản lý hàng chờ Waitlist (Dọn bàn sạch chuẩn 90 giây).
3. **Ma trận 03:** Xử lý lệch tiền két cuối ca (Thiếu $<20$k bù quỹ; Thiếu $\ge 50$k soi camera và lập biên bản).
4. **Ma trận 04:** Thẩm định đơn hàng giao đi & Nhiệt động bao bì (Đồ giòn hộp giấy Kraft đục lỗ; Món nước tách riêng; Nóng và đá tách 2 túi).
5. **Ma trận 05:** Ứng phó khẩn cấp cháy chảo dầu bếp Class K (**CẤM TẠT NƯỚC**, khóa gas, nắp đậy hoặc xịt bình Class K).
6. **Ma trận 06:** Giao thức Màu Tím xử lý đơn hàng dị ứng Big 9 (Thớt tím dao tím, chảo dầu riêng, cắm cờ tím bưng riêng).
7. **Ma trận 07:** Hạ nhiệt xung đột & Xử lý khách say xỉn ca đêm (Đứng góc $45^\circ$ cách 2m, tay mở ngang bụng, mời nước mát, hỗ trợ taxi theo NĐ 100).
8. **Ma trận 08:** Giám sát bể tách mỡ FOG (Nạo vét khi lấp đầy $\ge 25\%$; Dầu chiên thải UCO giao tái chế Biodiesel).
9. **Ma trận 09:** Xử lý phụ thu thức ăn thừa & Giới hạn giờ Buffet (Nhắc trước 15p; Thừa $>100$g tính phí mang về).
10. **Ma trận 10:** Phác đồ sơ cấp cứu bỏng dầu sôi & Vết cắt bếp (Xả nước mát $15-20$ phút, **CẤM mỡ trăn/kem đánh răng/đá lạnh**, bôi Hydrogel).
11. **Ma trận 11:** Nghiệm thu thực phẩm & Chống gian lận cân đong tại cửa sau (Cân đối chứng cân quán, trừ bì sọt rỗng, rã đông đo mạ băng $>15\%$).
12. **Ma trận 12:** Quy trình rửa chén bát bồn 3 ngăn & Tiệt trùng hóa chất (Ngăn 1 rửa $\ge 43^\circ\text{C} \rightarrow$ Ngăn 2 tráng $\rightarrow$ Ngăn 3 ngâm Clo $50-100\text{ ppm}$ hoặc nước nóng $\ge 77^\circ\text{C} \rightarrow$ **Úp ráo tự nhiên, CẤM khăn lau**).
13. **Ma trận 13:** Tiếp nhận yêu cầu chế độ ăn tôn giáo (Chay hỏi kiêng Ngũ Vị Tân; Halal cấm thịt heo và **CẤM RƯỢU CỒN**; Kosher cách ly thịt sữa).
14. **Ma trận 14:** Kiểm toán chai rượu mạnh dở cuối ca bằng cân điện tử (Tính thể tích $V = (m_{\text{cân}} - m_{\text{vỏ}})/0.94$, dung sai lệch $\le 30\text{ml}$).
15. **Ma trận 15:** Tiếp nhận & Kiểm soát an toàn hải sản quầy Raw Bar (Hàu $\le 4.4^\circ\text{C}$ khay đục lỗ, **LƯU THẺ NHÃN 90 NGÀY**; Cá ngừ $\le 4.0^\circ\text{C}$, chặn cá đứt chuỗi lạnh phòng ngộ độc Histamine).
16. **Ma trận 16:** Ứng phó sự cố gián đoạn mạng Internet & Bảo mật dữ liệu khách POS (Kích hoạt Offline SQLite mode; Bị rò rỉ dữ liệu **báo cáo A05 trong 72 giờ theo NĐ 13**).
17. **Ma trận 17:** Cân bằng thủy lực & Khắc phục sự cố trào bọt rót bia tươi taproom (Kiểm tra chênh áp $P = \Delta P_{\text{line}} + \Delta P_{\text{gravity}}$, chỉnh áp CO2, kho mát $2.2 - 3.3^\circ\text{C}$).

---

## 7. 🏗️ Kiến Trúc Học Tập & Tiếp Nạp Tri Thức (Dual-Layer Learning: RAG & SFT)

Hệ thống tiếp nạp tri thức của AI Bum vận hành theo mô hình 2 tầng (Dual-Layer Architecture):

```
┌────────────────────────────────────────────────────────────────────────┐
│                   AI BUM UNSLOTH INFERENCE ENGINE                      │
├──────────────────────────────────┬─────────────────────────────────────┤
│   TẦNG 1: RAG IN-CONTEXT PACK    │       TẦNG 2: SFT SCENARIOS         │
│  (materials/rag_knowledge/)      │   (sample_external_fnb_scenarios)   │
│  - fnb_operations_knowledge_pack │   - 26 Kịch bản thực chiến mẫu      │
│  - decision_trees_quick_ref      │   - 7 Nhóm câu hỏi cốt lõi          │
│  - fnb_knowledge_retrieval_chunks│   - Ngân hàng bài tập SFT chuẩn hóa │
│  => Truy xuất SQLite FTS5 (<2ms) │   => Unsloth FastLanguageModel SFT  │
└──────────────────────────────────┴─────────────────────────────────────┘
```

### Nguyên Tắc Quản Trị SHTT & An Toàn Dữ Liệu (IP & Data Governance):
1. **Zero Verbatim Ingestion (`allowed_in_train: false`)**: Các tài liệu sách thương mại có bản quyền quốc tế tuyệt đối không được nạp nguyên văn (verbatim text) vào prompt hay tập dữ liệu train của AI Bum. Toàn bộ học liệu đã được Việt hóa, chuyển hóa thành khung phương pháp luận độc lập.
2. **Zero PII & Zero Business Secrets**: Tuyệt đối không sử dụng dữ liệu khách hàng thật, số điện thoại, mật khẩu, doanh thu bí mật của quán thực tế vào tập dữ liệu học tập.
3. **Missing-Data Caution**: Luôn kích hoạt cờ nhận diện dữ liệu thiếu; nếu đề bài thiếu dữ liệu quan trọng, Bum từ chối kết luận võ đoán.
4. **Phiên bản quản lý dữ liệu**: Mọi tệp tin học liệu, kịch bản mẫu và RAG pack đều được đăng ký mã băm SHA-256 toàn vẹn trong [MANIFEST.json](file:///Users/banhbao/Quan%20Nho/ai-bum-implementation/learning/materials/MANIFEST.json).

---

## 8. 🚀 Nền Tảng Mô Hình: Qwen2.5 Tối Ưu Bằng Framework Unsloth

### A. Định Danh & Kiến Trúc Nền Tảng (Platform Architecture & Identity)
- **Base Model & Framework**: AI Bum sử dụng base model `unsloth/Qwen2.5-3B-Instruct-bnb-4bit` (Alibaba Qwen2.5), kết hợp framework **Unsloth** (`FastLanguageModel`) để tối ưu hóa bộ nhớ và tăng tốc huấn luyện LoRA/QLoRA.
- **Sở hữu trí tuệ**: Quán Nhỏ sở hữu tập dữ liệu tự tạo và các trọng số LoRA adapter được huấn luyện riêng của dự án, tuân thủ giấy phép nguồn mở của base model Qwen2.5 (Apache 2.0 / Qwen Community License) và các thư viện liên quan.

### B. So Sánh Hiệu Năng: Framework Unsloth vs Transformers Tiêu Chuẩn

| Tiêu Chí Kỹ Thuật | Huấn Luyện Transformers Tiêu Chuẩn | Tối Ưu Bằng Framework Unsloth | Đánh Giá Thực Tế Tại Quán Nhỏ |
| :--- | :--- | :--- | :--- |
| **Base Model Architecture** | Qwen2.5 kiến trúc chuẩn | Qwen2.5 nạp qua `FastLanguageModel` | Đồng nhất kiến trúc base model; không phải kiến trúc mô hình mới độc lập. |
| **Tiêu hao VRAM GPU** | Tốn VRAM lớn khi huấn luyện; dễ chạm trần VRAM trên card phổ thông (RTX 2060 6GB). | Giảm đáng kể VRAM (tham chiếu tài liệu Unsloth công bố tới ~70% VRAM nhờ Triton kernels và 4-bit). | Giúp train được LoRA trên card RTX 2060 6GB local với `MAX_SEQ_LENGTH = 512` an toàn. |
| **Tốc độ Huấn Luyện** | Tốc độ tiêu chuẩn HuggingFace Transformers. | Tăng tốc độ tính toán (tham chiếu Unsloth công bố 2–5x qua Manual Backprop Kernels). | Cho phép train các mẻ nhỏ nhanh chóng; các con số hiệu năng là số liệu công bố tham khảo của framework. |
| **Quản lý Trọng Số (Weights)** | Xuất LoRA adapter thông thường. | Hỗ trợ xuất LoRA adapter, merge 16-bit hoặc export GGUF linh hoạt. | Quán Nhỏ quản lý bộ adapter LoRA riêng; base model vẫn là Qwen2.5. |
| **Ngân sách Ngữ cảnh (Context Window)** | Mặc định theo tokenizer model. | Tối ưu hóa attention kernel; hỗ trợ mở rộng khi phần cứng đáp ứng. | Hiện hành cố định an toàn ở `MAX_SEQ_LENGTH = 512`; 1024 là đích thử nghiệm tương lai, chưa áp dụng production. |

### C. Quy Chuẩn Đồng Bộ Hóa Kỹ Thuật (System-Wide Specification)
1. **Dịch vụ suy luận BunServer (`unsloth_inference_service.py`)**:
   - Backend: `unsloth` (`FastLanguageModel`) nạp base model Qwen2.5.
   - Định danh hệ thống: `service: "ai-bum-unsloth-inference"`, base model `unsloth/Qwen2.5-3B-Instruct-bnb-4bit`.
   - Ngân sách ngữ cảnh: Cố định `MAX_SEQ_LENGTH = 512` tokens (ngưỡng an toàn thực tế đã nghiệm thu).
2. **Dịch vụ huấn luyện (`train_bum.py` & `engine.py`)**:
   - Khởi tạo qua `FastLanguageModel.from_pretrained("unsloth/Qwen2.5-3B-Instruct-bnb-4bit", max_seq_length=512, load_in_4bit=True)`.
   - Cấu hình LoRA rank chuẩn ($r=16, \alpha=32$), `target_modules = ["q_proj", "k_proj", "v_proj", "o_proj", "gate_proj", "up_proj", "down_proj"]`.
3. **Ứng dụng Flutter POS & AI Gateway**:
   - Tên hiển thị người dùng: **Trợ lý AI Bum**. Hệ thống ghi nhận đúng nguồn gốc: AI Bum vận hành trên base model Qwen2.5 tối ưu bởi framework Unsloth.
