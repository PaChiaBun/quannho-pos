# 🏆 Module: Khách hàng / Tích điểm

**Trạng thái:** ✅ Hoàn thành (Wallet + Stamp Card + Gói Nạp)
**Cập nhật:** 16/05/2026

---

## Mục Đích

Giữ chân khách hàng qua 3 cơ chế song song:
1. **Điểm tích lũy** — mỗi đơn hàng cộng điểm, đổi điểm lấy ưu đãi
2. **Ví khách hàng** — nạp tiền trước, dùng khi mua (Real + Bonus wallet)
3. **Stamp card** — tích đủ tem → nhận thưởng (thay thẻ giấy truyền thống)

---

## Tính Năng Chính

### 🪙 Điểm Tích Lũy (Points)
- Tự động cộng điểm sau mỗi đơn thanh toán thành công
- Tỉ lệ: chủ quán cài trong Cài đặt (`loyalty_rate`)
- Đổi điểm: 1 điểm = `loyalty_redeem_rate` VNĐ giảm giá (mặc định 1.000đ/điểm)
- Xem lịch sử điểm từng khách theo thời gian

### 💳 Ví Khách Hàng (Wallet)
Mỗi khách có **2 loại số dư độc lập**:

| Loại | Mô tả | Ghi chú |
|------|-------|---------|
| **Ví thật (Real)** | Tiền khách nạp vào — không mất hạn | Dùng thanh toán không giới hạn |
| **Ví thưởng (Bonus)** | Tiền quán tặng theo gói nạp — có thể có hạn | Tối đa `bonus_cap_pct`% /bill |

**Luồng nạp tiền:**
```
Khách nạp 500.000đ
  → Gói Vàng áp dụng (nạp ≥ 500K): bonus 15%
  → Real += 500.000đ | Bonus += 75.000đ
  → Ghi finance_records income (is_auto=true, chống gian lận thu ngân)
  → Ghi balance_transactions (2 dòng: topup_real + topup_bonus)
```

**Luồng thanh toán bằng ví:**
```
Bill 200.000đ, khách chọn "Thanh toán bằng Ví"
  → Tính bonus dùng được: tối đa 15% × 200K = 30.000đ
  → Dùng Bonus trước: bonusUsed = min(bonusBal, 30.000)
  → Dùng Real cho phần còn lại: realUsed = bill - bonusUsed
  → Nếu ví không đủ → báo thiếu bao nhiêu (thu thêm tiền mặt/QR)
  → Cập nhật real_balance, bonus_balance
  → Ghi balance_transactions (spend_real + spend_bonus)
```

### 🎁 Gói Nạp (Topup Packages)
Chủ quán tạo các mốc ưu đãi để khuyến khích nạp nhiều:

| Gói | Nạp từ | Bonus thêm |
|-----|--------|-----------|
| Gói Đồng | 100.000đ | +5% |
| Gói Bạc | 200.000đ | +10% |
| Gói Vàng | 500.000đ | +15% |
| Gói Bạch Kim | 1.000.000đ | +20% |
| Gói Kim Cương | 2.000.000đ | +30% |

> App tự chọn gói cao nhất phù hợp với số tiền khách nạp.

### 📮 Stamp Card (Thẻ Tích Tem)
- Mỗi đơn hàng đủ điều kiện → +1 tem
- Đủ `stamp_threshold` tem (mặc định 10) → nhận thưởng
- `stamp_count`: tem vòng hiện tại (reset về 0 sau khi đủ)
- `stamp_total`: tổng tem tích lũy toàn thời gian (không reset)

---

## Phần Thưởng Đổi Điểm (Rewards)
- Chủ quán tạo danh sách phần thưởng: tên + số điểm cần + giá trị giảm giá
- Khách xem và đổi điểm ngay trong app
- Hệ thống tự trừ điểm + ghi lịch sử

---

## Cấu Trúc Data Liên Quan

### Bảng `customers` (cột wallet)
| Cột | Mô tả |
|-----|-------|
| `loyalty_pts` | Điểm tích lũy hiện tại |
| `real_balance` | Số dư ví thật |
| `bonus_balance` | Số dư ví thưởng |
| `bonus_cap_pct` | % tối đa bonus dùng/bill (mặc định 15%) |
| `bonus_expires_at` | Hạn dùng bonus (null = không hết hạn) |
| `total_topup` | Tổng tiền đã nạp toàn thời gian |
| `stamp_count` | Số tem hiện tại (vòng này) |
| `stamp_total` | Tổng tem toàn thời gian |

### Bảng `balance_transactions` (lịch sử ví)
| Type | Ý nghĩa |
|------|---------|
| `topup_real` | Nạp tiền thật |
| `topup_bonus` | Nhận thưởng từ gói nạp |
| `spend_real` | Dùng ví thật thanh toán |
| `spend_bonus` | Dùng ví thưởng thanh toán |
| `bonus_expired` | Bonus hết hạn tự trừ |
| `refund` | Hoàn tiền |

### Bảng `topup_packages`
Lưu các gói nạp chủ quán tạo ra (tên, min_amount, bonus_pct).

### Bảng `loyalty_transactions`
Lịch sử điểm (pts_earned / pts_used) theo từng đơn hàng.

### Bảng `loyalty_rewards`
Danh sách phần thưởng có thể đổi điểm.

---

## Kết Nối Module Khác

- **← Bán hàng (POS):** Thanh toán xong → cộng điểm, trừ ví, ghi lịch sử
- **← Quản lý Bàn:** Checkout bàn → tương tự POS (trừ ví nếu dùng)
- **→ Thu Chi:** Nạp ví → tự ghi khoản "Thu - Nạp ví" (is_auto=true)

---

## Câu Hỏi Thường Gặp Bum Sẽ Trả Lời

| Câu hỏi | Trả lời gợi ý |
|---------|-------------|
| *"Khách hỏi ví còn bao nhiêu?"* | Tra theo SĐT → hiện Real + Bonus + hạn dùng bonus |
| *"Tôi muốn tạo gói nạp mới"* | Vào Điểm Tích → tab Gói Nạp → nhấn + → nhập tên/mốc/% |
| *"Khách đủ tem chưa?"* | Hiện stamp_count / stamp_threshold (vd: 7/10 tem) |
| *"Bonus đã hết hạn chưa?"* | Kiểm tra bonus_expires_at so với ngày hôm nay |
| *"Hôm nay nạp ví bao nhiêu?"* | Query finance_records type=income, description LIKE 'Nạp ví%' |
| *"Khách nào ví nhiều nhất?"* | Sort theo real_balance + bonus_balance giảm dần |

---

## Lưu Ý Nghiệp Vụ Quan Trọng

> ⚠️ **Bonus Cap:** Ví thưởng chỉ được dùng tối đa `bonus_cap_pct`% giá trị bill — tránh khách lạm dụng dùng toàn bonus.

> ⚠️ **Finance Auto-Record:** Mỗi lần nạp ví → ghi `finance_records` với `is_auto=true`. Thu ngân không thể xoá khoản này — chống gian lận.

> ⚠️ **Bonus Expires:** Nếu `bonus_expires_at` đã qua → toàn bộ bonus bị coi là 0 khi thanh toán. Chủ quán có thể gia hạn thủ công.
