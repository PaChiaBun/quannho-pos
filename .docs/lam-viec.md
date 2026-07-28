# Phong Cách Làm Việc — Quán Nhỏ POS

> Dựa trên nguyên tắc Andrej Karpathy cho AI coding assistant.
> Mỗi khi dev, bạn PHẢI tuân theo 4 nguyên tắc này.

---

## 🤝 Quy Tắc Làm Việc Với Chủ Dự Án

| # | Quy tắc | Chi tiết |
|---|---|---|
| 1 | **Lập kế hoạch trước** | Mọi task đều phải: lập kế hoạch → xin duyệt → mới làm |
| 2 | **Giải thích thuật ngữ** | Khi dùng từ kỹ thuật tiếng Anh → giải thích bằng ví dụ thực tế (quán ăn, lego...) |
| 3 | **Thấy bug → đề cập, không tự sửa** | Báo cho biết, hỏi có muốn sửa không |
| 4 | **Khi mơ hồ → trình bày 2-3 cách hiểu** | Để chủ dự án chọn, không tự đoán |
| 5 | **Chỉ báo khi có vấn đề** | Không làm phiền khi đang chạy tốt |
| 6 | **Vừa làm vừa giải thích** | Dạy kèm từng bước để chủ dự án học theo |
| 7 | **Chủ dự án tự test** | Bạn chạy thử trên máy thật và báo lại |
| 8 | **Comment song ngữ** | Tiếng Việt cho nghiệp vụ, tiếng Anh cho kỹ thuật |
| 9 | **Không thêm thư viện tùy tiện** | Ưu tiên tự làm, nếu thực sự cần thì đề xuất + giải thích lý do |
| 10 | **Thay đổi lớn phải báo trước** | Di chuyển file, đổi tên, tái cơ cấu → báo → giải thích → xác nhận → mới làm |

---


---

## 1. 🧠 Suy Trước Khi Code
**Không đoán mò. Nêu rõ giả định. Hỏi khi mơ hồ.**

- Nếu không chắc → hỏi, đừng tự đoán và chạy luôn
- Nếu có nhiều cách hiểu → trình bày rõ, không tự chọn im lặng
- Nếu có cách đơn giản hơn → nói ra, đừng làm phức tạp theo yêu cầu
- Nếu bị rối → dừng lại, nêu tên vấn đề, hỏi rõ

---

## 2. ✂️ Đơn Giản Là Số 1
**Code tối thiểu giải quyết được vấn đề. Không thêm thứ không được yêu cầu.**

- Không thêm tính năng ngoài yêu cầu
- Không tạo abstraction cho code chỉ dùng 1 lần
- Không thêm "linh hoạt" hay "cấu hình được" khi không ai hỏi
- Không xử lý lỗi cho tình huống không thể xảy ra
- **Nếu 200 dòng có thể viết 50 → viết lại**

> ✅ Kiểm tra: Một senior engineer có thấy đây là over-engineer không? Nếu có → đơn giản hoá.

---

## 3. 🔬 Chỉnh Sửa Phẫu Thuật
**Chỉ động vào đúng chỗ được yêu cầu. Không sửa lung tung.**

Khi sửa code hiện có:
- Không "cải thiện" code/comment/format xung quanh
- Không refactor thứ không bị hỏng
- Giữ nguyên style hiện tại dù bạn muốn làm khác
- Nếu thấy dead code không liên quan → **đề cập, đừng tự xóa**

Khi thay đổi của bạn tạo ra orphan:
- Xóa import/biến/hàm mà **chính bạn làm thừa**
- Không xóa dead code có sẵn trừ khi được yêu cầu

> ✅ Kiểm tra: Mỗi dòng thay đổi có truy ngược được về yêu cầu của user không?

---

## 4. 🎯 Thực Thi Theo Mục Tiêu
**Định nghĩa tiêu chí thành công. Loop đến khi đạt được.**

Chuyển đổi yêu cầu thành mục tiêu cụ thể có thể kiểm tra:

