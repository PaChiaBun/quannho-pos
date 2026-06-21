# 📊 Data Context — Bum Được Phép Đọc Gì?

---

## Nguyên Tắc

Bum được xem **toàn bộ data** của quán để đưa ra phân tích hợp lý. Chủ quán là người kiểm soát — Bum không tự ý chia sẻ data ra ngoài.

---

## Data Bum Nhận Được Mỗi Request

Khi user mở chat với Bum, Flutter app sẽ tự động thu thập và inject data này vào context:

### 📍 Ngữ Cảnh Hiện Tại
```json
{
  "current_screen": "finance_screen",     // màn hình đang mở
  "user_role": "owner",                   // owner | manager | staff
  "user_name": "Kay",
  "store_name": "Quán Nhỏ",
  "current_time": "2026-04-29T11:00:00+07:00"
}
```

### 💰 Dữ Liệu Tài Chính Hôm Nay
```json
{
  "today_revenue": 2500000,
  "today_orders": 15,
  "today_customers": 22,
  "today_profit": 1800000,
  "today_expenses": 700000,
  "vs_yesterday_pct": -12.3
}
```

### 📦 Tồn Kho (nếu module Kho bật)
```json
{
  "low_stock_items": ["Cà phê sữa", "Trà đào"],
  "out_of_stock_items": []
}
```

### 👥 Nhân Viên (nếu là owner/manager)
```json
{
  "total_staff": 5,
  "on_shift_now": 3,
  "staff_on_shift": ["Minh", "Lan", "Hùng"]
}
```

### 🪑 Bàn (nếu module Bàn bật)
```json
{
  "total_tables": 12,
  "occupied_tables": 7,
  "available_tables": 5
}
```

---

## Ví Dụ Prompt Được Inject

```
[DATA QUÁN HÔM NAY - 29/04/2026 11:00]
- Màn hình hiện tại: Thu Chi
- Người dùng: Kay (Chủ quán)
- Doanh thu hôm nay: 2,500,000đ (15 đơn, 22 khách)
- Lợi nhuận: 1,800,000đ | Chi phí: 700,000đ
- So với hôm qua: -12.3% ⚠️
- Đang có 3/5 nhân viên làm việc
- Bàn: 7/12 đang có khách
- Kho sắp hết: Cà phê sữa, Trà đào
```

---

## Phân Cấp Quyền Xem Data

| Vai trò | Data được thấy |
|---------|---------------|
| Owner | Tất cả — doanh thu, nhân viên, lương, lợi nhuận |
| Manager | Doanh thu, nhân viên, kho — không thấy chi tiết tài chính nội bộ |
| Staff | Chỉ data liên quan đến module họ được cấp quyền |

---

## Khi Bum Phân Tích Data

**Ví dụ — Chủ quán hỏi "Hôm nay thế nào?":**

> *"Anh Kay ơi, hôm nay doanh thu đạt 2.5 triệu — thấp hơn hôm qua 12.3% anh ạ. Bum thấy số đơn buổi chiều từ 14h–17h khá ít (chỉ 3 đơn). Kho cũng sắp hết cà phê sữa với trà đào — anh nhập thêm chưa ạ?"*

**Bum KHÔNG làm:**
- Không đoán mò nếu không có data
- Không so sánh với quán khác (không có data)
- Không đưa ra con số không có trong data thực

---

## Cập Nhật Data Realtime

- Data được thu thập **mỗi khi user mở chat** (không cache cũ)
- Nếu user hỏi về data cụ thể → Flutter query thêm từ SQLite local / Supabase
- Bum **không tự query database** — chỉ đọc data được Flutter inject vào

---

## 🕐 Ca Làm Việc (Shift) — Cập nhật 17/05/2026

### Cách kết nối data ca làm việc:

```
store_shift_configs (bảng ca)
  id, store_id, name, start_hour, start_minute, end_hour, end_minute, color

store_members (nhân viên)
  shift_config_id → FK → store_shift_configs.id
  (1 nhân viên = 1 ca tại 1 thời điểm)
```

### Data Bum nhận về ca:
```json
{
  "current_shift": {
    "name": "Ca Sáng",
    "time_label": "06:00 – 14:00",
    "is_active": true
  },
  "staff_shift_map": [
    { "staff": "Minh", "shift": "Ca Sáng" },
    { "staff": "Lan",  "shift": "Ca Chiều" }
  ]
}
```

### Logic detect ca hiện tại:
- `ShiftConfig.isCurrentShift(DateTime now)` → so sánh `startHour:startMinute` ≤ now < `endHour:endMinute`
- Hỗ trợ ca qua đêm: nếu `endHour < startHour` thì wrap around 24h
- Kết quả → hiển thị badge xanh "Ca Sáng • 06:00–14:00" trong progress header

---

## ⚙️ Vận Hành (Operations) — Cập nhật 17/05/2026

### Cách kết nối data Vận Hành:

```
ops_task_templates (template công việc)
  store_role_id    → FK → store_roles.id   (vai trò nào thấy task)
  shift_config_id  → FK → store_shift_configs.id (ca nào thấy task)
  assigned_staff_ids → UUID[] (assign cá nhân — ưu tiên cao nhất)

ops_daily_logs (log hàng ngày)
  template_id → FK → ops_task_templates.id
  staff_id    → FK → user_accounts.id
  log_date    → DATE (YYYY-MM-DD)
  is_completed, completed_at, notes
```

### Data Bum nhận về Vận Hành (Manager view):
```json
{
  "ops_today": {
    "date": "2026-05-17",
    "total_tasks": 48,
    "completed_tasks": 35,
    "completion_rate": "72.9%",
    "by_staff": [
      { "name": "Minh", "done": 8, "total": 8, "pct": "100%" },
      { "name": "Lan",  "done": 5, "total": 8, "pct": "62.5%" }
    ],
    "pending_critical": ["Lau sàn trước giờ mở cửa"]
  }
}
```

### Shift Gating Logic (quan trọng để Bum hiểu):
```
Khi nhân viên mở tab "Nhiệm Vụ":
  1. Load tất cả templates
  2. Filter theo: assigned_staff_ids chứa userId → LUÔN HIỆN
  3. Filter theo: storeRoleId == null HOẶC khớp role nhân viên
  4. Filter theo: shiftConfigId == null HOẶC khớp ca hiện tại
  5. ensureMyLogsToday() tạo daily_log cho từng template pass filter
  6. Nhân viên thấy đúng task của mình trong ca đó
```

### Câu hỏi Bum cần biết xử lý:
- *"Tại sao nhân viên A không thấy task X?"*
  → Kiểm tra: (1) task.storeRoleId ≠ role của A, (2) task.shiftConfigId ≠ ca hiện tại, (3) A không có trong assignedStaffIds
- *"Task tự động tạo mỗi ngày không?"*
  → Có — `ensureMyLogsToday()` seed khi NV mở tab Nhiệm Vụ, không cần quản lý thủ công
- *"Owner thấy bao nhiêu task?"*
  → Owner thấy TẤT CẢ templates (không lọc ca/role) — để review toàn bộ