| Thay vì... | Chuyển thành... |
|---|---|
| "Thêm validation" | "Viết test cho input sai, rồi làm cho pass" |
| "Fix bug này" | "Tái hiện bug bằng test, rồi fix cho pass" |
| "Refactor X" | "Đảm bảo test pass trước và sau khi refactor" |

Với task nhiều bước, nêu kế hoạch ngắn gọn:
```
1. [Bước] → kiểm tra: [điều kiện]
2. [Bước] → kiểm tra: [điều kiện]
3. [Bước] → kiểm tra: [điều kiện]
```

---

## ⚖️ Lưu Ý
Các nguyên tắc này **ưu tiên cẩn thận hơn tốc độ**.
Với task đơn giản (sửa typo, one-liner rõ ràng) → dùng phán đoán, không cần áp dụng cứng nhắc.

Mục tiêu: **Giảm sai sót tốn kém cho task phức tạp**, không phải làm chậm task đơn giản.

---

*Nguồn: [Andrej Karpathy](https://x.com/karpathy/status/2015883857489522876) · Adapt bởi forrestchang*

---

## 🎨 Nguyên Tắc Thiết Kế UI

> Tham khảo từ Baemin Vietnam — app giao đồ ăn có thiết kế được yêu thích nhất VN (2019–2023).

| Nguyên tắc | Áp dụng vào Quán Nhỏ |
|---|---|
| Font đậm, tròn, chunky | Outfit 900 + bo góc — đang làm đúng |
| 1 màu hero + nền sáng + 1 accent | Navy `#1C2151` + Kem `#FFF8F0` + Cam `#FF6B35` |
| Whitespace nhiều — không nhét chật | Cân nhắc khi thêm màn hình mới |
| Rounded corners nhất quán (16–20px) | Áp dụng toàn bộ card, sheet, button |
| Spring animation khi tap | Dùng `flutter_animate` — đã có sẵn |
| Tên + giá contrast cao, font rất lớn | POS: tên to, giá rõ, bấm nhanh |
| Section headers rõ ràng | Tiếp tục giữ pattern hiện tại |

> ⚠️ **Lưu ý POS**: Người dùng là nhân viên — đã biết món. Ưu tiên **tên to, giá rõ, bấm nhanh**. Không cần ảnh đẹp như app consumer.

### Responsive — Quy Tắc Bắt Buộc (từ 2026-04-30)

```dart
// ✅ Mọi màn hình mới PHẢI bọc bằng ResponsiveLayout
return ResponsiveLayout(
  mobile:  _MobileView(),
  tablet:  _TabletView(),
  desktop: _DesktopView(),
);

// ✅ Nút tối thiểu 52px (cảm ứng desktop/tablet)
SizedBox(height: 52, child: ElevatedButton(...))

// ✅ Không hardcode width
width: Responsive.isDesktop(context) ? 400 : double.infinity
```

**3 breakpoint chuẩn:**
- 📱 Mobile `< 600px` — Điện thoại nhân viên
- 📟 Tablet `600–1024px` — Tablet bếp treo tường
- 🖥️ Desktop `≥ 1024px` — Máy tính tiền POS cảm ứng

---

### 📝 Quy Tắc Audit Logging (Bắt Bắt Bắt Buộc từ 2026-07-28)

> **Mọi module mới khi phát triển PHẢI chèn `AppLogger.logUserAction(...)` tại tất cả các sự kiện thay đổi dữ liệu hoặc hành vi người dùng.**

```dart
// ✅ Mọi thao tác tạo, sửa, xóa, đổi trạng thái, thanh toán, phân quyền PHẢI ghi log:
AppLogger.logUserAction(
  tag: 'module_name', // 'pos' | 'table' | 'kitchen' | 'kho' | 'finance' | 'staff' | 'settings'
  action: 'Tên hành động mô tả rõ ràng (ví dụ: Tạo đơn hàng #QN-001)',
  details: {'key': 'value'}, // JSON chi tiết bổ sung
);
```
